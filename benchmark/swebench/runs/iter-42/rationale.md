# Iteration 43 — 変更理由

## 前イテレーションの分析

- 前回スコア: 85%（17/20）
- 失敗ケース: django__django-15368, django__django-15382, django__django-14122
- 失敗原因の分析:
  - 15368（EQUIV → NOT_EQ）: 変更関数にコード差分を発見した後、`because [trace through code — cite file:line]` の要件を「差分がある関数の行を引用する」ことで満たせてしまうため、その関数の実定義を test 固有の inputs で確認せずに NOT_EQ を結論した。差分が test inputs に到達しない（effect が同一）にもかかわらず DIFFERENT と判定された。
  - 15382（EQUIV → NOT_EQ）: 同上のパターン。関数名と差分要約を `because` 節に記載しただけで Claim を確定し、実定義確認なしに NOT_EQ に短絡した。
  - 14122（NOT_EQ → UNKNOWN）: ターン枯渇が主因。本変更の直接的な対象ではない。

## 改善仮説

Compare テンプレートの `because` 節は `[trace through code — cite file:line]` とあるだけで、「cited された関数について実定義を読み、この test の具体的な inputs への verified effect を記録する」という要件が明示されていない。そのため、エージェントは関数名や差分要約を根拠に Claim を書け、実定義を test-specific inputs で確認せずに結論を出せてしまう。

この「証拠の質要件の欠如」が EQUIV 偽陰性の根本原因である。`because` 節に「Claim で引用する各関数について、実定義を読みこの test の具体的な inputs への verified effect を記録する（名前や差分要約を書くのではなく）」という要件を追加することで、エージェントは実定義確認なしに `because` 節を満たせなくなり、test inputs への effect が同一であれば Comparison: SAME → EQUIV に正しく判定できるようになる。

原論文（Ugare & Chandra, arXiv:2603.01896）のコアメカニズムである VERIFIED 証拠の要求は Step 4 トレーステーブルには適用されているが、Compare Claim の `because` 節には引き継がれていなかった。本変更はこの未活用の論文アイデアを `because` 節に適用するものである。

## 変更内容

`## Compare` → `### Certificate template` → `ANALYSIS OF TEST BEHAVIOR` の fail-to-pass / pass-to-pass 両ブロックの `Claim` 行を修正（計 4 行置換）:

**fail-to-pass の `because` 節（×2 行）:**
- 変更前: `because [trace through code — cite file:line]`
- 変更後: `because [trace through code — for each function cited, read its definition and state its verified effect on this test's specific inputs at file:line, not merely a summary of the diff]`

**pass-to-pass の `behavior is` 節（×2 行）:**
- 変更前: `behavior is [description]`
- 変更後: `behavior is [description — verified at file:line]`

変更規模: 4 行置換（新規フィールド追加なし、行数増加なし）。

## 期待効果

- **django__django-15368（EQUIV 偽陰性）**: エージェントが変更関数 X の差分を発見した後、`because` 節を満たすために X の実定義を test-specific inputs で確認することを強いられる。X の effect が test inputs に到達しないことを実定義から確認すれば Claim: PASS → Comparison: SAME → EQUIV に正しく判定できる。改善可能。
- **django__django-15382（EQUIV 偽陰性）**: 同上のメカニズム。改善可能。
- **django__django-14122（NOT_EQ → UNKNOWN）**: 変化なし。ターン枯渇が主因であり本変更の直接的な作用は限定的。
- **既存正答ケース（NOT_EQ 9件）**: 真の NOT_EQ では、cited 関数の実定義を test inputs で確認しても effect が異なることが確認されるため結論は変わらない。Claim に引用済みの関数に対象を限定しているため、探索スコープの全面拡張にはならずターン消費の増大も最小限に抑えられる。

期待スコア: 85%（17/20）→ 90〜95%（EQUIV が +1〜2 改善）
