過去提案との差異: iter-12〜14 のように「STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を特定の観測境界へ狭める」方向ではなく、Step 5（反証）の実行順序だけを“結論を左右する主張から先に”へ再配置する。
Target: 両方（偽 EQUIV と偽 NOT_EQUIV）
Mechanism (抽象): 反証を「全ての主要主張に均等適用」から「結論反転に必要十分な hinge-claim から優先適用」へ順序最適化する。
Non-goal: STRUCTURAL TRIAGE の早期結論条件（missing file/import 等）を制限・置換したり、新しい必須ゲートを増やしたりしない。

カテゴリA（推論の順序・構造）内でのメカニズム選択理由
- SKILL.md は Step 3 で「次アクションは discriminative power（不確実性を最も解消する）で選ぶ」と明記している一方、Step 5（反証）は“どの主張から反証するか”の順序原理が弱く、結果として(1) 重要でない主張へ反証努力が分散する、(2) 結論を左右する主張の反証が遅れ、早期に誤結論が固まる、の両リスクが残る。
- そこで「反証の対象の選び方（対象の優先順位）」にだけ順序原理を導入し、探索の自由度を削らずに（境界を固定せずに）全モード共通で効く改善にする。

改善仮説（1つ）
- 反証（Step 5）を hinge-claim（否定されると結論が反転する最小集合）から先に当てる順序へ変えると、(a) 偽 EQUIV: 重要差分の見落とし、(b) 偽 NOT_EQUIV: 重要でない差分への過剰反応、の両方を同時に減らせる。

SKILL.md 該当箇所（短い引用）と変更案
- 現行（Core Method / Step 5）:
  "Scope: Apply counterfactual reasoning not only at the final conclusion, but at every key intermediate claim — especially:"
- 変更: 「まず hinge-claim を選んでそこから反証する」順序を 1〜2 文で差し込み、既存の例示（especially 以下）を圧縮して置換する（必須手順の総量は増やさない）。

Decision-point delta（IF/THEN、2行）
Before: IF Step 5 で複数の key intermediate claim がある THEN それらを広く（網羅気味に）反証対象として扱う because 重要度の序列が明示されていない。
After:  IF Step 5 で複数の key intermediate claim がある THEN まず 1–2 個の hinge-claim（否定されると結論が反転する主張）から反証する because 最大の判別力を最初に確保し、早期収束の誤りを減らす。

変更差分プレビュー（Before/After, 3–10行）
Before:
  ### Step 5: Refutation check (required)
  This step is **mandatory**, not optional.

  **Scope**: Apply counterfactual reasoning not only at the final conclusion, but at every key intermediate claim — especially:
  - "No test exercises this difference" — ...
  - "This behavior is X" ...
  - "These test outcomes are identical/different" — ...

After:
  ### Step 5: Refutation check (required)
  This step is **mandatory**, not optional.

  **Scope**: When multiple key intermediate claims exist, start with 1–2 hinge claims (claims whose negation would flip your conclusion), then expand to other key claims as needed.
  - "No test exercises this difference" — ...
  - "This behavior is X" ...
  - "These test outcomes are identical/different" — ...

failed-approaches.md との照合（整合 1–2 点）
- 「証拠の種類をテンプレで事前固定しすぎない」に整合: hinge-claim は“特定の証拠タイプ”を固定せず、各タスクの結論反転点に応じて対象が変わる（方向非依存）。
- 「探索の自由度を削りすぎない」に整合: 新しい観測境界への還元や、特定経路の半固定は行わず、既存 Step 5 の範囲内で“どこから反証するか”の順序だけを与える。

変更規模の宣言
- SKILL.md 変更は Step 5 の Scope 文を 1〜2 文差し替えるだけ（最大 4〜5 行以内、必須ゲートの純増なし）。
