# Iteration 74 — 変更理由

## 前イテレーションの分析

- 前回スコア: 前イテレーション時点のスコア（詳細は scores.json 参照）
- 失敗ケース: 複数の `not_eq` ケースで誤判定
- 失敗原因の分析: 意味論的差異を発見しているにもかかわらず、テスト観測への影響がないと浅い根拠で結論づける「subtle difference dismissal」が頻発していた。`NO COUNTEREXAMPLE EXISTS` セクションにおける反例候補の記述が "what input" という抽象的な表現に留まり、エージェントが実際の実行経路をトレースせずに形式的な記述で充足させてしまっていた。

## 改善仮説

反例候補の記述指示において「何を入力するか」ではなく「テスト内のどの実行経路が意味論的差異に到達するか」を要求するよう言い換えることで、エージェントは差異を発動させる条件をテストコード上でトレースせざるを得なくなる。これにより、意味論的差異が存在するにもかかわらず浅い検索で「反例なし」と早期結論する false EQUIV が減少し、`not_eq` 正答率が向上する。

## 変更内容

Compare → Certificate template → `NO COUNTEREXAMPLE EXISTS` セクション内の反例候補記述テンプレートを 1 行変更した。

- 変更前: `[describe concretely: what test, what input, what diverging behavior]`
- 変更後: `[describe concretely: what test, which execution path within that test reaches the semantic difference, what diverging behavior at the assertion]`

変更規模は既存行 1 行の文言精緻化のみ。新規ステップ・フィールド・セクションは追加していない。

## 期待効果

`NOT_EQUIVALENT` な実装ペアに対し、エージェントがテスト内の実行経路を具体的にトレースするよう誘導される。これにより「意味論的差異が存在するがテストには影響しない」という浅い判断が抑制され、`not_eq` の正答率向上が期待できる。

真に等価なケースでは、経路トレースの結果「差異に到達しない」と明示的に確認されるため、EQUIV 正答率への回帰リスクは低い。また、`COUNTEREXAMPLE` セクションにはすでに「trace from changed code to the assertion or exception — cite file:line」という同等の要求が存在しており、本変更は EQUIV 側の記述精度をその水準に対称化するものである。
