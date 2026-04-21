Mode: explain

QUESTION:
What specific code paths and logic are responsible for authentication cookies not being cleared after unauthenticated responses from expired or invalid tokens?

PREMISES:
P1: The reported behavior is about the HTTP auth flow and the `flipt_client_token` cookie.
P2: Cookie creation, forwarding, auth validation, and error rendering are split across auth middleware and gateway code.
P3: The only cookie-deletion logic I found is in the auth HTTP middleware’s `ErrorHandler` / logout `Handler`, not in token validation itself.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `authenticationHTTPMount` | `internal/cmd/authn.go:247-287` | `(ctx context.Context, logger *zap.Logger, cfg config.AuthenticationConfig, r chi.Router, conn grpc.ClientConnInterface)` | `void` | Builds the `/auth/v1` gateway, installs `runtime.WithErrorHandler(authmiddleware.ErrorHandler)`, and when sessions are enabled also installs cookie forwarding and the callback response option. |
| `ForwardCookies` | `internal/server/authn/method/http.go:44-55` | `(ctx context.Context, req *http.Request)` | `metadata.MD` | Reads `flipt_client_state` and `flipt_client_token` from the incoming HTTP request and forwards their values as gRPC metadata; it does not clear cookies. |
| `ForwardResponseOption` | `internal/server/authn/method/http.go:69-101` | `(ctx context.Context, w http.ResponseWriter, resp proto.Message)` | `error` | On auth callback responses, sets `flipt_client_token` as a cookie and redirects; this is where the client token cookie is established. |
| `Handler` | `internal/server/authn/middleware/http/middleware.go:32-45` | `(next http.Handler)` | `http.Handler` | Clears both auth cookies only for `PUT /auth/v1/self/expire`, then delegates to the wrapped handler. |
| `ErrorHandler` | `internal/server/authn/middleware/http/middleware.go:47-60` | `(ctx context.Context, sm *runtime.ServeMux, ms runtime.Marshaler, w http.ResponseWriter, r *http.Request, err error)` | `void` | Clears cookies only when `status.Code(err) == codes.Unauthenticated` and the request contained `flipt_client_token`; then delegates to the default HTTP error handler. |
| `clearAllCookies` | `internal/server/authn/middleware/http/middleware.go:63-76` | `(w http.ResponseWriter)` | `void` | Emits `Set-Cookie` deletions for both `flipt_client_state` and `flipt_client_token` with `MaxAge: -1`. |
| `ClientTokenAuthenticationUnaryInterceptor` | `internal/server/authn/middleware/grpc/middleware.go:326-346` | `(logger *zap.Logger, authenticator ClientTokenAuthenticator, o ...containers.Option[InterceptorOptions])` | `grpc.UnaryServerInterceptor` | Calls `authenticateClientToken`; on error it returns the error upstream. |
| `authenticateClientToken` | `internal/server/authn/middleware/grpc/middleware.go:377-421` | `(ctx context.Context, logger *zap.Logger, authenticator ClientTokenAuthenticator)` | `(context.Context, error)` | Extracts the token from metadata, looks up authentication, and returns `errUnauthenticated` when the token is missing/invalid or the auth record is expired. |
| `clientTokenFromMetadata` | `internal/server/authn/middleware/grpc/middleware.go:471-483` | `(md metadata.MD)` | `(string, error)` | Pulls the token from `authorization` or from the forwarded cookie metadata. |
| `ErrorUnaryInterceptor` / `handleError` | `internal/server/middleware/grpc/middleware.go:39-103` | `(ctx context.Context, req any, ... )` / `(ctx context.Context, err error)` | `(any, error)` / `error` | Converts project-local `errors.ErrUnauthenticated` into `status.Error(codes.Unauthenticated, ...)` before grpc-gateway sees the error. |

DATA FLOW ANALYSIS:
Variable: `clientToken`
  - Created at: `internal/server/authn/middleware/grpc/middleware.go:473-483`
  - Modified at: NEVER MODIFIED
  - Used at: `internal/server/authn/middleware/grpc/middleware.go:394-418`
  - Meaning: the bearer/cookie token that determines whether auth is valid or expired.

Variable: `auth`
  - Created at: `internal/server/authn/middleware/grpc/middleware.go:394`
  - Modified at: NEVER MODIFIED
  - Used at: `internal/server/authn/middleware/grpc/middleware.go:413-418`
  - Meaning: the stored authentication record whose `ExpiresAt` is checked.

Variable: `err`
  - Created at: `internal/server/authn/middleware/grpc/middleware.go:385-418`
  - Modified at: `internal/server/middleware/grpc/middleware.go:59-103`
  - Used at: `internal/server/authn/middleware/http/middleware.go:50-60`
  - Meaning: the auth failure is produced in gRPC middleware, converted to a gRPC status, then inspected by the HTTP error handler.

SEMANTIC PROPERTIES:
Property 1: Cookie deletion is not part of token validation.
  - Evidence: `authenticateClientToken` returns `errUnauthenticated` on failure (`internal/server/authn/middleware/grpc/middleware.go:394-418`) and does not call `Set-Cookie`.

Property 2: Cookie deletion is centralized in the HTTP error handler.
  - Evidence: `ErrorHandler` is the only unauthenticated-response path that calls `m.clearAllCookies(w)` (`internal/server/authn/middleware/http/middleware.go:50-57`).

Property 3: The deletion branch is narrow.
  - Evidence: It requires both `status.Code(err) == codes.Unauthenticated` and the presence of `flipt_client_token` in the original HTTP request (`internal/server/authn/middleware/http/middleware.go:54-56`).

Property 4: The auth gateway wiring is the only place that connects those pieces.
  - Evidence: `authenticationHTTPMount` installs `runtime.WithErrorHandler(authmiddleware.ErrorHandler)` and, when sessions are enabled, `runtime.WithMetadata(method.ForwardCookies)` (`internal/cmd/authn.go:255-268`).

ALTERNATIVE HYPOTHESIS CHECK:
If the opposite answer were true, what evidence would exist?
- Searched for: unconditional cookie deletion on unauthenticated auth responses, or another code path besides `ErrorHandler` calling `clearAllCookies`
- Found: `clearAllCookies` only in `internal/server/authn/middleware/http/middleware.go:41,56,63-76`; auth wiring only in `internal/cmd/authn.go:255-268`
- Conclusion: REFUTED — cookie clearing is not automatic; it happens only through the narrow `ErrorHandler` branch or the explicit logout `Handler`.

What this means for the reported behavior:
- The invalid/expired token path is: HTTP request with `flipt_client_token` → `ForwardCookies` copies it into gRPC metadata (`internal/server/authn/method/http.go:44-55`) → `authenticateClientToken` rejects it or sees expiry (`internal/server/authn/middleware/grpc/middleware.go:377-421`) → `ErrorUnaryInterceptor` converts the local unauthenticated error to `codes.Unauthenticated` (`internal/server/middleware/grpc/middleware.go:39-103`) → `authmiddleware.ErrorHandler` is supposed to clear cookies (`internal/server/authn/middleware/http/middleware.go:47-60`).
- If the cookie is still not being cleared, the only verified reasons in code are:
  1. the response did not reach this auth HTTP error handler path, or
  2. the error was not seen as `codes.Unauthenticated`, or
  3. the request did not present `flipt_client_token` to the handler.

FORMAL CONCLUSION:
By P1–P4, the behavior is governed by a split pipeline: validation happens in gRPC auth middleware, while cookie invalidation happens only in the auth HTTP gateway’s `ErrorHandler` / logout `Handler`. The validation code (`authenticateClientToken`) never clears cookies itself; it only returns `errUnauthenticated`, and the HTTP-side deletion is gated by `status.Code(err) == codes.Unauthenticated` plus the presence of the token cookie. Therefore, the code paths responsible for the reported repeated failures are the token-validation path in `internal/server/authn/middleware/grpc/middleware.go:377-421` and the narrowly gated cookie-clearing path in `internal/server/authn/middleware/http/middleware.go:47-60`; if the unauthenticated response bypasses that handler or fails its guard, the browser will keep resending the stale cookie.

ANSWER: The auth token is rejected in `authenticateClientToken`, converted to a gRPC unauthenticated status by `ErrorUnaryInterceptor`, and only then can `authmiddleware.ErrorHandler` clear cookies. The repeated-cookie behavior comes from the fact that cookie deletion is not done in validation itself; it is only done in that gated HTTP error handler.

CONFIDENCE: MEDIUM
