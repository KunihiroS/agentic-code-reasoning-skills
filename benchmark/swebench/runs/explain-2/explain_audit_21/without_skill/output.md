In this commit, Navidrome already has the reversible-password flow in place. The behavior is driven by a small set of code paths:

### 1) Passwords are encrypted before being written to `user.password`
- The `model.User` type separates the backend-only `Password` from the UI-facing `NewPassword` / `CurrentPassword` fields: `repo_nav/model/user.go:16-22`.
- `userRepository.Put()` encrypts `NewPassword` before persisting the user:
  - if `u.NewPassword != ""`, it calls `encryptPassword(u)`; then the encrypted value is written to the DB via `SetMap(values)` in `Put()`  
  `repo_nav/persistence/user_repository.go:61-83`
- `encryptPassword()` uses `utils.Encrypt()` and replaces `u.NewPassword` with the ciphertext before the insert/update happens:  
  `repo_nav/persistence/user_repository.go:314-323`

### 2) The encryption key is initialized with a fallback, and can be configured
- The default fallback key is `consts.DefaultEncryptionKey = "just for obfuscation"`:  
  `repo_nav/consts/consts.go:24-27`
- The config option exists and defaults to empty:  
  `repo_nav/conf/configuration.go:215`
- `initPasswordEncryptionKey()` does the key selection:
  - starts with the fallback key
  - if `passwordencryptionkey` is configured, it hashes that and uses it instead
  - it also checks a stored fingerprint in the properties table (`PasswordsEncryptedKey`) to detect key changes  
  `repo_nav/persistence/user_repository.go:256-312`
- If the saved fingerprint exists but does not match the configured key, it returns `errors.New("passwordEncryptionKey changed")` and logs that users won’t be able to login:  
  `repo_nav/persistence/user_repository.go:268-275`

### 3) Existing plaintext passwords were migrated to encrypted form
- The database migration `20210616150710_encrypt_all_passwords.go` reads every user password and re-encrypts it with the default key:  
  `repo_nav/db/migration/20210616150710_encrypt_all_passwords.go:18-51`

### 4) Passwords are decrypted when Navidrome needs the real password back
- `FindByUsernameWithPassword()` fetches the user and then calls `decryptPassword()` so callers get the plaintext password in `user.Password`:  
  `repo_nav/persistence/user_repository.go:99-104`
- `decryptPassword()` uses `utils.Decrypt()` to reverse the ciphertext:  
  `repo_nav/persistence/user_repository.go:325-333`
- The `UserRepository` interface explicitly documents that this method returns the decrypted password:  
  `repo_nav/model/user.go:34-37`

### 5) Authentication uses the decrypted password
#### Web login
- `server.doLogin()` calls `validateLogin()`:  
  `repo_nav/server/auth.go:46-65`
- `validateLogin()` uses `FindByUsernameWithPassword()` and compares the decrypted stored password to the supplied password:  
  `repo_nav/server/auth.go:154-169`
- If login succeeds, `buildAuthPayload()` uses `user.Password` to generate the Subsonic token (`md5(user.Password + salt)`), so this path depends on the password being decrypted first:  
  `repo_nav/server/auth.go:68-91`

#### Subsonic API auth
- `validateUser()` also calls `FindByUsernameWithPassword()` and then validates:
  - plaintext password (`p`)
  - token+salt (`t`/`s`)
  - JWT (`jwt`)  
  `repo_nav/server/subsonic/middlewares.go:108-137`
- For the token-based Subsonic flow, it computes `md5(user.Password + salt)` using the decrypted password:  
  `repo_nav/server/subsonic/middlewares.go:129-131`

### 6) What happens if the keys do not match
There are two distinct failure points:

1. **Startup/key initialization failure**
   - If the saved fingerprint says passwords were encrypted with a different key, `initPasswordEncryptionKey()` returns an error and logs a key-change warning:  
     `repo_nav/persistence/user_repository.go:268-275`

2. **Runtime auth failure**
   - `utils.Decrypt()` returns an error if AES-GCM decryption fails:  
     `repo_nav/utils/encrypt.go:39-64`
   - However, `FindByUsernameWithPassword()` currently **ignores** that decrypt error (`_ = r.decryptPassword(usr)`) and returns the user anyway:  
     `repo_nav/persistence/user_repository.go:99-104`
   - So in the login/auth paths, a bad key typically shows up as a credential mismatch rather than a propagated decrypt error:
     - web login: `validateLogin()` compares `u.Password != password` and returns nil/unauthorized on mismatch  
       `repo_nav/server/auth.go:154-169`
     - Subsonic auth: `validateUser()` does the same for `p` / token checks  
       `repo_nav/server/subsonic/middlewares.go:108-137`

### 7) User creation/update paths also go through the same encryption logic
- Initial admin creation uses `NewPassword`, then `Put()` encrypts it:  
  `repo_nav/server/initial_setup.go:39-58`
- The admin/user update path decrypts the existing password before validating the current password, then `Put()` re-encrypts any new password:  
  `repo_nav/persistence/user_repository.go:172-200`

## Bottom line
The relevant behavior is implemented by:
- `userRepository.Put()` + `encryptPassword()` for encryption at write time
- `FindByUsernameWithPassword()` + `decryptPassword()` for decryption at read/auth time
- `initPasswordEncryptionKey()` for default-key fallback, configured-key support, and key-change detection
- `validateLogin()` / `validateUser()` for authentication using the decrypted password

One important nuance: the code **does not propagate decrypt errors from `FindByUsernameWithPassword()`**; it ignores them and lets auth fail by password mismatch instead.
