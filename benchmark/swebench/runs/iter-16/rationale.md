# Iteration 16 — 変更理由

## 前イテレーションの分析

- 前回スコア: 不明 (iter-15 の scores.json 未参照)
- 失敗ケース: 特定ケースの固有識別子は記載しない
- 失敗原因の分析: コールチェーンの末端処理（例外捕捉、デフォルト値、ガード節など）を「確認済み」とみなしたまま推論を完結させてしまうケースが観察された。Guardrail #5 の「downstream code does not already handle」という文言が、何をもって「handle している」と判断するかを明示していないため、確認行為が曖昧なレベルにとどまりやすかった。

## 改善仮説

「downstream が既に処理しているか」という問いは、確認すべき構文パターンが例示されていない場合、「ざっと読んだ」程度で通過しやすい。具体的なパターン例（例外捕捉、デフォルト値、ガード節）を Guardrail #5 に埋め込むことで、確認行為の粒度が揃い、不完全なチェーンを見逃すリスクが下がると考えた。

## 変更内容

Guardrail #5 の既存の1行に、確認すべき構文パターンの例示フレーズを追加した。

変更前:
```
verify that downstream code does not already handle the edge case or condition you identified. Confident-but-wrong answers often come from thorough-but-incomplete analysis.
```

変更後:
```
verify that downstream code does not already handle the edge case or condition you identified — e.g., via exception handlers, default values, or guard clauses. Confident-but-wrong answers often come from thorough-but-incomplete analysis.
```

変更規模: 1行への文言追加のみ。追加・変更行数 1、削除行数 0。

## 期待効果

- コールチェーンの末端処理を確認する際に、例外捕捉・デフォルト値・ガード節という具体的な構文パターンが想起されるようになり、見落としが減少する。
- compare / diagnose / explain いずれのモードでも、チェーン末端の処理確認が必要な場面で等しく効果が得られる。
- Step 5.5 や Compare checklist の構造は無変更であり、既存の正答ケースへの回帰リスクは極めて低い。
