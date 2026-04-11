# Iteration 53 — 改善案提案

## 親イテレーション (iter-35) の選定理由

iter-35 はスコア 85%（17/20）を達成し、多数の子イテレーション（iter-36〜52）の中でも最高スコアを維持している安定した基盤である。直接の子 iter-49（BL-24）以外に、iter-35 を親として試した候補が極めて少なく、探索余地が残っている。

## 選択した Exploration Framework カテゴリ

**カテゴリ A：推論の順序・構造を変える**（逆方向推論）

選択理由：
- カテゴリ B〜E は iter-35 以前・以降の多くのイテレーションで試行済みであり、ブラックリスト BL-2〜25 に対応するものが多い。
- カテゴリ F（原論文の未活用アイデア）の候補は、Guardrails の対称化（BL-6）や Relevant 列追加（BL-8）など既に試行済みの形で結果が出ている。
- カテゴリ A の「逆方向推論」は BL-14（チェックリストへの逆方向推論追加）として試行されたが、失敗原因は「アドバイザリ形式での非対称な指示追加」であった。今回は **証明書テンプレート内の必須フィールド（非アドバイザリ）への対称な適用** という異なるメカニズムで実施し、BL-14 の失敗原因を回避できる。

## 改善仮説（1つ）

**iter-35 時点の EQUIV 偽陰性（15368, 13821）の根本原因は、ANALYSIS OF TEST BEHAVIOR の Claim 記述が「変更コードを起点に前向きにトレース」する構造になっており、エージェントが変更関数でコード差分を発見した時点で「この差分が assertion に到達する」と即断し、assertion まで実際に追跡せずに Comparison: DIFFERENT と結論する点にある。`because` 節の起点を「assertion から変更箇所へ逆向きにトレース」に切り替えることで、エージェントは常に「このテストが最終的にチェックする値」を出発点に推論するようになり、コード差分が assertion の出力値に影響しないケース（EQUIV）で正しく SAME を記録できるようになる。**

## SKILL.md のどこをどう変えるか

### 変更対象

Compare モードの証明書テンプレート内、`ANALYSIS OF TEST BEHAVIOR` の Claim C[N].1 / C[N].2 の `because` 節（2 行、テキスト置換のみ）。

### 現在の記述

```
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace through changed code to the assertion or exception — cite file:line]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace through changed code to the assertion or exception — cite file:line]
```

### 変更後の記述

```
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace from the assertion or exception back through the call chain to show how Change A produces this outcome — cite file:line at each step]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace from the assertion or exception back through the call chain to show how Change B produces this outcome — cite file:line at each step]
```

### 変更の意図

- **起点の変更**：「trace through changed code」（変更コード起点・前向き）→「trace from the assertion or exception back」（assertion 起点・逆向き）  
  → エージェントが最初に問うべき問い「このテストは何を観測しているか」から推論を始めることを強制する。  
- **構造は同一**：どちらの change でも同じフォーマットを使う（対称）。新規フィールド・新規セクション・新規テンプレート要素の追加なし。

## EQUIV と NOT_EQ の両方の正答率への影響予測

### EQUIV（現状 80% = 8/10）

予測: **改善（＋1〜2）**。  
- 現在の失敗パターン（15368, 13821）：変更コード読取 → 差分発見 → assertion に到達せず「DIFFERENT」即断  
- 変更後の期待動作：assertion から逆向きにトレース → 変更コードが assertion の値に影響しない経路（wrapper による正規化など）を発見 → 「Change A も Change B も同じ assertion 値を出力する」と記録 → SAME  
- 逆方向起点は premises P3（test が何を assert するか）と自然に整合し、P3 を正しく活用した推論を促す。

### NOT_EQ（現状 90% = 9/10）

予測: **維持〜微改善**。  
- 真の NOT_EQ ケースでは、assertion から逆向きにトレースしても Change A/B の違いが assertion 値に直結することを確認でき、結論は変わらない。  
- 11433（UNKNOWN）：assertion から逆向きに始めることで「このテストが何を観測するか」が明確になり、その観測次元での Change A/B の違いを直接確認できるため、収束が早まる可能性がある。

### 回帰リスク

既存の正答ケース（EQUIV 8件・NOT_EQ 9件）への影響は最小限。なぜなら：
- 変更は「因果の向き」のみで、「何を読むか」「何を記録するか」は変えない。
- assertion → call chain → changed code というパスが forward の changed code → call chain → assertion と同じ情報量を要求し、探索量は削減されない（原則 #3 準拠）。

## failed-approaches.md のブラックリストおよび共通原則との照合

### ブラックリスト照合

| BL | 内容 | 本提案との比較 |
|----|------|----------------|
| BL-14 | チェックリストへの逆方向推論追加 | **異なる**: BL-14 はアドバイザリ（チェックリスト）かつ非対称。本提案は証明書テンプレート（必須）かつ対称（C[N].1/C[N].2 両方に同じ適用） |
| BL-6  | Guardrail 4 の「対称化」 | **異なる**: BL-6 は既存の片方向制約を両方向に拡張し、差分が NOT_EQ 方向にのみ作用した。本提案は既存の「trace to assertion」という義務の起点と方向を変えるもので、NEW CONSTRAINT の追加ではない |
| BL-25 | `because` 節へのエンドポイント明記 | **異なる**: BL-25 は CONVERGENCE GATE 削除との複合変更で失敗。本提案は `because` 節の起点変更のみ（iter-35 が同様の因果で `because` 節を安全に変更済み）|
| BL-2  | NOT_EQ の証拠閾値・厳格化 | **該当しない**: 本提案は NOT_EQ の証拠要件を上げず、trace の方向を変えるのみ |

### 共通原則との照合

| # | 原則 | 照合 |
|---|------|------|
| 1 | 判定の非対称操作は必ず失敗する | ✓ C[N].1 と C[N].2 の両方に同一の `because` 形式を適用。対称 |
| 2 | 出力側の制約は効果がない | ✓ 入力側（推論の起点）を変える変更 |
| 3 | 探索量の削減は常に有害 | ✓ 探索量は維持（assertion から call chain を逆向きに読む = 同じ情報量） |
| 5 | 入力テンプレートの過剰規定は探索視野を狭める | ✓ 「何を記録するか」は変えず、「どこから始めるか」だけを変える |
| 6 | 対称化は既存制約との差分で評価せよ | ✓ 差分は C[N].1 と C[N].2 の両方に等しく作用する対称な変更 |
| 8 | 受動的な記録フィールドの追加は能動的な検証を誘発しない | ✓ 新規フィールド追加なし。既存 `because` 節の意味論変更のみ |
| 9 | メタ認知的自己チェックは機能しない | ✓ 自己チェック項目の追加なし |
| 14 | 条件付き特例探索は主比較ループを強化しなければ下がる | ✓ 主比較ループ（C[N].1/C[N].2 の `because` 節）を直接変更 |

## 変更規模の宣言

- **追加行数**: 0（既存 2 行のテキスト置換のみ。新規行追加なし）
- **削除行数**: 0（行削除なし。within-line テキスト置換）
- **変更行数**: 2（C[N].1 と C[N].2 の `because` 節）
- **新規ステップ・セクション・フィールド**: なし
- **hard limit（5行以内）**: ✓ 達成（追加 0 行）
