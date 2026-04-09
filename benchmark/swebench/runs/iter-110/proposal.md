# Iter-110 — Proposal

## Exploration Framework カテゴリ: C（強制指定）

**選択カテゴリ**: C — 比較の枠組みを変える  
**採用メカニズム**: C2「差異の重要度を段階的に評価する」

### カテゴリ内のメカニズム選択理由

C3（変更のカテゴリ分類を先に行う）は failed-approaches #7（分析前の中間ラベル生成によるアンカリングバイアス）に抵触するため除外。C1（関数単位での比較）はテストオラクルとの接続を断ち切るリスクがあり、compare モードの定義 D1（PASS/FAIL による等価性）と相性が悪い。C2 は既存の per-test ループを壊さず、比較の解像度をアサーションレベルに引き上げるため採用する。

---

## 改善仮説

`compare` モードの「NO COUNTEREXAMPLE EXISTS」節では、反例の記述単位が「diverging behavior（挙動の差異）」と指定されている。この粒度は実行パス上のどこかで挙動が分岐するという中間状態レベルの記述を許すため、エージェントが「テストアサーションまで到達しない挙動差」を仮想反例として採用しても形式的に充足される。その結果、EQUIVALENT 判定の根拠として「アサーションに届かない差異が存在しない」と主張する代わりに「実行パス上のどこかに差異が見当たらない」を採用するショートカットが可能になる。

仮説: NO COUNTEREXAMPLE EXISTS 節の反例記述をアサーションレベル（どのテストアサーションが異なる PASS/FAIL を生じうるか）に精緻化することで、EQUIVALENT 判定の反証構造が COUNTEREXAMPLE 節（NOT_EQUIVALENT 主張側）と同じ観測境界に揃い、双方の推論粒度が対称化される。これにより EQUIVALENT の偽陽性（テストオラクルを経由しない差異の見落とし）と NOT_EQUIVALENT の偽陽性（テストオラクルに届かない差異の過大評価）の双方が抑制されると期待する。

---

## SKILL.md の変更内容

### 変更箇所

`## Compare` セクションの証明書テンプレート内、`NO COUNTEREXAMPLE EXISTS` 節。

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
    [describe concretely: what test assertion would produce a different pass/fail, and what diverging value at that assertion would cause it]
```

### 変更規模宣言

**変更行数: 1 行**（既存行の文言精緻化のみ。新規ステップ・フィールド・セクションの追加なし）

---

## 一般的な推論品質への期待効果

### 減少が期待される失敗パターン

1. **偽 EQUIVALENT（テストオラクルを経由しない差異の見落とし）**  
   反例記述の粒度が「どのアサーションが、どんな値で失敗するか」に変わることで、エージェントは仮想反例を構成する際にテストオラクルとの接続を明示せざるを得なくなる。実行パス上の中間的な挙動差を「差異なし」と誤認するパターンが減少する。

2. **偽 NOT_EQUIVALENT（中間挙動差の過大評価）**  
   アサーションレベルへの着目を促すことで、「挙動が分岐する箇所を見つけたが PASS/FAIL には影響しない」ケースをエージェントが適切に EQUIVALENT と判定しやすくなる（COUNTEREXAMPLE 節のアサーション要件と整合した判断基準を持つため）。

3. **Guardrail #4「Do not dismiss subtle differences」の精度向上**  
   現在の Guardrail #4 は「差異を見つけたらトレースせよ」と指示するが、何をもって「影響あり」とするかの基準がない。アサーション境界という共通の観測点が compare モードの両経路に揃うことで、同ガードレールの適用判断が精緻化される。

---

## failed-approaches.md の汎用原則との照合

| 原則 | 照合結果 |
|------|----------|
| #1 判定の非対称操作 | **適合**。変更は NOT_EQUIVALENT 側（COUNTEREXAMPLE）が既に持つアサーションレベル記述を EQUIVALENT 側（NO COUNTEREXAMPLE）にも対称的に適用するものであり、立証責任の非対称化ではなく対称化である |
| #2 出力側の制約 | **適合**。変更は「何を書け」ではなく「仮想反例をどの粒度で考えよ」という処理側の改善 |
| #3 探索量の削減 | **適合**。探索量に影響しない |
| #6 対称化は既存制約との差分で評価せよ | **要確認・適合**。差分は EQUIVALENT 側の仮想反例記述がアサーションレベルに引き上がること。NOT_EQUIVALENT 側の既存アサーション要件と揃えることで「対称化」が成立しており、効果が非対称になる懸念は、両パスが同じ観測境界に収束するため問題にならない |
| #7 分析前ラベル生成によるアンカリング | **適合**。変更は分析完了後の反証構成ステップへの変更であり、分析前への中間ラベル挿入ではない |
| #17 中間ノードの局所分析義務化 | **適合**。変更はアサーション（観測境界）を指定するものであり、中間ノードへの注意固定とは逆の方向 |
| #18 特定証拠カテゴリへの物理的裏付け要求 | **適合**。アサーションの値・型を概念的に記述させるものであり、新たに `file:line` 引用を強制するものではない |
| #22 抽象原則での具体物の例示 | **適合**。変更は「観測可能な効果」（アサーション結果）を観測境界として指定するものであり、物理的なコード要素（関数名・ファイル名等）を探索目標として例示するものではない |
| #26 中間ステップでの物理的検証義務化 | **適合**。NO COUNTEREXAMPLE EXISTS は推論プロセスの最終反証ステップであり、中間ステップではない |
