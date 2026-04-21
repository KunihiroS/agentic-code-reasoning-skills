QUESTION: What is the root cause of the GitHub/OIDC auth validation issue, and how does the current implementation lead to it?

Selected mode: explain

PREMISES
P1: The reported bug is that startup should fail when GitHub/OIDC auth is incomplete, but it can instead start successfully.
P2: The app’s main server startup path uses `buildConfig()`, which calls `config.Load()`.
P3: `internal/config/authentication.go` contains explicit validation for GitHub/OIDC required fields and GitHub’s `read:org` dependency.
P4: The config schema in `config/flipt.schema.cue` marks those auth fields as optional.

FUNCTION TRACE TABLE
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `buildConfig` | `cmd/flipt/main.go:220-239` | `context.Context` | `(*zap.Logger, *config.Config, error)` | Loads config via `config.Load()` and returns an error if loading/validation fails. |
| `Load` | `internal/config/config.go:94-239` | `context.Context, string` | `(*Result, error)` | Reads config, unmarshals it, then runs collected validators after unmarshal. |
| `Config.validate` | `internal/config/config.go:425-452` | `*Config` | `error` | Checks version, auth-vs-authorization dependency, environments, and templates; does **not** validate `Authentication`. |
| `AuthenticationConfig.validate` | `internal/config/authentication.go:118-145` | `*AuthenticationConfig` | `error` | Validates enabled session settings and then iterates all auth methods, calling each method validator. |
| `AuthenticationMethod[C].validate` | `internal/config/authentication.go:406-411` | `*AuthenticationMethod[C]` | `error` | Skips validation when `Enabled` is false; otherwise delegates to the method-specific validator. |
| `AuthenticationMethodOIDCProvider.validate` | `internal/config/authentication.go:545-558` | `AuthenticationMethodOIDCProvider` | `error` | Requires `client_id`, `client_secret`, and `redirect_address`. |
| `AuthenticationMethodGithubConfig.validate` | `internal/config/authentication.go:626-654` | `AuthenticationMethodGithubConfig` | `error` | Requires `client_id`, `client_secret`, and `redirect_address`; also requires `read:org` when `allowed_organizations` is set. |

DATA FLOW ANALYSIS
Variable: `cfg`
- Created at: `internal/config/config.go:100-105`
- Modified at: `internal/config/config.go:224-230` by `v.Unmarshal(cfg, ...)`
- Used at: `internal/config/config.go:232-237` to run validators, and in `cmd/flipt/main.go:233-240` after `Load()` returns

Variable: `validators`
- Created at: `internal/config/config.go:152-157`
- Populated at: `internal/config/config.go:159-206`
- Consumed at: `internal/config/config.go:232-237`

SEMANTIC PROPERTIES
Property 1: Auth validation is runtime-based, not schema-based.
- Evidence: `Load()` only runs validation after unmarshal (`internal/config/config.go:224-237`), while the CUE schema marks `client_id`, `client_secret`, `redirect_address`, `allowed_organizations`, and `scopes` as optional (`config/flipt.schema.cue:92-118, 139-149`).

Property 2: The top-level `Config.validate()` does not validate auth sub-configs.
- Evidence: it checks version, authorization, environments, and templates only (`internal/config/config.go:425-452`).

Property 3: The actual GitHub/OIDC required-field checks do exist.
- Evidence: OIDC provider checks required fields (`internal/config/authentication.go:545-558`) and GitHub checks the same plus the `read:org` dependency (`internal/config/authentication.go:626-654`).

ALTERNATIVE HYPOTHESIS CHECK
If the opposite answer were true — that startup already rejects these invalid auth configs — then the startup path should clearly invoke the auth validators before the server runs.
- Searched for: startup config flow and validator invocation
- Found: `buildConfig()` calls `config.Load()` (`cmd/flipt/main.go:220-227`), and `Load()` runs validators after unmarshal (`internal/config/config.go:224-237`).
- Conclusion: the current tree already contains the validation machinery, so the silent-acceptance behavior must come from a path that bypasses `Load()`/its validator pass, or from an older revision before these validators were present.

FORMAL CONCLUSION
By P2, P3, and the trace above:
- The implementation has the correct GitHub/OIDC validation logic.
- The weak point is that the schema is permissive and `Config.validate()` omits authentication entirely.
- Therefore, any code path that does not go through `config.Load()` can accept incomplete GitHub/OIDC configs without failing early.

In this checkout, the server startup path does call `config.Load()`, so I could not verify the reported silent-acceptance behavior from the current source alone. The most defensible root-cause statement is that validation is split between a permissive schema and a separate runtime loader; if startup bypasses that loader, invalid auth config is accepted.

ANSWER: PARTIALLY VERIFIED — the current codebase already contains the required validation, but the design still allows bypass if a startup path skips `config.Load()`
CONFIDENCE: MEDIUM
