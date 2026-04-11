# Iteration 37 — 変更理由

## 前イテレーションの分析

- 前回スコア: 65%（13/20）
- 失敗ケース: django__django-15368, django__django-11179, django__django-13821, django__django-15382, django__django-14787, django__django-11433, django__django-12663
- 失敗原因の分析:
  - EQUIV 偽陰性（4件: 15368, 11179, 13821, 15382）: エージェントがコード差異を発見した後、その差異がテストの比較値に到達するかを確認せずに Claim FAIL と書く。テストが実際に比較している値を読まずに NOT_EQ と誤判定している。
  - UNKNOWN（3件: 14787, 11433, 12663）: ターン数超過による未判定。探索コスト増加が原因であり、今回の変更対象外。

## 改善仮説

各 relevant test についてテストソースを読み「テストが pass/fail を決定するために読む・比較するデータ依存値」を先に特定し、その値の生成元を 1 段逆方向に確認してから Claim を書く探索行動を追加することで、コード差異の発見でトレースを打ち切るショートカットが構造的に減り、EQUIV 偽陰性（EQUIV を NOT_EQ と誤判定）を減らせる。

現在の失敗パターンでは、エージェントは「Change A と Change B で関数 X が返す値が違う」というコード差異を発見し、その差異がテストの比較値に到達するかを確認せずに Claim FAIL と書く。テストが実際に比較している値（例: `assertEqual(response.status_code, 200)` の `response.status_code`）を先に特定すれば、変更がその値に影響するかどうかを確認する動機が生まれ、影響しない場合は Claim を PASS に修正できる。

## 変更内容

Compare checklist に探索指示を 1 行追加した。

追加行:
```
- For each relevant test, read the test to identify the data value it reads or compares to determine pass/fail; trace back one step to where that value is produced and verify whether the change affects it before writing a Claim
```

変更規模: 1 行追加のみ。テンプレートフィールド変更なし。新セクション追加なし。

## 期待効果

- EQUIV 正答率の改善を期待（現在 6/10 → 7〜9/10）。失敗していた 15368, 11179, 13821, 15382 において、テストの比較値を先に特定する探索ステップが挿入されることで、変更がその値に影響しないと確認できれば Claim を PASS に修正できる。
- NOT_EQ 正答率への悪影響なし（現在 7/10 → 維持 or 改善）。真の NOT_EQ ケースでは変更がテストの比較値に確かに影響を与えるため、追加の確認ステップは結論を変えない。
- UNKNOWN ケース（14787, 11433, 12663）への影響なし。追加は 1 ステップの確認のみであり、ターン数超過の原因となる探索コストを増やさない。
