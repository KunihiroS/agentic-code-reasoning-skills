過去提案との差異: 今回は STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件や D2 の relevant tests 発見規則を狭めず、差分発見後の「比較単位」を単発のテスト経路から共有された test-facing obligation へ切り替える。
Target: 両方
Mechanism (抽象): 意味差を見つけた後、ただちに「影響なし」または「差がある」と畳まず、その差分が両変更で同じテスト上の義務を満たすか未解決かを比較項目として保持する。
Non-goal: 未検証リンク一般を保留既定にすることでも、早期 NOT_EQUIV の条件を特定観測境界へ写像して狭めることでもない。

Payment: add MUST("After any semantic difference is found, classify it as obligation-preserving, obligation-breaking, or unresolved before absorbing it into the verdict.") ↔ demote/remove MUST("When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact")

## Category C 内での候補比較
1. STRUCTURAL TRIAGE の早期結論条件
- 現在のデフォルト挙動: missing file / missing module を見つけると詳細 ANALYSIS を飛ばして NOT EQUIVALENT に進みがち。
- 変更後に変わるアウトカム: NOT_EQUIV / 追加探索 / CONFIDENCE が変わりうる。
- 採用しない理由: 直近却下群と最も機構が近く、観測境界への写像の再演になりやすい。

2. D2 の relevant tests 発見規則
- 現在のデフォルト挙動: changed function/class/variable 参照検索を起点に fail-to-pass と pass-to-pass を集めがち。
- 変更後に変わるアウトカム: 追加探索 / 保留 / EQUIV が変わりうる。
- 採用しない理由: iter-15 と近く、片方向に fail-to-pass 側へ最適化しやすい。

3. 意味差を見つけた後の比較の畳み方
- 現在のデフォルト挙動: 「少なくとも 1 本の relevant test で同じ outcome を確認した差分」は no-impact として吸収しがちで、逆に構造差は test obligation へ写す前に強く見えがち。
- 変更後に変わるアウトカム: EQUIV / NOT_EQUIV / UNVERIFIED 明示 / 追加探索 / CONFIDENCE が変わる。
- 採用理由: compare の結論に入る直前の分岐であり、同じ差分でも「吸収」「反証探索継続」「差分確定」を切り替える実行時アウトカムを直接変えられる。

## 選定理由
- compare は現在 per-test tracing を持つが、差分発見後の比較粒度が実質「単発の witness path」に寄りやすく、ここを変えると EQUIV/NOT_EQUIV のどちらにも直結する。
- IF 条件と THEN 行動の両方を変えられる: 「1 本確認したら吸収」から「obligation が preserved/broken/unresolved のどれかに分類されるまで verdict へ吸収しない」へ移る。

## 改善仮説
意味差を見つけた後の比較単位を「その差分が満たす test-facing obligation」に揃えると、内部差分を早く吸収しすぎる偽 EQUIV と、内部差分をそのまま重く見すぎる偽 NOT_EQUIV の両方を減らせる。

## SKILL.md の該当箇所と変更方針
該当箇所の短い引用:
- "When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact"
- "EDGE CASES RELEVANT TO EXISTING TESTS"

変更方針:
- 「差分を見つけたら 1 本の relevant test で no-impact 判定して吸収する」読みを、"difference -> obligation classification" に置換する。
- 既存の EDGE CASES / per-test tracing / counterexample を流用し、新モードは作らず compare の比較粒度だけを変える。

## Decision-point delta
Before: IF a semantic difference is found and one traced relevant path still yields the same outcome THEN absorb that difference as no-impact and continue toward verdict because the comparison unit is a single witnessed path.
After:  IF a semantic difference is found and its shared test-facing obligation is not yet classified as preserved, broken, or unresolved for both changes THEN keep it as an explicit comparison item and require more search or UNVERIFIED/confidence reduction before verdict because the comparison unit is the obligation the tests observe.

## 変更差分プレビュー
Before:
- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact
- EDGE CASES RELEVANT TO EXISTING TESTS:
-   E[N]: [edge case]

After:
- Trigger line (planned): "After any semantic difference is found, classify the difference by the test-facing obligation it could change: preserved by both / broken in one change / unresolved."
- For each semantic difference that survives tracing:
-   OBLIGATION CHECK: what test-facing obligation could this difference change?
-   Status: PRESERVED BY BOTH / BROKEN IN ONE CHANGE / UNRESOLVED
-   Only PRESERVED BY BOTH differences may be absorbed into an EQUIVALENT argument.

## Discriminative probe
抽象ケース: 2 つの変更は同じ failing path を直し、代表入力では同じ assert を通るが、一方だけ別の入力正規化義務を upstream で外している。変更前はその代表 path だけを traced witness にして差分を no-impact 吸収し、偽 EQUIV になりやすい。
変更後はその差分を "input normalization before assertion" という obligation として残すため、未解決なら追加探索/UNVERIFIED に、片側だけ破る証拠が出れば NOT_EQUIV に進む。逆に両側で同じ obligation を満たすなら内部差分を安全に吸収でき、偽 NOT_EQUIV も減る。

## failed-approaches.md との照合
- 原則 1 と整合: 再収束を既定動作にせず、差分を downstream 一致で即吸収しない。比較の主語を「再収束」ではなく「共有 obligation の保存/破壊」に置く。
- 原則 2/3 と整合: 未検証一般を保留トリガー化せず、外部可視性の新ラベルで差分昇格をゲートしない。差分が既に見つかった場面で、その test-facing impact の分類だけを要求する。

## 変更規模の宣言
15 行以内の置換・圧縮で実装可能。Compare checklist の 1 箇所を置換し、EDGE CASES 付近に 3-5 行の obligation classification を挿入する想定。