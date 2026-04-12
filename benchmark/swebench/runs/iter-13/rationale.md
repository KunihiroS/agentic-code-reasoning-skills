# Iteration 13 — 変更理由

## 前イテレーションの分析

- 前回スコア: 不明（iter-12 の scores.json 未参照）
- 失敗ケース: 不明（参照制約により未確認）
- 失敗原因の分析: ソースが取得できない（UNVERIFIED）関数について、二次証拠を探す順序が不定のまま運用されていた。名前や型シグネチャから先に確認してしまう場合、確認バイアスが生じやすい構造になっていた。

## 改善仮説

ソースが入手できない関数について二次証拠を探す際、テストコードでの実際の使われ方（test usage）を最初に参照することで、関数の実際の振る舞いを最も直接的に示す証拠が先に得られる。これにより、名前や型宣言からの推測に依存する確認バイアスを軽減できる。

## 変更内容

SKILL.md の Step 4（Interprocedural tracing）の Rules 内、UNVERIFIED 関数に対する二次証拠の探索方法を記述した 1 行を変更した。

変更前: 「Search for type signatures, documentation, or test usage as secondary evidence.」（順序不定の列挙）

変更後: 「Search for secondary evidence in priority order: test usage first (shows actual behavior), then type signatures, then documentation.」（優先順位を明示した探索順序）

変更規模: 1 行（既存行の書き換えのみ、追加・削除なし）

## 期待効果

UNVERIFIED 関数を含む推論タスクにおいて、二次証拠の探索順序が明確になることで以下の改善が期待できる。

- 関数名・型シグネチャからの誤推測が減り、実際の使われ方に基づく帰納的な根拠付けが先に行われるようになる。
- Guardrail #5 が指摘する「不完全な推論チェーン」に対して、UNVERIFIED 関数の仮定の信頼性が早期に評価されるようになる。
- EQUIVALENT / NOT_EQUIVALENT の誤判定のうち、UNVERIFIED 関数の仮定ミスに起因するものが減少する。
- 変更は探索の優先順位の精緻化のみであり、探索自由度は維持されるため、既存の正答ケースへの回帰リスクは極めて低い。
