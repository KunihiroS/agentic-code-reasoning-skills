# Iteration 40 — 変更理由

## 前イテレーションの分析

- 前回スコア: 75%（15/20）
- 失敗ケース: 13821、15382、14787、11433、12663
- 失敗原因の分析:
  - 13821（EQUIV → NOT_EQ, 9ターン）: 早期誤結論。edge case の確認が Claim の外にある別欄（EDGE CASES）に後回しにされ、Comparison を書いた後に戻らなかった可能性がある。
  - 15382（EQUIV → UNKNOWN, 31ターン）: ターン上限到達。EDGE CASES 別欄の処理が余分なターンを消費した。
  - 14787（NOT_EQ → UNKNOWN, 31ターン）: 同上。
  - 11433（NOT_EQ → EQUIV, 26ターン）: caller 伝播の確認漏れ。本イテレーションの直接的な変更対象ではない。
  - 12663（NOT_EQ → UNKNOWN, 31ターン）: ターン上限到達。EDGE CASES 別欄の処理が余分なターンを消費した。

## 改善仮説

`EDGE CASES RELEVANT TO EXISTING TESTS` が持つ「ACTUAL tests が踏む edge case を再確認する」という anti-skip 義務を、Claim C[N].1 / C[N].2 の `because` 節に統合することで、

1. **anti-skip 機能は維持**される（義務は消えず Claim 内で生きる）
2. **別欄としての EDGE CASES を削除**でき、ターン予算を節約できる
3. **Claim が証拠として完結**するため、エージェントはトレース中に edge case を処理する（後処理に先送りしない）

この統合により、3件の UNKNOWN（15382、14787、12663）のターン枯渇を軽減しつつ、検証密度を落とさない。

論文（Ugare & Chandra, arXiv:2603.01896）の設計思想では、certificate の各 Claim は**その証拠を完全に封じ込める**ことで anti-skip を実現する。現在の EDGE CASES セクションは Claim の**外側**にある後処理的な欄であり、Claim 内で完結するという本来の設計から逸脱していた。

## 変更内容

- **修正**: Claim C[N].1 と C[N].2 の `because` 節に `; cover all branches this test actually exercises, not just the happy path` を追加（fail-to-pass ブロックおよび pass-to-pass ブロックの両方）
- **削除**: `EDGE CASES RELEVANT TO EXISTING TESTS:` 以下7行を削除

## 期待効果

| ケース | 現状 | 本変更の作用 | 予測 |
|--------|------|-------------|------|
| 13821 | EQUIV → NOT_EQ（9ターン） | Claim に edge-case 義務があるため、DIFFERENT と書く前に「このテストが踏む分岐でも差が出るか」を確認する誘導が生まれる | 改善の可能性あり |
| 15382 | EQUIV → UNKNOWN（31ターン） | EDGE CASES 別欄削除でターン節約 | +1 見込み |
| 14787 | NOT_EQ → UNKNOWN（31ターン） | 同上 | +1 見込み |
| 11433 | NOT_EQ → EQUIV（26ターン） | 本変更の直接的作用は限定的 | 変化なし〜微改善 |
| 12663 | NOT_EQ → UNKNOWN（31ターン） | EDGE CASES 別欄削除でターン節約 | +1 見込み |

- **現状**: 15/20（75%）
- **期待**: 17〜18/20（85〜90%）
