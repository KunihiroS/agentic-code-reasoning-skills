過去提案との差異: 「反証優先順位の差し替え」や「特定観測境界へ判定条件を還元して探索経路を半固定化」ではなく、差異の“重要度分類”を導入して比較の粒度を調整する提案。
Target: 両方（偽 EQUIV と偽 NOT_EQUIV）
Mechanism (抽象): 差異を“同じ差異”として扱わず、影響カテゴリ（契約/制御/内部）に分類して比較の判断単位を切り替える。
Non-goal: STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件や Step 5 の反証手順（やり方）を狭めたり置換したりしない。

カテゴリC（比較の枠組み）内での具体メカニズム選択理由
- 既存の compare は「差異を見つけたらテストへトレースして影響判定」という一本鎖が強く、差異の種類（外部契約に触れる差異 vs 内部表現の差異）による“比較の単位/重要度”の切替が明示されていない。
- その結果、(a) 内部リファクタ相当の差異を過大評価して NOT_EQUIV に倒す、(b) 見た目が小さいが外部契約（戻り値/例外/境界条件/入力解釈）に触れる差異を過小評価して EQUIV に倒す、の両側が起きうる。
- そこで「差異の重要度を段階的に評価する」（Objective.md のカテゴリC例: “差異の重要度を段階的に評価する”）を最小差分で compare の意思決定点に埋め込む。

改善仮説（1つ・汎用）
- 仮説: “差異を発見した”という事実だけで同一の比較行動を取らず、差異を (1) 契約差（観測可能な出力/例外/入力受理/副作用）、(2) 制御差（分岐条件・境界判定・到達性）、(3) 内部差（命名/配置/キャッシュ/表現変更）に分類してから比較単位を選ぶことで、偽 NOT_EQUIV（差異過大視）と偽 EQUIV（差異過小視）を同時に減らせる。

SKILL.md の該当箇所（短い引用）と変更案
引用（Compare checklist）:
- "When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact"

変更: 上の1行を「差異分類→分類に応じた比較単位の選択」に置換し、差異重要度（契約/制御/内部）を明示する。

Decision-point delta（IF/THEN 2行）
Before: IF semantic difference is found THEN trace at least one relevant test through the differing path because test-outcome divergence is the decision criterion.
After:  IF semantic difference is found THEN classify it as CONTRACT / CONTROL-FLOW / INTERNAL and only require test-tracing for CONTRACT or CONTROL-FLOW because those categories map directly to observable outcomes.

変更差分プレビュー（Before/After, 3–10行）
Before (Compare checklist excerpt):
- Trace each test through both changes separately before comparing
- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact
- Provide a counterexample (if different) or justify no counterexample exists (if equivalent)

After (Compare checklist excerpt):
- Trace each test through both changes separately before comparing
- When a semantic difference is found, classify it (CONTRACT / CONTROL-FLOW / INTERNAL); test-trace the differing path for CONTRACT or CONTROL-FLOW before concluding “no impact”
- Provide a counterexample (if different) or justify no counterexample exists (if equivalent)

failed-approaches.md との照合（整合 1–2点）
- 「次に探すべき証拠種類をテンプレで事前固定しすぎる」回避: 本提案は“証拠型の固定”ではなく、差異の種類という比較フレームを導入するだけで、具体的に何を検索せよ（特定シグナル捜索）を規定しない。
- 「既存の判定基準を特定の観測境界へ還元しない」整合: NOT_EQUIV/EQUIV の判定基準（D1: テスト結果）や反証ステップは置換せず、差異重要度の分類で“比較の粒度”を切り替えるだけで観測境界の狭窄を起こさない。

変更規模の宣言
- 変更は Compare checklist の1行置換（実質2行相当の内容を1行に圧縮）で、総変更規模は 1〜2 行（hard limit 5行以内）。
