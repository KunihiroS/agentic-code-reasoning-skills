# Iter-112 — Improvement Proposal

## カテゴリ: E（表現・フォーマットを改善する）

### カテゴリ E 内のメカニズム選択理由

カテゴリ E の選択肢は「曖昧文言の具体化・簡潔化・例示」の 3 種。
今回は **曖昧文言の具体化** を選択する。

対象は Guardrails の #5 の末尾文言：

> Confident-but-wrong answers often come from **thorough-but-incomplete analysis**.

「thorough-but-incomplete（徹底的だが不完全）」は形容矛盾に近く、
エージェントが「何が不完全なのか」を具体的に把握しにくい。
例示を追加すると固有の物理ターゲットへの過剰適応を招くリスクがある（failed-approaches #22）
ため、具体物ではなく **状態・性質の記述** で曖昧さを解消するのが適切。

---

## 改善仮説

> Guardrail #5 の「thorough-but-incomplete analysis」という形容矛盾を、
> 「正しい関数はトレースしたが最終観測点の手前で止まっている連鎖」という
> 状態記述に書き換えることで、エージェントが「どこまで追跡すれば完全とみなせるか」
> を正確に理解し、中間ノードで推論を打ち切る失敗が減る。

---

## SKILL.md の変更内容

**変更箇所**: Guardrails セクション、Guardrail #5 末尾の 1 文

```
変更前:
5. **Do not trust incomplete chains.** After building a reasoning chain,
   verify that downstream code does not already handle the edge case or
   condition you identified. Confident-but-wrong answers often come from
   thorough-but-incomplete analysis.

変更後:
5. **Do not trust incomplete chains.** After building a reasoning chain,
   verify that downstream code does not already handle the edge case or
   condition you identified. Confident-but-wrong answers often come from
   chains that trace the right functions but stop before the final
   observation point.
```

**変更行数**: 1 行修正（末尾文の書き換えのみ）

---

## 期待効果

### どのカテゴリ的失敗パターンが減るか

| 失敗パターン | 現状の問題 | 改善後の効果 |
|---|---|---|
| 中間ノード打ち切り | 「thorough」と書いてあるため自分の分析が十分と誤解しやすい | 「final observation point まで届いていないこと」が明確になり、追跡の終点を意識する |
| overall 精度低下 | 差分が中間関数に存在するとわかった時点でトレースを終わらせる | テストの最終 PASS/FAIL が観測できる地点まで追うべきと理解される |

- **overall** フォーカスに直接作用する：compare・localize・explain すべての
  モードで、中間ノード打ち切りが誤判定の原因になりうる。
- Guardrail #5 は "Subtle difference dismissal" という論文の失敗パターンに
  対応する番号であり、その文言を精緻化することは論文の知見の忠実な実装である。

---

## failed-approaches.md との照合

| 原則 | 照合結果 |
|---|---|
| #1 判定の非対称操作 | 非抵触 — 特定判定方向への有利化なし |
| #2 出力側の制約 | 非抵触 — 出力形式を制約していない |
| #3 探索量の削減 | 非抵触 — 探索を減らす変更ではない |
| #4 同じ方向の変更 | 非抵触 — 過去に同一方向の文言変更の記録なし |
| #5 入力テンプレートの過剰規定 | 非抵触 — テンプレートのフィールドを変更していない |
| #16 ネガティブプロンプト | 非抵触 — 禁止文言の追加ではなく概念の明確化 |
| #20 厳格・排他的な書き換え | 非抵触 — 「止まるな」という禁止ではなく「どこまでが完全か」の記述 |
| #22 具体物の例示 | **準拠** — 具体的なファイル・関数を例示せず状態記述で表現している |

全原則で非抵触・準拠を確認。

---

## 変更規模の宣言

- 変更行数: **1 行**（修正）
- 削除行: 0
- 新規ステップ・新規フィールド・新規セクション: なし
- Hard limit（5 行）: **適合**
