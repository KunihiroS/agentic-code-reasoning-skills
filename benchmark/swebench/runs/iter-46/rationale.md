# Iteration 46 — 変更理由

## 前イテレーションの分析

- 前回スコア: 不明（iter-45 の scores.json 未参照）
- 失敗ケース: 記載なし
- 失敗原因の分析: Guardrail #5 の文言が「downstream のみ確認する」という
  一方向の読み取りを許容しており、upstream（値が生成・設定される箇所）の
  確認が促されていなかった。片方向のトレースで完了したとみなす
  早期収束が失敗の一因と推定される。

## 改善仮説

Guardrail #5 の末尾文言に「upstream と downstream の両方を検証する」という
方向性を明示することで、エッジケース発見後に片方向トレースで完了と
みなす誤りを減らし、推論チェーン全体の完全性が向上する。

## 変更内容

SKILL.md の Guardrail #5 末尾文を 1 行変更した。

変更前の末尾:
「Confident-but-wrong answers often come from thorough-but-incomplete analysis.」

変更後:
「Confident-but-wrong answers often come from thorough-but-incomplete analysis
— verify both upstream (where the value was set or the state was created)
and downstream (where it is consumed or checked).」

削除行: 0、変更行: 1（既存文への末尾追記）。

## 期待効果

- `diagnose` モード: 症状サイトと根本原因サイトの分離（Guardrail #3 との連携）
  において、upstream 方向への探索を明示的に促す表現が補強される。
- `compare` モード: 変更点から upstream / downstream 両方向にトレースする
  ことで、片方だけが見逃していた副作用の検出精度が向上する。
- `explain` モード: Data flow analysis の「生成 → 変更 → 使用」三点追跡と
  Guardrail 層の一貫性が増し、双方向確認の習慣が強化される。
- 変更は言語・フレームワーク非依存の汎用原則であり、過剰適合のリスクはない。
