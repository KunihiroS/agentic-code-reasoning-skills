# Iteration 68 — proposal discussion

## 監査結論サマリ

提案は、既存の `COUNTEREXAMPLE (required if claiming NOT EQUIVALENT)` ブロック内で、単なる `Diverging assertion` を「テスト前提を破るコード側の divergence claim」へ置換する最小変更であり、compare の実行時アウトカム差は観測可能です。

主な効き方は NOT_EQUIV 側です。EQUIV 側への直接作用は弱いものの、誤った NOT_EQUIV への早期収束を抑え、根拠が不足する場合に追加探索または CONFIDENCE 低下へ戻す点で、現行 compare の判別品質を改善する見込みがあります。

承認可能。ただし実装時は、proposal にある通り「新しい必須ゲートの純増」ではなく、既存の `Diverging assertion` 行の置換として入れることが条件です。

## 1. 既存研究との整合性

検索なし（理由: 一般原則の範囲で自己完結）。

根拠は参照許可ファイル内で足ります。README.md は Agentic Code Reasoning の中核を、明示的 premise、file:line evidence、formal conclusion による semi-formal reasoning と説明しています。docs/design.md も、Patch Equivalence Verification は per-test iteration と counterexample obligation、Fault Localization は Premises → Code Path Tracing → Divergence Analysis → Ranked Predictions を中核とする、と整理しています。

今回の提案はこのうち fault localization 側の premise/claim/prediction 的な構造を、compare の counterexample obligation 内に限定して移植するものなので、研究コアとの整合性はあります。

## 2. Exploration Framework のカテゴリ選定

カテゴリ F「原論文の未活用アイデアを導入する」は概ね適切です。

理由:
- docs/design.md 上、localize/fault localization の設計は premise から divergence analysis / prediction へ進む構造を持つ。
- 現行 SKILL.md の compare は per-test PASS/FAIL と diverging assertion を要求しているが、「どのテスト前提を、どのコード側 behavior が破るのか」という claim 層は薄い。
- その claim 層を compare の counterexample 欄だけに移すのは、論文由来構造の限定的な再利用として妥当です。

補足すると、実際の変更形式は E「表現・フォーマット改善」にもまたがります。ただし改善仮説の由来は F で説明できるため、カテゴリ選定は不適切ではありません。

## 3. EQUIVALENT / NOT_EQUIVALENT 判定への作用

### NOT_EQUIVALENT 側

効果は直接的です。

変更前は、named test、反対の PASS/FAIL prediction、diverging assertion/check が埋まると、コード側の前提違反 claim が薄くても NOT_EQUIV に進みやすい構造でした。

変更後は、NOT_EQUIV を主張するには、Change A/B のどちらの behavior がどの premise/test expectation を破るのかを一文で結ぶ必要があります。これにより、単に「同じ assert で違うはず」と予測しているだけの偽 NOT_EQUIV は、追加探索または CONFIDENCE 低下へ戻りやすくなります。

### EQUIVALENT 側

直接の変更対象ではありません。

ただし、偽 NOT_EQUIV を出しにくくすることで、結果的に EQUIV 候補を prematurely に捨てる圧力は下がります。一方で、NO COUNTEREXAMPLE EXISTS 欄自体は変更しないため、偽 EQUIV を直接減らす主効果は限定的です。

本 proposal の `Target: 両方` はやや強い表現です。実効的には「主に偽 NOT_EQUIV を減らし、真 NOT_EQUIV では counterexample の説明品質を上げる。EQUIV 側には間接的に作用する」と見るのが正確です。

片方向悪化については、明白な逆方向の悪化はありません。真 NOT_EQUIV でも、実際にテスト前提を破る behavior があるなら claim は短く書けるはずで、根拠を過度に難しくして EQUIV へ逃がす構造にはなっていません。ただし claim 記述を厚くしすぎると failed-approaches の原則 3 に近づくため、実装は 1 行置換に留めるべきです。

## 4. failed-approaches.md との照合

最も近いリスクは原則 3 です。failed-approaches.md は、差分を特定の premise/assertion へ結びつけた CLAIM 形式への言い換えを必須化すると、比較そのものより再記述の整合が目的化しやすい、と警告しています。

今回の proposal はこの失敗形に近い語彙を使っていますが、本質的再演とはまでは判断しません。

理由:
- 対象が「差分ごと」ではなく、既存の NOT_EQUIV counterexample 欄に限定されている。
- 新しい Guardrail や Step 5.5 の必須チェックではなく、既存の `Diverging assertion` 行を置換する payment が明示されている。
- 探索開始点、証拠種類、観測境界を新しく固定するのではなく、NOT_EQUIV 結論直前の根拠文を premise-linked にする変更である。
- Trigger line が差分プレビュー内にあり、実装対象がずれにくい。

ただし、実装時に `Divergence claim` 以外の追加チェックや Guardrail を増やすと、原則 3 の再演になります。そこは明確に避ける必要があります。

## 5. 汎化性チェック

固有識別子の混入は見当たりません。

確認結果:
- 具体的なベンチマーク ID: なし。
- 特定リポジトリ名: なし。
- 特定テスト名: なし。
- 実コード断片: なし。
- 特定言語・フレームワーク前提: なし。

`P[N]`, `D[N]`, `[file:line]`, `[test expectation]` は SKILL.md のテンプレート用プレースホルダであり、固有識別子ではありません。

ドメイン前提についても、assert/check、test expectation、PASS/FAIL outcome は compare mode の定義そのものに属する汎用概念であり、特定言語や特定テストパターンへの過剰適合とは言えません。

## 6. 推論品質の期待改善

期待できる改善は、counterexample の根拠が「観測点の名指し」から「テスト前提を破る behavior と prediction の接続」へ一段具体化する点です。

これにより:
- named test と PASS/FAIL prediction だけで NOT_EQUIV に飛ぶ premature closure を減らす。
- assertion/check の場所は分かるが、なぜ片側だけその期待を破るのかが薄い場合に、追加探索へ戻りやすくなる。
- 真の NOT_EQUIV では、どの前提が破られるかを短く説明できるため、結論の説得力が上がる。
- 既存の counterexample obligation を弱めず、反証可能性を維持する。

## 停滞診断（必須）

懸念 1 点:
- proposal は監査 rubric に刺さる「研究由来」「payment」「Trigger line」をよく満たしていますが、compare の意思決定を変える観測可能差も明記されています。特に「claim が作れない場合は追加探索または CONFIDENCE 低下」という実行時挙動があるため、単なる説明強化に留まる懸念は低めです。

failed-approaches 該当チェック:
- 探索経路の半固定: NO。最初に読むファイルや単一 trace path を固定していない。
- 必須ゲート増: NO。ただし実装で新規チェックを追加すると YES になる。proposal 上は `Diverging assertion` の置換として payment 済み。
- 証拠種類の事前固定: NO 寄り。ただし「PREMISE → CLAIM → PREDICTION」を広く全差分へ要求すると YES になる。現 proposal は NOT_EQUIV counterexample 内の根拠文置換に限定されているため許容範囲。

## compare 影響の実効性チェック（必須）

0) 実行時アウトカム差
- NOT_EQUIV を出す直前に、単なる diverging assertion ではなく、premise/test expectation を破る code-side divergence claim が必要になる。
- claim が作れない場合、ANSWER: NO へ進まず、追加探索、UNVERIFIED 明示、または CONFIDENCE 低下が観測可能に増える。

1) Decision-point delta
- IF/THEN 形式で 2 行（Before/After）になっているか？ YES。
- Before/After は条件も行動も同じで理由だけ言い換えか？ NO。Before は diverging assertion/check で NOT_EQUIV へ進む。After は premise-linked divergence claim を先に作り、それが prediction を支える場合のみ進む。
- Trigger line が差分プレビュー内に含まれているか？ YES。`Trigger line (planned): "Divergence claim: At [file:line], Change A/B produces [behavior] that contradicts P[N]/test expectation [T] because [reason]."`

2) Failure-mode target
- 主対象: 偽 NOT_EQUIV。
- メカニズム: named test + opposite PASS/FAIL + assertion 名指しだけで成立したように見える counterexample を、premise/test expectation を破る具体 behavior へ接続できる場合に限定する。
- 副次効果: 真 NOT_EQUIV では反例説明が短く明確になる。偽 EQUIV への直接効果は限定的。

2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？
- NO。
- STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件は変更していない。
- したがって impact witness 要求の有無はこの proposal の主審査対象ではない。ただし実装時に structural gap からの早期結論へこの claim 形式を拡張してはいけない。

3) Non-goal
- 探索経路を単一 file/test/assertion へ固定しない。
- 新しい必須ゲートを増やさない。
- 証拠種類を全 compare に事前固定しない。
- 既存 `Diverging assertion` 行を `Divergence claim` 行へ置換するだけに留める。

## Discriminative probe（必須）

抽象ケース:
- 2 つの変更が同じ test assert に到達し、片側だけ FAIL と予測されているが、その FAIL 理由は実際にはテスト期待ではなく内部命名や中間表現の違いに依存している。
- 変更前は `Diverging assertion` を埋められるため偽 NOT_EQUIV に進みやすい。
- 変更後は「どの test expectation をどの behavior が破るか」を書けず、既存 counterexample 欄内で追加探索または CONFIDENCE 低下に戻るため、誤判定を避けやすい。

これは新しい必須ゲートの増設ではなく、既存 `Diverging assertion` 行を premise-linked claim に置換する総量不変の変更として説明されています。

## 支払い（必須ゲート総量不変）の検証

A/B 対応付けは明示されています。

- Add: `Divergence claim: At [file:line], Change A/B produces [behavior] that contradicts P[N]/test expectation [T] because [reason].`
- Demote/remove: `Diverging assertion: [test_file:line — the specific assert/check that produces a different result]`

この対応があるため、必須ゲートの純増にはなっていません。

## 修正指示（最小限）

1. 実装では `Diverging assertion` 行を置換し、追加の Step 5.5 チェックや Guardrail は増やさないこと。
2. `Target: 両方` の説明は、rationale 側では「主に偽 NOT_EQUIV、EQUIV には間接作用」と弱めること。
3. `PREMISE → CLAIM → PREDICTION` を全差分へ一般化せず、NOT_EQUIV counterexample 欄の 1 行に閉じること。

## 承認

承認: YES
