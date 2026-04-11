# Iteration 23 — 改善案（再提案）

## 選択カテゴリ: E（表現・フォーマットを改善する）— ANALYSIS 文言の明確化

### 選択理由

- 監査役フィードバック（iter-23 discussion.md）の指摘を受け、前案（カテゴリ A、TEST ASSERTION ANCHORING）は BL-1・BL-5 に実質的に抵触するとして差し戻された。
- 監査役は代替案として「ANALYSIS の `because [trace through code]` 指示を `test outcome mechanism` 中心に言い換える」カテゴリ E アプローチを提示した。本案はその提案を具体化したものである。
- 過去の未試行カテゴリ E を選択する理由:
  - 既存の失敗（BL-1〜10）はいずれも「何を記録するか（テンプレートのフィールド）」「何と比較しないか（除外ルール）」「閾値・立証責任」の変更である。本案は「推論の対象範囲の説明文言を正確にする」という異なる次元の改善。
  - 既存の Compare テンプレートの `because [trace through code — cite file:line]` は、トレース対象が何かを明示していない。モデルが「assert 文の前後のみ」をトレースしても形式上は満たせてしまう。
  - BL-4・BL-9・BL-10 はいずれも「追加フィールド」「条件分岐ゲート」「自己チェック」など新規構造物の挿入。本案は追加構造物を挿入せず、既存の `because [...]` 指示の説明文言のみを拡張する最小変更。

---

## 改善仮説

**Compare テンプレートの `ANALYSIS OF TEST BEHAVIOR` における `because [trace through code — cite file:line]` という指示は、「何をトレースするか」を限定していない。現状の文言では assert 文前後のコードだけをトレースしても形式上要件を満たせてしまい、例外・setup/teardown 失敗・副作用・control-flow 分岐など assert 以外のテスト結果決定要因を見落とすリスクがある。この指示を「テスト結果を決定する具体的なメカニズム（assertion、raised exception、setup/teardown failure、後続チェックの side effect）をトレースせよ」と明確化することで、特に NOT_EQ のトレース精度を損なわずに、assert 以外のメカニズムを通じてもテスト結果が変わらないと判定できる EQUIV ケースの分析精度を向上させる。**

根拠:
- 監査役フィードバック（iter-23 discussion §1「代替提案」）: 「`assertion` 中心ではなく `test outcome mechanism` 中心に言い換える。`Do not reduce the analysis to a single assert statement unless that is truly the only determinant.`」という具体的な文言提案を踏まえる。
- BL-5 の失敗コアは「PREMISES テンプレートが assert 行だけを記録させ、副作用・例外・テストフロー全体を落とした」ことだった。本案はその逆の方向に作用する: トレース指示の範囲を「assert 文だけ」から「assert を含む全ての pass/fail 決定要因」に **広げる**。
- 共通原則 #5（入力テンプレートの過剰規定は探索視野を狭める）の教訓を適用すると、現状の `because [trace through code]` は曖昧すぎて assert 行への過集中を防げていない。「何をトレースするか」の説明を具体化することは「視野を狭める」のではなく「見落としを防ぐ注意喚起」であり、性質が異なる。
- 既存の BL 群（BL-1〜10）が試みたのは「新規フィールドの追加」「条件分岐ゲートの挿入」「閾値変更」「自己チェック追加」など構造的な追加・変更。本案は既存の `because [...]` 指示の括弧内説明を拡充するだけで、新規フィールドも新規ステップも追加しない。

---

## SKILL.md の変更内容

**変更箇所**: Compare モードの Certificate template 内、`ANALYSIS OF TEST BEHAVIOR` ブロック冒頭に、per-test ループの前に 1 文の注釈を追加する。

**変更前**:
```
ANALYSIS OF TEST BEHAVIOR:

For each relevant test:
  Test: [name]
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Comparison: SAME / DIFFERENT outcome
```

**変更後**:
```
ANALYSIS OF TEST BEHAVIOR:
For each test, trace the concrete mechanism that determines pass/fail — this may be an assertion, a raised exception, a setup/teardown failure, or a side effect checked later in the test. Do not reduce the trace to a single assert statement unless that is truly the only outcome determinant.

For each relevant test:
  Test: [name]
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Comparison: SAME / DIFFERENT outcome
```

**変更内容**: 1文の注釈を追加（2行）。他セクションへの変更なし。  
**変更規模**: 2行追加。≤20行の制約内。

---

## EQUIV / NOT_EQ の正答率への影響予測

### EQUIV（現状: 7/10 = 70%）
- **予測: ±0〜+2**
- 13821/15382: 持続的失敗の一因は「コード差異を発見 → そのパスが assert に届くと推論 → NOT_EQ」というショートカット。本案はトレースすべきメカニズムの範囲を明示することで「assert に届くか」の問いを「pass/fail を決定するメカニズム全体に届くか」に精緻化し、誤った推論ジャンプを抑止する可能性がある。
- 安定正解 7 件: テンプレートの構造を変えず、`because [trace]` 指示の説明を広げるだけなので、すでに正しくトレースしているケースへの影響は最小。

### NOT_EQ（現状: 10/10 = 100%）
- **予測: 0（維持）**
- 本案はトレース対象を「assert 以外にも exception・setup failure・side effect を含む」に広げる。これは NOT_EQ の証拠を減らす方向ではなく、むしろ assert 以外のメカニズムで失敗するケースの検出力を補完する方向に作用する。
- NOT_EQ の立証責任を引き上げる出力制約（BL-2 型）でなく、トレース対象の説明文を広げる入力側の変更であるため、回帰リスクは低い。

---

## failed-approaches.md ブラックリストおよび共通原則との照合

| 項目 | 判定 | 理由 |
|------|------|------|
| BL-1 (ABSENT 定義) | 非抵触 | 削除テストの扱いを定義する変更を一切行わない。比較対象から何かを除外するルールなし。 |
| BL-2 (NOT_EQ 閾値引き上げ) | 非抵触 | 判定の立証責任・閾値・証拠要件を変更しない。 |
| BL-3 (UNKNOWN 禁止) | 非抵触 | 回答形式への制約なし。 |
| BL-4 (早期打ち切り) | 非抵触 | 探索を打ち切らない。 |
| BL-5 (P3/P4 過剰規定) | **逆方向に作用** | BL-5 は assert 行への視野を **狭める** 変更で失敗した。本案は「assert だけに限らずメカニズム全体を見よ」とトレース視野を **広げる** 変更。効果の方向が逆。 |
| BL-6 (Guardrail 4 対称化) | 非抵触 | Guardrail への変更なし。 |
| BL-7 (CHANGE CHARACTERIZATION) | 非抵触 | 変更の性質ラベリングを行わない。中間ラベルを生成させない。 |
| BL-8 (Relevant to 列) | 非抵触 | テーブルへの列追加なし。受動的記録フィールドを追加しない。 |
| BL-9 (Trace check 自己チェック) | 非抵触 | メタ認知的自己評価ステップを挿入しない。 |
| BL-10 (Reachability ゲート) | 非抵触 | 条件分岐ゲートを追加しない。 |
| 共通原則 #1 (非対称操作) | 非抵触 | `ANALYSIS OF TEST BEHAVIOR` の冒頭注釈は fail-to-pass/pass-to-pass の両ブロックに等しく適用され、EQUIV/NOT_EQ いずれの方向にも一方的に倒さない。 |
| 共通原則 #2 (出力制約は無効) | 非抵触 | 出力（判定・回答形式）への制約なし。入力側のトレース指示の明確化。 |
| 共通原則 #3 (探索量削減は有害) | 非抵触 | トレース対象範囲を広げる方向の変更であり、探索量を削減しない。 |
| 共通原則 #5 (入力テンプレート過剰規定) | 非抵触 | 本案は assert 行記録を**要求する**のではなく、assert だけに限定しないよう注意喚起する。探索視野を狭めるのではなく、広げる方向の変更。 |
| 共通原則 #7 (中間ラベルのアンカリング) | 非抵触 | 判定方向と相関するラベルを生成させない。 |
| 共通原則 #8 (受動記録 ≠ 能動検証) | 非抵触 | 記録フィールドを追加しない。既存の `because [trace]` 指示をより明確にすることで、能動的なトレース行動を促す。 |

---

## 変更規模

- **追加**: 2行（`ANALYSIS OF TEST BEHAVIOR:` 直後に注釈 1 文）
- **変更・削除**: なし
- **変更規模評価**: ≤20行の制約内。既存テンプレートの構造・他セクション・他モードに一切影響なし。最小限の文言拡充。
