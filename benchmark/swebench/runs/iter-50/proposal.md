# Iter-50 — Proposal

## Exploration Framework カテゴリ: C（強制指定）

### カテゴリ内でのメカニズム選択理由

カテゴリ C は「比較の枠組みを変える」であり、次の 3 つのメカニズムを含む。

1. テスト単位ではなく関数単位・モジュール単位で比較する
2. 差異の重要度を段階的に評価する
3. 変更のカテゴリ分類（リファクタリング/バグ修正/機能追加）を先に行う

今回はメカニズム 3「変更のカテゴリ分類を先に行う」を選択する。

理由:
compare モードの STRUCTURAL TRIAGE は「どのファイルが変わっているか」という
構造的な存在チェックを先に行うよう規定している（S1, S2, S3）。しかし 2 つの変更が
同じファイルを変えている場合でも、一方がロジックを書き換えるバグ修正であり、
他方が振る舞いを保存するリファクタリングである場合、変更の性質が根本的に異なるため
等価性の評価観点も変わる。現状の STRUCTURAL TRIAGE はこの「変更の意図的カテゴリ」を
明示的に問わないため、詳細トレースに入る前に観点が揃いにくい。

メカニズム 2（差異の重要度の段階評価）は失敗アプローチにある「探索中の証拠の
優先順位付け半固定」と近接し、特定シグナルの捜索に寄りやすいリスクがある。
メカニズム 1（関数単位比較）は既存の STRUCTURAL TRIAGE の S1/S2 が実質的に
カバーしており、重複になりやすい。

メカニズム 3 は failed-approaches.md のどの原則とも抵触しない。探索経路を固定するの
ではなく、「比較を始める前に何を見ようとしているか」という観点の整合を促すのみで、
探索の自由度は保たれる。

---

## 改善仮説

compare モードで STRUCTURAL TRIAGE を完了した直後に 2 つの変更それぞれの「変更の
意図的カテゴリ（バグ修正 / リファクタリング / 機能追加）」を一言で明示させると、
以降のトレースで「どの差異が等価性に影響しうるか」の判断軸が統一され、
観察的等価性の見落としと過剰な NOT EQUIVALENT 判定の両方が減る。

---

## SKILL.md への具体的な変更内容

対象箇所: Compare セクション STRUCTURAL TRIAGE の S3 の末尾（SKILL.md 行 191–192）

変更前:
```
  S3: Scale assessment — if either patch exceeds ~200 lines of diff,
      prioritize structural differences (S1, S2) and high-level semantic
      comparison over exhaustive line-by-line tracing. Exhaustive tracing
      is infeasible for large patches and produces unreliable conclusions.
```

変更後:
```
  S3: Scale assessment — if either patch exceeds ~200 lines of diff,
      prioritize structural differences (S1, S2) and high-level semantic
      comparison over exhaustive line-by-line tracing. Exhaustive tracing
      is infeasible for large patches and produces unreliable conclusions.
  S4: Change category — for each change, state its intent in one word:
      bug-fix / refactor / feature-add. Mismatched categories (e.g., one
      is a refactor, the other a bug-fix) indicate a higher prior that
      behavioral differences exist and raise the bar for EQUIVALENT.
```

追加行数: 4 行（変更規模 = 4 行 ≦ 5 行の hard limit を満たす）

---

## 期待効果: どのカテゴリ的失敗パターンが減るか

### EQUIV 方向の誤判定（NOT EQUIVALENT が正解なのに EQUIVALENT と判定）
変更カテゴリが不一致（バグ修正 vs リファクタリング）なのに同一視してしまう
パターンが減る。S4 で意図的カテゴリを先に確定させることで、詳細トレースに入る
前から「この差異は振る舞いに影響しうる」という意識が生まれる。

### NOT_EQ 方向の誤判定（EQUIVALENT が正解なのに NOT EQUIVALENT と判定）
両変更が「リファクタリング」と明示された場合、細部の文体的差異を根拠に
NOT EQUIVALENT と早まる判断を抑制する効果がある。カテゴリが一致していれば
等価性の証明バーを高める必要はなく、既存の COUNTEREXAMPLE CHECK に注力できる。

### overall への効果
変更の意図的カテゴリは「何を比較するか」の前提そのものに関わる。これを
STRUCTURAL TRIAGE 内に 1 ステップとして明示することで、全体的な比較の出発点が
揃い、仮説駆動探索（Step 3）の精度も間接的に向上する。

---

## failed-approaches.md との照合

| 原則 | 今回の変更との関係 |
|------|-------------------|
| 探索証拠の種類をテンプレートで事前固定しすぎない | S4 は「どの証拠を探すか」を指定しない。何を読むかではなく、読む前に意図カテゴリを宣言させるのみ。抵触しない。 |
| 探索の自由度を削りすぎない | S4 はトレース順序や読み始め箇所を指定しない。抵触しない。 |
| 局所的仮説更新を前提修正義務に直結させすぎない | S4 は仮説更新とは無関係。抵触しない。 |
| 既存ガードレールを特定の追跡方向で具体化しすぎない | S4 はガードレールの変更ではなくトリアージの拡張。抵触しない。 |
| 結論直前の自己監査に新しい必須メタ判断を増やしすぎない | S4 は STRUCTURAL TRIAGE 内（探索開始前）であり、結論直前ではない。抵触しない。 |

全原則との抵触なし。

---

## 変更規模の宣言

- 追加行: 4 行
- 削除行: 0 行
- hard limit（5 行）以内: YES
