The root cause is that the OIDC flow reuses configuration values **without normalizing them for the places they are used**, and that leads to two separate breakages:

1. **Cookie `Domain` is taken verbatim from `authentication.session.domain`**
   - In `internal/server/auth/method/oidc/http.go`, both OIDC cookies are created with `Domain: m.Config.Domain`:
     - `ForwardResponseOption` at **lines 47-70**, specifically line **65**
     - `Handler` at **lines 126-133**, specifically line **128**
   - The audit notes that `AuthenticationSession` accepts the domain as a plain string in `internal/config/authentication.go:94-101`, with no normalization step.
   - So if the config is `http://localhost:8080`, the cookie gets `Domain=http://localhost:8080`; if it is `localhost`, the cookie gets `Domain=localhost`.
   - Browsers reject those values because cookie domains must be hostnames only, and `localhost` is not valid for a `Domain` attribute in this flow. That means the state/token cookies never stick, and the OIDC exchange breaks.  
   - Evidence: `internal/server/auth/method/oidc/http.go:62-70`, `internal/server/auth/method/oidc/http.go:126-133`, `internal/config/authentication.go:94-101` (from the audit report).

2. **Callback URL construction does raw string concatenation**
   - In `internal/server/auth/method/oidc/server.go`, `callbackURL` at **lines 160-161** simply concatenates the configured host with the callback path.
   - `providerFor` then uses it at **line 175**.
   - If `RedirectAddress` ends with `/` (for example `http://localhost:8080/`), concatenation produces:
     - `http://localhost:8080//auth/v1/method/oidc/.../callback`
   - That double slash makes the redirect URI differ from the provider’s expected callback URL, so the OIDC provider rejects the flow.
   - Evidence: `internal/server/auth/method/oidc/server.go:160-161`, `internal/server/auth/method/oidc/server.go:175`.

So the behavior comes from two current implementation choices:
- **cookies use the configured domain value directly, without stripping scheme/port or omitting `Domain` for localhost**
- **callback URLs are built by naïve concatenation, without trimming a trailing slash**

That combination is exactly why OIDC login fails for `authentication.session.domain` values like `http://localhost:8080` or `localhost`, and for callback bases ending in `/`.
