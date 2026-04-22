過去提案との差異: これは STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を特定の観測境界へ狭める案ではなく、結論直前に verdict を支える最弱リンクを露出させて CONFIDENCE / 追加探索 / UNVERIFIED 明示を切り替える案である。
Target: 両方
Mechanism (抽象): 比較の最終局面で「未検証だから広く保留」ではなく「verdict を反転させうる最弱リンクが未反証か」を自己点検させ、結論の強さだけを変える。
Non-goal: 構造差から NOT_EQUIV へ進む条件を assertion boundary や特定 handler に固定しない。

カテゴリ D の具体的メカニズム選択理由:
- compare の停滞点は探索開始ではなく結論直前にあり、現行 Step 5.5 は「support を超えない」ことしか問わないため、verdict を反転させる未検証リンクが残っても HIGH で閉じる/逆に広く保留へ倒す、の両振れが起こりうる。
- この分岐は実行時アウトカムを変える。最弱リンクが verdict-critical なら HIGH→MEDIUM/LOW、または追加探索要求/UNVERIFIED 明示に倒れ、critical でなければ結論を維持できる。

改善仮説:
- 「結論前 self-check の最後の汎用 bullet を、verdict を反転させうる最弱リンクの特定とその扱いに置換する」と、偽 EQUIV と偽 NOT_EQUIV の両方を減らしつつ、非決定的な未検証項目まで広く保留化する回帰も抑えられる。

該当箇所と変更方針:
- 現行引用: "- [ ] The conclusion I am about to write asserts nothing beyond what the traced evidence supports."
- 変更: この抽象 bullet を、verdict-critical な最弱リンクを 1 つ特定し、それが未検証なら confidence を下げるか追加探索へ戻す、非critical なら明示して先へ進む bullet に置換する。

Decision-point delta:
Before: IF いくつか未検証/仮定依存が残るが文章上は traced evidence を超えていない THEN そのまま EQUIV / NOT_EQUIV を高めの確信で結びやすい because 包括的な support-boundary チェック
After:  IF verdict を反転させうる最弱リンクが未反証のまま残る THEN HIGH を禁止し、追加探索または UNVERIFIED 明示つきの低確信結論へ切り替える because verdict-critical-link チェック

Payment: add MUST("name the weakest verdict-critical link before conclusion and say whether it can flip the verdict") ↔ demote/remove MUST("The conclusion I am about to write asserts nothing beyond what the traced evidence supports.")

変更差分プレビュー:
Before:
- [ ] The conclusion I am about to write asserts nothing beyond what the traced evidence supports.
After:
- [ ] Name the weakest verdict-critical link in the chain.
- [ ] If reversing that link could flip EQUIV/NOT EQUIV and it remains UNVERIFIED, do not use HIGH confidence; either inspect the link next or state the verdict as UNVERIFIED-dependent.
Trigger line (planned): "Before concluding, identify the weakest verdict-critical link; if it is still UNVERIFIED and could flip the answer, lower confidence or inspect that link next."

Discriminative probe:
- 抽象ケース: 両変更は中盤の分岐条件だけ異なるが、下流で同じ値へ再収束する可能性も、例外化して別結果になる可能性もあり、その downstream handler が未読で残っている。
- Before では「今ある traced evidence を超えていない」と見なして偽 EQUIV または偽 NOT_EQUIV を出しやすい。After では未読 handler が weakest verdict-critical link として露出し、HIGH を落として追加探索か UNVERIFIED 依存を明示するため、誤判定を避けやすい。

failed-approaches.md との照合:
- 原則2に整合: 未確定性を一律に保留トリガーへしない。critical な最弱リンク 1 点だけを見るので、弱い未検証を広く救済する既定動作を増やさない。
- 原則3に整合: 新しい抽象ラベルで差分昇格をゲートしない。構造差の扱いは変えず、結論直前の自己点検だけを operational に置換する。

変更規模の宣言:
- Step 5.5 の bullet 1 行を 2 行へ置換する程度で、総差分は 6-8 行想定、hard limit 15 行以内。