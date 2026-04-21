# Iteration 17 — 変更理由

## 前イテレーションの分析

- 前回スコア: 未確認（このタスクでは参照範囲外）
- 失敗ケース: 未確認（このタスクでは参照範囲外）
- 失敗原因の分析: compare で片側だけが実トレース済み、もう片側が analogy / UNVERIFIED 依存でも、per-test の Comparison を埋めること自体が先行しやすく、弱い側の追跡より先に SAME / DIFFERENT を確定しがちだと分析した。

## 改善仮説

global な weakest-link の自己点検よりも、各 SAME / DIFFERENT comparison ごとに weaker-supported side を特定させた方が、比較の確信度を強い側ではなく弱い側に合わせられる。これにより、偽の EQUIVALENT / NOT EQUIVALENT の両方を減らしつつ、未検証性を新しい一律ゲートにせず次の探索先へ変換できる。

## 変更内容

- Step 5.5 の global weakest-link チェック 2 行を、comparison 単位で弱い側を特定して強い側だけで finalize しない自己チェックへ置換した。
- Compare の per-test analysis に、片側だけが analogy または UNVERIFIED 依存なら、その側を先に trace してから SAME / DIFFERENT を書く trigger line を 1 行追加した。
- 追加ではなく置換中心にし、必須判断の総量が増えないよう global weakest-link 項目を局所 comparison チェックへ統合した。
- Trigger line (final): "If only one side of a comparison depends on analogy or UNVERIFIED behavior, trace that side next before writing SAME / DIFFERENT."
- この Trigger line は proposal の差分プレビューにあった planned trigger line と一致しており、比較の分岐を発火させる位置にもそのまま配置した。

## 期待効果

各比較対で証拠の左右非対称が見えるようになり、片側だけ弱い証拠なのに Comparison を確定する誤りを減らせる。特に、片側が具体的な trace、もう片側が名称類似や構造類似ベースの analogy に留まる場面で、弱い側への追加追跡または provisional な扱いが起きやすくなり、compare の実効差が出やすくなる。