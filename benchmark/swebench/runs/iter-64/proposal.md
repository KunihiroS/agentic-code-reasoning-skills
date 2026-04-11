# Iteration 64 — 改善案提案

## 1. 親イテレーション (iter-35, フォーカス: not_eq) の選定理由

iter-35 は 75%（15/20）→ 85%（17/20）に改善した最新の安定ベースラインである。
Category E（Compare チェックリストの `because` 節を「trace through changed code to the assertion or exception — cite file:line」に精緻化）により EQUIV 側の偽陰性を抑制した。

**iter-35 の残存失敗ケース:**

| ケース | 正解 | 予測 | 失敗パターン |
|---|---|---|---|
| django__django-15368 | EQUIVALENT | NOT_EQUIVALENT | EQUIV 偽陽性（持続的） |
| django__django-13821 | EQUIVALENT | NOT_EQUIVALENT | EQUIV 偽陽性（持続的） |
| django__django-11433 | NOT_EQUIVALENT | UNKNOWN | NOT_EQ 収束失敗（31 ターン） |

今回のフォーカスドメインは `not_eq` であり、**11433 の UNKNOWN（31 ターン収束失敗）** の改善を最優先とする。

---

## 2. 選択した Exploration Framework カテゴリとその理由

**カテゴリ B: 情報の取得方法を改善する — 探索の優先順位付けを変える**

### 既試行の確認

iter-35 の直接の子イテレーション（iter-56）は **カテゴリ E**（Compare チェックリストの wording 変更, BL-29）を使用し、失敗した。
カテゴリ B は iter-35 の子イテレーションでは未使用である。

### カテゴリ B の既試行サブアプローチとの差分

| 過去の BL | 機構 | 今回との違い |
|---|---|---|
| BL-17 (iter-32) | caller/wrapper/helper まで relevant test の探索半径を拡大 | 今回は探索半径を変えず、**既存の D2(a)/(b) の semantic priority を checklist の実行順序として明示**する |
| BL-22 (iter-47) | D2(b) に「テスト削除から関連性を仮定するな」という禁止指示を追加 | 今回は禁止指示ではなく、D2 の定義に既に含まれる優先順位を **順序指示として checklist に反映** する |
| BL-18 (iter-36) | 削除/skip テストに対する条件付き追加 search 義務 | 今回は条件付き特例ではなく、**全ケースで fail-to-pass 先行**という普遍的な順序改善 |

---

## 3. 改善仮説（1つ）

**仮説**: Compare チェックリストの「テストをトレースせよ」という項目に、D2(a)（fail-to-pass）テストを D2(b)（pass-to-pass）テストより先に分析するという **優先順位指示**を追加することで、エージェントが最も診断力の高いテストから分析を始め、NOT_EQ の場合は counterexample を早期に発見でき、EQUIV の場合は同一結果を早期に確立できる。これにより NOT_EQ の収束失敗（UNKNOWN）を抑制しつつ、EQUIV の正答率を維持する。

### 根拠

D2(a) テスト（fail-to-pass）は「パッチが修正しようとしたテスト」であり、**変更の正しさを最も直接的に検証する**テストとして D2 の定義が "always relevant" と明示している。これに対し D2(b) テスト（pass-to-pass）は「コールパス上にある場合のみ relevant」と条件付きである。

現行 checklist は「Trace each test through both changes separately before comparing」と記述し、テストの分析順序を未規定のまま放置している。これにより、エージェントは pass-to-pass テストの大量分析にターンを消費しても fail-to-pass テストの counterexample 発見に到達できない可能性がある。

D2 の semantic priority を checklist の実行順序として明示することは：
- D2 の定義との整合性 ✓
- 新規制約の追加ではなく定義の反映 ✓
- 全ケースに普遍的に適用可能 ✓

---

## 4. SKILL.md のどこをどう変えるか（具体的な変更内容）

**変更箇所**: Compare checklist の 4 番目の項目

**変更前（現行 SKILL.md, 約 215 行付近）:**
```
- Trace each test through both changes separately before comparing
```

**変更後:**
```
- Trace fail-to-pass tests (D2a) through both changes first, then pass-to-pass tests (D2b); trace each through both changes separately before comparing
```

### 変更規模

- 修正行数: 1 行（既存行の精緻化）
- **追加行数: 0 行（5 行以内の制約を満たす）**
- 削除行数: 0 行

### 変更の意味

| 追加要素 | 意図 |
|---|---|
| `fail-to-pass tests (D2a) ... first` | 最も診断力の高いテストを先に分析させる |
| `then pass-to-pass tests (D2b)` | D2(b) の条件付き relevance を ordering として表現 |
| `trace each through both changes separately before comparing` | 既存の "separately before comparing" 要件を維持（A/B を並列に処理させない）|

---

## 5. EQUIV と NOT_EQ の両方の正答率にどう影響するかの予測

### NOT_EQ（現状 90% = 9/10 → 予測 95% = 9-10/10）

**改善メカニズム:**
- 11433（UNKNOWN, 31 ターン）: fail-to-pass テストから先に分析することで、counterexample が fail-to-pass テスト内にある場合は早期に発見でき、ターン消費が削減される
- 既存の正答 NOT_EQ ケース: 現行の "separately before comparing" 要件を維持するため、回帰リスクは極めて低い

**リスク:**
- 11433 の counterexample が pass-to-pass テスト内に存在する場合、改善効果は限定的（ただし悪化もしない）

### EQUIV（現状 80% = 8/10 → 予測 80-90% = 8-9/10）

**改善メカニズム:**
- 15368, 13821（EQUIV 偽陽性）: fail-to-pass テストで SAME 結果を確立できれば、NOT_EQ への早期誘導を防ぐ可能性がある
- 既存の正答 EQUIV ケース: 順序変更は分析の質を下げないため、回帰リスクは低い

**リスク:**
- EQUIV 失敗の根本原因（エージェントが code diff を見て NOT_EQ と即断する推論パターン）は本変更の対象外。15368/13821 への改善は限定的な可能性がある

### 全体予測

現状 85%（EQUIV 8/10 + NOT_EQ 9/10）  
予測 85〜90%（EQUIV 8-9/10 + NOT_EQ 9-10/10）

---

## 6. failed-approaches.md のブラックリストおよび共通原則との照合結果

### ブラックリスト照合

| BL | 本案との違い |
|---|---|
| BL-4 早期打ち切り | 本案は探索を打ち切らない。全 relevant test を分析する（順序のみ変更） |
| BL-12 テストソース先読みによる固定順序化 | BL-12 は「テスト入口を先に読む」というテスト vs コードの読取順序の変更。本案は fail-to-pass vs pass-to-pass という **テスト集合内の優先順位**の明示であり、読取の対象を新たに固定するものではない |
| BL-17 relevant test 検索の拡張 | BL-17 は探索半径を caller/wrapper まで広げた。本案は D2 の既存定義の範囲内で順序を変えるだけ |
| BL-22 D2(b) への禁止指示追加 | BL-22 は「〜から仮定するな」というネガティブプロンプトを追加した。本案は D2 の定義をポジティブな順序指示として反映するだけ |

**結論: いずれのブラックリスト項目とも実質的に異なる。**

### 共通原則照合

| 原則 | 照合結果 |
|---|---|
| #1 判定の非対称操作 | **問題なし**: fail-to-pass テストの先行分析は NOT_EQ・EQUIV 両方向に同等に作用する（どちらも fail-to-pass テストの結果から推論する） |
| #3 探索量の削減 | **問題なし**: 全 relevant test を分析する。順序変更は分析量を減らさない |
| #5 入力テンプレートの過剰規定 | **軽微リスク**: D2(a)/(b) の参照指示が特定の記述フォーマットを誘導する可能性。ただし「何を記録するか」ではなく「どの順序で分析するか」の指示であり、過剰規定には当たらない |
| #6 対称化は差分で評価せよ | **問題なし**: 差分は「fail-to-pass を先に分析する」という BOTH 方向に対称な優先順位の追加 |
| #7 中間ラベル生成のアンカリング | **問題なし**: テスト種別のラベル生成を要求しない。D2(a)/(b) の括弧は既存定義への参照であり、新たなカテゴリ導入ではない |
| #11 探索順序の固定は偏りを生む | **注意**: BL-12 の Fail Core（「最初に読む側に注意がアンカリングされる」）と近い懸念がある。しかし BL-12 は「テスト vs コード」という探索の軸を変えたのに対し、本案は D2 の semantic priority（fail-to-pass > pass-to-pass）を順序指示として反映するだけであり、新たな次元の固定ではない |

---

## 7. 変更規模の宣言

- **追加行数: 0 行（hard limit 5 行以内 ✓）**
- 修正行数: 1 行（既存行の精緻化）
- 削除行数: 0 行
- 新規ステップ・新規フィールド・新規セクション・新規テンプレート要素の追加: なし
