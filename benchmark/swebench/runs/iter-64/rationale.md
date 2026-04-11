# Iteration 64 — 変更理由

## 前イテレーションの分析

- 前回スコア: 85% (17/20)
- 失敗ケース: django__django-15368, django__django-13821, django__django-11433
- 失敗原因の分析: 15368, 13821 は EQUIV 偽陽性（EQUIVALENT が正解なのに NOT_EQUIVALENT と誤判定）。11433 は NOT_EQUIVALENT の収束失敗（31 ターン消費、UNKNOWN で終了）。

## 改善仮説

Compare チェックリストの「テストをトレースせよ」という項目に、D2(a)（fail-to-pass）テストを D2(b)（pass-to-pass）テストより先に分析するという優先順位指示を追加することで、エージェントが最も診断力の高いテストから分析を始め、NOT_EQ の場合は counterexample を早期に発見でき、EQUIV の場合は同一結果を早期に確立できる。これにより NOT_EQ の収束失敗（UNKNOWN）を抑制しつつ、EQUIV の正答率を維持する。

## 変更内容

Compare checklist の 4 番目の項目を精緻化。`Trace each test through both changes separately before comparing` を `Trace fail-to-pass tests (D2a) through both changes first, then pass-to-pass tests (D2b); trace each through both changes separately before comparing` に変更（1 行修正、追加・削除なし）。

## 期待効果

- 11433（UNKNOWN, 31 ターン）: fail-to-pass テストから先に分析することで counterexample を早期に発見し、収束失敗を抑制する。
- 15368, 13821（EQUIV 偽陽性）: fail-to-pass テストで SAME 結果を早期に確立できれば NOT_EQ への誤誘導を防ぐ可能性がある。
- 既存の正答ケース: 分析順序の変更のみで "separately before comparing" 要件を維持するため、回帰リスクは極めて低い。
- 全体予測: 85%（17/20）→ 85〜90%（17-18/20）
