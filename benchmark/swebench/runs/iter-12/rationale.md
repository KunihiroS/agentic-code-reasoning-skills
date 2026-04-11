# Iteration 12 — 変更理由

## 前イテレーションの分析

- 前回スコア: 70% (14/20)
- 失敗ケース: django__django-15368, django__django-13821, django__django-15382, django__django-14787, django__django-14122, django__django-12663
- 失敗原因の分析:
  - **15368（持続的失敗）**: EQUIVALENT なのに NOT_EQUIVALENT と誤判定（14 ターン）。過保守的なコードトレースによる誤判定が継続。
  - **13821（持続的失敗）**: EQUIVALENT なのに NOT_EQUIVALENT と誤判定（16 ターン）。テスト環境（SQLite バージョン）についての仮説的推論により NOT_EQUIVALENT と誤判定。
  - **15382（持続的失敗）**: EQUIVALENT なのに NOT_EQUIVALENT と誤判定（19 ターン）。ループ制御フローの誤トレース。
  - **14787（新規・判断放棄）**: NOT_EQUIVALENT なのに UNKNOWN（31 ターン）。ターン上限に到達し、結論を書けずに終了。
  - **14122（新規・判断放棄）**: NOT_EQUIVALENT なのに UNKNOWN（31 ターン）。同上。
  - **12663（新規・判断放棄）**: NOT_EQUIVALENT なのに UNKNOWN（31 ターン）。同上。

  **重要な観察**: 3件の UNKNOWN は全て恰度 31 ターンでターン上限に到達している。これはエージェントが反例（COUNTEREXAMPLE）を見つけた後も探索を続け、ターンを使い果たして FORMAL CONCLUSION を書けなくなるパターンを示している。反例が一つ確認できれば NOT EQUIVALENT の結論を導くのに十分であるにもかかわらず、追加の差分探索に費やして判断放棄に至っている。

## 改善仮説

**Compare モードの証明書テンプレートの COUNTEREXAMPLE セクションに「反例が確認されたら即座に FORMAL CONCLUSION に進め」という明示的な指示を追加することで、NOT_EQUIVALENT 判定時のターン枯渇を汎用的に防止できる。**

根拠:
- 現在のテンプレートの COUNTEREXAMPLE セクションは「Test [name] will ... Therefore changes produce DIFFERENT test outcomes.」で終わっており、その後に何をすべきか明示していない。エージェントはこのセクションを書いた後も引き続き他のテストや差分を探索し続け、最終的にターンを使い果たして UNKNOWN を返す。
- D1 の定義上、一つでも pass/fail が異なるテストが存在すれば NOT EQUIVALENT であり、追加の証拠は定義論的に不要である。COUNTEREXAMPLE セクションが完成した時点で結論に進むべき根拠は明確である。
- 「反例が確認されたら探索を停止する」という原則は、数学的証明における反例の役割と同じであり、汎用的な推論規律の強化である。特定のベンチマークケースに依存しない。
- この変更は EQUIVALENT 判定（NO COUNTEREXAMPLE EXISTS セクションを使うケース）には影響しない。また COUNTEREXAMPLE を書く前の探索プロセスや反証義務にも影響しない。

## 変更内容

`compare` モード証明書テンプレートの COUNTEREXAMPLE セクションの末尾に 2 行を追加:

```
  STOP: Once this counterexample is confirmed via traced code paths, proceed
  directly to FORMAL CONCLUSION. Do not continue exploring additional tests.
```

変更規模: 2 行追加（≤ 20 行の制約内）。

## 期待効果

- **14787, 14122, 12663**: COUNTEREXAMPLE セクションの指示により、エージェントが反例を確認した後に探索を続けてターンを使い果たす行動を抑制し、FORMAL CONCLUSION を書けるようになることを期待する。3件が UNKNOWN → NO（NOT_EQUIVALENT 正解）となれば、スコアが 14/20 → 17/20（85%）になることを期待する。
- **15368, 13821, 15382**: 本イテレーションの主仮説ではなく（これらは過保守的な EQUIVALENT 誤判定であり別の失敗モード）、今回の変更では改善を期待しない。
- **回帰リスク**: 変更は COUNTEREXAMPLE セクションの末尾への追記のみであり、EQUIVALENT 判定（NO COUNTEREXAMPLE EXISTS）の推論フロー、反証プロセス、コードトレース義務に影響しない。正常に判定できている 14 件への影響は極めて低い。
