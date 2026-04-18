# Iteration 24 — 変更理由

## 前イテレーションの分析

- 前回スコア: 不明（このチャットでは前回の scores.json が提供されていないため）
- 失敗ケース: 不明（同上）
- 失敗原因の分析: 不明（同上）

## 改善仮説

`compare` の冒頭で「最小反例の形」を先に固定すると、探索の入口がアンカリングされ、反例探索の幅が不必要に狭まる可能性がある。
そのため、まず定義と構造スコープ（比較対象の範囲）を確定してから反例候補生成に入る順序へ寄せることで、(a) 早すぎる NOT EQUIVALENT 側への寄りと、(b) 反例像の不備による EQUIVALENT 側への過小評価の両方を同時に減らす。

## 変更内容

`compare` の certificate template 冒頭 1 行を置換し、反例スケッチを最初に要求するのではなく、DEFINITIONS + STRUCTURAL TRIAGE を先に実行してスコープ確定後に反例スケッチへ進む順序に変更した（必須ゲートの純増はなく、既存の STRUCTURAL TRIAGE 自体も維持）。

Trigger line (final): "Complete every section; start with DEFINITIONS + STRUCTURAL TRIAGE to scope what must be compared, then sketch the minimal counterexample shape (reverse from D1) using what triage reveals."

上の Trigger line は proposal の差分プレビューにあった After の Trigger line と一致し、意図した一般化（順序のみ変更しアンカリングを弱める）として同等であることを確認した。

## 期待効果

- 反例の形状を早期に固定することで生じる探索経路の半固定（入口の狭窄）を弱め、比較対象のスコープ確定後に反例生成を行うことで、反証探索の取りこぼしと過早な結論の双方を抑制する。
- 変更は 1 行置換に限定され、既存のコア手順（定義、構造比較、詳細トレース、反証、結論）を維持したまま、意思決定点（反例生成のタイミング）だけを調整するため、回帰リスクと複雑性増加を最小化できる。
