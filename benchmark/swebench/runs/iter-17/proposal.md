# Iteration 17 — Proposal

## Exploration Framework カテゴリ

カテゴリ: F（原論文の未活用アイデアを導入する）

### このカテゴリ内でのメカニズム選択理由

Objective.md の Exploration Framework §F に挙げられた3つのメカニズムのうち、
「論文の他のタスクモード（localize/explain）の手法を compare に応用する」を選択する。

具体的には、論文 Appendix D（Code Question Answering テンプレート）の
DATA FLOW ANALYSIS — 「変数が作成・変更・使用されるまでの伝播経路を明示追跡する」
という手法を、compare モードの差分評価に応用する。

docs/design.md の以下の記述が根拠：
> "Beyond the templates, the paper also documents recurring failure patterns...
> Incomplete reasoning chains (§4.3 Error Analysis):
> The agent traces multiple functions but misses downstream handling."

この失敗パターンは compare モードで特に顕在化する。差異のある変数が最終的に
テストのアサーション対象の変数に伝播するかどうかを確認しないまま「影響なし」
と判定するケースがある。explain モードの変数追跡（DATA FLOW ANALYSIS）の
考え方はこの盲点を補う未活用知見である。

---

## 改善仮説

「差分によって生じた変数の値の変化が、テストのアサーション対象まで伝播するか
どうかを明示的に確認する義務を compare モードの差分評価に課すことで、
下流ハンドリングの見落とし（incomplete reasoning chain）による誤判定を減らせる。」

---

## SKILL.md のどこをどう変えるか

### 変更箇所

Guardrails セクション、Guardrail #4 の文末（1文追加）。

### 変更前

```
4. **Do not dismiss subtle differences.** If you find a semantic difference between
   compared items, trace at least one relevant test through the differing code path
   before concluding the difference has no impact.
```

### 変更後

```
4. **Do not dismiss subtle differences.** If you find a semantic difference between
   compared items, trace at least one relevant test through the differing code path
   before concluding the difference has no impact. When tracing, follow the changed
   variable's value from the point of divergence through to the assertion — confirm
   whether downstream code transforms or discards it before it reaches the test oracle.
```

### 変更規模の宣言

追加: 1文（1行）
削除: 0行
合計変更行数: 1行 ← hard limit（5行）の範囲内

---

## 一般的な推論品質への期待効果

### 減少が期待される失敗パターン

1. **EQUIVALENT 誤判定（compare モード）**
   差分のある関数が呼ばれているにもかかわらず、変数の下流伝播を確認せずに
   「差分はテストに影響しない」と早期結論する誤りを防ぐ。
   README.md に記載された「Two persistent failures remain — both involve EQUIVALENT
   pairs where the AI's code trace or scope judgment is incorrect.」に対応する。

2. **Incomplete reasoning chain（全モード共通）**
   docs/design.md の §4.3 Error Analysis が指摘するパターン：
   「エージェントが複数の関数をトレースするが、下流のハンドリングを見落とす」。
   Guardrail #4 はすでに「差分を無視しない」を要求しているが、
   「どこまでトレースすれば十分か」の指針がなかった。
   追加文により「アサーション到達まで追う」という終端条件が明示される。

3. **過信した EQUIVALENT 結論**
   Guardrail #5（「downstream code does not already handle the edge case」の確認）と
   相互補完し、差分の無害性を「変数伝播の不在」という具体的証拠で支える。

---

## failed-approaches.md の汎用原則との照合

| 原則 | 本提案の評価 | 理由 |
|------|-------------|------|
| 「探索すべき証拠の種類をテンプレートで事前固定しすぎる変更は避ける」 | 抵触しない | 「アサーション到達まで変数を追う」は探索経路の固定ではなく、トレースの終端条件の明示。何を探すかではなく「どこまで確認すれば十分か」を与える指針であり、仮説に都合よい証拠だけを追う確認バイアスは誘発しない。 |
| 「ドリフト抑制のための局所的具体化は探索の幅を狭める」 | 抵触しない | 変更はトレースの深度（どこまで追うか）の指針であり、探索の幅（どのファイルを読むか）を削減しない。 |
| 「結論直前の自己監査に新しい必須のメタ判断を増やしすぎない」 | 抵触しない | Step 5.5 には手を加えない。Guardrail #4 の本文への補足であり、新しい判定ゲートや自己監査チェック項目の追加ではない。既存の「trace at least one relevant test through the differing code path」という要求の具体化にとどまる。 |

全原則に抵触しないと判断する。

---

## 変更規模の宣言

- 追加行: 1行
- 削除行: 0行
- 合計: 1行（hard limit 5行 以内）
