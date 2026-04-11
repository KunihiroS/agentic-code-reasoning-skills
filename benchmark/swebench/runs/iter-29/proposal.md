# Iteration 29 — 改善案（修正版）

## 前イテレーションの分析

- iter-28 scores.json の実測値: 75%（15/20）
- 失敗ケース（iter-28）:
  - EQUIV 誤判定（3件）: django__django-15368, 13821, 15382 — AI が NOT_EQUIVALENT と誤答
  - NOT_EQ 判定不能（2件）: django__django-14787, 14122 — AI が UNKNOWN と回答

### iter-28 変更の副作用

iter-28 では COUNTEREXAMPLE ブロックに `By P[N]` フィールドを追加した。
これは COUNTEREXAMPLE（NOT_EQUIVALENT を主張する場合）にのみ作用し、
EQUIVALENT 方向には実効的変化がない。結果として BL-2（NOT_EQ の立証ハードル引き上げ）と
同一の効果が生じ、14787・14122 が UNKNOWN に回帰したと考えられる。
これは共通原則 #1（判定の非対称操作）および #6（既存制約との差分で評価せよ）の典型的な
違反パターンである。

---

## 本イテレーションの方針

監査コメントに従い、**1イテレーション1仮説**の原則を遵守する。

- **本イテレーション（iter-29）**: iter-28 の非対称制約の回帰修正のみ（変更 1 のみ）
- **次イテレーション（iter-30）以降**: 新規改善仮説（カテゴリ F 等）を独立して提案

---

## 選択した Exploration Framework カテゴリ

**回帰修正（Regression Fix）— iter-28 の非対称操作の除去**

本イテレーションは新規改善仮説ではなく、前イテレーションで導入した BL パターン違反の除去である。
カテゴリ分類は適用しない（ただし次イテレーションでカテゴリ F を検討する）。

---

## 改善仮説

**仮説**: iter-28 で COUNTEREXAMPLE ブロックに追加した `By P[N]` フィールドは、
NOT_EQ 結論時にのみ追加の立証を要求する非対称な制約であり、
14787・14122 の UNKNOWN 回帰の直接原因である。
このフィールドを削除することで、NOT_EQ の立証ハードルを iter-27 以前の水準に戻し、
UNKNOWN 回帰を解消できる。

---

## SKILL.md のどこをどう変えるか

### 変更 1: COUNTEREXAMPLE から `By P[N]` を削除（iter-28 の完全リバート）

**箇所**: `## Compare` セクション → Certificate template → `COUNTEREXAMPLE` ブロック

**変更前**（iter-28 状態）:
```
COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
  Test [name] will [PASS/FAIL] with Change A because [trace — cite file:line]
  Test [name] will [FAIL/PASS] with Change B because [trace — cite file:line]
  By P[N]: this test checks [assertion/behavior stated in P3 or P4], and the
           divergence above causes that assertion to produce a different result.
  Therefore changes produce DIFFERENT test outcomes.
```

**変更後**:
```
COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
  Test [name] will [PASS/FAIL] with Change A because [trace — cite file:line]
  Test [name] will [FAIL/PASS] with Change B because [trace — cite file:line]
  Therefore changes produce DIFFERENT test outcomes.
```

**理由**:
- `By P[N]` は COUNTEREXAMPLE（NOT_EQ 結論）にのみ作用し、EQUIV 方向には実効的変化がない
- 既存制約との差分で見ると、NOT_EQ 側にのみ追加の立証要求が生じており、共通原則 #1（非対称操作禁止）に違反
- 共通原則 #6（既存制約との差分で評価せよ）が示す通り、対称的に見える追加であっても差分が一方向のみに作用する典型例
- 14787・14122 の UNKNOWN 回帰はこの非対称性による立証ハードル引き上げが原因と判断

---

## 変更規模

- 変更 1: -3 行（`By P[N]` 行と前後の整形を含む削除）
- 合計: -3 行（20 行以内の目安に適合）

---

## EQUIV と NOT_EQ の正答率への予測

### NOT_EQ 正答率

- iter-28 で `By P[N]` により生じた 14787・14122 の UNKNOWN 回帰が解消する
- NOT_EQ の立証ハードルが iter-27 以前の水準に戻る
- 予測: **100% に復帰**（iter-27 水準）

### EQUIV 正答率

- 変更 1 は EQUIV 方向には実効的変化がない（COUNTEREXAMPLE ブロックは NOT_EQ 結論時のみ使用）
- 持続的 EQUIV 偽陽性 3 件（15368, 13821, 15382）は本変更の対象外
- 予測: **変化なし（70% = 7/10 のまま）**

### 総合予測

- 現行 75%（15/20）→ **85%（17/20）**（iter-27 以前の水準への回帰）

---

## failed-approaches.md ブラックリストおよび共通原則との照合

| チェック項目 | 判定 | 根拠 |
|---|---|---|
| BL-1（ABSENT 定義）| 非該当 | テストを比較対象から除外する定義は変更しない |
| BL-2（NOT_EQ 証拠閾値引き上げ）| **本変更がこれを修正** | `By P[N]` 削除で iter-28 の BL-2 相当パターンを解消 |
| BL-4（早期打ち切り）| 非該当 | 探索量に影響しない |
| BL-5（P3/P4 形式強化）| 非該当 | PREMISES の形式は変更しない |
| BL-7（中間ラベル生成）| 非該当 | 中間ラベルを生成させる要素を追加しない |
| BL-8（受動的記録フィールド）| 非該当 | 記録フィールドを追加しない（むしろ削除） |
| BL-9（メタ認知自己チェック）| 非該当 | 自己評価を追加しない |
| BL-10（Reachability ゲート）| 非該当 | 条件分岐ゲートを追加しない |
| BL-12（探索順序固定）| 非該当 | 探索順序を変更しない |
| BL-13（Key value データフロー）| 非該当 | 代理変数記録フィールドを追加しない |
| BL-14（Backward Trace）| 非該当 | 非対称な追加検証要求を追加しない |

### 共通原則との照合

1. **原則 #1（非対称操作禁止）**: iter-28 が追加した非対称な `By P[N]` を削除する → **修正** ✓
2. **原則 #2（出力制約禁止）**: 出力の制約を変更しない → **適合** ✓
3. **原則 #3（探索量削減禁止）**: 削除する行は記録要求の追加であり、削除しても探索量は削減しない → **適合** ✓
4. **原則 #6（既存制約との差分で評価）**: 差分は NOT_EQ 側の立証ハードル緩和のみ。EQUIV には無影響 → **既存の非対称性を解消** ✓

---

## 次イテレーション（iter-30）への予告

本イテレーションで回帰修正が完了した後、iter-30 では監査コメントが示すカテゴリ F の方向性で
以下の新規仮説を独立提案する予定：

> changed function でコード差異を発見したら、記録で止まらず、**最初の下流観測点**
> （return value / raised exception / mutated state / test oracle input）まで
> trace を継続し、A/B が再収束するかを確認する手続きルールを追加する。

これは記録欄の追加（BL-8/BL-13 系）ではなく、**検証行動そのものを延長する**ことで
EQUIV 偽陽性の根本原因（「差異発見で止まる → NOT_EQ へ飛ぶ」推論ジャンプ）に対処する。
