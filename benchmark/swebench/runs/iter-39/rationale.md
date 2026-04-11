# Iteration 39 — 変更理由

## 前イテレーションの分析

- 前回スコア: 75%（15/20）
- 失敗ケース: django__django-15368, django__django-13821, django__django-15382, django__django-14787, django__django-11433
- 失敗原因の分析:
  - 15368, 13821, 15382（EQUIV → NOT_EQUIVALENT 誤判定）: エージェントが直接変更された関数を読み、コードレベルの差異を発見した時点で「差異あり → DIFFERENT」と結論した。変更後の return value が immediate caller によって正規化・吸収されるかを確認しないまま NOT_EQUIVALENT と判定したと推定。
  - 14787（NOT_EQUIV → UNKNOWN）: 変更の影響範囲トレースが不完全で結論に至れなかった。
  - 11433（NOT_EQUIV → EQUIV 誤判定）: 変更の差異が caller を通じてテスト assertion まで伝播することを確認せずに EQUIVALENT と判定したと推定。

## 改善仮説

Compare checklist に「直接変更された関数を読んだ直後に、その immediate caller が変更後の return value または side-effect をどう使っているかを読め — テスト assertion に向かう方向へ少なくとも 1 ステップ追跡せよ」という探索行動義務を 1 行追加することで、エージェントが「変更コードに差異を発見 → 即 DIFFERENT」というショートカットを踏む前に、変更の影響が実際にテスト assertion まで伝播するかを自然に確認するようになる。

これは原論文（Ugare & Chandra, arXiv:2603.01896）Section 4 の anti-skip 機構に対応する。既存の checklist 第 3 項「For each function called in changed code」は下方向トレース（変更コード → 呼び出し先）を要求するが、上方向トレース（変更コード → 呼び出し元 caller の use）が欠落していた。本提案はこの欠落を補完する。

## 変更内容

SKILL.md の Compare checklist に 1 行を追加した。

変更箇所: Compare checklist の 3 行目と 4 行目の間

```diff
- For each function called in changed code, read its definition and record in the interprocedural trace table (Step 4)
+ After reading a directly changed function, read how its immediate caller uses the changed return value or side-effect — trace at least one step toward the test assertion
- Trace each test through both changes separately before comparing
```

追加: +1 行、変更・削除: 0 行

## 期待効果

### EQUIV 正答率（現在 7/10）→ 8〜9/10 改善見込み

- 15368, 13821, 15382: immediate caller の use を読む義務が発生することで、caller が差異を吸収・正規化するケースを発見できるようになる → EQUIVALENT の正しい判定につながる。

### NOT_EQ 正答率（現在 8/10）→ 8/10 維持見込み

- 真の NOT_EQUIV ケースでは caller が差異を伝播させるため、caller の use を読むことで伝播が確認され、NOT_EQUIVALENT の根拠が強化される。
- 本変更は「DIFFERENT と主張する前に確認せよ」という結論段階の非対称制約ではなく、探索段階の行動義務であるため、既存の正答ケースに悪影響を与えない。
