過去提案との差異: STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件や反証優先順位（pivot/highest-tier-first）の具体化ではなく、原論文の explain（data-flow）手法を compare の「各テストの因果トレース」に移植する提案。
Target: 両方（偽 EQUIV と 偽 NOT_EQUIV を同時に減らす）
Mechanism (抽象): compare の per-test tracing を「呼び出し列」中心から「アサーションに到達する変数の data-flow slice」中心へ寄せ、結論の根拠を到達性で安定化する。
Non-goal: 構造差→NOT_EQUIV の早期判定条件の狭窄、証拠種類のテンプレ固定、新しい必須ゲートの純増はしない。

---

カテゴリ F 内での具体的メカニズム選択理由
- 原論文は task ごとにテンプレが異なるが、explain（コードQA）では「DATA FLOW ANALYSIS（変数の Created/Modified/Used）」が、推論鎖の欠落（incomplete chains）や“見た目の差”への過剰反応を抑える役割を持つ。
- SKILL.md には explain 側の data-flow が明示されている一方、compare 側は「assertion outcome まで trace」と書かれていても、実際の作業単位が call-chain になりやすく、(a) 差分がアサーションに到達しないのに NOT_EQ を出す／(b) 到達しているのに途中で握りつぶして EQUIV を出す、の両方が起きうる。
- そこで compare の「各テストの Claim C[N].1/.2 の書き方」だけを、explain の data-flow 概念で補強し、探索経路の半固定や新規ゲート追加を避けつつ、根拠の粒度を“到達性”に揃える。

改善仮説（1つ）
- compare で PASS/FAIL を主張する直前に「そのテストのアサーションが読んでいるキー変数（または出力）を1つ特定し、Created/Modified/Used を両パッチで追う」よう促すと、差分の影響判定がアサーション到達性に収束し、偽 EQUIV（影響の見落とし）と偽 NOT_EQ（影響の過大視）が同時に減る。

SKILL.md の該当箇所（短い引用）
1) compare（現状）
- "Claim C[N].1: With Change A, this test will [PASS/FAIL] because [trace from changed code to test assertion outcome — cite file:line]"
- "Claim C[N].2: With Change B, this test will [PASS/FAIL] because [trace from changed code to test assertion outcome — cite file:line]"
2) explain（既にあるが compare に未移植）
- "DATA FLOW ANALYSIS: Variable: [key variable name] - Created at / Modified at / Used at"

Decision-point delta（IF/THEN 2行）
Before: IF 書いているのが compare の Claim C[N].1/.2（テストの PASS/FAIL 根拠） THEN 変更コード→アサーション outcome までを call-chain 中心にトレースする because file:line の逐次トレース。
After:  IF 書いているのが compare の Claim C[N].1/.2（テストの PASS/FAIL 根拠） THEN アサーションが読むキー変数/値を1つ明示し、その data-flow（Created/Modified/Used）で両パッチの到達性をトレースする because data-flow slice + file:line。

変更差分プレビュー（Trigger line を含む）
Before:
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace from changed code to test assertion outcome — cite file:line]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace from changed code to test assertion outcome — cite file:line]
After:
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace to the test assertion outcome via data-flow of the asserted key value (created/modified/used) — cite file:line]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace to the test assertion outcome via data-flow of the asserted key value (created/modified/used) — cite file:line]

failed-approaches.md との照合（整合 1–2 点）
- 「証拠種類の事前固定を避ける」: 追う対象は“各テストのアサーションが実際に読むキー変数/値”であり、固定の証拠カテゴリをテンプレで列挙しない（テストごとに変わる）。
- 「観測境界への過度な還元を避ける」: 構造差→NOT_EQUIV の条件を特定の観測境界に狭めるのではなく、既存の per-test tracing を“到達性の表現”として強化するだけで、探索の自由度を削らない。

変更規模の宣言
- SKILL.md の compare テンプレ内の 2 行置換（合計 5 行以内、必須ゲートの純増なし）。
