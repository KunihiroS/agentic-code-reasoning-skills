The behavior comes from a gap between **where authentication fails** and **where cookies are cleared**.

### 1) The HTTP auth middleware only clears cookies on the explicit logout endpoint
`internal/server/auth/http.go:26-47`

```go
if r.Method != http.MethodPut || r.URL.Path != "/auth/v1/self/expire" {
    next.ServeHTTP(w, r)
    return
}
```

Only `PUT /auth/v1/self/expire` triggers cookie deletion:

```go
for _, cookieName := range []string{stateCookieKey, tokenCookieKey} {
    cookie := &http.Cookie{
        Name:   cookieName,
        Value:  "",
        Domain: m.config.Domain,
        Path:   "/",
        MaxAge: -1,
    }
    http.SetCookie(w, cookie)
}
```

So for any other request, the middleware just forwards the request and **does not inspect the response**, which means it cannot clear cookies on a later `401 Unauthorized` response.

---

### 2) The auth interceptor rejects expired/invalid cookie tokens with `Unauthenticated`
`internal/server/auth/middleware.go:74-116`

This is the main failure path:

- It accepts tokens from either:
  - `Authorization: Bearer ...`
  - or the cookie forwarded via `grpcgateway-cookie`
- It extracts the cookie token here:

```go
func clientTokenFromMetadata(md metadata.MD) (string, error) {
    if authenticationHeader := md.Get(authenticationHeaderKey); len(authenticationHeader) > 0 {
        return clientTokenFromAuthorization(authenticationHeader[0])
    }

    cookie, err := cookieFromMetadata(md, tokenCookieKey)
    if err != nil {
        return "", err
    }

    return cookie.Value, nil
}
```

- Then it looks up the token and checks expiry:

```go
auth, err := authenticator.GetAuthenticationByClientToken(ctx, clientToken)
...
if auth.ExpiresAt != nil && auth.ExpiresAt.AsTime().Before(time.Now()) {
    return ctx, errUnauthenticated
}
```

So an expired or invalid cookie token is turned into `codes.Unauthenticated`.

---

### 3) The HTTP server wires the auth middleware around the gRPC gateway, but does not add any unauthenticated-error cookie cleanup
`internal/cmd/auth.go:112-145`

The `/auth/v1` gateway is mounted like this:

```go
authmiddleware = auth.NewHTTPMiddleware(cfg.Session)
middleware := []func(next http.Handler) http.Handler{authmiddleware.Handler}
...
r.Use(middleware...)
r.Mount("/auth/v1", gateway.NewGatewayServeMux(muxOpts...))
```

For OIDC, there is a forward-response hook only for successful callback responses:

```go
runtime.WithForwardResponseOption(oidcmiddleware.ForwardResponseOption),
```

But there is **no `WithErrorHandler` or similar hook** here to clear cookies when the gRPC gateway returns an error response.

---

### 4) The server methods and gRPC error translation also produce `Unauthenticated`
`internal/server/auth/server.go:40-49, 89-104`

These endpoints also return `errUnauthenticated` when no auth context exists:

```go
return nil, errUnauthenticated
```

And the generic gRPC error interceptor maps app-level unauthenticated errors to gRPC `codes.Unauthenticated`:

`internal/server/middleware/grpc/middleware.go:34-65`

```go
case errs.AsMatch[errs.ErrUnauthenticated](err):
    code = codes.Unauthenticated
```

So the request ends up as an unauthenticated HTTP response, but nothing in the HTTP layer clears the cookies for that path.

---

### 5) Evidence that cookie clearing is only tested for logout
`internal/server/auth/http_test.go:11-33`

The test only checks that cookies are cleared for `PUT /auth/v1/self/expire`. There is no code path or test showing cookie invalidation on unauthenticated error responses.

---

## Summary
The bug is caused by these combined code paths:

1. **`auth.UnaryInterceptor`** accepts cookie tokens and returns `Unauthenticated` for invalid/expired tokens.
2. **`authenticationHTTPMount`** mounts the gRPC gateway without an error-response hook.
3. **`auth.HTTPMiddleware.Handler`** clears cookies **only** for `PUT /auth/v1/self/expire`, not for `401`/`Unauthenticated` responses.

That’s why browsers keep sending the stale cookie: the server rejects it, but never sends `Set-Cookie` headers to expire it on authentication failure.
