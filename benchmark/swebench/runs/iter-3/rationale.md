# Iteration 3 — 変更理由

## 前イテレーションの分析

- 前回スコア: 未確認（この実装タスクで参照を許可されたファイルには前イテレーションのスコア記録がない）
- 失敗ケース: 未確認（同上）
- 失敗原因の分析: 結論直前の自己点検が「全体として traced evidence があるか」という総称的な確認に寄りやすく、結論を支える最弱の outcome-critical なリンクが未検証でも、そのまま結論に進む余地がある。

## 改善仮説

最終結論の直前で、推論チェーンの weakest link を 1 つ明示させ、そのリンクが outcome-critical かつ UNVERIFIED / assumption-bearing なら、追加の targeted search/trace か confidence の明示的な引き下げに分岐させる。これにより、未検証の弱い環を抱えたまま EQUIVALENT / NOT EQUIVALENT を断定する過信を減らせる。

## 変更内容

Step 5.5 の既存 self-check から、汎用的な「 traced evidence supports 」確認 1 項目を削除し、その代わりに以下を入れた。
- weakest link を命名するチェック
- そのリンクが outcome-critical かつ UNVERIFIED / assumption-bearing な場合に、1 回の targeted search/trace か confidence 引き下げを要求するチェック
- 上記の分岐を self-check の直前で発火させる Trigger line

Trigger line (final): "Before concluding, identify the weakest outcome-critical link; if it is UNVERIFIED, do one targeted check or lower confidence explicitly."

この Trigger line は proposal の差分プレビューにあった planned Trigger line と一致しており、意図した一般化の範囲でも同等である。

## 期待効果

追加探索が必要な未検証リンクを結論直前で露出できるため、根拠が薄いままの同値判定や非同値判定を減らしやすい。とくに、他の追跡が十分でも weakest outcome-critical link だけが assumption-bearing な場合に、追加確認か confidence downgrade のどちらかへ行動を変えることが期待される。
