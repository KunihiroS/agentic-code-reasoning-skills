# Iteration 54 — proposal discussion

## 1. 既存研究との整合性

検索なし（理由: 一般原則の範囲で自己完結）。

提案は外部の新概念に強く依拠しているというより、参照許可ファイル内の docs/design.md にある「Fault Localization: Code Path Tracing → Divergence Analysis」と、SKILL.md 既存 Guardrail の「symptom と root cause を混同しない」を compare の COUNTEREXAMPLE 行へ局所移植するもの。追加の Web 検索で確認すべき固有主張はない。

整合性は概ね良い。README.md / docs/design.md は、半形式的テンプレートを certificate として使い、premises、trace、counterexample obligation によって unsupported claim を減らす設計を説明している。今回の変更は NOT_EQUIV の証明欄で、終端 assertion だけでなく「最初に A/B が違った trace point から、その assertion に異なる形で到達する」ことを要求するため、certificate の粒度を原因側へ少し広げる変更として説明できる。

## 2. Exploration Framework のカテゴリ選定

カテゴリ F（原論文の未活用アイデアを導入する）の選定は適切。

理由:
- docs/design.md は Fault Localization の構成要素として Code Path Tracing → Divergence Analysis を明示している。
- SKILL.md の compare には per-test trace と counterexample obligation はあるが、NOT_EQUIV counterexample の該当行は現在「Diverging assertion」だけで、divergence origin までは要求していない。
- localize/explain の発想を compare の結論欄へ全面移植するのではなく、既存の 1 行を置換するだけなので、研究コアを保ったまま未活用要素を狭く導入している。

汎用原則としても理にかなっている。任意の言語・フレームワークで、テスト outcome の差を主張するには、終端の assert/check だけでなく「どの値・状態・分岐の差がそこへ到達したのか」を説明できる方が、症状と原因の混同を減らせる。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用

NOT_EQUIVALENT への作用:
- 主作用は偽 NOT_EQUIV の削減。
- 変更前は「同じ assertion 付近に差分らしい説明がある」だけで DIFFERENT outcome として閉じやすい。
- 変更後は first differing branch/state/value から assert/check までの短い trace が必要になるため、終端症状だけの差や再合流する内部差を NOT_EQUIV に昇格しにくくなる。
- ただし、trace origin を示せる真の NOT_EQUIV では、むしろ counterexample の説得力が上がる。

EQUIVALENT への作用:
- 直接の変更対象は NOT_EQUIV counterexample 欄なので、EQUIV への作用は間接的。
- 偽 NOT_EQUIV を避けた結果、同じ assertion outcome へ到達する場合は EQUIV または UNVERIFIED へ戻りやすくなる。
- 逆に、見かけ上同じ outcome に見えても、差分 origin から別 assertion outcome へ到達する trace を発見できれば、偽 EQUIV の回避にも効く。
- ただし提案文の「Target: 両方」はやや強い。実効的には NOT_EQUIV の証拠品質改善が主で、EQUIV は副作用として「誤った counterexample を退ける」「隠れた divergence を追いやすくする」程度に整理するのが正確。

片方向最適化の懸念:
- 片方向だけを明白に悪化させる変更ではない。
- NOT_EQUIV のハードルを上げるため、真の NOT_EQUIV で origin localization が難しい場合に保留・低 confidence へ寄るリスクはある。
- しかし既存の「Diverging assertion」行を置換するだけで、STRUCTURAL TRIAGE や per-test analysis 全体に新しい探索義務を広げていないため、許容範囲。

## 4. failed-approaches.md との照合

本質的な再演ではないと判断する。

- 原則 1「再収束を比較規則として前景化しすぎない」: NO。提案は再収束を EQUIV の既定規則にしていない。むしろ NOT_EQUIV 主張時の因果 trace を明確化するもの。
- 原則 2「未確定 relevance や脆い仮定を常に保留側へ倒す」: NO。未確定なら常に UNVERIFIED へ倒すという広い fallback は追加していない。ただし origin が書けない場合に NOT_EQUIV を弱めるため、実装時に「origin 不明なら常に保留」と読ませない表現にする必要はある。
- 原則 3「差分の昇格条件を新しい抽象ラベルや必須の言い換え形式で強くゲートしすぎない」: 概ね NO。新しい抽象ラベル分類ではなく、既存の diverging assertion 行を origin + assertion に置換している。ただし “first differing branch/state/value” が、探索前から単一の形に固定されるとこの原則に近づくため、文言は “branch/state/value” の例示に留めるのがよい。
- 原則 4「終盤の証拠十分性チェックを confidence 調整へ吸収しすぎない」: NO。confidence への吸収ではなく counterexample の証拠行を強める変更。
- 原則 5「最初に見えた差分から単一の追跡経路を即座に既定化しすぎない」: NO。探索順の固定ではなく、NOT_EQUIV を既に claim する場面の certificate 形を変える変更。ただし “first differing” の語は、最初に見えた差分ではなく「trace 上で最初に実際に分岐した点」として読ませる必要がある。
- 原則 6「探索理由と情報利得を潰しすぎない」: NO。該当しない。

## 5. 汎化性チェック

固有識別子チェック:
- 具体的なベンチマーク ID: なし。
- リポジトリ名: なし。
- 具体的テスト名: なし。
- 実コード断片: なし。
- SKILL.md 自身の文言引用とテンプレート断片はあるが、Objective.md の R1 減点対象外に該当する。

ドメイン・言語依存:
- “branch/state/value”, “assert/check”, “file:line” は一般的なコード推論語彙であり、特定言語や特定テストフレームワークを前提にしていない。
- テスト outcome を軸にする点は SKILL.md の compare mode 定義そのものと整合している。

汎化性は PASS 水準。

## 6. compare 影響の実効性チェック

0) 実行時アウトカム差:
- NOT_EQUIV の ANSWER を出す前に、COUNTEREXAMPLE 欄の必須証拠が「終端 assertion」から「first differing trace point + assertion outcome trace」へ変わる。
- 観測可能には、ANSWER: NO not equivalent の根拠文に divergence origin が出る、または origin から assertion までを示せない場合に CONFIDENCE を下げる / UNVERIFIED を明示する / EQUIV 側へ戻る、という差が出る。

1) Decision-point delta:
- IF/THEN 形式で 2 行（Before/After）になっているか？ YES。
- Before: IF Change A/B の test outcome が異なると主張でき、終端の diverging assertion を示せる THEN NOT_EQUIV へ進む。
- After: IF Change A/B の test outcome が異なると主張でき、最初の divergent trace point から diverging assertion までを示せる THEN NOT_EQUIV へ進む。
- 条件も行動も同じで理由だけ言い換え、ではない。NOT_EQUIV に進む条件が assertion-only から origin-to-assertion trace へ変わっている。
- 差分プレビュー内に Trigger line の自己引用が含まれているか？ YES。proposal line 68 に planned trigger line がある。

2) Failure-mode target:
- 主対象: 偽 NOT_EQUIV。
- メカニズム: assertion 付近の症状だけではなく、A/B が最初に異なる branch/state/value と、その差が assertion outcome 差へ伝播する trace を要求するため、結果差に結びつかない内部差を counterexample として過大評価しにくい。
- 副対象: 偽 EQUIV。
- メカニズム: 表面的に同じ outcome と見える場合でも、trace origin を探す過程で outcome を変える実分岐が見つかれば NOT_EQUIV counterexample を構成しやすくなる。ただし副次効果であり、主効果ほど強くない。

2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？
- YES。ただし直接の修正対象は COUNTEREXAMPLE 行であり、STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件そのものを書き換えてはいない。
- NOT_EQUIV の根拠が「ファイル差がある」だけに退化していないか？ 退化していない。
- impact witness を提案が要求しているか？ YES。After の “reaches [assert/check:file:line] differently” が PASS/FAIL に結びつく assertion boundary の目撃を要求している。
- 注意点: structural gap から直接 FORMAL CONCLUSION へ進める既存文言との整合が必要。今回の 1 行置換は通常の COUNTEREXAMPLE 欄に効くため、早期 structural NOT_EQUIV の例外条件を追加で狭める必要はない。

3) Non-goal:
- 探索経路を「最初に見えた差分」へ半固定しない。
- 新しい必須ゲートを純増しない。既存の “Diverging assertion” 行を “Divergence origin + assertion” 行へ置換する。
- 証拠種類を特定のテストパターン、言語構文、オラクル可視性、特定ファイル種別へ事前固定しない。
- 未確定な origin を常に保留へ送る一般ルールにはしない。あくまで NOT_EQUIV counterexample を claim する時の certificate 形の変更に留める。

## 7. 停滞診断

監査 rubic に刺さる説明強化へ偏り、compare の意思決定を変えていない懸念:
- 懸念は小さい。proposal は docs/design.md 由来の説明だけでなく、COUNTEREXAMPLE の 1 行置換、Payment、Before/After の Decision-point delta、Trigger line を示しており、実行時に NOT_EQUIV へ進む条件が変わる。

failed-approaches.md 該当性:
- 探索経路の半固定: NO。NOT_EQUIV claim 時の証拠行の置換であり、次に読むファイルや最初の探索アンカーを固定していない。
- 必須ゲート増: NO。Payment が明示され、既存 MUST の置換になっている。
- 証拠種類の事前固定: NO。assert/check は既存の compare 定義に含まれる outcome boundary で、branch/state/value は具体的証拠種類の固定ではなく trace point の抽象表現。ただし実装時は “branch/state/value” を排他的分類として扱わせないようにすること。

## 8. Discriminative probe

抽象ケース:
- 2 つの変更は中間で異なる値を一度作るが、後段の正規化により同じ test assertion outcome に到達する。
- 変更前は assertion 付近の説明だけで「差分があるので別 outcome」と読み、偽 NOT_EQUIV に寄りやすい。
- 変更後は、最初の divergent trace point から assertion outcome 差までを 1 本で示せないため、NOT_EQUIV counterexample が完成せず、EQUIV または UNVERIFIED/低 confidence に戻れる。

これは新しい必須ゲートの増設ではなく、既存の “Diverging assertion” 行の置換で説明されている。Payment も proposal 内で A/B 対応付けが明示されている。

## 9. 推論品質の期待改善

期待できる改善:
- NOT_EQUIV の counterexample が、終端症状の列挙から因果 chain の短い certificate へ変わる。
- 「assertion が違うはず」という結論先行の説明を減らし、どの値・状態・分岐が assertion outcome に伝播したかを明示させる。
- 既存の per-test trace、interprocedural tracing、refutation check と整合し、研究コアを弱めない。
- 変更量が 1 行置換中心で、認知負荷の増加が小さい。

残る軽微な懸念:
- “Target: 両方” はやや強く、主効果は偽 NOT_EQUIV 削減である。EQUIV 改善は間接効果として表現した方がよい。
- “first differing” が「最初に目に入った差分」と誤読されると failed-approaches.md 原則 5 に近づく。実装時は “first trace point where the two executions actually differ” の意味に寄せるべき。

## 10. 最小修正指示

1. Target の説明を「主: 偽 NOT_EQUIV、従: 偽 EQUIV」に弱める。両方に効くという主張は残してよいが、EQUIV への作用は間接効果として書く。
2. Trigger line の “first differing branch/state/value” は、探索順固定に読ませないため “first trace point where A and B actually differ (branch/state/value, etc.)” のように、実行 trace 上の分岐点であることを明確にする。
3. 実装では必ず既存の “Diverging assertion” 行の置換に留め、別の required 行や self-check を増やさない。

## 結論

承認: YES

理由: 汎化性違反はなく、failed-approaches.md の本質的再演でもない。compare の実行時アウトカム差は、NOT_EQUIV counterexample の成立条件が assertion-only から origin-to-assertion trace へ変わる点で具体的であり、Trigger line と Payment も proposal 内に明示されている。細部の表現修正は必要だが、監査 PASS の下限を満たしたまま compare の意思決定改善に結びつく提案と判断する。
