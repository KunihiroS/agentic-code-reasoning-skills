過去提案との差異: 直近の却下案のように STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件や UNVERIFIED 既定分岐をいじらず、既存の「差分を見たら relevant test を通す」指示を compare の決定点へ局所化しつつ重複した必須表現を削る提案である。
Target: 両方
Mechanism (抽象): 分岐を増やさず、散在する重複指示を 1 つの局所トリガへ統合して「差分発見時の次の一手」を早く決めさせる。
Non-goal: 構造差→NOT_EQUIV の条件を特定の観測境界へ狭めたり、保留/UNVERIFIED の既定化を増やしたりしない。

カテゴリ G の候補は 3 つあった: (1) Compare checklist と Guardrail #4 に散った「semantic difference を見たら relevant test を通す」を分析位置へ統合する、現在は差分発見後も全体テンプレを続けがち→追加探索の発火位置が早まる; (2) Step 5.5 の重複チェックを削る、現在は終盤 checklist 最適化を招きがち→保留は減るが証拠床の低下が怖い; (3) Step 3/4 の「real time で書け」の重複圧縮、現在も挙動差がほぼ出ない→捨てる。選定は (1)。理由は、compare 中の実行時アウトカムを直接変えられる唯一の圧縮であり、しかも偽 EQUIV / 偽 NOT_EQUIV の両方向に効くから。

改善仮説: compare で最も停滞を生むのは「差分を見つけた瞬間の次行動」が checklist/guardrail に分散していることなので、その指示を ANALYSIS OF TEST BEHAVIOR 直下の単一トリガへ統合すると、モデルは差分を見た時点で即座に relevant test trace に入れ、結論の早合点と終盤の過剰再点検を同時に減らせる。

該当箇所の短い引用: Compare checklist の「When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact」と Step 5 の「This step is mandatory, not optional.」。変更は、前者を ANALYSIS OF TEST BEHAVIOR の局所トリガとして移設し、後者の重複 MUST を削る。
Payment: add MUST("When a semantic difference is observed before a test-outcome difference is shown, immediately trace one relevant test through that differing branch before any verdict.") ↔ remove MUST("This step is mandatory, not optional.")

Decision-point delta:
Before: IF semantic difference is noticed but no diverging assertion is yet traced THEN continue broad template execution and often defer the test probe until checklist/conclusion time because the action cue is split across distant reminders.
After:  IF semantic difference is noticed but no diverging assertion is yet traced THEN immediately trace one relevant test through that branch before any verdict because the trigger sits at the compare decision point itself.

変更差分プレビュー:
Before:
- "This step is mandatory, not optional."
- "When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact"
After:
- ANALYSIS OF TEST BEHAVIOR:
- Trigger line (planned): "When a semantic difference is observed before a test-outcome difference is shown, immediately trace one relevant test through that differing branch before any verdict."
- [delete redundant Step 5 sentence] "This step is mandatory, not optional."

Discriminative probe: 抽象ケースとして、2 変更が内部 helper の条件分岐だけ異なり、その差分が実テストで踏まれるか未確認の場面を考える。変更前は差分を見ただけで終盤に偽 NOT_EQUIV へ傾くか、逆に downstream の類似性を見て偽 EQUIV に寄りやすい。変更後は差分発見直後に 1 本の relevant test trace が必ず先に走るため、分岐未到達なら証拠付き EQUIV、到達して assertion が割れれば証拠付き NOT_EQUIV になり、どちらも早合点を避けられる。

failed-approaches.md との照合: 原則 1/3 に反して新しい抽象ラベルや再収束既定を足しておらず、構造差の結論条件も狭めていない。原則 2 に反して UNVERIFIED/保留への fallback を guardrail 化するのでもなく、既存の探索指示を局所再配置するだけである。

変更規模の宣言: 実 diff は 10 行未満を想定し、新規モードなし・必須総量は payment で相殺する。