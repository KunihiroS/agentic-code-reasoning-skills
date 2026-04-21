# Iteration 5 — 変更理由

## 前イテレーションの分析

- 前回スコア: 85% (17/20)
- 失敗ケース: 固有識別子は省略するが、同じ観測結果への再収束だけで EQUIVALENT に寄りやすい比較と、局所差の説明だけで NOT EQUIVALENT に寄りやすい比較が残っていた。
- 失敗原因の分析: no-counterexample の根拠が sink agreement 中心だと、共有された観測結果の前にある最初の挙動差と、その差を吸収する downstream handler/normalizer の有無が compare の証拠単位として明示されにくい。そのため、因果鎖が閉じる前に EQUIVALENT へ進んだり、逆に局所差だけを見て差分の無害化を見落としたりする余地があった。

## 改善仮説

EQUIVALENT 側の no-counterexample 記述に、共有された観測結果へ至る前の earliest divergence と、それを吸収する downstream handler/normalizer を対で書かせれば、再収束の理由を closed causal chain として確認できる。これにより、同じ観測結果という事実だけに引っ張られた偽 EQUIVALENT と、局所差だけに引っ張られた偽 NOT EQUIVALENT の両方を減らせる。

## 変更内容

- `NO COUNTEREXAMPLE EXISTS` 節に trigger line を追加し、2つの trace が同じ observed outcome に至る前に分岐している場合は earliest behavioral divergence と downstream handler/normalizer を明示するよう置換した。
- 同節の counterexample 記述テンプレートを、単なる diverging behavior ではなく earliest divergence と downstream handler の有無を書く形へ置換した。
- Compare checklist から、局所差が見つかったときの追加トレース義務を削除し、上記の no-counterexample 記述へ統合した。これにより必須ゲートの総量を増やさず、既存義務の置換に留めた。
- Trigger line (final): "If the two traces diverge before reaching the same observed outcome, name the earliest behavioral divergence and the downstream handler/normalizer that makes the outcomes match."
- この Trigger line は proposal の差分プレビューにあった Trigger line と一致しており、比較分岐を `NO COUNTEREXAMPLE EXISTS` の入口で発火させる配置として反映できている。

## 期待効果

共有された assertion や observed outcome への再収束が見えても、その前段で分岐した振る舞いと吸収点を追跡しない限り EQUIVALENT を正当化できなくなるため、compare の因果鎖が閉じやすくなる。結果として、再収束だけを根拠にした過剰な同値判定と、局所差だけを根拠にした過剰な非同値判定の双方が減ることを期待する。
