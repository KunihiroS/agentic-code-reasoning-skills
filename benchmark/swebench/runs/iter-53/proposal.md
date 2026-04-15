# Iteration 53 — 改善提案

## Exploration Framework カテゴリ: F

カテゴリ F（原論文の未活用アイデアを導入する）を選択する。

### カテゴリ F 内での具体的なメカニズム選択理由

原論文 Appendix D（Code Question Answering = `explain` モード）には、SEMANTIC PROPERTIES セクションとして「属性を証拠付きで列挙する」構造が存在する。これは変数・オブジェクト・関数が保つ不変条件（semantic invariant）を明示させる仕組みである。

現在の SKILL.md において、この発想は `explain` モードにのみ反映されており、`compare` モードには応用されていない。

compare モードで EQUIVALENT を主張するとき、現在の `NO COUNTEREXAMPLE EXISTS` ブロックは検索対象を自由形式で記述させる。しかし、反証の検索空間には「差分が生み出す semantic invariant の変化（副作用の有無・例外発生条件の変化・状態遷移の違いなど）」が本来含まれるべきであり、これが省略されると「テストが直接行使しない振る舞いの差異」を見落とすリスクがある。

localize/explain の手法（SEMANTIC PROPERTIES）を compare の反証ステップに応用することで、EQUIVALENT の誤判定（= overall スコアの中でも equiv 方向の失敗）を減らせると期待できる。

---

## 改善仮説

compare モードで EQUIVALENT と結論する際の反証探索に、semantic invariant（状態・副作用・例外発生条件などが両変更間で変わらないことの確認）を検索対象として明示的に含めることで、テストが直接行使しない振る舞いの差異を見落とすリスクを抑制できる。

---

## SKILL.md への変更内容

### 変更箇所

compare モードの証明書テンプレート内、`NO COUNTEREXAMPLE EXISTS` ブロックの `Searched for:` 行。

### 変更前（SKILL.md 行 238）

```
    Searched for: [specific pattern — test name, code path, or input type]
```

### 変更後

```
    Searched for: [specific pattern — test name, code path, input type, or semantic invariant altered by the diff (e.g., side effects, exception conditions, state mutations)]
```

### 変更規模の宣言

変更行数: 1 行（既存行の文言精緻化のみ。新規ステップ・新規フィールド・新規セクションなし）。
削除行: 0 行。
合計カウント対象: 1 行 ≦ 5 行（制限内）。

---

## 一般的な推論品質への期待効果

### 減少が期待される失敗パターン

1. **Subtle difference dismissal（Guardrail #4 に対応する失敗）**: 差分があるにもかかわらず「テストで行使されないから同じ」と早期に打ち切るパターン。反証探索の対象に semantic invariant を含めることで、トレースが「pass/fail の直接パス」だけに限定されなくなり、副作用・例外・状態変化の差異も確認対象に入る。

2. **Incomplete reasoning chains（§4.3 Error Analysis の知見）**: 関数の呼び出しパスは正しく追えていても、その関数が変更前後で保つ不変条件の差異を下流で処理しているかどうかを確認せずに結論するパターン。semantic invariant の確認義務を反証探索に組み込むことで、この見落としを抑制できる。

3. **overall スコアへの影響**: EQUIVALENT 誤判定（equiv 方向の失敗）が主要ターゲット。NOT_EQUIVALENT への影響は限定的（反証が見つかった場合に誤って NOT_EQUIVALENT とする方向への余分なバイアスを与えない）。

---

## failed-approaches.md 汎用原則との照合

| 原則 | 照合結果 |
|------|----------|
| 「次に探すべき証拠の種類をテンプレートで事前固定しすぎる」 | 抵触しない。変更は `Searched for:` の例示を拡充するのみで、特定の検索順序や探索経路を強制しない。semantic invariant は探索対象の追加例示であり、他の証拠種類を排除しない。 |
| 「探索の自由度を削りすぎない」 | 抵触しない。「どこから読み始めるか」「どの境界を先に確定するか」という読解順序には一切触れない。 |
| 「局所的な仮説更新を即座の前提修正義務に直結させすぎない」 | 無関係。前提管理の仕組みには変更なし。 |
| 「既存の汎用ガードレールを特定の追跡方向で具体化しすぎない」 | 抵触しない。`Searched for:` はガードレールではなく反証テンプレートの例示フィールドであり、方向を指定していない。 |
| 「結論直前の自己監査に新しい必須メタ判断を増やしすぎない」 | 抵触しない。Step 5.5（Pre-conclusion self-check）には変更なし。既存の `NO COUNTEREXAMPLE EXISTS` ブロック内の例示拡充であり、新たな判定ゲートや必須項目を追加しない。 |

---

## 変更規模の宣言（再掲）

- 追加・変更: 1 行（既存行への文言追加）
- 削除: 0 行
- 新規ステップ / 新規フィールド / 新規セクション: なし
- 5 行以内の制限: 満たす
