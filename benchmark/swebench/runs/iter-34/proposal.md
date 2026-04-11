# Iteration 35 — 改善案提案

## 1. iter-34 却下の要約と本提案の方向転換

### iter-34 却下理由
- 変更の実効差分が **出力テンプレート文言の整形**（COUNTEREXAMPLE の `By P[N]`、NO COUNTEREXAMPLE EXISTS の `what assertion in P[N]`）と **Guardrail 2 の assertion 到達義務強化** に集中しており、BL-2 / BL-15 / 共通原則 #2 #6 に実質的に近い
- NOT_EQ 側のみに completion pressure を上げる非対称な変更になっている

### 監査役の代替提案
- **カテゴリ C: 比較の枠組みを変える**
- テスト単位の比較の前に、変更された関数/公開 API ごとに「外部可観測契約」を1行で比較するステップを入れる
- 「この差分は return value / raised exception / mutated persistent state / emitted call のどれを変えうるか」を関数単位で先に整理し、その後 relevant test と接続する

---

## 2. 選択した Exploration Framework カテゴリ

### カテゴリ C: 比較の枠組みを変える

**選択理由**:
- iter-34 まで多く試行してきたカテゴリ E（表現・フォーマット）は、今回の監査で実質的に限界を指摘された
- 監査役が代替案として明示的に「カテゴリ C の未試行メカニズム」を提案している
- カテゴリ C の既試行は BL-7（変更性質の自由記述ラベル付け）と BL-16（`Comparison:` 直前への観測点注釈）であり、今回の提案はいずれとも機構が異なる（後述）

---

## 3. 現状の失敗パターン分析

### 失敗ケース分類（iter-33 スコア 70%）

| 種別 | 失敗ケース | 根本原因の仮説 |
|------|-----------|--------------|
| EQUIV 偽陽性 | 15368, 13821, 15382 | コード差異を発見した段階でトレースを打ち切り「コード差分 → テスト結果が異なる」と短絡推論 |
| NOT_EQ UNKNOWN | 13417, 11433, 14122 | 探索対象が広すぎ、31 ターン内に証拠が収束しない |

### 両失敗に共通する根本問題
現行テンプレートでは、比較分析がいきなり「テスト単位」から始まる。エージェントは次のショートカットを取りやすい：
- **EQUIV 偽陽性方向**: コード差異の有無をスキャン → 差異発見 → `Comparison: DIFFERENT` と即断（関数の外部可観測な出力が実際に変わるかを検証しない）
- **NOT_EQ UNKNOWN 方向**: relevant test 候補が多く探索が収束しない（どのテストが「この変更の可観測な出力を assert しているか」の絞り込みができない）

**共通の欠如**: 変更された関数が外部に何を公開しているか（return value / exception / state mutation / emitted call）を**テスト分析の前**に明確にするステップがない。

---

## 4. 改善仮説

**仮説**: テスト単位の比較 (ANALYSIS OF TEST BEHAVIOR) を始める前に、変更された各関数/シンボルの「外部可観測な契約（Observable Contract）」を列挙し、その差分の scope を確認するステップを追加することで：

1. **EQUIV 偽陽性の抑制**: 関数内部の実装差異が外部可観測契約（return / exception / state / calls）を実際に変えるかどうかを先に確認する。契約が変わらなければ、テスト分析での「差異が DIFFERENT outcome を生むか」という問いへの答えが絞られる。
2. **NOT_EQ UNKNOWN の解消**: 可観測契約のうち「diff が触れうる category」が先に特定されることで、その category を directly assert するテストに探索を集中できる。探索の幅が絞られ、ターン内に収束しやすくなる。

---

## 5. 過去の類似失敗との差分分析

### BL-7（CHANGE CHARACTERIZATION）との差異
- **BL-7 の失敗機序**: 変更ファイルの種別（production code / test code / both）という「判定方向と強く相関するラベル」を生成させた。「test code only」→ EQUIV、「production code」→ NOT_EQ という暗黙ヒューリスティックが形成された。
- **今回の差異**: CONTRACT SURVEY が問うのは「この関数が外部に何を公開しているか（return type / exception / state / calls）」と「この diff は公開インターフェースのどの category に触れうるか」。これらは**判定方向（EQUIV/NOT_EQ）と直接相関しない**。`Diff scope: return value affected` は「return value が変わりうる」という探索仮説であり、NOT_EQ への直接的なアンカーにはならない（return value が変わっても、それを assert するテストがなければ EQUIV）。

### BL-16（`Comparison:` 直前への観測点注釈）との差異
- **BL-16 の失敗機序**: 各テストの `Comparison: SAME/DIFFERENT` の直前に観測点リストを埋め込んだ。これは「出力側のフレーミング追加」であり、探索行動を変えなかった。
- **今回の差異**: CONTRACT SURVEY はテスト比較ループの**前**に置かれる独立ステップであり、`Comparison:` フィールドを変更しない。テスト分析を出力フレームで制約するのではなく、**テスト探索のターゲットを決定する前処理**として機能する。

### BL-8（受動的記録フィールドの追加）との差異
- **BL-8 の失敗機序**: 関数トレーステーブルに記録列を追加しても、エージェントはもっともらしいテキストを生成するだけで、能動的な検証を誘発しなかった。
- **今回の差異**: CONTRACT SURVEY の各フィールドは `file:line` 引用を必須とする。`Contract: return [type/semantics at file:line]` の形式により、関数の return 文を実際に読むことが要求される。受動的な記録ではなく、**コード読取を強制する能動的フィールド**である。

---

## 6. SKILL.md の変更内容

### 変更箇所: compare テンプレートへの CONTRACT SURVEY セクション追加

**挿入位置**: PREMISES の直後、ANALYSIS OF TEST BEHAVIOR の直前

**変更前（現行の iter-33 状態）**:
```
PREMISES:
P1: Change A modifies [file(s)] by [specific description]
P2: Change B modifies [file(s)] by [specific description]
P3: The fail-to-pass tests check [specific behavior]
P4: The pass-to-pass tests check [specific behavior, if relevant]

ANALYSIS OF TEST BEHAVIOR:
```

**変更後（提案）**:
```
PREMISES:
P1: Change A modifies [file(s)] by [specific description]
P2: Change B modifies [file(s)] by [specific description]
P3: The fail-to-pass tests check [specific behavior]
P4: The pass-to-pass tests check [specific behavior, if relevant]

CONTRACT SURVEY (one entry per changed function/symbol):
  Function: [name — file:line]
  Contract: return [value type/semantics]; raises [exception or NONE];
            mutates [persistent state or NONE]; calls [observable side-effects or NONE]
  Diff scope: which contract element(s) could this diff alter? [list or NONE]
  Test focus: tests that directly assert the listed Diff scope element(s)

ANALYSIS OF TEST BEHAVIOR:
```

### 変更規模
- 追加: 6 行
- 変更: 0 行
- 削除: 0 行
- **合計: 6 行追加**（20 行以内の目安に対して十分小さい）

---

## 7. CONTRACT SURVEY の動作

### EQUIV 偽陽性ケースへの作用

現在の EQUIV 偽陽性（15368, 13821, 15382）では、エージェントがコード差異を発見した時点でトレースを打ち切る。

CONTRACT SURVEY により：
1. まず変更関数の contract を `file:line` 付きで列挙（return type, exception, state, calls）
2. `Diff scope` で「diff が public contract のどこを変えうるか」を先に確認
3. Diff scope が NONE（内部実装のみ変更）の場合、テスト分析でも「コード差異が可観測に伝播するか」を意識しやすくなる
4. Diff scope が非 NONE でも、`Test focus` で「その category を assert するテスト」を先に特定することで、短絡的な `Comparison: DIFFERENT` を防ぐ

### NOT_EQ UNKNOWN ケースへの作用

現在の UNKNOWN（13417, 11433, 14122）では、探索が広く浅くなりターンが枯渇する。

CONTRACT SURVEY により：
1. 変更関数の contract から `Diff scope` を先に確定
2. `Test focus` でその category を直接 assert するテストを絞り込む
3. ANALYSIS OF TEST BEHAVIOR を絞り込んだテストから開始でき、探索幅が減少してターン内に収束しやすくなる

---

## 8. EQUIV / NOT_EQ の正答率への予測影響

### EQUIV 正答率
- **現状**: 7/10（15368, 13821, 15382 が NOT_EQUIV 誤判定）
- **予測**: 8〜10/10 に改善
- **根拠**: CONTRACT SURVEY がコード差異と可観測契約変化の間のギャップを先に検証させることで、内部差異をそのまま DIFFERENT outcome に短絡させるパターンを抑制できる

### NOT_EQ 正答率
- **現状**: 7/10（13417, 11433, 14122 が UNKNOWN）
- **予測**: 8〜10/10 に改善
- **根拠**: CONTRACT SURVEY の `Test focus` により可観測出力を assert するテストへ探索を集中でき、ターン効率が改善する

### 全体予測: 70% → **85〜100%**

---

## 9. failed-approaches.md ブラックリスト・共通原則との照合

### ブラックリスト照合

| BL | 内容 | 照合結果 |
|----|------|---------|
| BL-1 | ABSENT 定義追加 | 無関係 |
| BL-2 | NOT_EQ 証拠閾値厳格化 | ✓ 閾値変更なし。CONTRACT SURVEY は新たな証拠要求ではなく、探索の優先順位付け |
| BL-7 | 変更性質の自由記述ラベル付け | ✓ 「判定方向と相関するラベル」ではなく「可観測契約 category」を問う（前述 §5 参照） |
| BL-8 | 受動的記録フィールド追加 | ✓ `file:line` 引用必須により能動的コード読取を強制（前述 §5 参照） |
| BL-15 | COUNTEREXAMPLE wording 変更 | 無関係（COUNTEREXAMPLE には一切触れない） |
| BL-16 | `Comparison:` 直前注釈追加 | ✓ `Comparison:` フィールドへの追加ではなく、独立した前処理ステップ（前述 §5 参照） |
| BL-17 | relevant test 検索の拡張 | ✓ 逆方向（絞り込み）。`Test focus` は探索を広げるのではなく、可観測 category で絞る |

### 共通原則との照合

| 原則 | 内容 | 照合結果 |
|------|------|---------|
| #1 判定の非対称操作 | EQUIV/NOT_EQ の一方に有利な変更禁止 | ✓ CONTRACT SURVEY は EQUIV（scope NONE → 可観測変化なし確認）にも NOT_EQ（scope あり → テスト絞り込み）にも対称に有用 |
| #2 出力側の制約 | 出力テンプレート変更は効果がない | ✓ COUNTEREXAMPLE / NO COUNTEREXAMPLE EXISTS / Guardrail に一切触れない |
| #3 探索量の削減禁止 | 探索を減らす変更は全て悪化 | ✓ 探索量は減らさない。探索の優先順位付けにより無駄な幅を減らすが、必要な検証は維持 |
| #4 同方向の変形反復禁止 | 同じ効果の変更は表現を変えても失敗 | ✓ 過去の失敗方向（出力制約強化、ラベル付けアンカリング、閾値引き上げ）とは独立 |
| #5 テンプレート過剰規定 | 探索視野を狭めるテンプレート変更禁止 | ✓ CONTRACT SURVEY は何を探索しないかを規定しない。`Test focus` は絞り込みの「示唆」であり、他テストを排除するルールではない |
| #6 対称化の実効差分 | 文面上対称でも実効差分が非対称なら違反 | ✓ 変更前との実効差分を確認: 追加される CONTRACT SURVEY は PREMISES → ANALYSIS の間にある中立ステップ。COUNTEREXAMPLE も Guardrail も変更しない |
| #7 中間ラベルのアンカリング | 判定方向と相関するラベルは危険 | ✓ 可観測 category 列挙は判定方向と直接相関しない（詳細 §5 参照） |
| #8 受動的記録フィールド | 記録 ≠ 検証 | ✓ `file:line` 必須により能動的検証を強制 |
| #13 relevant test 集合の精度 | 精度を落とす探索拡張は有害 | ✓ CONTRACT SURVEY は絞り込み（精度向上）方向 |

---

## 10. 研究コア構造との整合確認

変更後も以下のコア要素はすべて維持される:
- **番号付き前提（P1〜P4）**: 変更なし
- **仮説駆動探索（Step 3）**: 変更なし
- **手続き間トレース（Step 4）**: 変更なし
- **COUNTEREXAMPLE / NO COUNTEREXAMPLE EXISTS テンプレート**: 変更なし

CONTRACT SURVEY の追加は Agentic Code Reasoning 論文の「explicit premises → execution-path tracing → formal conclusions」構造と整合する。具体的には:
- Contract: 変更関数の外部可観測動作についての **explicit premise**
- Diff scope: 「どの contract element が変わりうるか」という **探索仮説の構造化**
- Test focus: 仮説に基づく **targeted evidence collection**

---

## 11. 特定ベンチマークケース依存チェック

CONTRACT SURVEY は任意の言語・プロジェクトの patch equivalence タスクに等しく適用される。関数の return / exception / state / calls の category は普遍的であり、Django 固有の構造に依存しない。
