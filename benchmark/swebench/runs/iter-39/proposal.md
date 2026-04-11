# Iteration 39 — 改善案提案（改訂版）

## 1. 選択した Exploration Framework カテゴリ

**カテゴリ F：原論文の未活用アイデアを導入する**

具体的サブアプローチ：「論文の anti-skip 機構を compare モードの変更コード読み取り時に適用する」

### 選択理由

前回提案（カテゴリ C: D3 定義 + D3 check 欄追加）は、BL-6/BL-8/BL-10/BL-16 および iter-26 と実質的に重複すると指摘を受け却下された。

既試行カテゴリの整理：
- カテゴリ A（推論順序）: BL-12, BL-14 で失敗済み
- カテゴリ B（情報取得）: iter-37（checklist 1 行追加）で 65%→75% に改善、頭打ち
- カテゴリ C（比較枠組み）: BL-7, BL-16, iter-26, iter-38, iter-39 初版で失敗済み
- カテゴリ D（メタ認知）: BL-9 で失敗済み
- カテゴリ E（表現改善）: 直接改善効果が限定的
- **カテゴリ F（原論文の未活用アイデア）**: iter-38 が P[N] クロスリファレンス導入を試みたが、まだ未活用のサブアプローチが残っている

原論文 (Ugare & Chandra, arXiv:2603.01896) Section 4 の error analysis は「incomplete reasoning chains」をコアエラーとして位置づけ、その対策として **変更コードを読んだ直後に downstream handler / caller を少なくとも 1 段追う** anti-skip 機構を規定している。

現在の SKILL.md の Compare checklist には「変更コードが呼ぶ関数を読め」（下方向: changed code → 呼び出し先）という義務があるが、**「変更コードの return value を使う caller を読め」（上方向: changed code → 呼び出し元）** という義務が欠落している。これが論文の未活用アイデアであり、カテゴリ F の未試行サブアプローチである。

---

## 2. 改善仮説

**仮説**: Compare checklist に「直接変更された関数を読んだ直後に、その immediate caller が変更後の return value / side-effect をどう使っているかを読め」という探索行動義務を 1 行追加することで、エージェントが「変更コードに差異を発見 → 即 DIFFERENT」というショートカットを踏む前に、変更の影響が実際にテスト assertion まで伝播するかを自然に確認するようになる。

現在の EQUIV 偽陰性の失敗パターン（15368, 13821, 15382 と推定）:
1. エージェントは変更された関数を読み、差異を発見する
2. その差異が caller によって正規化・吸収されるかを確認せずに NOT_EQUIVALENT と結論する

新しい checklist 項目が機能するメカニズム：
- 変更関数の immediate caller の use を読む → caller が差異を吸収する場合に EQUIVALENT と正しく判定できる
- 変更関数の差異が caller を通じて伝播する場合 → NOT_EQUIVALENT を確認できる（既存の正答に影響しない）

この変更は「before asserting DIFFERENT」という表現を含まない（iter-26 との違い）。探索段階（Step 3/4 の trace table 構築中）に適用され、結論段階での非対称な立証要求ではない。

---

## 3. SKILL.md のどこをどう変えるか

### 変更箇所：Compare checklist（1 行追加）

**変更前**（checklist 3 行目と 4 行目の間）:

```
- For each function called in changed code, read its definition and record in the interprocedural trace table (Step 4)
- Trace each test through both changes separately before comparing
```

**変更後**（間に 1 行追加）:

```
- For each function called in changed code, read its definition and record in the interprocedural trace table (Step 4)
- After reading a directly changed function, read how its immediate caller uses the changed return value or side-effect — trace at least one step toward the test assertion
- Trace each test through both changes separately before comparing
```

### 変更規模

- 追加：+1 行
- 変更・削除：0 行
- 合計差分：**+1 行**（20 行以内の目安を大幅に下回る）

---

## 4. EQUIV と NOT_EQ の両方の正答率への影響予測

### EQUIV 正答率（現在 7/10）
**改善見込み：8〜9/10**

失敗 3 件（15368, 13821, 15382）の推定失敗パターン：エージェントが変更された関数を読み、コードレベルの差異を発見した時点で「差異がある → DIFFERENT」と結論する。変更後の return value が caller でどう処理されるかを追わない。

新規 checklist 項目は変更関数の immediate caller を読む行動義務を発生させる：
- Caller が差異を吸収・正規化する場合 → テスト assertion に差異が到達しないことを発見 → EQUIVALENT と正しく判定
- Caller が差異を伝播させる場合 → 伝播が確認される → DIFFERENT の根拠が強化される（既存正答に影響なし）

### NOT_EQ 正答率（現在 8/10）
**維持見込み：8/10**

真の NOT_EQ ケースでは、変更関数の差異は caller を通じてテスト assertion まで伝播する。Caller の use を読むことでその伝播が確認され、NOT_EQUIVALENT の結論を変えることなく証拠を強化する方向に作用する。新規項目は「DIFFERENT と主張する前に確認せよ」という結論段階の制約ではなく、探索段階の行動義務であるため、NOT_EQ ケースでの追加記述コストは最小限に抑えられる。

---

## 5. failed-approaches.md ブラックリスト・共通原則との照合

| BL / 原則 | 照合 | 根拠 |
|-----------|------|------|
| BL-6（対称化の差分が非対称） | ✅ 非該当 | 本変更は「DIFFERENT 主張前の確認」という結論段階の義務ではない。変更コード読み取り時という探索段階に適用され、既存制約との差分は SAME/DIFFERENT 両方向に均等に作用する探索行動の追加 |
| BL-8（受動的記録フィールド） | ✅ 非該当 | 記録欄の追加ではなく、**読むべきコードの指定**。「何を書くか」ではなく「何を読むか」を要求する探索行動の義務。記録オーバーヘッドを追加しない |
| BL-10（Reachability ゲート） | ✅ 非該当 | YES/NO の条件分岐ゲートではなく、「caller を読む」という行動要件。Caller が差異を吸収するかは trivially 解決しない（実際に読まないと判断できない） |
| BL-16（Comparison 周辺の観測フレーム） | ✅ 非該当 | Comparison 行・テンプレート本体（ANALYSIS OF TEST BEHAVIOR）に手を加えない。Compare checklist の探索フェーズへの追加 |
| iter-26（assertion 到達確認） | ✅ 異なる | iter-26 は結論段階に「assert 到達を確認せよ」という検証義務を追加した。本提案は探索段階に「caller の use を読む」という行動義務を追加する。**適用タイミング（結論 vs 探索）と機構（検証義務 vs 読む行動）が根本的に異なる** |
| 共通原則 #1（判定の非対称操作） | ✅ 適合 | 「DIFFERENT と書く前に～」ではなく「変更コードを読んだら～」。非対称な立証要求を生まない |
| 共通原則 #2（出力側の制約） | ✅ 適合 | 出力（結論・テンプレート記述）ではなく、入力側（何を読むか）の改善 |
| 共通原則 #5（入力テンプレートの過剰規定） | ✅ 適合 | 「何を記録するか」ではなく「どう探索するか」の指示。探索の視野を狭めない |
| 共通原則 #8（受動的記録フィールド） | ✅ 適合 | 記録欄を追加しない。探索行動（追加のコード読み取り）を要求する |
| 共通原則 #10（失敗モードを弁別しないゲート） | ✅ 適合 | ゲートではないため trivially 通過される問題が発生しない |

---

## 6. 原論文との対応

論文 Section 4 の「incomplete reasoning chains」エラー分析：「関数を複数トレースしても downstream での処理を見落とす」パターンが記述されている。SKILL.md の Step 4 Rules は「Trace through conditionals... not just the happy path」や「if this trace were wrong, what concrete input would produce different behavior?」を要求しているが、これらは tracing DOWN（変更コードが呼ぶ関数）への義務である。

Compare モードでは、変更コードから TEST ASSERTION までの UP 方向（変更コードを呼ぶもの）への追跡が不足している。現在の checklist 第 3 項「For each function **called** in changed code」は下方向トレースを要求するが、「変更コードを**呼ぶ** caller の use」への追跡は明示されていない。

本提案は論文の anti-skip 機構の compare モードへの適用であり、Step 4 の「下向きトレース完全性」を補完する「上向きトレースの起点義務」として機能する。

---

## 7. 既試行との差別化（詳細）

### iter-26 との差
- iter-26（失敗）: checklist に「`When claiming different test outcomes, verify the behavioral divergence reaches the test assertion condition`」を追加 → **結論段階**での検証義務、DIFFERENT 主張時のみ発火
- 本提案: checklist に「`After reading a directly changed function, read how its immediate caller uses the changed return value`」を追加 → **探索段階**での行動義務、変更コードを読んだ時点で常に発火

差の核心：iter-26 は「DIFFERENT と主張する前に確認せよ」という **非対称な結論段階の義務** であり、BL-6 型の問題を持つ。本提案は「変更コードを読んだら次を読む」という **探索拡張の行動義務** であり、結論の方向性に依存しない。

### BL-16 との差
- BL-16（失敗）: `Comparison:` 行の直前に観測基準の注釈を埋め込み → compare テンプレートの Comparison 周辺に観測フレームを追加
- 本提案: Compare checklist の探索フェーズに 1 行追加 → Comparison テンプレート本体に手を加えない

### BL-10 との差
- BL-10（失敗）: 「テストが変更コードに到達するか」 → YES/NO ゲート（relevant test に対して trivially YES）
- 本提案: 「変更関数の caller の use を読む」 → 行動義務（trivially 解決しない：caller が差異を吸収するか伝播させるかは実際に読んで確認する必要がある）
