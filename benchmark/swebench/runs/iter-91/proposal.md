# Iteration 91 — Proposal

## Exploration Framework カテゴリと選定理由

**カテゴリ: C — 比較の枠組みを変える**（"差異の重要度を段階的に評価する"）

`equiv` ドメインの誤判定の主因は、内部実装の差異を発見した後、その差異がテストの観察境界（assertion 入力、返り値、例外）まで伝播するかを確認せずに NOT_EQUIVALENT と結論づけるパターンである。このカテゴリは「差異の重要度を段階的に評価する」ことを狙いとしており、D1 定義の精緻化という形で「観察境界に届かない差異は等価判定に無関係」という原則を枠組みに組み込む。

---

## 改善仮説

**等価性の定義（D1）に「テストが観察できない内部実装差異は判定に無関係」という明示的なクローズを加えると、内部差異を観察境界と混同することに起因する false NOT_EQUIVALENT が減少する。**

定義の段階で「観察境界に伝播しない差異は D1 の等価性に影響しない」ことが明記されれば、エージェントは内部差異を発見した時点で自動的に「この差異は観察点まで届くか？」という判断ステップを踏む根拠を得る。Guardrail #4（差異を発見したら必ず 1 件のテストをトレースしてから判定せよ）と組み合わせることで、「内部差異あり → 即 NOT_EQUIVALENT」という短絡が抑制される。

---

## SKILL.md のどこをどう変えるか

### 変更箇所

`## Compare` セクション内の **Certificate template** の `DEFINITIONS` ブロック、`D1` の定義行。

### 変更内容

**変更前:**
```
D1: Two changes are EQUIVALENT MODULO TESTS iff executing the relevant
    test suite produces identical pass/fail outcomes for both.
```

**変更後:**
```
D1: Two changes are EQUIVALENT MODULO TESTS iff executing the relevant
    test suite produces identical pass/fail outcomes for both.
    Internal implementation differences that do not propagate to a
    test-observable outcome (returned value, raised exception, mutated
    state, or assertion input) are irrelevant to this definition.
```

### 変更規模の宣言

**追加行数: 3 行**（削除: 0 行）。5 行 hard limit 以内。

---

## 一般的な推論品質への期待効果

### 減少が期待される失敗パターン

1. **「内部差異の誤った観察差異への昇格」**  
   エージェントが「コード A と B は内部処理が違う → 挙動が違う → NOT_EQUIVALENT」と短絡するパターン。D1 に観察境界の基準が明記されることで、差異がそこまで届くかどうかを問う自然な足場が生まれる。

2. **「観察点の同一性への見落とし」**  
   test analysis のパレンテティカル注記 `(Base this on the first observation point...)` はすでに存在するが、それが D1 の定義レベルで裏づけられていないため見落とされがちである。D1 との整合性が明示されることで、当該注記の拘束力が強まる。

### 副次的効果（NOT_EQ への影響）

D1 の新クローズは「伝播しない差異は無関係」と言うだけであり、「伝播する差異は引き続き判定に影響する」という骨子は変わらない。Guardrail #4 が「差異を見つけたら必ずトレースせよ」と要求し続けるため、NOT_EQUIVALENT を正当に主張するための証拠要件は弱まらない。

---

## failed-approaches.md の汎用原則との照合結果

| 原則 | 適合判定 | 根拠 |
|------|----------|------|
| #1 判定の非対称操作 | **適合** | D1 の定義はどちらの結論にも対称的に適用される。EQUIV を優遇するのではなく、等価性の意味を明確化するだけ。 |
| #2 出力側の制約 | **適合** | 変更は定義（入力・処理側のフレームワーク）であり、「こう答えろ」という出力制約ではない。 |
| #3 探索量の削減 | **適合** | 探索を削減しない。むしろ「伝播するか？」を確認するトレースを促す。 |
| #4 同方向の変化 | **適合** | 過去に D1 の観察境界明示化を試みたイテレーションは failed-approaches.md に存在しない。 |
| #5 入力テンプレートの過剰規定 | **適合** | 記録フィールドの追加ではなく、定義の精緻化。 |
| #8 受動的記録フィールドの追加 | **適合** | 新しいテーブル列やフィールドを追加しない。 |
| #12 アドバイザリな非対称指示 | **適合** | チェックリストや推奨形式ではなく、定義の明文化。方向は対称。 |
| #16 ネガティブプロンプト | **適合** | 特定パターンの禁止ではなく、等価性の定義における正の記述。 |

---

## 変更規模の宣言

- 追加行: **3 行**
- 削除行: 0 行
- 合計変更行: 3 行（hard limit 5 行以内 ✓）
- 対象: 既存の `D1` 定義へのテキスト付加（新規ステップ・新規フィールド・新規セクションの追加なし）
