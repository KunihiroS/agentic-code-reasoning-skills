過去提案との差異: compare の早期 NOT_EQUIV 条件や観測境界の制限ではなく、全モード共通の Step 5 に「反証対象の明示」という表現改善を入れる。
Target: 両方（偽 EQUIV と偽 NOT_EQUIV を同時に減らす）
Mechanism (抽象): Step 5 のチェック対象を「結論」から「反転させる主張（decision‑critical claim）」へ言語化し、テンプレート上で対象主張を先に宣言させる。
Non-goal: STRUCTURAL TRIAGE の条件調整・早期 NOT_EQUIV の条件限定・特定の証拠種類の事前固定は行わない。

カテゴリ E（表現・フォーマット）としての選択理由
- 現状の Step 5 は「やり方（counterfactual の書式）」は定義されている一方、どの主張を反証対象として選ぶかがテンプレート上で曖昧なまま残る。
- 曖昧さは、(a) 反証が“結論全体”にぼやけて実質チェックにならない（偽 EQUIV を通す）か、(b) 局所の些末差に過集中して結論反転シグナルを外す（偽 NOT_EQUIV を増やす）両方の形で回帰しうる。
- そこで、追加ゲートではなく「1行の欄追加」と「1行の定義追記」で、反証の“対象の選び方”をテンプレート駆動にする。

改善仮説（1つ）
- Step 5 の記述で「何を falsify するチェックか」を先に固定（=対象主張を明示）すると、反証が“探索の正当化文”に落ちず、EQUIV / NOT_EQUIV どちらでも結論反転に効く反例探索へ収束しやすくなる。

SKILL.md 該当箇所（短い引用）
- Step 5 scope: "Apply counterfactual reasoning ... at every key intermediate claim"
- テンプレート冒頭: "If my conclusion were false, what evidence should exist?" / "If the opposite answer were true, what evidence would exist?"

どう変えるか（要点）
- 「key intermediate claim」を“それが誤りなら最終回答が反転する主張”として 1 行で定義する。
- Step 5 テンプレートに 1 行だけ "TARGET CLAIM:" 欄を追加し、反証対象を明示してから探索を書く。
  （証拠種類や観測境界は固定しない。あくまで“対象主張”の明示のみ。）

Decision-point delta（IF/THEN 2行）
Before: IF Step 5 を書く THEN "結論が偽なら何があるべきか" から開始する because counterfactual（対象主張が暗黙）
After:  IF Step 5 を書く THEN 先に "TARGET CLAIM:（誤りなら最終回答が反転する主張）" を宣言してから開始する because counterfactual（反証対象を明示）

変更差分プレビュー（抜粋 3–10行）
Before:
  **Scope**: Apply counterfactual reasoning ... at every key intermediate claim — especially:
  COUNTEREXAMPLE CHECK:
  If my conclusion were false, what evidence should exist?
  ALTERNATIVE HYPOTHESIS CHECK:
  If the opposite answer were true, what evidence would exist?
After:
  **Scope**: Apply counterfactual reasoning ... at every key intermediate claim (i.e., a claim that, if false, would flip your final answer).
  COUNTEREXAMPLE CHECK:
  TARGET CLAIM: [the decision-critical claim you are trying to falsify]
  If my conclusion were false, what evidence should exist?
  ALTERNATIVE HYPOTHESIS CHECK:
  TARGET CLAIM: [the decision-critical claim you are trying to falsify]
  If the opposite answer were true, what evidence would exist?

failed-approaches.md との照合（整合 1–2点）
- 「次の探索で探すべき証拠種類をテンプレで事前固定しすぎる」を回避: 追加するのは evidence 種別ではなく、反証すべき“主張”の明示欄のみ。
- 「判定基準を特定の観測境界に過度還元」を回避: 早期 NOT_EQUIV 条件やテスト可視性など、境界の限定は一切導入しない。

変更規模の宣言
- SKILL.md の変更は最大 3 行（Scope 1 行の追記 + テンプレート 2 行追加）。