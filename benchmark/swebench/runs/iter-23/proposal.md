過去提案との差異: 早期NOT_EQUIV条件や反証優先順位(“pivot claims”/highest-tier-first)の再設計ではなく、原論文の explain(コードQA)由来のデータフロー手法を compare の「差分影響判定」に移植する提案。
Target: 両方（偽 EQUIV と 偽 NOT_EQUIV を同時に減らす）
Mechanism (抽象): 「差分を見つけたらテストを1本トレース」ではなく「テストの assert へ流れ込む値を起点に最小データフロー(スライス)を両側で確認」へ切り替える。
Non-goal: STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件をどう制限するか／観測境界へ還元する方針の追加はしない。

カテゴリF内での具体的メカニズム選択理由
- docs/design.md は原論文 Appendix D (Code Question Answering) のテンプレ要素として「Function trace table (VERIFIED)」「data flow tracking」「alternative hypothesis check」を抽出している。
- SKILL.md の explain には DATA FLOW ANALYSIS がある一方、compare で「差分がテスト outcome に影響するか」の判定は、現状は“少なくとも1本トレース”という粗い指示に寄っており、差分の重要度判断が過剰(偽NOT_EQ)にも過小(偽EQUIV)にも振れやすい。
- そこで、原論文由来だが compare には未活用な「データフローで結論に寄与する値へ局所化する」手法を、差分影響判定のガードレールに最小限で導入する。

改善仮説（1つ）
- 仮説: 「差分を見つけたとき、assert に到達する値（入力→中間→出力）のデータフローを明示して両側比較する」ことを既定の行動にすると、(a) 差分が assert に届かない場合の過剰な NOT_EQUIV を減らし、(b) 差分が assert に届く場合の見落としを減らして、EQUIV/NOT_EQ の両方向の誤判定を同時に抑える。

SKILL.md の該当箇所（短い引用）と変更方針
- 現状（Guardrails #4）:
  “If you find a semantic difference between compared items, trace at least one relevant test through the differing code path before concluding the difference has no impact.”
- 変更: 上記の「trace a test」を、explain の DATA FLOW ANALYSIS 発想で「assert へ流れ込む値を起点に、差分→assert の到達可否を最小スライスで両側確認」へ置換する（行動が変わる）。

Decision-point delta（IF/THEN 2行）
Before: IF semantic difference is found THEN trace at least one relevant test through the differing code path because call-path evidence
After:  IF semantic difference is found THEN trace the assert-dependent data flow slice (difference → asserted value) on both sides before judging impact because data-flow-to-assert evidence

変更差分プレビュー（Before/After）
Before:
- 4. **Do not dismiss subtle differences.** If you find a semantic difference between compared items, trace at least one relevant test through the differing code path before concluding the difference has no impact.
After:
- 4. **Do not dismiss subtle differences.** If you find a semantic difference between compared items, identify the assert-dependent value(s) and trace the minimal data flow slice (difference → asserted value) on both sides before concluding the difference has no impact.

failed-approaches.md との照合（整合点）
- 「証拠種類の事前固定を避ける」: 追加で“探すべき証拠タイプ”を固定せず、既に compare で必須の「テスト/assert」という同一根拠に対して、到達経路の切り出し方（データフロー）だけを提示する。
- 「探索経路の半固定を避ける」: 読解順序や観測境界を固定しない。差分が見つかった“局所の瞬間”にのみ適用され、次アクションは「assert に寄与する値」という不確実性の解消（情報利得）で決まる。

変更規模の宣言
- SKILL.md 変更は 1 行置換（実質 1 行増分なし、必須ゲート純増なし）。
