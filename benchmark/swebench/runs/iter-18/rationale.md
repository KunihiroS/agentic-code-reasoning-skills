# Iteration 18 — 変更理由

## 前イテレーションの分析

- 前回スコア: N/A（この作業で参照を許可されたファイルには未記載）
- 失敗ケース: N/A（この作業で参照を許可されたファイルには未記載）
- 失敗原因の分析: 未検証の行が残っていても、「結論に影響しない」という叙述で EQUIVALENT / NOT_EQUIVALENT の判断へ進めてしまう曖昧さがあり、決定的な claim が UNVERIFIED 依存のまま結論へ流れる分岐が残っていた。

## 改善仮説

結論単位の曖昧な免責をやめ、verdict-distinguishing claim ごとに VERIFIED 依存かどうかを判定させれば、未検証リンクを narrative で吸収しにくくなり、追加探索・NOT VERIFIED 明示・LOW confidence への分岐が働いて誤判定を減らせる。

## 変更内容

Step 5.5 の self-check で、既存の「UNVERIFIED でも結論に影響しなければ可」という 1 項目を削除し、以下の 2 項目へ置換した。

- verdict-distinguishing claim は VERIFIED 行のみに依存するか、結論前に NOT VERIFIED と明示する
- UNVERIFIED 行は、EQUIVALENT / NOT_EQUIVALENT claim がそれに依存しない場合に限り許容する

Trigger line (final): "Every verdict-distinguishing claim depends only on VERIFIED rows, or is explicitly marked NOT VERIFIED before conclusion."

この Trigger line は proposal の差分プレビューにある planned trigger line と同じ趣旨であり、Step 5.5 の判定箇所に直接配置することで Decision-point delta の分岐を実際に発火させる形になっている。

## 期待効果

決定 claim が UNVERIFIED 依存のまま formal conclusion に進むケースで、追加の targeted search、NOT VERIFIED 明示、または LOW confidence への切り替えが起きやすくなる。これにより、未検証リンクを都合よく benign 扱いして EQUIVALENT と誤判定するケースと、逆に未確認差分を強調して NOT_EQUIVALENT と誤判定するケースの両方を抑制できる。