過去提案との差異: これは未検証リンクを保留側へ倒す Guardrail でも、counterexample 不在を結論へ吸収する片方向最適化でも、構造差→NOT_EQUIV の観測境界狭窄でもなく、各比較対での「証拠の左右非対称」を次の探索先に変換する提案である。
Target: 両方
Mechanism (抽象): SAME/DIFFERENT を書く直前に、どちら側の主張が弱い証拠に依存しているかを明示し、その弱い側を次の追跡対象にすることで、比較の早すぎる確定を減らす。
Non-goal: 早期 NOT_EQUIV の条件を特定の観測境界へ写像して狭めたり、未検証性そのものを新しい保留ゲートにしたりはしない。

カテゴリ D 内での具体的メカニズム選択理由:
- 候補1: 各 Comparison の証拠左右差。現在は片側だけ十分に traced でも SAME/DIFFERENT を置きがちで、変更後は追加探索または provisional 化が起きる。
- 候補2: Step 5.5 の weakest-link 処理。現在は global に confidence を下げて verdict 自体は維持しがちで、変更後は UNVERIFIED の付着先が claim 単位で残る。
- 候補3: NO COUNTEREXAMPLE EXISTS の探索打ち切り。現在は既に見た経路の再確認で終わりがちで、変更後は未追跡の高分岐側へ探索が伸びる。
- 選定: 候補1。compare の最小単位である C[N].1/C[N].2 の間で IF/THEN が変わり、EQUIV/NOT_EQUIV の両方向にある「片側だけ弱いのに比較を確定する」誤りを同じ規則で抑えられる。

改善仮説:
- compare の誤判定は「差分の有無」だけでなく「左右の証拠強度の非対称を comparison 行で見えなくすること」からも生じる。Comparison の直前で weaker side を特定し、その側が analogy/UNVERIFIED に依存するなら次の探索をそこへ向ければ、偽 EQUIV と偽 NOT_EQUIV の両方を減らせる。

SKILL.md の該当箇所と変更方針:
- Compare の `Claim C[N].1 / Claim C[N].2 / Comparison: SAME / DIFFERENT outcome`
- Step 5.5 の `- [ ] I named the weakest link in my reasoning chain.`
- 変更は「global weakest link」の 1 項目を、「各 comparison で weaker side を特定する」局所自己チェックへ置換する。Payment: add MUST("For any SAME/DIFFERENT comparison, identify the weaker-supported side; if only one side relies on analogy or UNVERIFIED behavior, target that side before finalizing the comparison.") ↔ demote/remove MUST("I named the weakest link in my reasoning chain.")

Decision-point delta:
Before: IF one side of C[N].1/C[N].2 is traced and the other is mostly analogy/structural similarity THEN still write `Comparison: SAME / DIFFERENT` because per-test slots are filled and weakest-link handling is only global.
After:  IF one side of C[N].1/C[N].2 is traced and the other is mostly analogy/UNVERIFIED THEN next action targets the weaker side (or the comparison stays provisional) because comparison confidence must match the weaker-supported claim, not the stronger one.

変更差分プレビュー:
Before:
- [ ] I named the weakest link in my reasoning chain.
- Comparison: SAME / DIFFERENT outcome
After:
- [ ] For each SAME/DIFFERENT comparison, I identified which side has weaker support and did not finalize the comparison from the stronger side alone.
- Trigger line (planned): "If only one side of a comparison depends on analogy or UNVERIFIED behavior, trace that side next before writing SAME / DIFFERENT."
- Comparison: SAME / DIFFERENT outcome

Discriminative probe:
- 抽象ケース: 2 変更とも同じ API を触るが、A は assertion まで traced、B は「同名 helper なので同じだろう」で Comparison を埋める場面。
- Before では偽 EQUIV が起きやすい。After では weaker side= B が明示され、B 側の helper/guard を追加追跡して divergence を見つけるか、少なくとも comparison を provisional のまま保つので誤確定を避けやすい。
- これは新ゲート純増ではなく、既存の weakest-link MUST の置換である。

failed-approaches.md との照合:
- 原則2と整合: 未検証性を一律に保留トリガーへ昇格せず、局所的な次探索選択にだけ使う。
- 原則3と整合: 差分を新しい抽象ラベルで昇格/降格せず、既存の per-test comparison の中で証拠強度の非対称を見える化するだけである。

変更規模の宣言:
- 置換中心で 8-10 行想定。新規モードなし、MUST 総量は payment で相殺し、15 行以内に収める。