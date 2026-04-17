# Iteration 6 — 変更理由

## 前イテレーションの分析

- 前回スコア: N/A
- 失敗ケース: N/A
- 失敗原因の分析: compare において、構造差分だけを根拠に早期 NOT EQUIVALENT へ短絡しやすく、また EQUIVALENT 側でも反例探索の起点が曖昧になりやすい。

## 改善仮説

compare の意思決定を「反例の最小形（counterexample shape）を先に仮置きして反証可能性を中心に進める」方向へ前倒しし、早期 NOT EQUIVALENT は“関連テスト経路上の欠落”が確立できた場合に限定すれば、偽 NOT_EQUIV と偽 EQUIV の両方が減る。

## 変更内容

- Compare / Certificate template 冒頭の指示を、ANALYSIS 前に最小反例形をスケッチする順序へ置換。
- 早期 NOT EQUIVALENT の許可条件を、S2 による「関連テストが import/exercise する経路上」の構造欠落の確立に束縛。

## 期待効果

- 見た目の構造差分のみで結論を急ぐ分岐が弱まり、テスト関連性に基づく判定が増える。
- ANALYSIS が反例探索/反証として運用されやすくなり、早計な EQUIVALENT を抑制できる。