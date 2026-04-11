# Iteration 35 — 変更理由

## 前イテレーションの分析

- 前回スコア: 75%（15/20）
- 失敗ケース: django__django-15368, django__django-11179, django__django-13821, django__django-15382, django__django-14787
- 失敗原因の分析:
  - django__django-15368, django__django-11179, django__django-13821: EQUIV 偽陰性。コード差異を発見した時点で Change A と Change B の observable behavior を対称的に比較せず、DIFFERENT と即断した。
  - django__django-15382: EQUIV 収束失敗。同様に A/B の observable behavior の同一性を確認する場がなく、UNKNOWN に終わった。
  - django__django-14787: NOT_EQ 収束失敗。contract が異なる次元が不明確なまま探索が拡散し、31 ターン内に収束できなかった。

## 改善仮説

Compare テンプレートの PREMISES と ANALYSIS OF TEST BEHAVIOR の間に CONTRACT DELTA セクションを追加し、各変更シンボルについて Change A / Change B の外部可観測契約（return / raises / mutates / emits）を同一フォーマットで別行記述させ、`Delta:（A ≠ B な次元、または SAME）` を明示させることで、EQUIV 偽陰性を抑制できる。

現行テンプレートでは、エージェントが「コード差異発見 → DIFFERENT 即断」という短絡を取りやすい。CONTRACT DELTA により `Change A observable:` と `Change B observable:` を並べて書くことが強制され、「A も B も同じ値を返す → Delta: SAME」という明示的な対称比較ステップが生まれる。

## 変更内容

Compare テンプレートの certificate template 内、`P4: The pass-to-pass tests check ...` と `ANALYSIS OF TEST BEHAVIOR:` の間に CONTRACT DELTA セクション（7行）を追加した。既存の行はいっさい変更していない。

```
CONTRACT DELTA (one entry per changed symbol):
  Symbol: [name]
  Change A — observable: return [semantics at file:line]; raises [exception or NONE]; mutates [state or NONE]; emits [call or NONE]
  Change B — observable: return [semantics at file:line]; raises [exception or NONE]; mutates [state or NONE]; emits [call or NONE]
  Delta: [dimension(s) where A ≠ B — or SAME if no observable dimension differs]
  Test focus: tests that assert the Delta dimension(s)
```

## 期待効果

- **EQUIV（現状 60% → 予測 70〜80%）**: `Delta: SAME` を確定させることで、ANALYSIS でのコード差異→DIFFERENT 短絡を防ぐ。特に「内部実装は異なるが observable behavior は同じ」パターン（django__django-15368 等の典型）で効果が期待できる。
- **NOT_EQ（現状 90% → 予測 85〜90%）**: `Delta: return differs` のように明示されると、その次元を assert するテストへの探索フォーカスが絞られ、収束を助ける。本変更は既存 checklist item 5 を変更しないため、EQUIV 側ガードも維持される。
- **全体予測**: 80〜85%（EQUIV 7〜8/10 + NOT_EQ 8〜9/10）
