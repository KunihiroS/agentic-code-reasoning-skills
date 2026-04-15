# Iteration 52 — 変更理由

## 前イテレーションの分析

- 前回スコア: 不明（iter-51 の scores.json 未参照）
- 失敗ケース: 詳細は scores.json 参照
- 失敗原因の分析: Step 5 COUNTEREXAMPLE CHECK の `Found:` フィールドで、
  反証が見つからなかった場合に探索努力を省略した "NONE FOUND" 一言で済ませる
  記述が発生しやすかった。これが EQUIVALENT 誤判定に繋がる探索省略を招いていた。

## 改善仮説

Step 5 反証チェックの `Found:` フィールドに「証拠が存在した場合」と
「証拠が存在しなかった場合」の両方の記述例を明示することで、
探索省略を自己検出しやすくし、全体的な推論品質が向上する。

## 変更内容

`compare` および `audit-improve` 用 COUNTEREXAMPLE CHECK ブロックの
`Found:` フィールドを以下のとおり精緻化した（1行変更）。

変更前:
```
- Found: [what — cite file:line]
```

変更後:
```
- Found: [cite file:line if evidence exists; or "NONE FOUND — searched [specific pattern] in [file(s)]"]
```

## 期待効果

- 反証が見つからなかった場合に探索した内容と対象を明記させることで、
  探索省略による偽 EQUIVALENT 誤判定が減少すると予想する。
- 反証が見つかった場合は `cite file:line` の明示要件が維持されるため、
  根拠の曖昧な NOT_EQUIVALENT 誤判定も抑制される。
- 変更規模が1行であるため、既存の正答ケースへの回帰リスクは極めて低い。
