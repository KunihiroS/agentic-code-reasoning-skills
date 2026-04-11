# Iteration 28 — 変更理由

## 前イテレーションの分析

- 前回スコア: 65%（13/20）
- 失敗ケース: django__django-15368, django__django-11179, django__django-13821, django__django-15382, django__django-13417, django__django-14787, django__django-14122
- 失敗原因の分析:
  - EQUIV 偽陽性（4件: 15368, 11179, 13821, 15382）: AI がコード差異を COUNTEREXAMPLE に記録して NOT_EQUIVALENT と結論している。差異の発見から「テスト結果が変わる」という論理ジャンプを、P3/P4 に記載されたテストのアサーション条件への参照なしに行っている。
  - NOT_EQ 偽陰性（2件: 13417, 14787）: 差異がテストの検査内容（P3/P4）に与える影響を十分に追跡できず EQUIVALENT と誤判定している。
  - NOT_EQ 判定不能（1件: 14122）: 推論が収束せず UNKNOWN となった。

## 改善仮説

Compare モードの COUNTEREXAMPLE ブロックで反例の `[reason]` が自由テキストであるため、AI は「コード差異が存在する → NOT_EQUIVALENT」という論理ジャンプを PREMISES（特に P3/P4）への参照なしに記述できてしまう。Fault Localization テンプレート（Phase 3）が `CLAIM D1: ... which contradicts PREMISE T[N]` という前提参照を必須とするのと同様に、COUNTEREXAMPLE ブロックにも `By P[N]` フィールドを追加して論理接続の明示を要求することで、コード差異 → テスト結果への因果連鎖の検証を強制し、EQUIV 偽陽性を削減できる。

NO COUNTEREXAMPLE EXISTS ブロックにも対称的に P[N] のアサーション条件を明示させることで、EQUIV 主張時の反証探索が P3/P4 の具体的な検査内容に基づくものになる。

## 変更内容

`## Compare` セクションの Certificate template 内の2箇所を修正:

1. **COUNTEREXAMPLE ブロック**: `[reason]` を `[trace — cite file:line]` に変更し、`By P[N]:` フィールドを1行追加。
   - 変更前: 自由テキストの `[reason]`
   - 変更後: `[trace — cite file:line]` + `By P[N]: this test checks [assertion/behavior stated in P3 or P4], and the divergence above causes that assertion to produce a different result.`

2. **NO COUNTEREXAMPLE EXISTS ブロック**: `[describe concretely: what test, what input, what diverging behavior]` を P[N] のアサーション条件を含む記述に変更。
   - 変更前: `what test, what input, what diverging behavior`
   - 変更後: `what test, what assertion in P[N], what code difference would cause that assertion to produce a different result`

合計変更: +2行追加、1行変更。

## 期待効果

- **EQUIV 正答率の改善（+10〜20pp 予測）**: `By P[N]` フィールドを必須にすることで、AI は「このコード差異が P3/P4 に記載されたテストのアサーション条件とどう矛盾するか」を明示しなければならない。差異がテストの検査内容に影響しない場合、有効な `By P[N]` を書けないため COUNTEREXAMPLE を成立させられず、誤った NOT_EQUIVALENT 判定を抑制できる。
- **NOT_EQ 正答率への影響（0〜-5pp 予測）**: 正当な NOT_EQ ケースでは P3/P4 がテストの検査内容を記述しており、`By P[N]` は自然に書ける。BL-14（backward trace 全体）と異なり、1文の接続確認にとどまるため認知負荷の大幅な増加は見込まれない。
