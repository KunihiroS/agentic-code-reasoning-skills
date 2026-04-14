# Iter-29 Proposal

## Exploration Framework カテゴリ: F (強制指定)

### カテゴリ F 内での具体的なメカニズム選択

カテゴリ F の定義:
  - 論文に書かれているが SKILL.md に反映されていない手法を探す
  - 論文の他のタスクモード (localize/explain) の手法を compare に応用する
  - 論文のエラー分析セクションの知見を反映する

今回選択したメカニズム: "explain モードの DATA FLOW ANALYSIS を compare の Claim 記述に応用する"

docs/design.md に記録されているとおり、論文の Code Question Answering (Appendix D) テンプレートには
`DATA FLOW ANALYSIS` セクションが存在し、変数の「作成 / 変更 / 使用」を明示的に追跡させる。
このアイデアはexplain モードには反映されているが、compare モードの ANALYSIS OF TEST BEHAVIOR には
移植されていない。

compare モードでは現在、Claim C[N].1 / C[N].2 に

  "because [trace from changed code to test assertion outcome — cite file:line]"

と書くことが求められるが、「変更前後で何の値・型・副作用が変わるのか」を明示させる指示がない。
そのため、同じ実行経路をたどっていても戻り値・副作用・例外の変化を見落とした PASS/FAIL 判定が
生じやすい。explain の DATA FLOW ANALYSIS が変数レベルで変化点を明示させるのと同様に、
compare の Claim 記述でも「どの値・型・副作用が変わるか」を一言記述させることで、
微妙な差異を見落とす確認バイアスを構造的に抑制できる。

これは Objective.md カテゴリ F の「explain 手法の compare 応用」に正確に対応する。


## 改善仮説 (1つだけ、抽象的・汎用的)

compare モードで PASS/FAIL を判定する前に、変更が引き起こす具体的な値・型・副作用の変化を
Claim ごとに一行記述させることで、観察等価に見えて実は副作用や例外経路だけが異なる実装の
差異を見落とす「subtle difference dismissal」パターンが減少し、全体的な判定精度が向上する。


## SKILL.md のどこをどう変えるか

### 変更対象

compare モードの Certificate テンプレート内、ANALYSIS OF TEST BEHAVIOR セクションの
Claim 記述部分 (SKILL.md 行 209-212 付近)。

### 変更前 (引用)

```
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace from changed code to test assertion outcome — cite file:line]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace from changed code to test assertion outcome — cite file:line]
```

### 変更後 (引用)

```
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace from changed code to test assertion outcome — cite file:line;
                note what value/type/side-effect concretely changes]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace from changed code to test assertion outcome — cite file:line;
                note what value/type/side-effect concretely changes]
```

### 変更規模の宣言

変更行数: 2行 (既存行 2行の末尾への文言追加。削除行なし)
新規ステップ・新規フィールド・新規セクションの追加: なし
5行以内 hard limit: 充足


## 一般的な推論品質への期待効果

### 減少が期待される失敗パターン

1. Subtle difference dismissal (docs/design.md §4.1.1 / Guardrail #4 に対応):
   コードの差異を発見したが「テスト結果には影響しない」と早急に結論づけてしまうパターン。
   「何が変わるか」を一文書かせることで、影響ゼロと断言する前に具体的な変化点を明示させ、
   その変化が downstream assertion に届くかどうかを再確認させる。

2. Incomplete reasoning chains (docs/design.md §4.3):
   関数列をトレースしたが途中で止まり、変数の最終的な型・値・副作用まで追わないパターン。
   Claim の記述欄に「値/型/副作用が何であるか」を要求することで、下流ハンドリングまで
   追わずに PASS と判定する不完全チェーンを抑制する。

3. overall カテゴリへの効果:
   EQUIV / NOT_EQUIV 双方の精度改善が期待される。NOT_EQUIV の見落とし (EQUIV と誤判定する
   偽陽性) は subtle difference dismissal に起因することが多く、EQUIV の誤判定 (NOT_EQUIV
   と誤判定する偽陰性) は不完全チェーンにより存在しない差異を「ある」と誤認することに
   起因することがある。どちらも変化点の明示によって改善方向に働く。


## failed-approaches.md の汎用原則との照合結果

原則1: 「探索で探すべき証拠の種類をテンプレートで事前固定しすぎる変更は避ける」
  → 今回の変更は新規の必須探索ステップや証拠種類の追加ではなく、Claim 記述欄の
    説明文を 1フレーズ拡張するのみ。探索経路は変更しない。非抵触。

原則2: 「ドリフト抑制のための局所的な具体化は探索の自由度を削りすぎる」
  → 今回の変更は探索の順序・優先度・読み始め方には一切影響しない。ANALYSIS セクションの
    結論記述の明示度を上げるだけ。非抵触。

原則3: 「局所的な仮説更新を即座の前提修正義務に直結させすぎない」
  → 今回の変更は Step 3 (仮説駆動探索) でも Step 2 (前提) でもなく、Step 6 に至る前の
    Claim 記述の精緻化。仮説更新サイクルへの介入なし。非抵触。

原則4: 「結論直前の自己監査に新しい必須のメタ判断を増やしすぎない」
  → Step 5.5 (Pre-conclusion self-check) には一切触れない。変更対象は ANALYSIS OF TEST
    BEHAVIOR 内の Claim テンプレート文字列のみ。非抵触。

照合結果: 4原則すべてと非抵触。


## 変更規模の宣言

- 変更行数 (追加・修正): 2行
- 削除行数: 0行
- 新規セクション・新規フィールド・新規ステップ: なし
- hard limit (5行): 充足
