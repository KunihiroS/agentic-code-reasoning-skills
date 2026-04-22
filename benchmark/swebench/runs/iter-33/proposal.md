過去提案との差異: 直近却下案のように STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を特定の観測境界へ狭める提案ではなく、意味差を見つけた後の「次にどこまで追うか」という downstream tracing 分岐を変える。
Target: 両方
Mechanism (抽象): compare に、A/B の最初の意味差が見つかった時点で verdict へ進む前に「その差を最初に受ける downstream consumer/handler」を優先追跡する分岐を埋め込み、差の吸収/増幅の確認を test trace の中間点で行わせる。
Non-goal: 構造差から NOT_EQUIV へ進む早期結論条件を新しい観測境界で再定義しない。

カテゴリ F 内での具体的メカニズム選択理由
- docs/design.md の「incomplete reasoning chains」と Guardrail #5 は、論文のエラー分析が compare に十分具体化されていないことを示している。現在の compare は per-test iteration は強いが、「差を見つけた後に最初の downstream handler を確認する」という localize/explain 的な次アクション規則が薄い。
- この変更は structural gate ではなく exploration-order の変更なので、偽 NOT_EQUIV を減らしつつ、差が実際に assertion へ届くケースでは偽 EQUIV も減らせる。

禁止方向の整理
- 構造差/早期 NOT_EQUIV を特定の観測境界へ写像して狭める方向は不可。
- 未確定性を広く UNVERIFIED / 保留へ倒す既定分岐の追加は不可。
- 差分を新しい抽象ラベルで昇格ゲートする方向は不可。

Decision-point candidates considered
1. Semantic difference found, downstream handling unresolved
   - Current default: 差を見つけた後、1 本の test trace か概念的な no-impact 説明で verdict に寄りやすい。
   - Observable delta: 追加探索が first consumer/handler に向き、EQUIV / NOT_EQUIV の早まりを抑える。
2. UNVERIFIED call sits on the first possible divergence path
   - Current default: UNVERIFIED を明示しても、そのまま verdict へ進みやすい。
   - Observable delta: UNVERIFIED 明示や追加探索は増えるが、保留側の既定化に寄りやすい。
3. Structural triage finds file/module asymmetry
   - Current default: 早期 NOT_EQUIV に進める。
   - Observable delta: 結論条件が変わるが、直近却下案と機構が近すぎるので不採用。

選定: Candidate 1
- compare の挙動差が、verdict 直行ではなく「最初の downstream consumer/handler を読む」という追加探索として明確に観測される。
- IF 条件と THEN 行動の両方が変わり、EQUIV/NOT_EQUIV のどちらにも効く。

改善仮説
- compare は「差を見つけた瞬間」ではなく「その差を最初に受ける downstream consumer/handler を確認した瞬間」を verdict 候補点にすると、 incomplete reasoning chain 由来の偽 EQUIV と偽 NOT_EQUIV を同時に減らせる。

該当箇所と変更方針
- 現行引用1: "When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact"
- 現行引用2: "Do not trust incomplete chains. After building a reasoning chain, verify that downstream code does not already handle the edge case or condition you identified"
- 変更方針: compare checklist の一般的な no-impact 指示を、最初の downstream consumer/handler を明示的に探す trigger に置換し、Guardrail #5 の抽象警告を compare 側の分岐規則へ寄せる。

Decision-point delta
Before: IF A/B の意味差が見つかり、ある test への影響を概略説明できる THEN SAME / DIFFERENT の結論に寄りやすい because 差分の存在そのものか、粗い per-test trace を根拠化しやすい
After:  IF A/B の最初の意味差が中間値・例外・状態更新に現れ、その後の受け手が未確認 THEN first downstream consumer/handler の読解を次アクションにする because 根拠は「差が吸収されるか増幅されるかを決める最初のコード点」に置く

Payment: add MUST("When Change A and B first diverge at an intermediate behavior, inspect the first downstream consumer/handler on that path before deciding SAME / DIFFERENT.") ↔ demote/remove MUST("When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact")

変更差分プレビュー
Before:
- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact
- Do not trust incomplete chains. After building a reasoning chain, verify that downstream code does not already handle the edge case or condition you identified
After:
- Trigger line (planned): "When Change A and B first diverge at an intermediate behavior, inspect the first downstream consumer/handler on that path before deciding SAME / DIFFERENT."
- If that consumer normalizes the divergence, continue the same test trace; if it exposes the divergence, use that site to anchor the counterexample or no-counterexample argument.
- Do not trust incomplete chains; in compare, treat the first downstream consumer/handler as the default next inspection point after a discovered divergence.

Discriminative probe
- 抽象ケース: A/B が中間表現の生成で異なるが、その直後の normalizer が一方では差を潰し、別ケースでは assertion 向けに露出させる。
- Before では最初の差を見て偽 NOT_EQUIV、または normalizer を飛ばして偽 EQUIV が起きがち。After では first consumer/handler を必ず次に読むので、差の吸収/増幅が分かれ、誤判定を避けやすい。
- これは新ゲート追加ではなく、既存の「differing path を traceする」要求を first consumer/handler 起点へ置換するだけである。

failed-approaches.md との照合
- 原則1/3に反しない: 差分を新しい抽象ラベルで昇格・抑制せず、構造差の結論条件もいじらない。変えるのは semantic difference 発見後の次アクションだけ。
- 原則2に反しない: 未検証なら広く保留に倒す規則ではなく、追加探索先を first consumer/handler に限定して evidence generation を促す。

変更規模の宣言
- 想定 diff は 6-10 行。compare checklist の 1 行置換＋Guardrail #5 への 1-3 行圧縮追記で収める。