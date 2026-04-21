The root cause is **incomplete authentication-config validation**.

What the code currently does:

- Flipt’s config loader only fails startup when a config type implements `validate()` and that method returns an error.  
  See `internal/config/config.go:77-183`, especially the validation loop at `176-180`.

- For authentication, the top-level validator only:
  - checks cleanup/session settings, and
  - delegates to each method’s `validate()` implementation.  
  See `internal/config/authentication.go:135-180`.

- But the auth method validators are incomplete:
  - `AuthenticationMethodOIDCConfig.validate()` is a no-op: `internal/config/authentication.go:405`.
  - `AuthenticationMethodOIDCProvider` has **no validation method at all**: `internal/config/authentication.go:407-415`.
  - `AuthenticationMethodGithubConfig.validate()` only checks the `read:org` / `allowed_organizations` relationship; it does **not** validate that `client_id`, `client_secret`, or `redirect_address` are present.  
    See `internal/config/authentication.go:484-490`.

- The generated schema also reflects that these fields are optional, not required:
  - GitHub provider fields are present with an empty `required` list in `config/flipt.schema.json:181-210`.
  - OIDC provider fields are all optional in `config/flipt.schema.json:250-261`.
  - The CUE schema likewise marks them optional in `config/flipt.schema.cue:70-94`.

How this leads to the startup behavior:

- When auth is enabled, Flipt registers the GitHub and OIDC servers without any extra startup-time validation.  
  See `internal/cmd/auth.go:117-129`.

- GitHub server construction simply copies the config values into `oauth2.Config`, even if they are empty strings.  
  See `internal/server/auth/method/github/server.go:58-75`.

- OIDC doesn’t even build provider clients until an authorize/callback request comes in; `providerFor()` is only called later, and it uses the provider fields directly.  
  See `internal/server/auth/method/oidc/server.go:168-215`.

So the behavior is: **invalid auth configs are unmarshaled successfully, pass the current validation hooks, and the auth servers are still registered**, which means Flipt starts even when required GitHub/OIDC credentials are missing.

One nuance: in this checked-out commit, GitHub’s `read:org` check is already present in `AuthenticationMethodGithubConfig.validate()` (`internal/config/authentication.go:484-488`). The verifiable gap here is the lack of required-field validation for GitHub and OIDC credentials.
