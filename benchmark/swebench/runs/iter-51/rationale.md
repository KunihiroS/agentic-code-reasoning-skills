# Iteration 51 — 変更理由

## 前イテレーションの分析

- 前回スコア: proposal には未記載
- 失敗ケース: proposal には固有ケースの列挙なし
- 失敗原因の分析: 内部的な意味差と、実際に verdict を運ぶ assert/check の結果差が同じ Comparison 欄へ流れ込み、内部差分を過大評価する偽 NOT_EQUIV と、assert/check の結果差を見落とす偽 EQUIV の両方が起きうる。

## 改善仮説

比較単位を raw semantic behavior ではなく、各 relevant test の traced assert/check result に揃える。これにより、内部挙動差は記録しつつも、それが assert/check result を変える場合だけ verdict-bearing として扱える。

## 変更内容

- per-test Comparison 欄を、Change A/B が同じ assert/check に到達したときの result を比較する形式へ置換した。
- `Comparison: SAME / DIFFERENT outcome` を `Comparison: SAME / DIFFERENT assertion-result outcome; note any internal semantic difference separately.` に置換し、内部意味差と verdict を決める結果差を分離した。
- 必須ゲートの総量を増やさないため、pre-conclusion self-check の既存項目を、file search/code inspection の実施確認から、semantic difference が traced assert/check result を変えるかどうかの確認へ置換した。

Trigger line (final): "For each relevant test, compare the traced assert/check result, not merely the internal semantic behavior; semantic differences are verdict-bearing only when they change that result."

この Trigger line は proposal の差分プレビューにあった Trigger line と一致しており、Decision-point delta の分岐を per-test Comparison 欄で発火させる位置に入っている。

## 期待効果

内部表現や途中挙動が異なっても、同じ assert/check result に到達する場合は SAME と判断しやすくなる。逆に、内部説明が似ていても assert/check result が異なる場合は DIFFERENT と判断しやすくなる。これにより、比較の根拠が behavior-level difference から assertion-result outcome へ移り、EQUIV/NOT_EQUIV の両方向で誤判定を減らすことが期待できる。
