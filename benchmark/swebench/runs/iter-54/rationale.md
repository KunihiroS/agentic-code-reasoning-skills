# Iteration 54 — 変更理由

## 前イテレーションの分析

- 前回スコア: 提案文では未指定
- 失敗ケース: 提案文では個別ケースを列挙せず、比較判断の一般的な失敗形として扱う
- 失敗原因の分析: NOT EQUIVALENT の根拠が終端の assertion 差に寄ると、症状と原因を混同し、最初に実行トレースが分岐した地点から assertion outcome までの因果 chain が薄いまま結論へ進む可能性がある。

## 改善仮説

NOT EQUIVALENT の counterexample 欄で、終端 assertion だけではなく、最初に異なる branch/state/value と、その地点から異なる assert/check outcome へ到達する短い trace を同じ行で要求すれば、症状だけを根拠にした偽 NOT EQUIVALENT を減らし、同時に実際の分岐を伴う NOT EQUIVALENT の証拠品質を上げられる。

## 変更内容

既存の必須行を増やさず、counterexample 内の diverging assertion 行を置換した。

Trigger line (final): "Divergence origin + assertion: [first differing branch/state/value — cite file:line] reaches [assert/check:file:line] differently."

この Trigger line は提案の差分プレビューにある planned line と一致しており、NOT EQUIVALENT の分岐を発火させる counterexample 欄そのものに配置されている。

Decision-point delta:
- Before: test outcome の差と終端の diverging assertion を示せれば、assertion-level counterexample として NOT EQUIVALENT へ進みやすかった。
- After: test outcome の差に加えて、最初の divergent trace point から diverging assertion までを示す必要があり、divergence-origin counterexample として結論する。

## 期待効果

- 終端症状だけを原因差として扱う誤判定を抑える。
- 同じ assertion outcome へ再合流する差分を NOT EQUIVALENT と誤読しにくくする。
- 既存の 1 行置換なので、結論前の判定手順の総量は増やさず、compare に効く意思決定点だけを変更する。
