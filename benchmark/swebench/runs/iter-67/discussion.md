# Iteration 67 — 監査 discussion

## 1. 既存研究との整合性

検索なし（理由: 一般原則の範囲で自己完結）。

提案は、外部の特殊概念に依拠しているというより、既存 SKILL.md の D1「relevant test suite の pass/fail outcomes が同一なら equivalent」という定義と、README / docs/design.md が説明する certificate-based reasoning（premises、per-item tracing、counterexample obligation）に早期 STRUCTURAL TRIAGE の文言を揃える変更である。したがって Web 検索で新規根拠を足す必要は低い。

## 2. Exploration Framework のカテゴリ選定

カテゴリ E（表現・フォーマット改善）としては概ね適切。

理由:
- 変更対象は新しい探索手順ではなく、SKILL.md の既存文言 “clear structural gap” の判定単位を D1 の pass/fail outcomes に寄せる置換である。
- 「構造差がある」から「その構造差が relevant test の A/B PASS/FAIL 差を説明できる」へ言い換えるため、曖昧な許可条件の具体化として扱える。
- ただし STRUCTURAL TRIAGE の早期 NOT_EQUIVALENT 条件に触れるため、単なる表現改善ではなく、compare の停止条件を変える実効差を持つ。これは悪くないが、impact witness の要求まで明確でないと偽 NOT_EQUIV に直結する。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用

EQUIVALENT 側:
- 改善方向: missing file / missing module / missing test data のような構造差だけで早期 NOT_EQUIVALENT に倒れるケースを減らす。
- 期待効果: 構造差があっても relevant test の PASS/FAIL 差を説明できない場合は ANALYSIS 継続になるため、偽 NOT_EQUIV を減らし、結果として真の EQUIVALENT を拾いやすくなる。
- リスク: 「named relevant test」のみだと、テスト名を挙げただけで実際の assertion boundary まで見ずに、もっともらしい PASS/FAIL 差を作る余地が残る。

NOT_EQUIVALENT 側:
- 改善方向: 真の NOT_EQUIVALENT では、構造差から relevant test の A/B PASS/FAIL 予測差を示せるため、早期結論の道は残る。
- 期待効果: 単なるファイル差ではなく outcome-level evidence へ接続するので、NOT_EQUIV の根拠品質が上がる。
- リスク: impact witness が「assertion boundary を 1 つ目撃する」形で要求されていないため、変更後も named test + 予測差だけで早期終了し、既存の COUNTEREXAMPLE 欄が要求する Diverging assertion の強さを迂回する可能性がある。

片方向性:
- 主な改善対象は偽 NOT_EQUIV の削減で、EQUIVALENT 側に強く効く。
- NOT_EQUIVALENT 側も、正しい場合は早期結論を維持する設計なので片方向だけの最適化ではない。
- ただし assertion boundary なしでは、NOT_EQUIVALENT 側の根拠がまだ弱く、早期結論の安全性が不足している。

## 4. failed-approaches.md との照合

- 原則 2「未確定な relevance や脆い仮定を、常に保留側へ倒す既定動作にしすぎない」: NO。提案は「未検証なら保留」を一般化していない。早期 NOT_EQUIV の条件を outcome-level に揃えるだけで、UNVERIFIED fallback を増やしてはいない。
- 原則 3「差分の昇格条件を新しい抽象ラベルや必須の言い換え形式で強くゲートしすぎない」: 部分的懸念あり。新しい抽象ラベルは導入していないが、「named relevant test の A/B PASS/FAIL 予測差」を早期結論条件にするため、構造差の昇格条件を強める変更ではある。これは D1 と整合するため許容可能な方向だが、assertion boundary まで要求しないと、逆に形式的な test name 充足が目的化する。
- 原則 5「最初に見えた差分から単一の追跡経路を即座に既定化しすぎない」: NO。任意の relevant test でよく、読むファイル順・観測境界・assertion 種別を固定していない。
- 「探索経路の半固定」: NO。特定のファイル順や単一経路を指定していない。
- 「必須ゲート増」: NO に近いが注意。既存 MAY 条件の置換として説明されているため新しい大きな必須ゲートではない。ただし Trigger line 追加と早期結論条件の強化は実質的な停止条件変更なので、支払い説明は「既存早期許可文の置換」として実装時に崩さないこと。
- 「証拠種類の事前固定」: YES 寄りの懸念。原因文言は “one named relevant test whose A/B PASS/FAIL predictions differ”。D1 に合わせる意味では妥当だが、STRUCTURAL TRIAGE 早期結論で assertion boundary を要求しないと、証拠種類が「テスト名 + 予測差」という形式に固定され、実際の impact witness を欠くおそれがある。

## 5. 汎化性チェック

固有識別子・過剰適合:
- 具体的な数値 ID: なし。
- リポジトリ名: なし。
- テスト名: なし。
- 実コード断片: なし。引用されているのは SKILL.md 自身の文言と疑似的な差分プレビューであり、Objective.md の減点対象外に該当する。
- 特定言語・ドメイン前提: なし。test pass/fail outcome、relevant test、structural gap は言語横断的な比較概念である。

汎化性は概ね満たす。

## 6. compare 影響の実効性チェック

0) 実行時アウトカム差:
- clear structural gap だけでは早期 NOT_EQUIVALENT に進まず、named relevant test の A/B PASS/FAIL 予測差を説明できない場合は ANALYSIS 継続になる。
- ANSWER が即 NO から、追加探索後の YES / NO / 低 CONFIDENCE へ変わりうる。

1) Decision-point delta:
- IF/THEN 形式で 2 行（Before/After）になっているか？ YES。
- Before: IF S1/S2 reveals a clear structural gap THEN proceed directly to NOT EQUIVALENT because structural absence is treated as sufficient evidence.
- After: IF S1/S2 reveals a gap and the gap supports one named relevant test with different A/B PASS/FAIL predictions THEN proceed directly to NOT EQUIVALENT; otherwise continue ANALYSIS because verdict evidence is outcome-level.
- 条件も行動も同じで理由だけ言い換えか？ NO。早期終了条件が「構造差」から「構造差 + outcome prediction difference」へ変わっている。
- 差分プレビュー内に Trigger line が含まれているか？ YES。`Trigger line (planned): "Early structural NOT EQUIVALENT needs one named relevant test with different A/B PASS/FAIL predictions."`
- ただし、Trigger line は assertion boundary / diverging assertion まで要求していないため、STRUCTURAL TRIAGE 早期結論としては witness が弱い。

2) Failure-mode target:
- 主対象: 偽 NOT_EQUIV。
- メカニズム: 構造差だけで早期 NOT_EQUIVALENT に進む条件を弱め、test outcome 差に接続できない場合は ANALYSIS に戻す。
- 副作用として、真の NOT_EQUIV は relevant test の diverging PASS/FAIL prediction を提示できるため維持される。

2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？ YES。
- NOT_EQUIV の根拠が「ファイル差がある」だけに退化していないか？ 退化はしていない。named relevant test の A/B PASS/FAIL 予測差を要求している。
- impact witness（PASS/FAIL に結びつく具体的な分岐＝assertion boundary を 1 つ目撃できる形）を提案が要求しているか？ NO。
- 理由: proposal は “one named relevant test whose A/B PASS/FAIL predictions differ” までは要求するが、既存 COUNTEREXAMPLE 欄の “Diverging assertion: [test_file:line]” 相当の assertion boundary を早期結論条件に含めていない。早期 NOT_EQUIVALENT は full ANALYSIS をスキップできる箇所なので、この不足は compare 停滞・偽 NOT_EQUIV に直結しうる。

3) Non-goal:
- 探索開始点、読むファイル順、assertion 種別、単一観測境界は固定しない。
- 新しい抽象ラベルや二軸分類を導入しない。
- UNVERIFIED や保留を広い既定 fallback にしない。
- 既存の早期結論許可文を置換する範囲に留め、必須ゲート総量を増やさない。

## 7. Discriminative probe

抽象ケース:
- Change A だけが補助ファイルを変更し、Change B は補助ファイルを触らない。ただし関連テストはその補助ファイルを import / load せず、両変更とも同じ公開 API 経路で fail-to-pass を満たす。
- 変更前は “missing file” という構造差だけで早期 NOT_EQUIVALENT に倒れやすい。変更後は relevant test の A/B PASS/FAIL 差を説明できないため ANALYSIS 継続となり、偽 NOT_EQUIV を避けやすい。
- ただしこの probe を確実に効かせるには、「named relevant test」だけでなく、そのテスト内のどの assertion/check が A/B で分岐するかを早期 NOT_EQUIV の witness として要求する必要がある。

## 8. 停滞診断

監査 rubric に刺さる説明強化へ偏り、compare の意思決定を変えていない懸念:
- 懸念は小さい。Decision-point delta は実際に「早期 NOT_EQUIVALENT に進む / ANALYSIS に戻る」の分岐を変えている。
- ただし、Trigger line が “named relevant test with different A/B PASS/FAIL predictions” に留まり、assertion boundary を要求しないため、実装後に「テスト名を挙げるだけ」の説明強化へ退化する懸念が 1 点ある。

failed-approaches.md 該当性:
- 探索経路の半固定: NO。
- 必須ゲート増: NO（既存 MAY 条件の置換として実装する限り）。
- 証拠種類の事前固定: YES 寄り。原因文言は “one named relevant test whose A/B PASS/FAIL predictions differ”。D1 との整合上は妥当だが、assertion boundary を伴わないと「テスト名 + 予測差」の形式充足に寄る。

支払い（必須ゲート総量不変）:
- proposal は “既存 MAY early-conclusion condition の置換” と説明しており、方向性はよい。
- ただし Trigger line を 1 行追加するなら、差分上は既存の早期許可 3 行を置換・統合して総量をほぼ不変にすることを実装時に明示する必要がある。

## 9. 全体の推論品質への期待

期待できる改善:
- STRUCTURAL TRIAGE の利点（大きな構造差を早く拾う）を残しつつ、D1 の outcome-level 判定単位に接続させるため、早期結論の根拠が強くなる。
- 特に、構造差を見つけた瞬間に NOT_EQUIVALENT とする premature closure を減らせる。
- compare の出力で、結論が「ファイル差」ではなく「relevant test の A/B PASS/FAIL 差」に基づくようになり、FORMAL CONCLUSION の品質が上がる。

不足:
- 早期 NOT_EQUIVALENT で full ANALYSIS をスキップできる以上、最低 1 つの impact witness は “named test” では足りず、assertion/check boundary まで要求すべき。

## 10. 修正指示（最小限）

1. 最大ブロッカー: After 文と Trigger line の “one named relevant test with different A/B PASS/FAIL predictions” を、既存 COUNTEREXAMPLE 欄と整合する “one named relevant test and assertion/check whose A/B PASS/FAIL predictions differ because of that gap” に置換すること。
   - 追加ではなく置換で対応する。
   - 目的は新しい必須ゲート追加ではなく、早期 NOT_EQUIVALENT の witness を file diff から assertion boundary へ引き上げること。

2. 「Payment」は “既存 3 行の早期許可文を、assertion/check witness を含む 3〜4 行へ置換。別セクションに新規 MUST は追加しない” と書き直すこと。
   - Trigger line は After ブロック内に統合し、別の独立チェック項目として増やさない。

3. Non-goal に「assertion/check の種類や探索経路は固定しない。必要なのは早期 NOT_EQUIV を支える impact witness が 1 つ見えていることだけ」と明記すること。

## 結論

承認: NO（理由: STRUCTURAL TRIAGE / 早期 NOT_EQUIVALENT に触れる提案だが、impact witness として assertion boundary / diverging check を 1 つ目撃する要求が差分プレビューと Trigger line に入っていないため。named relevant test + PASS/FAIL prediction だけでは、早期 NOT_EQUIV の根拠が形式的なテスト名提示に退化し、偽 NOT_EQUIV 停滞を残す。）
