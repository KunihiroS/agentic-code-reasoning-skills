QUESTION: What is the root cause of the OIDC login issue, and how does the current code lead to it?

DEFINITIONS:
- The relevant behavior is the browser-visible OIDC login flow: state cookie creation, callback exchange, and client-token cookie emission.

PREMISES:
P1: Flipt loads and validates configuration before wiring auth middleware at runtime.
P2: Session-compatible auth enables the OIDC HTTP middleware, which is responsible for state/client-token cookies.
P3: The config validator normalizes `authentication.session.domain` to a hostname-only value.
P4: The OIDC state cookie omits `Domain` for `localhost`, but the client-token cookie does not.
P5: The OIDC callback URL helper in this checkout strips trailing slashes before appending the fixed callback path.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `config.Load` | `internal/config/config.go:90-209` | `(ctx context.Context, path string)` | `(*Result, error)` | Reads config, unmarshals it, then runs all collected validators after unmarshal. |
| `(*AuthenticationConfig).validate` | `internal/config/authentication.go:118-152` | `(*AuthenticationConfig)` | `error` | Requires `authentication.session.domain` when session auth is enabled, calls `getHostname`, and writes the normalized host back to `c.Session.Domain`. |
| `getHostname` | `internal/config/authentication.go:155-163` | `(rawurl string)` | `(string, error)` | Prepends `http://` if needed, parses the URL, and returns only the host part before `:`. |
| `authenticationHTTPMount` | `internal/cmd/authn.go:247-279` | `(ctx context.Context, logger *zap.Logger, cfg config.AuthenticationConfig, r chi.Router, conn grpc.ClientConnInterface)` | `void` | Wires auth middleware from `cfg.Session`; if session auth is enabled, it installs the OIDC/GitHub HTTP middleware and the forward-response hook. |
| `NewHTTPMiddleware` | `internal/server/authn/method/http.go:25-41` | `(config config.AuthenticationSessionConfig)` | `Middleware` | Stores the session config for later cookie handling. |
| `Middleware.Handler` | `internal/server/authn/method/http.go:110-167` | `(next http.Handler)` | `http.Handler` | For authorize requests, creates the state cookie; it omits `Domain` only when `m.config.Domain` starts with `localhost`. |
| `Middleware.ForwardResponseOption` | `internal/server/authn/method/http.go:75-101` | `(ctx context.Context, w http.ResponseWriter, resp proto.Message)` | `error` | On callback response, sets the client-token cookie with `Domain: m.config.Domain` unconditionally, then redirects. |
| `clearAllCookies` | `internal/server/authn/middleware/http/middleware.go:63-76` | `(w http.ResponseWriter)` | `void` | Clears state/token cookies and also sets `Domain: m.config.Domain` unconditionally. |
| `callbackURL` | `internal/server/authn/method/oidc/server.go:233-236` | `(host, provider string)` | `string` | Trims a trailing slash from `host` before appending `/auth/v1/method/oidc/<provider>/callback`. |
| `providerFor` | `internal/server/authn/method/oidc/server.go:248-300` | `(provider, state, nonce string)` | `(*capoidc.Provider, *capoidc.Req, error)` | Builds the provider config and uses `callbackURL(providerCfg.RedirectAddress, provider)` as the redirect URI. |

DATA FLOW ANALYSIS:
Variable: `cfg.Authentication.Session.Domain`
- Created at: config load/unmarshal, then validated at `internal/config/config.go:90-209`
- Modified at: `internal/config/authentication.go:132-135` (`c.Session.Domain = host`)
- Used at: `internal/cmd/authn.go:255-278` when constructing both HTTP middleware instances

Variable: `m.config.Domain`
- Created at: `internal/server/authn/method/http.go:25-41` from the session config
- Modified at: NEVER MODIFIED inside the middleware
- Used at:
  - state cookie creation: `internal/server/authn/method/http.go:147-167`
  - client-token cookie creation: `internal/server/authn/method/http.go:78-89`
  - cookie clearing: `internal/server/authn/middleware/http/middleware.go:63-76`

Variable: `providerCfg.RedirectAddress`
- Created at: auth config for the OIDC provider
- Modified at: NEVER MODIFIED
- Used at: `internal/server/authn/method/oidc/server.go:267-295` through `callbackURL(...)`

SEMANTIC PROPERTIES:
Property 1: Runtime config is normalized before middleware wiring.
- Evidence: `config.Load` runs validation after unmarshal (`internal/config/config.go:189-209`), and `AuthenticationConfig.validate` rewrites the session domain to a hostname-only value (`internal/config/authentication.go:127-135`).

Property 2: State-cookie handling special-cases `localhost`, but client-token handling does not.
- Evidence: `Middleware.Handler` omits `Domain` when `m.config.Domain` starts with `localhost` (`internal/server/authn/method/http.go:160-165`), while `ForwardResponseOption` always sets `Domain: m.config.Domain` (`internal/server/authn/method/http.go:78-87`).

Property 3: The trailing-slash callback bug is not present in this checkout.
- Evidence: `callbackURL` trims trailing slash before concatenation (`internal/server/authn/method/oidc/server.go:233-236`), and tests cover `host: "localhost:8080/"` and `host: "http://localhost:8080/"` expecting a single-slash callback URL (`internal/server/authn/method/oidc/server_internal_test.go:9-39`).

ALTERNATIVE HYPOTHESIS CHECK:
If the opposite answer were true, I would expect:
- A callback helper that does naive concatenation and produces `//`
- Or cookie code that never emits `Domain=localhost`

Searched for:
- `callbackURL` implementations and tests
- `Domain` assignments in the OIDC/session middleware and cookie-clearing code

Found:
- `callbackURL` strips trailing slashes in OIDC and GitHub (`internal/server/authn/method/oidc/server.go:233-236`, `internal/server/authn/method/github/server.go:91-95`)
- OIDC tests explicitly assert trailing slashes do not produce `//` (`internal/server/authn/method/oidc/server_internal_test.go:9-39`)
- The middleware still emits `Domain: m.config.Domain` for the token cookie and for cookie clearing (`internal/server/authn/method/http.go:78-89`, `internal/server/authn/middleware/http/middleware.go:63-76`)
- Middleware tests still expect `Domain == "localhost"` on cleared cookies (`internal/server/authn/middleware/http/middleware_test.go:71-88`)

Conclusion: the callback-URL half of the reported issue is refuted in this checkout; the remaining live problem is cookie-domain handling.

FORMAL CONCLUSION:
By P1 and P2, the OIDC login flow is driven by the session middleware and the OIDC callback response hook. By P3, the session domain is normalized at config-load time, so scheme/port are stripped before runtime wiring. However, by P4, the state cookie gets a localhost exception but the client-token cookie does not: `ForwardResponseOption` still sets `Domain: m.config.Domain` unconditionally, and `clearAllCookies` does the same. Therefore, when the session domain resolves to `localhost`, Flipt still emits `Set-Cookie` headers with `Domain=localhost`, which browsers may reject, preventing the OIDC session cookie from sticking and breaking the login flow after callback. By P5, the trailing-slash callback bug described in the issue is not present in the current code because `callbackURL()` trims the slash before concatenation.

ANSWER: The root cause in the current codebase is inconsistent cookie-domain handling: the session domain is normalized, but the OIDC client-token cookie (and cookie-clearing path) still reuses `localhost` as a cookie `Domain`, which browsers can reject. The callback URL double-slash problem is already fixed in this checkout.

CONFIDENCE: MEDIUM
