# Iteration 18 — Proposal

## Exploration Framework カテゴリ: A (強制指定)

カテゴリ A「推論の順序・構造を変える」の中から、
今回は **逆方向推論 (backward reasoning)** を選択する。

### カテゴリ内でのメカニズム選択理由

compare モードの per-test 分析は現在、前向き（forward）に進む:
テストを読み → 各変更のコードパスをトレースし → PASS/FAIL を記録する。
この順序では、エージェントは「差異を発見したら止まる」設計になっているが、
EQUIVALENT 判定の場合は差異が見つからないまま分析が終わる。
そのとき、「何を探しているか」が明示されていないため、
確証バイアス（無差異を確認し続けること）が生じやすい。

逆方向推論は「もしこれらが NOT EQUIVALENT なら、どの動作差異が存在するはずか」を
分析開始前に明示させる。これにより per-test トレースが、
無差異確認ではなく、**具体的な反証ターゲットに対する有向探索** になる。
他の Category A メカニズム（ステップ順序の入れ替え、並列/直列変換）より
失敗モードへの対応が直接的であり、変更も最小限に収まる。

---

## 改善仮説

compare モードで EQUIVALENT 判定を下す際、エージェントは
「テストを一通りトレースして差異が見つからなかった」という
消極的な証拠に依存しやすい。
分析開始前に NOT EQUIVALENT となり得る条件を逆算して明示させると、
per-test トレースが方向付けられた反証探索に変わり、
仮説に都合のよい観察だけを積み重ねる確証バイアスが抑制される。
これにより EQUIVALENT 判定の精度が向上し、全体正答率も改善される。

---

## SKILL.md への具体的な変更

### 変更箇所

compare モードの Certificate template 内、
ANALYSIS OF TEST BEHAVIOR セクションの冒頭に 1 行追加する。

### 変更前 (SKILL.md line 203–206 付近)

```
ANALYSIS OF TEST BEHAVIOR:

For each relevant test:
  Test: [name]
```

### 変更後

```
ANALYSIS OF TEST BEHAVIOR:

Pre-analysis: Before tracing any test, state the minimal behavioral difference
that would make these changes NOT EQUIVALENT (e.g., a specific return value,
exception, or side effect that would diverge). This defines the target of the
per-test search below.

For each relevant test:
  Test: [name]
```

### 変更規模の宣言

追加行数: 4 行（hard limit 5 行以内）
削除行数: 0 行（制限カウント対象外）
既存セクションへの文言追加のみ。新規ステップ・新規フィールド・新規セクションなし。

---

## 一般的な推論品質への期待効果

### 減少が期待される失敗パターン

1. **消極的 EQUIVALENT 判定**
   差異が見つからなかったから EQUIVALENT、という構造の判断。
   逆方向ターゲットを先に定義することで、
   「見つからなかった」ではなく「探してなかった」ことが可視化される。

2. **Guardrail #4 の違反（subtle difference dismissal）**
   意味的差異を発見しても「テストに影響しない」と早期に棄却するパターン。
   NOT EQUIVALENT 条件を先に明示しておくと、
   発見された差異がそのターゲットに該当するかを照合する動機が生まれる。

3. **確証バイアスによる探索の早期打ち切り**
   per-test 分析中に「差異なし」が続くと分析が形式化し、
   後半のテストが浅くなる傾向がある。
   分析前に反証ターゲットを宣言すると、後半テストへの注意も維持される。

### 影響しない（回帰リスクが低い）パターン

- NOT EQUIVALENT 判定: COUNTEREXAMPLE セクションは変更しないため影響なし
- diagnose / explain / audit-improve モード: compare テンプレート固有の変更であり無影響
- STRUCTURAL TRIAGE による早期終了パス: Pre-analysis より前に完了するため無影響

---

## failed-approaches.md の汎用原則との照合

### 原則 1: 探索の証拠種類をテンプレートで事前固定しすぎない

今回の変更は「何の証拠を探すか」を固定するのではなく、
「どのような **差異** が存在すれば NOT EQUIVALENT になるか」という
**方向性** を宣言させるに留まる。
具体的な探索対象（ファイル、関数、テスト）は依然としてエージェントが判断する。
→ 抵触しない。

### 原則 2: 探索ドリフト対策で探索の自由度を削りすぎない

Pre-analysis は探索手順を制約するのではなく、
「分析の目的を明確にする」プロンプトである。
per-test のトレース手順・観察の記録方法は変更しない。
→ 抵触しない。

### 原則 3: 結論直前の自己監査に新しい必須メタ判断を増やしすぎない

Pre-analysis は ANALYSIS セクションの **冒頭** に置かれる前処理であり、
Step 5.5（結論直前の自己チェック）には手を加えない。
また「推論の最弱点を特定させる」ような複合評価軸ではなく、
1 つの問い（NOT EQUIVALENT 条件の明示）に限定している。
→ 抵触しない。

---

## 変更規模の宣言（再掲）

- 追加行数: 4 行
- 変更行数: 0 行
- 削除行数: 0 行
- hard limit (5 行) に対して: 適合
