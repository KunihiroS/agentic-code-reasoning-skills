# Iteration 15 — 変更理由

## 前イテレーションの分析

- 前回スコア: 80% (16/20)
- 失敗ケース: django__django-15368, django__django-15382, django__django-14787, django__django-12663
- 失敗原因の分析:
  - **15368（持続的失敗）**: EQUIVALENT なのに NOT_EQUIVALENT と誤判定（13 ターン）。Patch B がテストメソッドを削除するケース。エージェントが「削除されたテスト → 実行されない → pass/fail 結果が変わる → NOT_EQUIVALENT」と推論する。これは D2 の定義にある pass/fail の二値判定を「削除されたテスト」に誤適用した概念的エラーである。
  - **15382（持続的失敗）**: EQUIVALENT なのに UNKNOWN（31 ターン）。探索ループ枯渇。iter-14 の CONVERGENCE GATE でも改善されなかった。
  - **14787（持続的失敗）**: NOT_EQUIVALENT なのに EQUIVALENT と誤判定（28 ターン）。エージェントが真の差異を発見しても「テスト結果に影響しない」と誤結論した。
  - **12663（持続的失敗）**: NOT_EQUIVALENT なのに UNKNOWN（31 ターン）。探索ループ枯渇。iter-11〜14 の各アプローチでも改善なし。

  **重要な観察**: 15368 の失敗はターン枯渇ではなく（13 ターン）、D2 定義の概念的ギャップに起因する。現行の D1/D2 は pass/fail の二値でテスト結果を定義しているが、パッチ自体がテストを削除するケースの扱いが明示されていない。エージェントは「削除されたテストは実行されない → pass でも fail でもない → 結果が異なる → NOT_EQUIVALENT」と推論しがちである。

## 改善仮説

**compare テンプレートの DEFINITIONS に D3 を追加し、パッチによって削除・無効化されたテストの outcome を "ABSENT" として定義することで、"テスト削除 → 自動的に NOT_EQUIVALENT" という誤推論を汎用的に防止できる。**

根拠:
- 現行の D1 は "identical pass/fail outcomes" と定義しているが、ABSENT（削除されたテスト）はこの二値の外にある第三の状態である。このギャップが 15368 のような誤推論の温床になっている。
- D3 を追加することで「両パッチが同じテストを削除した場合（ABSENT == ABSENT）は同一結果、一方のみが削除した場合は差異」というルールが明示され、エージェントは正しい比較軸を持つことができる。
- この定義はパッチがテストファイルを変更するあらゆるケース（デッドコード削除、テストリファクタリング、非推奨テストの除去など）に普遍的に適用可能であり、特定のベンチマークケースに依存しない。
- iter-11〜14 で試みられた修正（Step 3 の CONVERGENCE GATE、Step 5.5 の UNKNOWN 禁止チェックリスト、Step 5/6 の STOP 指示）はいずれも探索制御または結論フェーズへの介入であり、本改善は DEFINITIONS（Step 1 の概念定義）への介入であり重複しない。

## 変更内容

compare テンプレートの DEFINITIONS ブロック内、D2 の末尾（"restrict the scope of D1 accordingly." の直後）に D3 を追加（4 行）:

```
D3: A test that is deleted or disabled by a patch has outcome ABSENT for that patch.
    ABSENT == ABSENT counts as identical outcomes (not a difference).
    ABSENT vs PASS or ABSENT vs FAIL is a difference only when one patch removes
    the test while the other keeps it present and running.
```

変更規模: 4 行追加（≤ 20 行の制約内）。

## 期待効果

- **15368**: D3 により、エージェントは「Patch B がテストを削除 → ABSENT」「Patch A が同テストを保持または同様に削除 → 同一/異なる扱いを正しく判断」という推論を行えるようになる。両パッチが同じテストを ABSENT にする場合、ABSENT == ABSENT として EQUIVALENT の根拠になる。誤った NOT_EQUIVALENT 判定の抑制を期待する。
- **15382, 12663**: 本イテレーションの主仮説ではなく（これらはターン枯渇が主因）、直接的な改善は期待しない。
- **14787**: 本イテレーションの主仮説ではないが、D3 の追加がテスト削除に関する誤解を一部排除する可能性はある。
- **回帰リスク**: D3 は新しい ABSENT カテゴリを定義するが、テストが削除されないケース（多数）には影響しない。ABSENT が適用されるのはパッチがテストファイルを変更する場合に限られ、既存の pass/fail 判定ロジックには変更を加えない。回帰リスクは低い。
