# Iteration 20 — 変更理由

## 前イテレーションの分析

- 前回スコア: 75% (15/20)
- 失敗ケース: django__django-15368, django__django-13821, django__django-15382, django__django-14787, django__django-12663
- 失敗原因の分析:

  **失敗パターンの内訳:**
  - EQUIVALENT → NOT_EQUIVALENT（3 件）: 15368, 13821, 15382
  - NOT_EQUIVALENT → EQUIVALENT（1 件）: 14787（26 ターン消費）
  - NOT_EQUIVALENT → UNKNOWN（1 件）: 12663（31 ターン枯渇）

  **EQUIVALENT → NOT_EQUIVALENT の持続的失敗（iter-14 以来）:**
  - 15368・13821・15382 はいずれも EQUIVALENT ペアだが、エージェントがコードの意味的差異を発見した後、NOT_EQUIVALENT と誤判定する「浅い反例」パターン。
  - この失敗は 2 つの段階で起きている:
    - **段階 1 — 到達性の欠如**: 変更されたコードが当該テストの実行パスに含まれるかどうかを明示的に確認せずに、テストに対する PASS/FAIL トレースを開始している。
    - **段階 2 — アサーション特定の欠如**: COUNTEREXAMPLE を主張する際に、どのテストアサーション（file:line）が実際に異なる結果を生むかを特定せず、「コードが変わった → テストが失敗するはずだ」という推論のみで記入できてしまう構造になっている。

  **過去イテレーションの教訓:**
  - iter-17 では ANALYSIS OF TEST BEHAVIOR に `Changed code on this test's execution path: [YES/NO]` フィールドを追加し 75% を達成したが、15368・15382 の修正には至らなかった（段階 2 が未解決）。
  - iter-19 では COUNTEREXAMPLE に `Diverging assertion: [test_file:line]` を追加し 75% を達成したが、13821 が回帰し 14787 が UNKNOWN → EQUIVALENT に悪化した（段階 1 が未解決）。
  - 両フィールドはそれぞれ段階 1・段階 2 に対処するものだが、単独では十分でなかった。現在の SKILL.md にはいずれも含まれていない。

  **NOT_EQUIVALENT → EQUIVALENT（14787）:**
  - iter-19 の Diverging assertion 追加後、14787 は UNKNOWN から EQUIVALENT（誤）に変化した。推測されるメカニズム: 具体的なアサーション file:line を求める構造があっても見つけられなかった場合、エージェントが COUNTEREXAMPLE を満たせないと判断して NO COUNTEREXAMPLE EXISTS（EQUIVALENT）に流れた可能性がある。
  - 段階 1 の到達性確認フィールドが同時に存在することで、テストが変更コードに到達する事実を明示的に確認させ、COUNTEREXAMPLE 探索を正当化できる可能性がある。

## 改善仮説

**「浅い反例」問題は 2 段階の構造的欠陥に起因する。(1) ANALYSIS OF TEST BEHAVIOR で変更コードがテストの実行パスにあるかを確認しない、(2) COUNTEREXAMPLE で具体的なアサーションの file:line を要求しない。この 2 つは同一根本原因（浅い反例）への異なる防止ゲートであり、両方を同時に追加することで相互補完的に機能し、単独適用の限界を超えられる。**

根拠:
- 段階 1 ゲート（到達性確認）: テストが変更コードに到達しない場合、そのテストを反例として使うことを構造的に防ぐ。`NO — mark and skip to next test` によって、不到達テストへの詳細トレースを省略し、ターン消費も抑制する。
- 段階 2 ゲート（アサーション特定）: 到達性確認を通過したテストについて、COUNTEREXAMPLE を満たすには具体的なアサーション file:line の特定が必要になる。差異がアサーションに到達しない場合、このフィールドを埋められず EQUIVALENT に戻るよう誘導する。
- 両フィールドの組み合わせにより: 到達性なし → スキップ、到達性あり → アサーション特定まで要求、という 2 段階チェックが成立する。
- いずれもプログラミング言語・フレームワーク非依存の汎用概念（実行パス、テストアサーション）であり、overfitting ではない。
- 変更規模は 2 行追加（≤ 20 行の制約内）。同一根本原因に対する一体的な修正であり、複数の独立した問題を同時に修正するものではない。

## 変更内容

### 変更 1: ANALYSIS OF TEST BEHAVIOR への到達性確認フィールド追加

```diff
 For each relevant test:
   Test: [name]
+  Changed code on this test's execution path: [YES — cite file:line / NO — mark and skip to next test]
   Claim C[N].1: With Change A, this test will [PASS/FAIL]
```

### 変更 2: COUNTEREXAMPLE へのアサーション特定フィールド追加

```diff
 COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
   Test [name] will [PASS/FAIL] with Change A because [reason]
   Test [name] will [FAIL/PASS] with Change B because [reason]
+  Diverging assertion: [test_file:line — the specific assert/check that produces a different result]
   Therefore changes produce DIFFERENT test outcomes.
```

変更規模: 2 行追加（≤ 20 行の制約内）。  
変更箇所: compare テンプレートの ANALYSIS および COUNTEREXAMPLE ブロックのみ。他のモード・ステップへの影響なし。

## 期待効果

- **15368・13821・15382（EQUIVALENT → NOT_EQUIVALENT 誤判定）**: 段階 1 ゲートにより、変更コードが到達しないテストへの不要なトレースが回避される。到達するテストでも段階 2 ゲートにより具体的なアサーション file:line の特定が必要になり、差異がアサーションに到達しない場合は EQUIVALENT に戻るよう誘導される。
- **14787（NOT_EQUIVALENT → EQUIVALENT 誤判定）**: 段階 1 ゲートで変更コードがテストに到達することを明示的に確認させることで、COUNTEREXAMPLE 探索の正当性が担保され、EQUIVALENT への早期収束を防ぐ効果が期待される。
- **12663（UNKNOWN）**: 段階 1 ゲートにより不要な探索が省かれ、ターン消費が減少することで、31 ターン枯渇前に結論に達しやすくなる可能性がある。
- **回帰リスク**: iter-17・iter-19 の個別適用時に現在正解の 15 件は影響を受けなかった実績がある。両フィールドを同時に追加しても、正解ケースは既に正しいアサーションをトレースしているため、追加フィールドへの記入は確認作業にとどまる。
