# Proposal — iter-104

## フォーカスドメイン: `not_eq`
2 つの実装が **異なる振る舞い** を持つと判定する精度の向上。

---

## Exploration Framework カテゴリと選定理由

**カテゴリ E — 表現・フォーマットを改善する**
（「曖昧な指示をより具体的な言い回しに変える」）

`not_eq` 失敗の典型パターンは次の通りである。モデルは ANALYSIS
ステップで意味論的な発散点を正しく発見するが、その発散が「テストアサーションに
到達しない」という誤った伝播追跡を行って EQUIVALENT に収束してしまう。
この誤判定の根底には、現在の Compare チェックリスト内の文言にある曖昧さがある。

「trace at least one relevant test through the differing path」という
指示は「1 件追跡すれば十分」という解釈を許容する。最初に追跡したテストで
伝播なし（SAME）と結論した場合、残りの fail-to-pass テストを追跡せずに
全体を EQUIVALENT と判定する誤りが起きる。
カテゴリ E の「曖昧な指示を具体的な言い回しに変える」アプローチにより
この曖昧さを解消できる。新規ステップや新規フィールドは一切不要で、
既存チェックリスト項目の精緻化のみで効果が得られる。

---

## 改善仮説（1つ）

**仮説**: 意味論的な発散点が発見された後、すべての fail-to-pass テストに
対して伝播追跡を実施することを明示的に義務化すれば、最初の SAME 結論による
早期打ち切りが防止され、`not_eq` の判定精度が向上する。

現状の「at least one relevant test」という文言は最小例の提示に過ぎず、
fail-to-pass テストのうち発散が到達するものとしないものが混在するケースで、
発散が到達しないテストを先に調べた場合に false EQUIV を誘発する。
fail-to-pass テスト全件への追跡義務はこの経路を封じる。

---

## SKILL.md への変更内容

**変更箇所**: `## Compare` → `### Compare checklist` 内の 1 行

**変更前**:
```
- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact
```

**変更後**:
```
- When a semantic difference is found, trace each fail-to-pass test through the differing path before concluding it has no impact on test outcomes
```

変更内容:
1. `at least one relevant test` → `each fail-to-pass test`
   （追跡対象の曖昧な下限を、既に D2(a) で定義済みの fail-to-pass テスト全件に限定）
2. `has no impact` → `has no impact on test outcomes`
   （「影響なし」の意味を判定に直結するテスト結果に明示的に限定）

---

## 期待効果

### `not_eq` 精度への効果
- **直接対象となる失敗パターン**: 意味論的発散を発見しながら、追跡した 1
  件のテストで伝播なし (SAME) と判断し、残りのテストを調べずに EQUIVALENT
  と誤判定するケース。
- fail-to-pass テスト全件の追跡を義務化することで、発散が到達するテストが
  1 件でも存在すれば NOT EQUIVALENT が正しく導出される。

### `equiv` 精度への影響
- fail-to-pass テスト全件を追跡し全件で SAME → EQUIVALENT という結論の
  構造自体は変わらない。
- 追跡件数が増えることで探索コストが若干増加するが、fail-to-pass テスト数は
  通常少なく、既存テンプレートの "For each relevant test:" と整合する範囲。

### 減少が期待される失敗カテゴリ
- **早期打ち切りによる false EQUIVALENT**: 最初の追跡で SAME → 全体 EQUIV の論理飛躍
- **不完全な伝播追跡**: 一部のテストのみ追跡した不完全な根拠に基づく EQUIV 判定

---

## failed-approaches.md 汎用原則との照合

| 原則 | 該当内容 | 判定 |
|------|---------|------|
| #1 判定の非対称操作 | 発散発見後の追跡範囲拡大はEQUIV/NOT_EQ 双方に対称的に作用する | 非抵触 |
| #2 出力側制約は無効 | 出力への制約ではなく「どう探索するか」という処理側の改善 | 非抵触 |
| #3 探索量削減は有害 | fail-to-pass 全件追跡は探索量を増加させる方向 | 非抵触 |
| #13 関連テスト集合の低精度拡張 | fail-to-pass テストは既に D2(a) で高精度に定義済みの集合。集合を拡張していない | 非抵触 |
| #14 条件付き特例探索の追加 | 「発散が見つかった場合」に発動するが、これは中心ループの tracing 強化であり side-quest 追加ではない | 非抵触 |
| #17 中間ノードの局所分析義務化 | 中間ノード分析を義務化するのではなく、エンドツーエンドの追跡対象テストの数を増やす変更 | 非抵触 |
| #18 特定証拠への物理的裏付け要求 | file:line レベルの引用を要求していない | 非抵触 |
| #22 抽象原則内の具体物例示 | "each fail-to-pass test" は物理的探索目標ではなく、既定義の概念カテゴリ（D2a）への参照 | 非抵触 |

その他の原則（#4〜#12, #15, #16, #19〜#21, #23〜#27）との抵触も検討し、
いずれも該当しないことを確認した。

---

## 変更規模の宣言

- **変更行数**: 1 行の文言置換（削除 1 行 + 追加 1 行）
- **Hard limit（5 行）**: 遵守（追加行数 = 1）
- **新規ステップ・新規フィールド・新規セクション**: なし
- **削除行**: 1 行（カウント対象外）
