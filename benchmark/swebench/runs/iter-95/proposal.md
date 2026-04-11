# Iteration 95 — 改善提案

## Exploration Framework カテゴリ

**カテゴリ E: 表現・フォーマットを改善する**（曖昧な指示をより具体的な言い回しに変える）

**選定理由**:
Guardrail #4 は「微妙な差異を無視するな」という原則として既に存在するが、
「トレースしてみよ」という指示が何を確認すれば完了かを規定していない。
「少なくとも1つの関連テストを通して差分コードパスをトレースせよ」という
既存指示は、エージェントにトレースの "終点" を指定していないため、
中間ノードで観察された挙動の変化をもって「影響なし」と打ち切りやすい。
Category E の「曖昧な指示をより具体的な言い回しに変える」に合致する。

---

## 改善仮説

**仮説**: Guardrail #4 の「差異をトレースせよ」という指示に、
「テストのアサーション境界での観測可能な効果（戻り値・例外・副作用）を特定せよ」
という終点条件を付加することで、中間ノードで止まる不完全なトレースを抑制し、
エンドツーエンドの因果連鎖の完結率が向上する。

この仮説は「状態や性質（final outcome, observable effect）で指示すべき」という
failed-approaches 原則 #22 の知見に直接対応する。

---

## SKILL.md への具体的な変更

### 変更対象

`## Guardrails` セクションの Guardrail #4（1 箇所）

### 変更前

```
4. **Do not dismiss subtle differences.** If you find a semantic difference between compared items, trace at least one relevant test through the differing code path before concluding the difference has no impact.
```

### 変更後（追記箇所を強調）

```
4. **Do not dismiss subtle differences.** If you find a semantic difference between compared items, trace at least one relevant test through the differing code path before concluding the difference has no impact. In this trace, identify what observable effect at the test assertion boundary (return value, exception, or side effect) would change if the difference propagated — only dismiss the difference if this effect is absorbed before reaching that boundary.
```

**追加文（1行）**:
> In this trace, identify what observable effect at the test assertion boundary (return value, exception, or side effect) would change if the difference propagated — only dismiss the difference if this effect is absorbed before reaching that boundary.

---

## 一般的な推論品質への期待効果

### 削減が期待される失敗パターン

1. **中間ノード打ち切り**: 差分が見つかった関数の内部挙動変化のみを観察し、
   その変化がテストのアサーションまで到達するかを確認しないまま
   「影響なし」と結論する誤判定パターン。

2. **不完全な因果連鎖による EQUIV 誤判定**: 差異が intermediate な状態変化に
   留まると仮定して、テスト観測点での実際の影響を追わずに EQUIVALENT と
   結論するケース（完全だが不完全な分析からの誤判定）。

3. **根拠の薄い NOT_EQUIVALENT 主張**: 「差異がある → テストに影響する」という
   推論ジャンプを、アサーション境界での観測可能な効果を明示せずに行うケース。

### EQUIV / NOT_EQ 両方向への影響

- **EQUIV 精度**: 追加条件が「吸収されていることの確認」を要求するため、
  不完全なトレースによる誤 EQUIV 主張を抑制。
- **NOT_EQ 精度**: 差異が observable effect として境界に届くことを
  明示させるため、裏付けのある NOT_EQ 判定の根拠が強化される。
- **非対称性の回避**: 両結論方向ともに同じ「アサーション境界での観測」を
  求めるため、立証責任の非対称化（失敗原則 #1）を生じない。

---

## failed-approaches.md 汎用原則との照合

| 原則番号 | 内容要旨 | 照合結果 |
|----------|----------|----------|
| #1 | 判定の非対称操作は必ず失敗する | ✅ 両方向に同一の観測義務を課すため非対称化しない |
| #2 | 出力側の制約は効果がない | ✅ 出力形式ではなく「何を確認するか」の入力・処理側変更 |
| #3 | 探索量の削減は常に有害 | ✅ 探索を削減しない。境界まで追跡することで探索を増やす方向 |
| #8 | 受動的な記録フィールド追加は検証を誘発しない | ✅ フィールド追加ではなく、既存 Guardrail の終点条件の明確化 |
| #9 | メタ認知的自己チェックは機能しない | ✅ 自己評価ではなく、コードをたどる能動的行動（tracing）を要求 |
| #15 | 固定長の局所追跡ルールは観測境界を近似できない | ✅ ホップ数でなく意味論的な境界（アサーション境界）で指定 |
| #17 | 中間ノードの局所的分析義務化はE2E追跡を阻害する | ✅ 中間ノードではなくエンドポイント（テスト境界）を対象とする |
| #18 | 特定証拠カテゴリへの物理的裏付け要求は探索予算を枯渇させる | ✅ file:line の引用義務化ではなく、observable effect の特定 |
| #22 | 具体物の例示は物理的探索目標として過剰適応される | ✅ 状態・性質（observable effect, assertion boundary）で指示 |
| #26 | 中間ステップでの過剰な物理的検証要求は予算枯渇を招く | ✅ 中間ではなく終点を指定。物理的引用より効果の性質を問う |

抵触する原則: **なし**

---

## 変更規模の宣言

- **追加行数**: 1 行（既存 Guardrail #4 末尾への文追記）
- **削除行数**: 0 行
- **合計変更**: 1 行（hard limit 5 行以内 ✅）
