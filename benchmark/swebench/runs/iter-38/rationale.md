# Iteration 38 — 変更理由

## 前イテレーションの分析

- 前回スコア: 75% (15/20)
- 失敗ケース: django__django-15368, django__django-13821, django__django-15382, django__django-14787, django__django-14122
- 失敗原因の分析:
  - **EQUIV 偽陰性 3件（15368、13821、15382）**: エージェントはコード差異を発見した後、「その差異がテストのアサーションに到達するか（P3 が記述する動作に影響するか）」を確認せずに Claim FAIL と記録した。コード差異 ≠ テスト動作差異であるケースで、P3 の動作への接続確認が省略されていた。
  - **NOT_EQ 偽陽性 1件（14787）**: EQUIV であるにもかかわらず NOT_EQUIVALENT と判定。P3 の期待動作への接続追跡が不十分だった。
  - **UNKNOWN 1件（14122）**: 判定不能として出力。探索・証拠不足が原因。

## 改善仮説

compare モードの Claim テンプレートに、localize モードの「クレームはプレミスを参照する」構造を導入する。

localize モードの PHASE 3 では各 CLAIM が `which contradicts PREMISE T[N] because [reason]` という形でプレミスへの明示的参照を要求する。一方、compare モードの Claim テンプレートの `because` 節は「コードトレース + file:line 引用」を求めるのみで、「そのトレース結果が P3/P4（テストが何を検証するかを記述するプレミス）に対してどう接続するか」の確認を要求していなかった。

Claim テンプレートに `show whether the behavior in P[N] is satisfied or violated` を追加することで、エージェントは「コード差異を発見 → 即 FAIL」というショートカットを踏む前に、コードトレースの終端を P3/P4 の期待動作と照合する義務を負う。

## 変更内容

`## Compare` セクションの `ANALYSIS OF TEST BEHAVIOR` における Claim テンプレート（2行）を変更した。

**変更前**:
```
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
```

**変更後**:
```
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace through code and show whether the behavior in P[N]
                is satisfied or violated — cite file:line]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace through code and show whether the behavior in P[N]
                is satisfied or violated — cite file:line]
```

（P[N] = fail-to-pass テストに対しては P3、pass-to-pass テストに対しては P4）

変更規模: 2行修正 + 継続行 2行追加、合計 4行。新規セクション・フィールド追加なし。

## 期待効果

- **EQUIV 正答率の改善（7/10 → 8〜9/10 見込み）**: 15368、13821、15382 では「コード差異はあるが P3 の動作は変わらない → PASS/PASS → SAME」という推論経路が明示的になることで、EQUIV 偽陰性が減少する。
- **NOT_EQ 正答率の維持（8/10）**: 真の NOT_EQ ケースでは変更が P3 の動作を実際に違反するため、`show whether P3 is violated` を要求しても NOT_EQ の立証責任が一方的に高まるわけではない。14787 についても P3 との明示的接続要求が改善に寄与する可能性がある。
