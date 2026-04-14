# Iteration 26 — Proposal

## Exploration Framework Category: C (強制指定)

カテゴリ C「比較の枠組みを変える」の 3 つのメカニズムのうち、
今回は「変更のカテゴリ分類（リファクタリング/バグ修正/機能追加）を先に行う」を選択する。

### メカニズム選択理由

SKILL.md の compare モードはすでに STRUCTURAL TRIAGE (S1, S2, S3) という
「詳細トレース前の先行評価」構造を持つ。この構造は NOT EQUIVALENT の早期検出に
最適化されており、EQUIVALENT 方向の判断を支援するメカニズムが手薄である。

変更のカテゴリ（リファクタリング的か、バグ修正的か、機能追加的か）を
STRUCTURAL TRIAGE 段階で識別することで、2 つの変更が「同じ目的を別実装で達成して
いるかどうか」という観点を比較の出発点に据えられる。これは EQUIVALENT 判定を
強化する方向に直接作用し、かつ既存の構造（STRUCTURAL TRIAGE の S3 行）への
文言精緻化として実現できるため、新規ステップ追加なしで達成できる。

他の 2 メカニズム（テスト単位→関数単位への粒度変更、差異重要度の段階的評価）は
いずれも既存のテンプレート構造を大きく変形するか、新規フィールドの追加を要するため
今回の変更規模制約に適合しない。

---

## 改善仮説

STRUCTURAL TRIAGE の S3（スケール評価）に変更の意図カテゴリの識別を加えることで、
モデルが詳細トレース前に「この 2 変更はリファクタリング的に等価な別実装か、
それとも異なる機能的意図を持つか」という軸を先に定めるようになる。
これにより、EQUIVALENT 判定において過小評価されていた意図的同一性の証拠が
早期に考慮され、全体的な比較品質が向上すると予想する。

---

## SKILL.md への具体的な変更

### 変更箇所

compare モード、STRUCTURAL TRIAGE の S3 の文言を精緻化する。

### 変更前

```
  S3: Scale assessment — if either patch exceeds ~200 lines of diff,
      prioritize structural differences (S1, S2) and high-level semantic
      comparison over exhaustive line-by-line tracing. Exhaustive tracing
      is infeasible for large patches and produces unreliable conclusions.
```

### 変更後

```
  S3: Scale and intent assessment — if either patch exceeds ~200 lines of diff,
      prioritize structural differences (S1, S2) and high-level semantic
      comparison over exhaustive line-by-line tracing. Exhaustive tracing
      is infeasible for large patches and produces unreliable conclusions.
      Also identify the change category for each patch (refactoring /
      bug-fix / feature-addition): two patches that share the same category
      and target the same defect or abstraction boundary provide stronger
      prior evidence for EQUIVALENT before detailed tracing begins.
```

### 変更規模の宣言

- 削除行: 0
- 追加・変更行: 3（タイトル行の語追加 1 行 + 新文 2 行）
- 合計変更行数: 3 行（hard limit 5 行以内）

---

## 一般的な推論品質への期待効果

### 減少が期待されるカテゴリ的失敗パターン

1. **EQUIVALENT の見逃し（過剰な NOT EQUIVALENT 判定）**
   現状の STRUCTURAL TRIAGE は構造的ギャップ（ファイル不一致・完全性欠如）を
   優先的に検出するため、「別アプローチで同じ結果を達成するリファクタリング的変更」
   に対して NOT EQUIVALENT 方向のバイアスが生じやすい。
   変更カテゴリを先に識別することで、このバイアスを補正する先行仮説を提供できる。

2. **詳細トレース段階での見当違いの比較単位選択**
   変更カテゴリが不明なまま詳細トレースに入ると、比較すべき粒度（関数シグネチャか
   アルゴリズム出力か副作用か）を誤りやすい。カテゴリの先行識別はこの粒度選択を
   適切に誘導する。

3. **全体方向: overall（比較品質の向上）**
   EQUIVALENT と NOT EQUIVALENT の両ケースで、比較の「目的意識」が明確になるため、
   証拠収集の方向性が定まりやすくなる。とくに overall スコアを下げている
   「EQUIVALENT の取りこぼし」に対して直接的な改善効果を期待できる。

---

## failed-approaches.md の汎用原則との照合

| 原則 | 本提案との関係 | 判定 |
|------|----------------|------|
| 探索で探すべき証拠の種類をテンプレートで事前固定しすぎない | 変更カテゴリの識別は「先行仮説の強さ」を調整するものであり、読むべき証拠の種類を固定しない。詳細探索は引き続き自由 | 抵触なし |
| 探索の自由度を削りすぎない・読解順序の半固定を避ける | S3 は「詳細トレース前」の任意スケール評価ステップの精緻化であり、どのファイルをどの順で読むかを規定しない | 抵触なし |
| 局所的な仮説更新を前提修正義務に直結させすぎない | 変更カテゴリは探索開始前の一度だけの識別であり、探索中の仮説更新ループとは切り離されている | 抵触なし |
| 結論直前の自己監査に新しい必須のメタ判断を増やしすぎない | Step 5.5（Pre-conclusion self-check）への追加ではなく、STRUCTURAL TRIAGE（Step 2 相当の早期段階）への追加 | 抵触なし |

全原則に抵触しないことを確認した。

---

## 研究コアの踏襲確認

- 番号付き前提: 変更なし（PREMISES セクションは維持）
- 仮説駆動探索: 変更なし（Step 3 の HYPOTHESIS 構造は維持）
- 手続き間トレース: 変更なし（Step 4 の interprocedural trace table は維持）
- 必須反証: 変更なし（Step 5 の COUNTEREXAMPLE CHECK は維持）

S3 は STRUCTURAL TRIAGE 内の一ステップであり、コア構造の外側に位置する。
変更はコアを強化する方向であり、逸脱はない。
