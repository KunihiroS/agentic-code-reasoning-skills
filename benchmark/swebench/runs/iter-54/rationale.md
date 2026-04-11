# Iteration 54 — 変更理由

## 前イテレーションの分析

- 前回スコア: 75% (15/20)
- 失敗ケース: 13821, 15382, 14787, 11433, 12663
- 失敗原因の分析: 13821 は EQUIV → NOT_EQ の誤判定（変更関数でコード差分を発見した後、caller が差分を吸収していることを確認しなかった）。15382, 14787, 12663 は 31 turns 到達による UNKNOWN。11433 は判定ミス。

## 改善仮説

Guardrail 5 の「downstream code」という用語が曖昧であるため、エージェントが「downstream = callee（呼び出し先）」と誤解し、「変更関数 → 呼び出し元 caller → テスト assertion」方向の確認を省略している可能性がある。`compare` モードにおける「downstream」の意味を caller 方向（テスト call path 上の caller）として明示することで、Guardrail 5 が意図した「不完全な推論チェーンを信用するな」という原則が正しく機能するようになる。

## 変更内容

Guardrail 5 の既存行に補足句を挿入した（新規行の追加なし）。

変更箇所: `verify that downstream code does not already handle the edge case or condition you identified` の直後に `— in \`compare\` mode, callers on the test call path are downstream, not just callees.` を追加。

## 期待効果

- **13821（EQUIV 誤判定）**: caller が差分を吸収しているかを確認する動機が強化され、EQUIVALENT への正答改善が期待できる。
- **15382, 14787, 12663（UNKNOWN）**: 直接的な作用は限定的だが、caller 方向の探索を促進することで間接的に改善の余地がある。
- **NOT_EQ 正答率**: 真の NOT_EQ では caller が差分を伝播させるため、caller 確認により NOT_EQ の根拠が強化されるだけで判定は変わらない。悪化要因なし。
