# Iteration 37 — 変更理由

## 前イテレーションの分析

- 前回スコア: N/A（今回の作業範囲では未参照）
- 失敗ケース: N/A（今回の作業範囲では未参照）
- 失敗原因の分析: compare で差分を見つけた後の比較粒度が単一の traced test に寄りやすく、同一の assertion outcome を見た時点で比較を局所化しすぎる停滞がある、という仮説を採用した。

## 改善仮説

見つかった semantic difference を「tested input/state partition 自体を変える差分」か「同一 partition 内の representative computation 差分」かで分類し、その分類で compare scope を決めるようにすると、単一テスト経路の一致を過大評価せず、false EQUIV と false NOT EQUIV の両方を減らせると考えた。

## 変更内容

- compare テンプレートの "EDGE CASES RELEVANT TO EXISTING TESTS" を、差分ごとに Kind と Compare scope を書く "DIFFERENCE CLASSIFICATION" に置換した。
- compare checklist の "trace at least one relevant test" を、まず partition-changing か representative-only かを判定する指示へ置換した。
- Trigger line (final): "Treat partition-changing differences as scope expanders for comparison, not as immediate verdicts."
- この Trigger line は proposal の差分プレビューにある planned trigger line と一致しており、差分を即時 verdict ではなく比較範囲拡張の分岐として扱う一般化をそのまま反映している。

## 期待効果

差分発見後の意思決定点で、単一 traced path の一致だけを根拠に比較を閉じず、tested partition に触れる関連テスト群へ比較を広げるべき場合を明示できる。これにより、局所一致による premature EQUIV を避けつつ、partition を変えない差分では current traced test に比較を留められるため、必須判定手順の総量を増やさずに compare の分岐精度を上げられる。
