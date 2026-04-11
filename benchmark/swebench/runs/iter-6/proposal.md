# Iter-6 改善提案

## Exploration Framework カテゴリ: A（強制指定）

カテゴリ A の定義（Objective.md より）:
> A. 推論の順序・構造を変える
> - ステップの実行順序を入れ替える
> - 並列に行っていた分析を直列にする（またはその逆）
> - 結論から逆算して必要な証拠を特定する（逆方向推論）

### 今回選択したカテゴリ A 内のメカニズム: 逆方向推論（backward reasoning）の先行適用

compare モードの STRUCTURAL TRIAGE（S1/S2/S3）は現在「ファイル差分の構造的なギャップを先に見つけること」を目的としている。
しかし ANALYSIS section（テストごとのトレース）は「各テストが PASS か FAIL か」を前向きに積み上げる。

カテゴリ A の「逆方向推論」とは、FORMAL CONCLUSION で求める結論（EQUIVALENT か NOT EQUIVALENT か）を
先に仮置きしたうえで、その仮説に必要な証拠を特定してから ANALYSIS を走らせる構造に変えることである。

現在の SKILL.md は "Complete each section in order" を義務付けており、
Step 1 → Step 2 → Step 3 → ... → Step 6 の前向きトレースを強制する。
これにより、テストを全トレースし終わるまで「どちらの結論が成立しやすいか」の観点が生まれない。

逆方向推論を部分的に先行させることで、
ANALYSIS 前に「EQUIVALENT が成立するためにはどの証拠が不足しているか」を宣言させると、
トレース中の注意が等価性の判断に直接関係する差異に集中し、
等価と誤判定する（EQUIV 方向の誤り）を減らすことが期待できる。

---

## 改善仮説（1つ）

compare モードのトレース開始前に「EQUIVALENT が成立するための必要条件リスト」を
明示的に宣言させることで、前向きトレースが等価性の反証に直結し、
証拠不足のまま EQUIVALENT と結論する誤りが減る。

---

## SKILL.md への具体的変更

### 変更箇所

STRUCTURAL TRIAGE の S3 の直後（S3 の行）に 1 行追加する。
すでに存在する行への文言追加のみ（新規ステップ追加ではなく、S3 行の精緻化）。

### 変更前

```
  S3: Scale assessment — if either patch exceeds ~200 lines of diff,
      prioritize structural differences (S1, S2) and high-level semantic
      comparison over exhaustive line-by-line tracing. Exhaustive tracing
      is infeasible for large patches and produces unreliable conclusions.
```

### 変更後

```
  S3: Scale assessment — if either patch exceeds ~200 lines of diff,
      prioritize structural differences (S1, S2) and high-level semantic
      comparison over exhaustive line-by-line tracing. Exhaustive tracing
      is infeasible for large patches and produces unreliable conclusions.
  S4: Equivalence preconditions — before ANALYSIS, state what behavioral
      properties both changes must share for EQUIVALENT to hold. Use this
      list to focus tracing on the properties most likely to diverge.
```

### 変更規模の宣言

追加行数: 3 行（S4 ラベル行 + 2 行の説明）
削除行数: 0 行
合計変更行数: 3 行（hard limit 5 行以内 — 適合）

---

## 一般的な推論品質への期待効果

### 減少が期待される失敗パターン

1. **等価性の誤判定（EQUIV → 実は NOT EQUIV）**
   現在の前向きトレースは「両方 PASS ならば同じ」という確認作業になりがちで、
   差異がないことを証明する観点が COUNTEREXAMPLE CHECK（Step 5）まで生まれない。
   S4 により、「何が同じであれば等価か」を ANALYSIS 前に宣言することで、
   各テストのトレース中に等価性条件との照合が自然に発生する。

2. **Guardrail #4「微妙な差異の無視」の早期検出**
   SKILL.md Guardrail #4:
   > Do not dismiss subtle differences. If you find a semantic difference
   > between compared items, trace at least one relevant test through the
   > differing code path before concluding the difference has no impact.

   S4 で等価性前提条件を先に列挙することで、差異を発見したときに
   「その差異は S4 で宣言した等価性条件を破るか」という逆方向チェックが
   ANALYSIS 中に行われる。これにより Guardrail #4 の遵守が構造的に促進される。

3. **全体的な overall 品質向上**
   S4 は STRUCTURAL TRIAGE（S1/S2/S3）と ANALYSIS の橋渡しとして機能し、
   構造的ギャップが見つからなかった場合でも「何をトレースすべきか」の
   方向性を与えるため、セマンティックに深いトレースが選択的に行われる。

---

## failed-approaches.md との照合結果

failed-approaches.md の現在の内容:
> 本ファイルは過去のイテレーションで試した改善案の失敗から抽出された汎用的な原則のみを記載する。
> （ベンチマーク刷新に伴いリセット。）

汎用失敗原則は現時点でゼロ（リセット後）。
抵触する原則なし。

---

## 研究コア構造の維持確認

| コア要素 | 今回の変更による影響 |
|----------|----------------------|
| 番号付き前提 (Step 2) | 変更なし |
| 仮説駆動探索 (Step 3) | 変更なし |
| 手続き間トレース (Step 4) | 変更なし（トレース対象の選択指針が追加されるのみ） |
| 必須反証 (Step 5) | 変更なし（S4 は Step 5 前の ANALYSIS 入口に位置する） |
| ステップ順序 | Step 1-6 の順序は維持。S4 は STRUCTURAL TRIAGE 内の補足であり独立ステップではない |

---

## 変更規模の最終確認

- 追加: 3 行
- 削除: 0 行
- Hard limit (5 行): 適合
- 新規ステップ追加: なし（STRUCTURAL TRIAGE の S3 に続く S4 は同セクション内の項目追加であり、
  Core Method の番号付きステップ Step 1〜6 への追加ではない）
- 新規セクション追加: なし
- 新規フィールド追加: なし（S4 は既存の STRUCTURAL TRIAGE ブロック内への項目追加）
