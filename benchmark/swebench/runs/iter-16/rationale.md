# Iteration 16 — 変更理由

## 前イテレーションの分析

- 前回スコア: 70% (14/20)
- 失敗ケース: django__django-15368, django__django-13821, django__django-14373, django__django-15382, django__django-14787, django__django-14122
- 失敗原因の分析:

  **失敗パターンの内訳:**
  - EQUIVALENT → NOT_EQUIVALENT（4 件）: 15368, 13821, 14373, 15382
  - NOT_EQUIVALENT → EQUIVALENT（1 件）: 14787
  - NOT_EQUIVALENT → UNKNOWN（1 件）: 14122

  **iter-15 の変更（D3 追加）の評価:**
  - D3（削除されたテストを ABSENT として定義）は 12663 を修正した一方で、13821・14373・14122 の 3 件を新たに壊した（ネット -2）。
  - D3 はロールバックされ、現在の SKILL.md は iter-14 状態（80%）に戻っている。
  - D3 の失敗原因推定: ABSENT という第三の状態を導入することで、エージェントが通常のテストカバレッジ判断においても ABSENT 概念を誤適用し、EQUIVALENT → NOT_EQUIVALENT 誤判定が増加した。

  **持続的失敗の根本原因（iter-14 以来）:**
  - **15368・15382**: EQUIVALENT なのに NOT_EQUIVALENT と誤判定。エージェントはコードの差異を発見した後、その差異が実際にテストの pass/fail に影響するかどうかを十分に検証せずに NOT_EQUIVALENT と結論付ける。
  - **14787**: NOT_EQUIVALENT なのに EQUIVALENT と誤判定。エージェントは差異を発見するが「テスト結果に影響しない」と誤結論する。
  - **12663**: NOT_EQUIVALENT なのに UNKNOWN（ターン枯渇）。

  **重要な観察**: iter-14・15 を通じて最も多い失敗タイプは「EQUIVALENT → NOT_EQUIVALENT」である（iter-15: 4/6 失敗）。これはエージェントがコードの差異を見つけた際に、その差異がどのテストを通じてどのコードパスで実際に検証されるかを確認せずに COUNTEREXAMPLE を主張する「浅い反例」問題である。現行の COUNTEREXAMPLE ブロックはテスト名と理由を要求するが、テストから変更コードへの呼び出しパスの file:line 引用を要求しない。これがギャップである。

## 改善仮説

**compare テンプレートの COUNTEREXAMPLE ブロックに「Call path from test to changed code」フィールドを 1 行追加し、NOT_EQUIVALENT を主張する際にテストエントリポイントから変更コード箇所までの呼び出しパスを file:line で必須引用させることで、根拠のない「コード差異の発見 → NOT_EQUIVALENT」という短絡的推論を汎用的に防止できる。**

根拠:
- 現行の COUNTEREXAMPLE ブロックは「Test [name] will [PASS/FAIL] because [reason]」を要求するが、エージェントは reason として「コードが変わった」という抽象的な説明のみを書き、テストが変更コードパスを実際に通るかどうかを確認しない。
- Call path の file:line 引用を必須にすることで、エージェントはテストファイルを開いて変更された関数/メソッドが実際に呼ばれていることを確認しなければならない。この確認プロセス自体が誤判定の抑止力になる。
- この要件は compare モードの COUNTEREXAMPLE 構造に最小限の追加（1 行）であり、EQUIVALENT 判断には影響しない（NO COUNTEREXAMPLE EXISTS ブロックは変更しない）。
- 呼び出しパスの引用はどのプログラミング言語・フレームワークにも適用可能な一般的手法であり、Django 固有でない。
- D3 が問題を起こした「DEFINITIONS への介入（概念定義の拡張）」とは独立した層（証明テンプレートの構造）での修正であり、同一アプローチの繰り返しではない。

## 変更内容

compare テンプレートの COUNTEREXAMPLE ブロック（4 行）に 1 行追加:

```diff
 COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
   Test [name] will [PASS/FAIL] with Change A because [reason]
   Test [name] will [FAIL/PASS] with Change B because [reason]
+  Call path from test to changed code: [test_file:line → ... → changed_file:line]
   Therefore changes produce DIFFERENT test outcomes.
```

変更規模: 1 行追加（≤ 20 行の制約内）。

## 期待効果

- **15368・15382**: Call path の引用義務により、エージェントはテストが変更コードパスに実際に到達することを file:line で示さなければならない。「削除されたテストが実行されない → NOT_EQUIVALENT」「コードトレースが変わる → NOT_EQUIVALENT」という浅い推論が抑制され、実際にテストが変更箇所を実行するかどうかの確認が促される。
- **13821・14373（iter-15 の新規失敗）**: 同様に、Call path 確認が浅い NOT_EQUIVALENT 判断を防ぎ、iter-14 状態に回帰する（または改善する）ことを期待する。
- **14787**: NOT_EQUIVALENT → EQUIVALENT の誤判定は本改善の主対象ではないが、Call path 確認が差異の影響範囲をより正確に特定させる効果があるかもしれない。
- **12663**: ターン枯渇による UNKNOWN は本改善の主対象ではなく、直接的な改善は期待しない。
- **回帰リスク**: 変更は COUNTEREXAMPLE ブロックのみで、EQUIVALENT 判断（NO COUNTEREXAMPLE EXISTS）・他モード・他ステップには影響しない。Call path の確認は現行の compare checklist 「Trace each test through both changes separately before comparing」と方向性が一致しており、新しい要件の導入よりも既存の要件の構造的強化である。回帰リスクは低い。
