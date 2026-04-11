# Iteration 57 — 改善提案

## 親イテレーション (iter-33) の選定理由

iter-33 (スコア 70%, 14/20) はスコア的には低いが、その失敗パターンに明確な因果関係があるため、
改善の起点として選んだ。

iter-33 の直前のベースライン（iter-32 相当）は 85%（17/20）であり、iter-33 で追加した
D2 の 5 行が NOT_EQ 側の 3 件（13417, 11433, 14122）を新たに UNKNOWN（31 turns）へ
退行させた。つまり iter-33 の変更は EQUIV 偽陰性 3 件を解決しないまま、新たに NOT_EQ
UNKNOWN 3 件を引き起こした。この因果関係が明確なため、「iter-33 の追加を差し戻す」
という仮説が検証可能かつ効果が予測しやすい。

## Exploration Framework カテゴリ

**カテゴリ E: 表現・フォーマットを改善する**（具体的には「冗長・有害な指示を削除して
認知負荷を下げる」）

### 選択理由

- iter-33 自身はカテゴリ B（情報の取得方法を改善する）を選択し、テスト読解の優先順序と
  検索制限を D2 に追加した。今回は「追加した指示が推論品質を下げた」という逆方向の
  診断に基づく修正であるため、カテゴリ E（表現整理・簡潔化）が最適。
- カテゴリ A（推論順序）、B（情報取得）、D（メタ認知）では数多くの失敗が蓄積しており、
  安全に試せる余地が少ない。
- カテゴリ E の「冗長な部分を簡潔にして認知負荷を下げる」は直接適合する。

## 改善仮説（1つ）

**iter-33 が D2 に追加した 5 行（テスト読解優先順序 ＋ 検索制限句）を削除することで、
NOT_EQ 側 3 件の UNKNOWN 退行が解消され、スコアが 70% → 85% 前後に回復する。**

根拠：

1. **検索制限 "Do not expand the search to callers or wrappers not referenced by tests."**
   が、NOT_EQ 証拠を間接テスト経由でしか見つけられないケース（13417, 11433, 14122）で、
   エージェントが適切なテストに到達できずにターン上限（31 turns）を使い切った可能性が高い。

2. **テスト優先順序 "read first those whose assertions directly observe the primary output"**
   は、直接アサーションを持つテストを優先させることで、間接テストが証拠となる NOT_EQ
   ケースを後回しにし、前述の問題を悪化させた可能性がある。

3. pre-iter-33 状態（D2 にこの追加なし）は 85%（17/20）を達成しており、同一 SKILL.md
   の他のすべての部分は変更されていない。差し戻しにより 85% 相当の性能に戻ると期待できる。

## SKILL.md のどこをどう変えるか

### 変更箇所

`## Compare` セクション内の Certificate template の `DEFINITIONS D2` ブロック。

### 変更内容（削除のみ）

**Before（iter-33 追加済みの現在の状態）：**

```
    To identify them: search for tests referencing the changed function, class,
    or variable. When multiple tests are found, read first those whose
    assertions directly observe the change's primary output — its return value,
    raised exception, or directly modified attribute — before tests that only
    transitively invoke the changed code through intermediate layers. Do not
    expand the search to callers or wrappers not referenced by tests.
    If the test suite is not provided, state this as a constraint
    in P[N] and restrict the scope of D1 accordingly.
```

**After（差し戻し後）：**

```
    To identify them: search for tests referencing the changed function, class,
    or variable. If the test suite is not provided, state this as a constraint
    in P[N] and restrict the scope of D1 accordingly.
```

### 変更規模

- **追加行数**: 0 行（hard limit: 5 行以内 ✅）
- **削除行数**: 5 行（制限対象外）

## EQUIV と NOT_EQ の両方の正答率への影響予測

### NOT_EQ 正答率（現状 7/10 → 期待 10/10）

- 13417, 11433, 14122 の 3 件はいずれも 31 turns（ターン上限）で UNKNOWN だった。
- 削除により「callers/wrappers への検索を禁止する」制限がなくなり、エージェントが
  間接テストを通じて NOT_EQ 証拠を発見できるようになる。
- これら 3 件は pre-iter-33 時点では正答していたため、差し戻しにより正答に戻ると予測。

### EQUIV 正答率（現状 7/10 → 期待 7/10 維持または 8/10 微改善）

- EQUIV 偽陰性 3 件（15368, 13821, 15382）は pre-iter-33 時点でも不正解だった。
  本提案ではこれらは直接改善しない（別イテレーションの課題）。
- ただし「テスト読解優先順序」の削除により、エージェントが固定された優先バイアスなく
  テストを探索できるようになり、EQUIV 側で微改善の可能性もある（期待値は変化なし）。
- 悪化リスクは低い：pre-iter-33 時点で EQUIV は 7/10 が正答しており、D2 を元に戻す
  だけなのでその状態より悪化する根拠がない。

## failed-approaches.md のブラックリストおよび共通原則との照合

### ブラックリスト照合

| BL | 内容 | 本提案との関係 |
|----|------|---------------|
| BL-17 | caller/wrapper へ検索を積極的に拡張 → 70% に低下 | 本提案は「拡張禁止の解除」であり、積極的拡張命令の追加ではない。中立状態への復帰。異なるメカニズム |
| BL-22 | 特定パターンからの関連性推定を禁止 → 75% に低下 | 本提案は禁止文の削除。同様に禁止を追加する方向ではない |
| その他 | 各 BL は「何かを追加して失敗」 | 本提案は「追加を削除して戻す」のみ。追加はゼロ |

**ブラックリスト抵触なし。**

### 共通原則との照合

| # | 原則 | 照合 |
|---|------|------|
| 1 | 判定の非対称操作は必ず失敗する | 削除対象の「Do not expand」は NOT_EQ 側にのみ不利な制限だった。削除することで非対称性が解消される。✅ |
| 2 | 出力側の制約は効果がない | 削除のみ。出力制約の追加なし。✅ |
| 3 | 探索量の削減は常に有害 | 検索制限の削除＝探索量の回復。✅ |
| 4 | 同じ方向の変更は表現を変えても同じ結果 | 差し戻し後は「前回成功した状態」への復帰。新しい方向性の変更ではない。✅ |
| 5 | 入力テンプレートの過剰規定は探索視野を狭める | 過剰規定の削除。原則の正方向への適用。✅ |
| 13 | relevant test 集合の低精度な拡張は有害 | 拡張命令は追加していない。中立状態への復帰のみ。✅ |
| 14 | 条件付き特例探索追加でも主ループを強化しなければ低下 | 特例探索命令の追加なし。✅ |
| 16 | ネガティブプロンプトによる禁止は過剰適応を招く | ネガティブプロンプト（"Do not expand"）を削除する側。原則の正方向。✅ |

**共通原則抵触なし。**

## 変更規模の宣言

- **追加行数**: 0 行（hard limit 5 行以内 ✅）
- **削除行数**: 5 行（制限対象外）
- **変更対象**: `## Compare` セクション → Certificate template → `DEFINITIONS D2` ブロックのみ
- **変更性質**: iter-33 で追加した 5 行を完全に差し戻す。他のセクション・フィールド・
  テンプレートへの変更なし。研究のコア構造（番号付き前提、仮説駆動探索、手続き間トレース、
  必須反証）はすべて維持。
