# Iteration 34 — Proposal

## カテゴリ: E (表現・フォーマットを改善する)

### カテゴリ E 内でのメカニズム選択理由

Objective.md の Exploration Framework カテゴリ E には以下の3つのメカニズムがある:
- 曖昧な指示をより具体的な言い回しに変える
- 冗長な部分を簡潔にして認知負荷を下げる
- 例示を追加または改善する

今回は「曖昧な指示をより具体的な言い回しに変える」を選択する。

理由: SKILL.md の Guardrail #4 は compare モードの核心的な判断ルールだが、
現行の文言は「if you find a semantic difference ... before concluding the
difference has no impact」という条件表現のみで、判断基準が曖昧である。
「何を根拠にして no impact と言ってよいのか」が示されていないため、
実際には差分が存在するにもかかわらず「影響なし」と早期結論する失敗パターンが
誘発されやすい。これを具体化することで、overall の推論品質を向上させる。

---

## 改善仮説

セマンティックな差分を発見した後の「影響なし」判断に明示的な追跡条件を
加えることで、不十分なトレースによる誤判定（特に NOT_EQUIVALENT を
EQUIVALENT と誤認するパターン）を抑制できる。

---

## 変更内容

対象行: SKILL.md Guardrail #4 (行 456)

### 変更前

```
4. **Do not dismiss subtle differences.** If you find a semantic difference between compared items, trace at least one relevant test through the differing code path before concluding the difference has no impact.
```

### 変更後

```
4. **Do not dismiss subtle differences.** If you find a semantic difference between compared items, trace at least one relevant test through the differing code path before concluding the difference has no impact. A "no impact" conclusion requires: (a) identifying a concrete test that exercises the differing path, and (b) confirming its assertion outcome is identical under both changes.
```

### 変更規模

変更行数: 1行（既存行への文言追加のみ）
追加文字数: 約170文字相当の文言追加
新規ステップ・新規フィールド・新規セクション: なし
削除行: 0行

宣言: **変更規模 = 1行 (hard limit 5行以内を満たす)**

---

## 期待効果

### 減少が期待される失敗パターン

overall ドメインの観点から:

1. **早期打ち切りによる誤 EQUIVALENT 判定の抑制**
   現行の Guardrail #4 は「少なくとも1つのテストをトレースせよ」とは
   言っているが、「何を確認すれば十分か」が曖昧であった。追加条件 (a)(b) により、
   「テストを一応読んだが assertion を確認せずに済ませる」という不完全なトレースが
   ガードレールの文言上で明確に禁止される。

2. **確認バイアスによる証拠の取捨選択の抑制**
   追加条件 (b) は「アサーションの結果が同一であることを確認する」ことを要求する。
   これにより、差分の存在を認識しながら都合の良い方向に証拠を解釈するパターンに
   対してより明確な反証義務が生じる。

3. **compare モードの「NO COUNTEREXAMPLE EXISTS」節との整合性向上**
   SKILL.md の compare テンプレートには「I searched for exactly that pattern」を
   求める節がすでに存在する。Guardrail #4 の具体化はこの節と同じ証拠基準を
   インライン的に要求するものであり、モード全体で一貫した推論品質が保たれる。

---

## failed-approaches.md 汎用原則との照合

| 原則 | 照合結果 |
|------|----------|
| 探索を「特定シグナルの捜索」へ寄せすぎない | 非抵触。本提案は探索の手順を固定せず、あくまで「no impact を主張する際の最低証拠基準」を明示するのみ。 |
| 探索の自由度を削りすぎない | 非抵触。読解順序や探索経路への制約は一切加えていない。 |
| 局所的な仮説更新を前提修正義務に直結させすぎない | 非抵触。本変更は仮説更新プロセスに関与せず、結論前の証拠要件を具体化するものである。 |
| 結論直前の自己監査に新しい必須のメタ判断を増やしすぎない | 要注意点として精査した。本提案は Step 5.5 の pre-conclusion self-check に新項目を加えるのではなく、既存の Guardrail #4 の文言を具体化するものである。新しいチェックポイントや判定ゲートは追加していない。(a)(b) は Guardrail の内容説明であり、既存の「trace at least one relevant test」の何を確認すべきかを補足するのみ。 |

**結論: failed-approaches.md の汎用原則すべてに対して非抵触。**

---

## 変更規模の宣言

- 変更対象: SKILL.md 行 456 (Guardrail #4)
- 変更種別: 既存行末への文言追加
- 変更行数: 1行
- 削除行数: 0行
- 合計カウント対象行数: 1行 ≤ 5行 (hard limit)
- 新規ステップ/フィールド/セクション: なし
