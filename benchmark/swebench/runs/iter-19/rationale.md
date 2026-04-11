# Iteration 19 — 変更理由

## 前イテレーションの分析

- 前回スコア: 70% (14/20)
- 失敗ケース: django__django-15368, django__django-13821, django__django-15382, django__django-14787, django__django-14122, django__django-12663
- 失敗原因の分析:

  **失敗パターンの内訳:**
  - EQUIVALENT → NOT_EQUIVALENT（3 件）: 15368, 13821, 15382
  - NOT_EQUIVALENT → UNKNOWN（3 件）: 14787（31 ターン枯渇）、14122（31 ターン枯渇）、12663（31 ターン枯渇）

  **iter-18 変更（UNKNOWN 禁止注記）の評価:**
  - iter-18 の変更は FORMAL CONCLUSION の ANSWER フィールド直後に「UNKNOWN は無効、LOW 信頼度で YES/NO にコミットせよ」という注記を追加した。
  - 効果: 15315（UNKNOWN → EQUIVALENT 正解）は修正されたが、14787 は依然 UNKNOWN（31 ターン枯渇）、14122・12663 も UNKNOWN のまま。
  - 退行: 13821 が EQUIVALENT 正解 → NOT_EQUIVALENT 不正解に悪化（UNKNOWN 禁止により、探索不完全のまま誤った NOT_EQUIVALENT にコミットした可能性）。
  - ネット: +1 修正 -2 退行 = スコア 75% → 70% に悪化。

  **EQUIVALENT → NOT_EQUIVALENT の持続的失敗（15368・15382 は iter-15〜18 の全 4 回失敗）:**
  - エージェントはコードの意味的差異を発見し、「この差異がテスト結果を変える」という主張（COUNTEREXAMPLE）を行う。
  - しかし、現在の COUNTEREXAMPLE テンプレートは「Test [name] will [PASS/FAIL] ... because [reason]」と要求するのみで、[reason] が具体的なテストアサーションのトレースを含まなくても構造上は記入可能。
  - 結果として、エージェントは「コードが変わっている → このテストは異なる動作をするはずだ」という推論のみで COUNTEREXAMPLE を満たし、NOT_EQUIVALENT と結論付ける。実際にはその差異がテストアサーションに到達しない（またはアサーションの評価結果が変わらない）にもかかわらず。
  - これは iter-16 の rationale で「浅い反例」問題と命名されているパターンと同一。iter-17・18 の変更（到達性確認フィールド追加・UNKNOWN 禁止）はこの問題を直接解決しなかった。

  **UNKNOWN の根本原因（別問題として認識）:**
  - 14787・14122・12663 は最大ターン（31）を消費しても結論に至れない。UNKNOWN 禁止でも改善しないことから、問題は「コミットの意志」ではなく「探索中の判断構造」にある。この問題は今回の仮説対象外とし、別イテレーションで取り組む。

## 改善仮説

**COUNTEREXAMPLE セクションに「Diverging assertion: [test_file:line — the specific assert/check that produces a different result]」フィールドを 1 行追加することで、エージェントが NOT_EQUIVALENT を主張する際にテストアサーションの具体的な file:line を特定することが構造的に要求され、「浅い反例」による誤判定を防止できる。**

根拠:
- 現在の COUNTEREXAMPLE テンプレートは PASS/FAIL の「理由」を求めるが、具体的なテストアサーションの特定を要求しない。エージェントはコードの差異から論理的に PASS/FAIL を推論するだけで記入できる。
- テストアサーションの file:line を明示的に要求することで、エージェントはテストコードを実際に読み、「どのアサーションがどのように変わるか」を検証せざるを得なくなる。この検証が「コードが変わった → テストが失敗する」という根拠薄弱な推論を構造的に防ぐ。
- 具体的なアサーションが特定できない場合、COUNTEREXAMPLE を満たせず、エージェントは EQUIVALENT と結論するか、証拠不足として LOW 信頼度で判断を留保する。
- この変更はプログラミング言語・フレームワークに依存しない（テストアサーションはあらゆるコードベースに存在する汎用概念）。
- 変更規模は 1 行追加のみ。COUNTEREXAMPLE セクション以外（explore、反証、他モード）への影響ゼロ。

## 変更内容

compare テンプレートの `COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):` ブロックに 1 行追加:

```diff
 COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
   Test [name] will [PASS/FAIL] with Change A because [reason]
   Test [name] will [FAIL/PASS] with Change B because [reason]
+  Diverging assertion: [test_file:line — the specific assert/check that produces a different result]
   Therefore changes produce DIFFERENT test outcomes.
```

変更規模: 1 行追加（≤ 20 行の制約内）。
変更箇所: compare テンプレートの COUNTEREXAMPLE ブロックのみ。他のセクション・モードへの影響なし。

## 期待効果

- **15368・15382・13821（EQUIVALENT → NOT_EQUIVALENT 誤判定）**: エージェントは COUNTEREXAMPLE を主張するために、実際のテストアサーション（file:line）を特定する必要が生じる。差異がアサーションに到達しない場合、このフィールドを埋められず、正しく EQUIVALENT と判定することが期待される。
- **14787・14122・12663（UNKNOWN）**: 今回の変更の主対象ではないが、COUNTEREXAMPLE 構造の明確化により、NOT_EQUIVALENT を正しく主張できる場合のターン消費が減る可能性がある。
- **回帰リスク**: 現在 NOT_EQUIVALENT を正解している 10 件は、すでに正しいアサーションをトレースして判定しているはずであり、Diverging assertion フィールドの追加は追加の確認にとどまる。過剰なターン消費を招くリスクは低い（1 cite の追加であり、新たな探索フェーズではないため）。
