# Iter-56 — Proposal

## Exploration Framework カテゴリ: C（強制指定）

### カテゴリ C の定義（Objective.md より）

> C. 比較の枠組みを変える（比較粒度、差異重要度、変更分類）
> - テスト単位ではなく、関数単位・モジュール単位で比較する
> - 差異の重要度を段階的に評価する
> - 変更のカテゴリ分類（リファクタリング/バグ修正/機能追加）を先に行う

### カテゴリ C 内でのメカニズム選択理由

カテゴリ C には 3 つのメカニズムが並ぶ。そのうち「差異の重要度を段階的に評価する」を選択する。

理由は以下の通り。

1. **変更分類（リファクタリング/バグ修正/機能追加）の事前判定**は、STRUCTURAL TRIAGE が既に
   S1（修正ファイル一覧）と S2（完全性）という構造差分を先行評価するステップを持っており、
   変更分類はその自然な延長である。しかし現行の STRUCTURAL TRIAGE は「あるかないか」の二値
   判定（同一ファイルか否か）を行うだけで、差異の影響の深刻度を段階化していない。

2. **差異の重要度の段階評価**は、現行 SKILL.md の ANALYSIS OF TEST BEHAVIOR と
   EDGE CASES RELEVANT TO EXISTING TESTS の間にある空白を埋める。現行は「差異が存在する」
   という事実と「テスト結果が SAME / DIFFERENT か」という二値結論を直接つなぐ構造であり、
   「存在するが軽微」「存在するが全テスト経路外」「存在しかつ実質的」という段階が明示化
   されていない。このためエージェントは意図せず DIFFERENT という結論を回避するか、または
   差異の重さを過大評価して NOT EQUIVALENT に引っ張られやすい。

3. 残りの「テスト単位ではなく関数単位で比較する」は STRUCTURAL TRIAGE S1/S2 と
   Step 4 の interprocedural trace table が既にカバーしており、追加変更の余地が小さい。

よって **「差異の重要度を段階化する」** メカニズムを今回の実装対象とする。

---

## 改善仮説（1つ）

compare モードにおいて、変更間の意味的差異が発見された際にその差異の
**テスト到達可能性（reachability）** を段階的に分類させることで、
エージェントが「差異は存在するが既存テストに到達しない」「差異が到達し
かつ観察可能」という中間状態を明示的に扱えるようになり、
EQUIVALENT 判定の精度（過剰 NOT_EQUIVALENT 方向の誤判定の削減）
と NOT_EQUIVALENT 判定の精度（差異の軽視による誤 EQUIVALENT の削減）
の両方が改善される。

差異の扱いは従来「差異がある → counterexample を探す」という二段跳びだったが、
「差異がある → その差異は既存テストの実行経路上に乗るか → 乗るならどのアサーションに
影響するか」という三段階にすることで、トレースの抜け落ちを減らす。

---

## SKILL.md の変更内容

### 対象箇所

SKILL.md の compare モード内の STRUCTURAL TRIAGE セクション（S1〜S3 の直後、
PREMISES の直前）。

現行は S3 の後に「If S1 or S2 reveals a clear structural gap…」という早期終了
条件が書かれているだけで、差異の重要度段階評価への言及がない。

### 変更前（現行 SKILL.md の該当行 — S3 末尾から PREMISES 直前）

```
  S3: Scale assessment — if either patch exceeds ~200 lines of diff,
      prioritize structural differences (S1, S2) and high-level semantic
      comparison over exhaustive line-by-line tracing. Exhaustive tracing
      is infeasible for large patches and produces unreliable conclusions.

If S1 or S2 reveals a clear structural gap (missing file, missing module
update, missing test data), you may proceed directly to FORMAL CONCLUSION
with NOT EQUIVALENT without completing the full ANALYSIS section.
```

### 変更後

```
  S3: Scale assessment — if either patch exceeds ~200 lines of diff,
      prioritize structural differences (S1, S2) and high-level semantic
      comparison over exhaustive line-by-line tracing. Exhaustive tracing
      is infeasible for large patches and produces unreliable conclusions.
  S4: Difference severity — for each semantic difference found, classify
      it as: (a) NOT_REACHABLE by any relevant test path, (b) REACHABLE
      but producing identical observable outputs, or (c) REACHABLE and
      producing divergent outputs. Only class (c) justifies NOT EQUIVALENT.

If S1 or S2 reveals a clear structural gap (missing file, missing module
update, missing test data), you may proceed directly to FORMAL CONCLUSION
with NOT EQUIVALENT without completing the full ANALYSIS section.
```

### 変更規模の宣言

追加行数: 4 行（S4 の 4 行を新たに追加）
削除行数: 0 行
合計変更: 4 行 ≤ 5 行（hard limit 内）

---

## 一般的な推論品質への期待効果

### 対象となる失敗パターン

1. **過剰 NOT_EQUIVALENT**（EQUIVALENT → NOT_EQUIVALENT 誤判定）  
   意味的差異が検出された時点で NOT EQUIVALENT 結論に飛ぶケース。
   S4 は差異を三クラスに分類する義務を課すため、「差異はあるが (a) or (b)」
   という中間判断を明示化する。これにより NOT_REACHABLE な差異を根拠に
   NOT EQUIVALENT とする早計な結論を抑止する。

2. **差異の軽視による誤 EQUIVALENT**（NOT_EQUIVALENT → EQUIVALENT 誤判定）  
   差異に気づいてはいるが「影響はない」と曖昧に判断して EQUIVALENT に倒すケース。
   S4 の (c) クラスの定義（REACHABLE かつ観察可能な divergent outputs）により、
   差異の重さを根拠なく過小評価することへの抑止が働く。

3. **Guardrail #4（微小差異の却下）の補強**  
   既存 Guardrail #4:「Do not dismiss subtle differences. If you find a semantic
   difference between compared items, trace at least one relevant test through
   the differing code path before concluding the difference has no impact.」
   S4 はこのガードレールを STRUCTURAL TRIAGE の段階に前倒しし、比較の早い段階で
   差異の重要度クラスを確定させる枠組みを提供する。

---

## failed-approaches.md の汎用原則との照合結果

| 原則（要約） | 照合結果 |
|---|---|
| 探索すべき証拠の種類をテンプレートで事前固定しすぎない | 適合：S4 は差異の**分類**を求めるが、どの差異を探すか・どのファイルを読むかは固定しない。探索経路は自由なまま。 |
| 探索の自由度を削りすぎない（ドリフト対策が探索幅を狭める問題） | 適合：S4 は STRUCTURAL TRIAGE 内に置かれ、詳細トレース (Step 3/4) の順序・幅には介入しない。 |
| 局所的な仮説更新を即座の前提修正義務に直結させすぎない | 適合：S4 は差異クラスの宣言であり、前提の再訂正義務は一切含まない。 |
| 既存の汎用ガードレールを特定の追跡方向で具体化しすぎない | 適合：S4 は方向非依存（どの関数・モジュールにも適用可能）な三クラス分類である。 |
| 結論直前の自己監査に新しい必須メタ判断を増やしすぎない | 適合：S4 は結論前ではなく STRUCTURAL TRIAGE（結論よりずっと前の段階）に配置。 |

**抵触する原則: なし**

---

## 変更規模の宣言

- 追加行: 4 行（S4 の項目本文）
- 削除行: 0 行
- Hard limit（5 行）以内: **適合**
- 新規ステップ・新規フィールド・新規セクション: 既存 STRUCTURAL TRIAGE 内の
  S3 に続く番号付き項目（S4）の追加であり、構造上はリストの延長。
  新規セクションの追加ではない。
