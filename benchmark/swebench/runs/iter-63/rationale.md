# Iteration 63 — 変更理由

## 前イテレーションの分析

- 前回スコア: proposal.md に記載なし
- 失敗ケース: proposal.md に個別ケースの記載なし
- 失敗原因の分析: per-test compare で片側の trace と比較判断が混ざり、両変更の PASS/FAIL 予測が揃う前に SAME/DIFFERENT へ進むことがある。これにより、片側説明へのアンカリングによる偽 EQUIV と、局所的な意味差からの premature な偽 NOT_EQUIV の両方が起きうる。

## 改善仮説

各テストの比較を、説明の類似性ではなく Change A / Change B の独立した PASS/FAIL 予測ペアの比較として直列化すると、SAME/DIFFERENT の判断がテスト結果の同一/相違に基づきやすくなる。

## 変更内容

Compare template の per-test 記述を `Claim C[N].1` / `Claim C[N].2` から `Prediction pair` へ置換し、A と B の PASS/FAIL 予測を先に揃えてから Comparison を書く順序にした。あわせて Compare checklist の既存項目を、同じ趣旨の prediction-pair 要求へ置換し、必須ゲートの純増にならないようにした。

Trigger line (final): "Do not write SAME/DIFFERENT until both A and B predictions for this test are present."

この Trigger line は proposal の差分プレビューにあった planned Trigger line と一致しており、Decision-point delta の分岐を発火させる場所である per-test template 内に配置した。

## 期待効果

Before では、片側 trace が十分に似ている/違うように見えた時点で `Comparison: SAME / DIFFERENT outcome` を書きがちだった。After では、同じテストについて A/B の PASS/FAIL 予測が両方記録されている場合だけ Comparison に進み、不足していれば missing side prediction を先に埋める。これにより、比較単位が説明文の印象ではなく outcome pair になり、EQUIV/NOT_EQUIV 双方の premature comparison を減らすことが期待できる。
