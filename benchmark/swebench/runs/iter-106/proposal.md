# Iter-106 Proposal

## フォーカスドメイン
`equiv` — 2 つの実装が同じ振る舞いを持つと判定する精度の向上

---

## Exploration Framework カテゴリと選定理由

**カテゴリ E: 表現・フォーマットを改善する**

> "曖昧な指示をより具体的な言い回しに変える"

`compare` モードの `NO COUNTEREXAMPLE EXISTS` ブロックにある反例記述のテンプレート文言が、SKILL.md の定義 D1（等価性 = テストの pass/fail 結果が一致すること）と整合していない。現行の `[diverging behavior]` という表現は「コード上の差異」と「アサーション結果の差異」の両方を指し得るため、モデルがコード内部の挙動差異を反例として記述し、それを「発見した」と判断して誤って NOT EQUIVALENT を結論する経路が存在する。この曖昧さを D1 に合わせた形で精緻化することで、等価性の判定基準を一貫させる。

---

## 改善仮説

**反例の記述フレームを「コード挙動の差異」から「テストアサーション結果の差異」へ精緻化することで、equiv ケースでの偽陰性（実際は EQUIVALENT なのに NOT EQUIVALENT と誤判定）が減少する。**

反例記述テンプレートが D1（等価性はテスト pass/fail 結果で定義）と整合したとき、モデルは反例を「どのアサーションが異なる PASS/FAIL 結果を出すか」として具体化しなければならない。equiv ケースにおいて、コード差異がアサーション結果まで伝播しない場合、この問いに対して「そのような反例は存在しない」という正しい結論へ自然に誘導される。

---

## 変更内容

### 変更箇所

`compare` モード Certificate Template の `NO COUNTEREXAMPLE EXISTS` セクション内、反例の記述フィールド（1 行）。

### 変更前

```
NO COUNTEREXAMPLE EXISTS (required if claiming EQUIVALENT):
  If NOT EQUIVALENT were true, a counterexample would look like:
    [describe concretely: what test, what input, what diverging behavior]
```

### 変更後

```
NO COUNTEREXAMPLE EXISTS (required if claiming EQUIVALENT):
  If NOT EQUIVALENT were true, a counterexample would look like:
    [describe concretely: what test, which assertion would produce a different PASS/FAIL outcome, and why]
```

### 変更規模の宣言

**変更行数: 1 行（既存行への文言精緻化）**
削除行: 0 行
合計: 1 行（hard limit 5 行以内を満たす）

---

## 期待される推論品質への効果

### 改善が期待される失敗パターン

**「コード差異 → 反例あり → NOT EQUIVALENT」という短絡推論の抑制**

現行では、モデルが `NO COUNTEREXAMPLE EXISTS` ブロックで反例を記述する際、「この関数は異なる値を返す」という内部挙動の差異を反例として記述し、対応するテストを探索してそれを「発見」してしまうことがある。テストが変更済み関数を呼び出していれば、呼び出し経路は存在するため、モデルは「反例が存在する」と誤解釈して NOT EQUIVALENT と結論する。

変更後は反例を「どのアサーションの pass/fail 結果が変わるか」という形で記述することが求められる。equiv ケースでは、コード差異がアサーションまで伝播しないため、モデルは「そのようなアサーション差異は存在しない」という正しい検索結果を得て、EQUIVALENT と正しく結論できる。

### not_eq ケースへの影響

`not_eq` ケースにはアサーション結果の実際の差異が存在するため、より精緻化された反例記述の要求（「どのアサーションが変わるか」）にも答えられる。`COUNTEREXAMPLE` ブロック（NOT EQUIVALENT を主張する際に使用）は変更しないため、NOT EQUIVALENT の主張経路には直接影響しない。

---

## failed-approaches.md の汎用原則との照合

| 原則 | 照合結果 |
|------|---------|
| #1 判定の非対称操作 | ✅ 不抵触。変更は `NO COUNTEREXAMPLE EXISTS` ブロック内の記述フォーマットの精緻化であり、EQUIV / NOT_EQ どちらかへ立証責任を非対称に引き上げるものではない。D1 の定義に合わせた表現の一貫化にとどまる。 |
| #2 出力側の制約は効果がない | ✅ 不抵触。変更は「何を答えるか」ではなく「何を記述・探索するか」（処理側・入力側）を改善する。 |
| #5 入力テンプレートの過剰規定 | ✅ 不抵触。記録すべき項目を増やしているのではなく、既存項目の意味を D1 の定義と整合するよう明確化している。 |
| #7 中間ラベル生成によるアンカリング | ✅ 不抵触。分析ステップ前の分類・ラベル付けではなく、反例記述の粒度を明確化する変更である。 |
| #8 受動的記録フィールドの追加 | ✅ 不抵触。新規フィールドを追加していない。 |
| #18/#19/#26 物理的証拠の義務化 | ✅ 不抵触。`file:line` の引用を要求していない。「どのアサーションが差分を示すか」を概念的に記述することを求めており、探索予算を圧迫する物理的裏付けは要求しない。 |
| #20 厳格な言い換えによる立証責任引き上げ | ✅ 不抵触。変更は「diverging behavior → different PASS/FAIL outcome」という方向性の変更であり、EQUIV/NOT_EQ の一方に有利な立証責任の引き上げではなく、D1 に沿った定義の明確化である。 |

その他の原則（#3, #4, #6, #9–#17, #21–#27）は本変更の性質と直接関係しないが、いずれにも抵触しないことを確認済み。
