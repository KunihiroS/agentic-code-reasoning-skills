# Iteration 56 — 変更理由

## 前イテレーションの分析

- 前回スコア: 85%（17/20）（親イテレーション: iter-35）
- 失敗ケース: django__django-15368, django__django-13821, django__django-11433
- 失敗原因の分析: 15368・13821 は EQUIV であるにも関わらず NOT_EQ と誤判定。エージェントはコード差分を発見し「intermediate な実行経路が異なる」ことを根拠に NOT_EQ と結論づけており、テストの PASS/FAIL 最終結果まで正確にトレースできていない。11433 は NOT_EQ であるが UNKNOWN（31 ターン超）で終了しており、複雑なコードの追跡に起因する。

## 改善仮説

チェックリスト項目 6 の「observable test outcome」という表現が曖昧であり、エージェントが「コード実行経路の差」を「テスト結果の差」と混同している。「observable test outcome」を「PASS/FAIL result」に精緻化し、「not merely the internal execution path」という対比句を加えることで、コード差分からテスト結果への短絡（jumps-to-conclusion）を抑制できる。

## 変更内容

`## Compare` セクションの `### Compare checklist` 内、1 行の文言を修正:

- **変更前**: `verify that the difference produces a different observable test outcome by tracing through at least one test`
- **変更後**: `verify that the difference changes the PASS/FAIL result of at least one relevant test, not merely the internal execution path`

新規追加行: 0 行（既存行の文言精緻化のみ）。

## 期待効果

- **15368・13821（EQUIV → NOT_EQ 誤判定）**: 「not merely the internal execution path」という対比句により、エージェントが「コード経路の差 ≠ テスト合否の差」を意識し、NO COUNTEREXAMPLE EXISTS セクションでより厳密に PASS/FAIL を確認するよう誘導される。EQUIV の正答率が 80%（8/10）→ 90〜100%（9〜10/10）へ改善する可能性がある。
- **11433（UNKNOWN）**: 本変更はチェックリスト 1 行の修正であり認知負荷の増加はほぼなく、直接的な改善・悪化は見込みにくい。
- **NOT_EQ 正答済みケース**: 「PASS/FAIL result を示せば条件を満たす」という明確な基準であり、真の NOT_EQ ケースの立証ハードルは実質的に変わらない。
