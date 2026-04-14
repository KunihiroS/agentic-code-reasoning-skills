# Iteration 14 — Improvement Proposal

## Exploration Framework カテゴリ: C (強制指定)

カテゴリ C「比較の枠組みを変える」のうち、今回選択する具体的メカニズムは:

> **変更のカテゴリ分類（リファクタリング/バグ修正/機能追加）を先に行う**

### このメカニズムを選んだ理由

現行 SKILL.md の STRUCTURAL TRIAGE は S1（修正ファイル差分）・S2（カバレッジ完全性）・
S3（規模評価）の 3 軸を持つが、「この変更はどういう種類の変更か」という
セマンティック・カテゴリの宣言がない。その結果、エージェントは変更の性質を
暗黙のうちに判断しながらトレースを進めることになり、

- リファクタリング的な変更（同じ結果を異なる経路で達成する）を追うときに
  「経路が違う＝異なる振る舞い」という表層的な差異に引きずられて
  NOT_EQUIVALENT と誤判定するリスク（EQUIV 方向の失敗）、
- 微妙なバグ修正（実質的な振る舞い変化）を追うときに
  「構造は似ている」という印象から EQUIVALENT と誤判定するリスク
  （NOT_EQ 方向の失敗）

の両方が生じうる。変更カテゴリを S2 完了直後に明示宣言させることで、
その後の ANALYSIS の焦点と必要な証拠の種類が絞られ、
不要な方向への推論ドリフトを構造的に抑制できる。

カテゴリ C の他の 2 つのメカニズム（テスト単位→関数/モジュール単位比較、
差異の重要度の段階的評価）は、それぞれ別途検討できる独立したメカニズムであり、
今回は「変更分類を先行させる」という単一仮説のみに絞る。

---

## 改善仮説

**比較対象の変更を ANALYSIS 前に変更カテゴリ（リファクタリング・バグ修正・
機能追加）として分類させることで、その分類がその後の証拠探索と
等価性判断の基準を適切に絞り込み、表層的な経路差異への過剰反応と
実質的な意味差への過小反応の両方を減らせる。**

---

## SKILL.md の変更内容

### 変更箇所

STRUCTURAL TRIAGE ブロック内の S2 行（現行）:

```
  S2: Completeness — does each change cover all the modules that the
      failing tests exercise? If Change B omits a file that Change A
      modifies and a test imports that file, the changes are NOT EQUIVALENT
      regardless of the detailed semantics.
```

### 変更後

```
  S2: Completeness — does each change cover all the modules that the
      failing tests exercise? If Change B omits a file that Change A
      modifies and a test imports that file, the changes are NOT EQUIVALENT
      regardless of the detailed semantics. Also classify the change type:
      REFACTOR (same outcome, different path), BUG-FIX (corrects wrong
      behavior), or FEATURE (new behavior). Use this classification to
      calibrate the depth of semantic tracing required in ANALYSIS.
```

### diff（追加行のみ、削除行なし）

```diff
-      regardless of the detailed semantics.
+      regardless of the detailed semantics. Also classify the change type:
+      REFACTOR (same outcome, different path), BUG-FIX (corrects wrong
+      behavior), or FEATURE (new behavior). Use this classification to
+      calibrate the depth of semantic tracing required in ANALYSIS.
```

### 変更規模の宣言

追加行: 3 行（hard limit 5 行以内 — 適合）
削除行: 1 行（制限にカウントしない）
新規ステップ・新規フィールド・新規セクション: なし

---

## 一般的な推論品質への期待効果

### 減少が期待される失敗パターン

1. **EQUIV 方向の誤判定（偽陰性）**
   変更が REFACTOR に分類されたとき、エージェントは「経路の違いはあっても
   出力が同じであることを確認すればよい」という焦点を持てる。
   これにより、実装経路の表層的差異に反応して NOT_EQUIVALENT と誤判定する
   リスクが下がる。

2. **NOT_EQ 方向の誤判定（偽陽性）**
   変更が BUG-FIX に分類されたとき、エージェントは「どこかで振る舞いが
   変わっているはず」という適切な疑いを持ち、ANALYSIS での証拠探索を
   より入念に行える。

3. **推論ドリフトの抑制**
   S2 での分類宣言は、エージェントが ANALYSIS に入る前に自分の仮説を
   明示的にコミットさせるため、Guardrail #4「微妙な差異を見逃すな」と
   補完的に機能し、ANALYSIS 中の焦点の散漫を防ぐ。

### 維持されるもの

- COUNTEREXAMPLE / NO COUNTEREXAMPLE の反証義務は変わらない。
- Step 3 の仮説駆動探索、Step 4 の手続き間トレース表は変わらない。
- 番号付き前提・必須反証というコア構造は変わらない。

---

## failed-approaches.md の汎用原則との照合

| 原則 | 照合結果 |
|------|----------|
| 探索を「特定シグナルの捜索」へ寄せすぎる変更は避ける | 本提案は「どのシグナルを探すか」を固定しない。BUG-FIX/REFACTOR/FEATURE という分類は探索範囲を強制的に絞るのではなく、**探索の焦点の深度を調整する手がかり** として機能する。探索の自由度は維持されている。 |
| ドリフト抑制のための局所的な具体化が探索の幅を狭める | 変更カテゴリの宣言は S2 の出力であり、ANALYSIS に入る前のメタ情報にとどまる。ANALYSIS 内の具体的な探索手順は変えない。狭めるのは「必要な証拠の深さの判断基準」のみであり、「探索対象ファイルや関数の列挙」は絞らない。 |
| 結論直前の自己監査に新しい必須メタ判断を増やしすぎない | 本提案は結論直前（Step 5.5）ではなく、STRUCTURAL TRIAGE（探索前半）に分類を置く。役割が重複する既存チェックはなく、最終判断の萎縮リスクはない。 |

3 原則すべてに抵触なし。

---

## 変更規模の宣言（再確認）

- 変更対象: SKILL.md の STRUCTURAL TRIAGE ブロック S2 の末尾
- 追加行数: 3
- 削除行数: 1（ピリオドで終わっていた行を分割統合）
- 新規セクション/ステップ/フィールド: なし
- hard limit (5 行) との対比: 3 ≤ 5 → **適合**
