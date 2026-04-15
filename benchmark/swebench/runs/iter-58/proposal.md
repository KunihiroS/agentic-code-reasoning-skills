# Iteration 58 — Improvement Proposal

## Exploration Framework カテゴリ

カテゴリ: **E. 表現・フォーマットを改善する**

### カテゴリ内のメカニズム選択理由

カテゴリ E は「曖昧文言の具体化」「簡潔化」「例示」の3つのメカニズムを含む。
今回は **「曖昧文言の具体化」** を選択する。

対象箇所 (SKILL.md Step 5.5 の第4チェック項目) は:
- 「semantic difference was found」時のみ条件付きで確認を促しており、
  差異が見つからなかった場合（EQUIVALENT を主張する場合）に何を確認するかが明記されていない。
- この非対称な条件式は、読み手に「差異が無ければこの項目は自動的にパス」という
  誤った解釈を与えうる。
- 対称化によって、EQUIVALENT 方向の誤判定と NOT_EQUIVALENT 方向の誤判定の
  両方を同一チェックポイントでカバーできる。
- 新規フィールドや新規ステップを追加せず、既存の一文の条件節を拡張するだけで達成できるため、
  変更規模を 5 行以内に収められる。

---

## 改善仮説

「差異が見つかった場合の確認義務（Guardrail #4 参照）は既存の条件式で表現されているが、
差異が見つからなかった場合の確認義務は同じ箇所に明記されていない。この非対称性が
EQUIVALENT 方向の誤判定につながりうる。条件節を both-direction（差異あり・差異なし双方）
に対称化することで、結論直前の自己チェックが全体的な推論品質向上に寄与する。」

---

## SKILL.md の変更内容

### 変更前

```
- [ ] The conclusion I am about to write asserts nothing beyond what the traced evidence supports.
      If a semantic difference was found, did I trace at least one relevant test through the differing
      path before concluding it affects (or does not affect) the outcome? (cf. Guardrail #4)
```

### 変更後

```
- [ ] The conclusion I am about to write asserts nothing beyond what the traced evidence supports.
      If a semantic difference was found, did I trace at least one relevant test through the differing
      path before concluding it affects (or does not affect) the outcome? If no semantic difference
      was found, did I verify this absence via an explicit search rather than by stopping exploration
      early? (cf. Guardrail #4)
```

### 変更の性質

- 既存行への文言追加（文末への 1 文付加）
- 新規ステップ・新規フィールド・新規セクションの追加なし
- 削除行なし

---

## 一般的な推論品質への期待効果

### どのカテゴリ的失敗パターンが減るか

1. **「差異なし」を差異の積極的不在証明なしに主張するパターン**
   探索を途中で打ち切り、見つからなかったことを「存在しないことの証拠」として
   扱う推論は典型的な不完全分析。変更後は結論直前に「探索打ち切りではなく、
   明示的なサーチを経ているか」の自問を促す。

2. **EQUIVALENT 誤判定（overall 方向の精度劣化）**
   差異が見つかった場合のチェックと同等の水準を差異がない場合にも求めることで、
   全体的なバランスが改善される。

3. **Step 5 の NO COUNTEREXAMPLE EXISTS ブロックとの整合性向上**
   compare モードのテンプレートには「Searched for: / Found:」の明示が求められている。
   Step 5.5 の自己チェック項目が同じ水準を要求することで、テンプレートと
   自己チェックの一貫性が高まる。

---

## failed-approaches.md の汎用原則との照合

| 原則 | 照合結果 |
|------|----------|
| 探索で探すべき証拠の種類をテンプレートで事前固定しすぎない | 非抵触。「何を探すか」ではなく「探索打ち切りでないことを確認したか」という手続き水準の確認であり、証拠の種類を固定していない。 |
| 探索ドリフト対策で探索の自由度を削りすぎない | 非抵触。読解順序・境界確定の早期固定には関与しない。 |
| 局所的な仮説更新を前提修正義務に直結させすぎない | 非抵触。仮説更新ループではなく、結論直前の自己チェックへの追記。 |
| 既存の汎用ガードレールを特定の追跡方向で具体化しすぎない | 非抵触。方向を「差異なし」に限定しているが、これはチェック条件の対称化であり、特定の追跡方向の半固定ではない。対称化前の片側条件を補完する形であるため、探索経路の早期固定とは異なる。 |
| 結論直前の自己監査に新しい必須のメタ判断を増やしすぎない | 要注意点。既存チェック項目の条件節への追記であり、実質的に「探索が明示的サーチを経ているか」という確認を加えている。ただし、Step 5 のテンプレートですでに同等の義務が記述されており、重複した役割を担う新規判定ゲートではない。また「特定の検証経路の強制」でなく「打ち切りでないことの確認」という抽象水準に留まっている。 |

総合: 既知の失敗原則には抵触しないと判断する。

---

## 変更規模の宣言

- 追加行数: **2 行**（既存行末への文追加を 2 行扱い）
- 削除行数: 0 行
- 合計変更行数: **2 行**（hard limit 5 行以内 — 適合）
