# Iteration 59 — Proposal

## Exploration Framework カテゴリ: F

カテゴリ F「原論文の未活用アイデアを導入する」を選択する。

### カテゴリ内での具体的なメカニズム選択理由

原論文の三タスクのうち Code Question Answering (Appendix D) は、explain モードへと翻訳されており、その中核的な構造として SEMANTIC PROPERTIES セクションがある。このセクションは「変化しない意味的性質を個別に根拠付きで列挙する」という反証技法であり、不完全な推論チェーン（Guardrail #5）を防ぐ役割を持つ。

compare モードの ANALYSIS OF TEST BEHAVIOR は per-test の結果比較に特化しているが、「両変更が共通して変化させない振る舞いの根拠を明示する」という SEMANTIC PROPERTIES 相当の観点を持っていない。これは論文に存在し、explain モードには翻訳済みだが、compare モードには未適用のアイデアである。

特に EQUIVALENT 判定における典型的な失敗パターン——「差異を見つけたが影響なしと早計する」(Guardrail #4) および「下流のハンドリングを見落とす」(Guardrail #5)——は、共通不変な振る舞いの境界を明示させることで抑制できる。これは localize/diagnose の DIVERGENCE ANALYSIS が前提として「何が一致しているか」を先に固定する発想とも一致する。

---

## 改善仮説

compare モードの EDGE CASES セクションの冒頭に、両変更が同じ振る舞いを保持していると言える根拠を 1 件以上明示させる一文を追加することで、EQUIVALENT と判定する前に「不変な共通振る舞い」の確認を促し、下流ハンドリングの見落としと差異の早計な無視を抑制できる。

---

## SKILL.md の変更内容

### 変更箇所

compare モードの Certificate template 内、`EDGE CASES RELEVANT TO EXISTING TESTS:` の直前行。

### 変更前

```
EDGE CASES RELEVANT TO EXISTING TESTS:
(Only analyze edge cases that the ACTUAL tests exercise)
```

### 変更後

```
SHARED INVARIANTS (required if claiming EQUIVALENT):
  At least one: [behavior that is identical in both changes — cite file:line from each side]
EDGE CASES RELEVANT TO EXISTING TESTS:
(Only analyze edge cases that the ACTUAL tests exercise)
```

### 変更規模の宣言

追加行数: 2 行（hard limit 5 行以内、適合）
削除行数: 0 行

---

## 一般的な推論品質への期待効果

### 減少が期待される失敗パターン

1. **Guardrail #4 の早計な無視**: 差異を見つけたまま EQUIVALENT と判定するケースでは、まず共通不変な振る舞いの根拠を列挙する義務が生じることで、その差異が本当に影響しないことを間接的に確認する負荷が上がる。

2. **Guardrail #5 の不完全チェーン**: 「両変更が同じ振る舞いを保持している根拠」を file:line 付きで示す際に、トレースされていない下流コードの存在が顕在化しやすくなる。

3. **overall 判定の質向上**: EQUIVALENT 方向での過信が下がることで、EQUIV / NOT_EQ 双方向の判定精度が安定する。

---

## failed-approaches.md の汎用原則との照合

| 原則 | 本提案との関係 |
|------|---------------|
| 探索すべき証拠の種類をテンプレートで事前固定しすぎない | SHARED INVARIANTS は「何を探すか」ではなく「何を示すか」の最低要件のみ規定。探索経路は自由。適合 |
| 探索の自由度を削りすぎない | 新フィールドは compare の ANALYSIS 後に位置し、探索の最中ではなく整理段階の記録。適合 |
| 局所的な仮説更新を前提修正義務に直結させすぎない | 前提の再点検は要求しておらず、発見した共通根拠の記録のみ。適合 |
| 既存のガードレールを特定の追跡方向で具体化しすぎない | Guardrail #4/#5 を特定方向に強制する記述ではなく、EQUIVALENT 主張時の根拠明示という中立的な要件。適合 |
| 結論直前の自己監査に新しい必須のメタ判断を増やしすぎない | SHARED INVARIANTS は Step 5.5 や FORMAL CONCLUSION の前ではなく ANALYSIS フェーズ内に置くため、結論直前の判定ゲートとは別。適合 |

全原則と非抵触を確認。

---

## 変更規模の宣言

- 追加行: 2 行
- 変更行: 0 行
- 削除行: 0 行
- 合計変更規模: 2 行（hard limit 5 行以内、適合）
