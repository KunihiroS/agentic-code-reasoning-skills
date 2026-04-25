# Iteration 57 — 変更理由

## 前イテレーションの分析

- 前回スコア: 未記載
- 失敗ケース: 個別ケース名は記載しない
- 失敗原因の分析: 広い構造読みだけで過度な非同等判断に寄る場合と、最初に見えた差分の下流確認だけで過度な同等判断に寄る場合の両方があり、結論規則ではなく次に読む対象の選び方を改善する必要がある。

## 改善仮説

次に読む対象を選ぶ時点で、現在の複数仮説を最も分離できる最小の source/test artifact を明示すれば、目立つ変更箇所や広すぎる周辺読みへの固定を避け、同じ証拠量でも同等・非同等の判別に使える観察を増やせる。

Trigger line (final): "DISCRIMINATIVE READ TARGET: [smallest source/test artifact likely to separate at least two live hypotheses; if none exists, write NOT FOUND and broaden one step]"

この Trigger line は proposal の差分プレビューにあった Trigger line と一致しており、次に読む対象を選ぶ分岐を発火させる位置に入っている。

## 変更内容

Step 3 の探索ジャーナルで、任意の情報利得欄を、少なくとも 2 つの live hypotheses を分離しうる最小の source/test artifact を先に名指しする欄へ置換した。あわせて、必須ゲートの純増を避けるため、別ステップにあった冗長な必須強調文を削除した。

## 期待効果

探索前の意思決定が「読む理由の説明」から「分離できる観察の事前指定」に変わるため、最初の差分だけに引っ張られる誤判定と、広く読みすぎて未確定性を増やす誤判定の両方を減らすことが期待される。新しい結論条件は追加せず、既存欄の置換と冗長文の削除に留めるため、研究コアと反証手順への影響は限定的である。
