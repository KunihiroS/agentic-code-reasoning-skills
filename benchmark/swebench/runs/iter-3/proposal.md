過去提案との差異: 今回は STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を狭めず、結論直前の自己点検で「弱い環」を outcome に結びつける分岐を変える。
Target: 両方
Mechanism (抽象): 結論の weakest supporting link が outcome-critical かつ UNVERIFIED/assumption-bearing なとき、即結論ではなく追加探索か明示的な確信度低下へ分岐させる。
Non-goal: 構造差そのものの扱いを観測境界ベースで再定義したり、STRUCTURAL TRIAGE の NOT_EQUIV 条件を狭めたりしない。

Payment: add MUST("Name the weakest outcome-critical link; if it is UNVERIFIED, do one targeted check or downgrade confidence explicitly.") ↔ demote/remove MUST("The conclusion I am about to write asserts nothing beyond what the traced evidence supports.")

カテゴリ D 内での具体的メカニズム選択理由:
- compare が停滞/誤判定しやすいのは、「証拠があるか」一般ではなく「どのリンクが結論を支えているか」が未特定のまま結論に進めてしまう分岐だから。弱い環が特定されれば、追加探索・UNVERIFIED 明示・CONFIDENCE 低下の少なくとも1つが実際に変わる。
- これは structural gap の閾値調整ではなく、既存の Step 5.5 self-check を outcome-sensitive に置換するだけなので、研究コアを保ったまま EQUIV/NOT_EQUIV の両方向の過信を下げられる。

改善仮説:
- 決定直前に「最も弱いが outcome-critical な主張」を1つ特定させ、その主張が未検証なら targeted な反証探索か confidence downgrade に分岐させると、 incomplete chain に起因する偽 EQUIV と偽 NOT_EQUIV の両方を減らせる。

SKILL.md の該当箇所と変更:
- Step 4: "If source is unavailable ... mark UNVERIFIED and note the assumption."
- Step 5.5: "The conclusion I am about to write asserts nothing beyond what the traced evidence supports."
- 変更は、後者の汎用 self-check を「weakest link の同定 + outcome-critical なら targeted check or confidence downgrade」へ置換する。前者の UNVERIFIED 規則はそのまま使い、compare の結論条件を outcome-critical assumption に接続する。

Decision-point delta:
Before: IF テンプレート各欄が埋まり、直接の矛盾が見えない THEN 現在の推論鎖から EQUIV/NOT_EQUIV に進む because 根拠型が「全体として traced evidence がある」かどうかの総称チェックだから。
After:  IF 現在の結論を支える weakest link が outcome-critical かつ UNVERIFIED/assumption-bearing THEN そのリンクに対する targeted search/trace を1回追加し、未解消なら UNVERIFIED を明示して CONFIDENCE を下げる because 根拠型が「結論を支える最弱リンクの検証状態」に変わるから。

変更差分プレビュー:
Before:
- [ ] The conclusion I am about to write asserts nothing beyond what the traced evidence supports.

After:
- [ ] I named the weakest link in my reasoning chain.
- [ ] If that link is outcome-critical and UNVERIFIED/assumption-bearing, I did one targeted search/trace against it or explicitly lowered confidence and kept the uncertainty attached to that claim.
Trigger line (planned): "Before concluding, identify the weakest outcome-critical link; if it is UNVERIFIED, do one targeted check or lower confidence explicitly."

Discriminative probe:
- 抽象ケース: 両変更とも見かけ上は同じ分岐に到達するが、その同値性は source unavailable な helper の挙動仮定1つに依存している。変更前は「他が十分 traced されている」ため偽 EQUIV か偽 NOT_EQUIV を出しがち。
- 変更後はその helper が weakest outcome-critical link として露出し、使用箇所/型/テスト痕跡への targeted search を追加するか、未解消のままなら UNVERIFIED 明示 + LOW/MEDIUM confidence に落ちるので、過信した誤判定を避けやすい。
- これは新しい必須ゲートの純増ではなく、既存の mandatory self-check 1 項目の置換である。

failed-approaches.md との照合:
- 「再収束を比較規則として前景化しすぎない」に反しない。再収束優先の新規既定動作は導入せず、むしろ incomplete reasoning chain の弱い環を露出して追加探索/低信頼へ倒す。
- 却下済みの「構造差→NOT_EQUIV 条件を特定観測境界へ写像して狭める」提案とも別物で、変更対象は STRUCTURAL TRIAGE ではなく pre-conclusion self-check の分岐である。

変更規模の宣言:
- 置換ベースで 4-6 行程度。新規モード追加なし、mandatory 総量は payment の通り純増させない。
