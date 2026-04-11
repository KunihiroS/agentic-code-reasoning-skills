# Iteration 51 — 変更理由

## 前イテレーションの分析

- 前回スコア: 75% (15/20)（親: iter-39）
- 失敗ケース: EQUIV 偽陽性 1件、NOT_EQ 偽陰性 1件、UNKNOWN 3件
- 失敗原因の分析: Guardrail 5 が「不完全な推論チェーン」を一方向（caller が差分を吸収するか確認）にのみ実装しており、反対方向（チェーンが変更関数の境界で止まりテスト観測点に到達しているか）のチェックが欠如していた。これにより 13821 型（EQUIV→NOT_EQ 誤判定）と 11433 型（NOT_EQ→EQUIV 誤判定）の両タイプの誤判定が継続した。

## 改善仮説

Guardrail 5 を双方向化することで、「callers が差分を吸収するか」と「チェーンがテスト観測点まで到達しているか」の両方向チェックを対称的に義務付け、両タイプの誤判定を同時に改善できる。

## 変更内容

SKILL.md の Guardrail 5（`## Guardrails` → `### From the paper's error analysis`）の既存 1 行を文言精緻化した。旧表現の `downstream code does not already handle the edge case` を `callers do not already normalize or absorb the identified difference before the test observes it` に明確化し、さらに `and that the chain connects the change to a test-observable outcome — not just to the changed function's boundary` を同一文に追加することで双方向チェックを実装した。追加行数: 0（既存行の文言精緻化のみ）。

## 期待効果

- NOT_EQ 偽陰性（11433 型）: `chain connects the change to a test-observable outcome` チェックが、変更の差分を発見しながらテスト assertion への伝播確認を省いて EQUIV と誤判定するケースを防止する。
- EQUIV 偽陰性（13821 型）: `callers do not already normalize or absorb` という具体的語彙が、iter-39 の Compare checklist 追加と相乗的に働き、caller が差分を吸収するにもかかわらず NOT_EQ と誤判定するケースを抑制する。
- UNKNOWN 率: Guardrail の確認義務は per-Claim の citation 要求ではないため、BL-25 型のターン枯渇リスクを増大させない。
