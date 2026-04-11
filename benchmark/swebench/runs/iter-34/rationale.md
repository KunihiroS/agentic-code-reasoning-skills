# Iteration 35 — 変更理由

## 前イテレーションの分析

- 前回スコア: 70%（14/20）
- 失敗ケース: django__django-15368, django__django-13821, django__django-15382, django__django-13417, django__django-11433, django__django-14122
- 失敗原因の分析:
  - **EQUIV 偽陽性（15368, 13821, 15382）**: コード差異を発見した時点でトレースを打ち切り、「コード差分 → テスト結果が異なる」と短絡推論している。内部実装の差異が外部可観測な契約（return value / exception / state / calls）に実際に影響するかを検証しないまま `Comparison: DIFFERENT` と結論している。
  - **NOT_EQ UNKNOWN（13417, 11433, 14122）**: 探索対象が広すぎ、31 ターン内に証拠が収束しない。どのテストが「この変更の可観測な出力を assert しているか」を絞り込めないまま探索が拡散する。

## 改善仮説

現行テンプレートでは比較分析がいきなり「テスト単位」から始まるため、エージェントは次のショートカットを取りやすい。

- **EQUIV 偽陽性方向**: コード差異の有無をスキャン → 差異発見 → `Comparison: DIFFERENT` と即断（関数の外部可観測な出力が実際に変わるかを検証しない）
- **NOT_EQ UNKNOWN 方向**: relevant test 候補が多く探索が収束しない（どのテストが「この変更の可観測な出力を assert しているか」の絞り込みができない）

**共通の欠如**: 変更された関数が外部に何を公開しているか（return value / exception / state mutation / emitted call）を**テスト分析の前**に明確にするステップがない。

テスト単位の比較（ANALYSIS OF TEST BEHAVIOR）を始める前に、変更された各関数・シンボルの「外部可観測な契約（Observable Contract）」を列挙し、差分の scope を確認する CONTRACT SURVEY ステップを追加することで:

1. **EQUIV 偽陽性の抑制**: 関数内部の実装差異が外部可観測契約を実際に変えるかどうかを先に確認する。契約が変わらなければ、テスト分析での「差異が DIFFERENT outcome を生むか」という問いへの答えが絞られる。
2. **NOT_EQ UNKNOWN の解消**: 可観測契約のうち「diff が触れうる category」が先に特定されることで、その category を直接 assert するテストに探索を集中できる。探索幅が絞られ、ターン内に収束しやすくなる。

## 変更内容

`compare` テンプレートの PREMISES と ANALYSIS OF TEST BEHAVIOR の間に CONTRACT SURVEY セクションを追加した。

```
CONTRACT SURVEY (one entry per changed function/symbol):
  Function: [name — file:line]
  Contract: return [value type/semantics]; raises [exception or NONE];
            mutates [persistent state or NONE]; calls [observable side-effects or NONE]
  Diff scope: which contract element(s) could this diff alter? [list or NONE]
  Test focus: tests that directly assert the listed Diff scope element(s)
```

- 追加: 6 行
- 変更: 0 行
- 削除: 0 行

## 期待効果

- **EQUIV 偽陽性（15368, 13821, 15382）の改善**: CONTRACT SURVEY がコード差異と可観測契約変化の間のギャップを先に検証させることで、内部差異をそのまま DIFFERENT outcome に短絡させるパターンを抑制できる。`Diff scope: NONE` と確認できれば、テスト分析での短絡を防ぐ。
- **NOT_EQ UNKNOWN（13417, 11433, 14122）の改善**: `Test focus` により可観測出力を assert するテストへ探索を集中でき、ターン効率が改善する。探索幅の削減により 31 ターン内での収束が期待できる。
- **全体予測**: 70% → 85〜100%
