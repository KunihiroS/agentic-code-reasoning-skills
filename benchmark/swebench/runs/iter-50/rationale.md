# Iteration 50 — 変更理由

## 前イテレーションの分析

- 前回スコア: 80%（16/20）
- 失敗ケース: 15368（EQUIV→NOT_EQ）、15382（EQUIV→UNK）、14787（NOT_EQ→EQUIV）、12663（NOT_EQ→UNK）
- 失敗原因の分析:
  - 14787: CONVERGENCE GATE（BL-4）が LOW confidence EQUIVALENT で探索を強制停止させ、真の差分を観測する前に判定を確定した
  - 12663: エージェントが changed function までは読んでいるが、assertion site までのコールパスが不明確なままターンが枯渇した
  - 15382: CONVERGENCE GATE による早期打ち切りで両変更の assertion 結果を確認できなかった可能性

## 改善仮説

`compare` モードの `because` 節にトレースエンドポイント「assertion または exception site まで」を明記し、CONVERGENCE GATE（BL-4）を除去することで、エージェントが変更関数のコードを読んだ時点で Claim を確定する「浅いトレース」を防ぎ、正確なテスト結果の導出が可能になる。

localize モードの `PHASE 2: CODE PATH TRACING` は「Build the call sequence: test → method1 → method2 → ...」として assertion まで追跡することを明示している。この構造を compare モードの `because` 節に適用した。

## 変更内容

1. **CONVERGENCE GATE を削除**: Step 3 末尾の 4 行ブロック（`CONVERGENCE GATE (required after each observation set):` から始まる部分）を除去。過剰な早期打ち切りを防ぐ。
2. **`ANALYSIS OF TEST BEHAVIOR` の Claim `because` 節を精緻化**: `because [trace through code — cite file:line]` → `because [trace through changed code to the assertion or exception — cite file:line]`（C[N].1、C[N].2 の 2 箇所）
3. **`COUNTEREXAMPLE` の `because` 節を精緻化**: `because [reason]` → `because [trace from changed code to the assertion or exception — cite file:line]`（2 箇所）
4. **Compare checklist に 1 行追加**: `Do not conclude NOT EQUIVALENT from a code difference alone — verify the difference reaches the test's assertion or exception by tracing the full call path`

## 期待効果

- 14787（NOT_EQ→EQUIV 誤）: CONVERGENCE GATE 除去により LOW confidence EQUIVALENT での早期停止が解消。`because` 節で assertion まで追跡すれば真の差分が観測できる。
- 12663（NOT_EQ→UNK 誤）: トレースエンドポイント明記により「何を確認すれば結論できるか」が明確になり、ターン枯渇前に assertion での差分を発見できる。
- 15382（EQUIV→UNK 誤）: CONVERGENCE GATE 除去により探索継続が可能になり、両変更で同一結果を確認できる。
- iter-35（85%、17/20）で同一の `because` 節エンドポイント明記変更が成功した実績があり、同等の効果を期待する。
- 全体予測: 16/20（80%）→ 17/20（85%）
