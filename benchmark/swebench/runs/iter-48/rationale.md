# Iteration 48 — 変更理由

## 前イテレーションの分析

- 前回スコア: 75% (15/20)
- 失敗ケース: 15368, 13821, 15382, 14787, 12663
- 失敗原因の分析: 15368・13821 は EQUIV を NOT_EQ と誤判定（EQUIV 偽陰性）。変更関数で差分を発見した後、呼び出し元が差分を吸収するかどうか確認せずに NOT_EQ を結論した。

## 改善仮説

Compare checklist の既存行「When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact」が曖昧であるため、エージェントは変更関数のコードを読んだ時点で義務を満たしたと解釈し、吸収確認を省略したまま NOT_EQ を結論する。この行を、すでにトレース済みの relevant test call path 上の consumer 関数を読み、差分が伝播するか吸収されるかを記録してから Claim を確定するよう方向性を明示した形に精緻化することで、EQUIV 偽陰性を修正できる。

## 変更内容

SKILL.md の `### Compare checklist` 5 番目の bullet（line 220）を 1 行置換した。「semantic difference」→「behavioral difference in a changed function」に絞り、トレース済み test call path 上の consumer 関数を読んで伝播/吸収を記録してから Claim を確定することを義務化した。

## 期待効果

- 15368・13821: nearest consumer 確認により吸収を発見 → EQUIV 偽陰性が解消される可能性が高い
- 既存の NOT_EQ 正答ケース: 真 NOT_EQ では consumer が伝播を確認するだけなので結論は変わらない
- 期待スコア: 75%（15/20）→ 80〜85%（EQUIV +1〜+2）
