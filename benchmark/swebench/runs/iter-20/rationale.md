# Iteration 20 — 変更理由

## 前イテレーションの分析

- 前回スコア: N/A（この作業ではスコア記録を参照していない）
- 失敗ケース: N/A（この作業ではケース一覧を参照していない）
- 失敗原因の分析: compare では、証拠収集後に独立した必須自己監査ゲートがもう一度結論を止めやすく、未検証点を局所的に明示して結論へ進む代わりに、追加探索や保留へ寄りやすい構成になっていた。

## 改善仮説

独立した pre-conclusion self-check を削除し、その役割を FORMAL CONCLUSION 内の不確実性明示へ統合すれば、番号付き前提・手続き間トレース・必須反証を維持したまま、重複ゲートによる保留過多を減らせる。

## 変更内容

- compare の直前にあった独立の Step 5.5 を削除した。
- FORMAL CONCLUSION に、未検証項目が残る場合は結論内で明示し、比較対象のテスト結果を変えうる場合にだけ CONFIDENCE を下げる trigger line を追加した。
- Compare checklist には、ANSWER 前の追加ゲートではなく、certificate 内で既に満たした義務の recap であることを明記した。

Trigger line (final): "If unverified items remain, state them in the conclusion and lower CONFIDENCE unless they can change the compared test outcomes."

この Trigger line は proposal の差分プレビューにあった planned trigger line と一致しており、独立ゲートではなく FORMAL CONCLUSION で分岐を発火させる一般化として同等である。

## 期待効果

- per-test trace と refutation が揃っている場面では、未検証点が結論を変えないことを明示したうえで ANSWER と CONFIDENCE に進みやすくなる。
- 追加の必須ゲートを増やさず、むしろ独立ゲートを統合したため、結論前の判定手順の総量を増やさずに compare の停滞を減らせる。
- 変更は compare の終端付近に限定されており、研究コアを保ったまま回帰リスクを抑えられる。