# Iteration 58 — 変更理由

## 前イテレーションの分析

- 前回スコア: 85% (17/20)
- 失敗ケース: 15368, 15382, 14787
- 失敗原因の分析: 15368（EQUIV→NOT_EQ）はコード上の差異がテストアサーションまで伝播するかを未確認のまま NOT_EQ に結論。14787（NOT_EQ→EQUIV）はテストアサーションから逆算して観測可能な差異があるかを確認していない。いずれも推論連鎖の終点がテストの観測点まで到達していないことが共通原因。

## 改善仮説

Guardrail §5 の「downstream code」が曖昧で、テストのアサーション自体まで追跡する義務を明示していない。この表現を「downstream code — including the test assertions themselves」に具体化することで、差異の "到達性検証" をテストの観測点まで明示し、EQUIV/NOT_EQ どちらの方向でも証拠連鎖の完全性が向上する。

## 変更内容

Guardrails §5 の既存行 1 行のみを文言精緻化:
- `downstream code` → `downstream code — including the test assertions themselves`
- `does not already handle` → `does not already neutralize`
- `the edge case or condition you identified` → `the effect you identified`

追加・削除行数はゼロ。変更行数は 1 行。

## 期待効果

- 15368: コード差異を発見後、テストアサーションまでの追跡が促され NOT_EQ への早期飛躍を抑制。改善可能性: 中〜高
- 14787: テストアサーションから逆算して差異の観測可能性を確認する動線が強化。改善可能性: 低〜中
- 想定スコア: 85% → 88〜90%（17→18 件程度）
