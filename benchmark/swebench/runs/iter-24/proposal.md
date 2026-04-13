# Iteration 24 — Proposal

## Exploration Framework カテゴリ

カテゴリ: A — 推論の順序・構造を変える

### カテゴリ A 内の具体的なメカニズム選択

カテゴリ A には以下の三つのメカニズムが列挙されている:

1. ステップの実行順序を入れ替える
2. 並列に行っていた分析を直列にする（またはその逆）
3. 結論から逆算して必要な証拠を特定する（逆方向推論）

今回は **メカニズム 3「逆方向推論」** を選択する。

理由: `compare` モードにおける現在のフローは「変更 A と変更 B を順方向にトレースし、最後に差異があれば NOT EQUIVALENT と結論づける」という構造である。この順方向アプローチでは、推論者が EQUIVALENT へ収束しそうだと感じた時点で反証探索を浅く打ち切るリスクがある。逆方向推論、すなわち「EQUIVALENT であるとしたら成立しなければならない必要条件を先に列挙し、そのうちのどれが崩れるかを見る」というアプローチは、反証すべき具体的なターゲットを先に明示することで、無意識の確証バイアスによる早期収束を構造的に防ぐ。これは Objective.md の Exploration Framework が定義する「逆算して必要な証拠を特定する」に直接対応する。

---

## 改善仮説

`compare` モードの STRUCTURAL TRIAGE セクションにおいて、構造的な等価性の必要条件を先に宣言させ、その後の詳細トレースをその必要条件の検証として位置づけることで、順方向トレースの終盤での反証スキップを減らし、EQUIVALENT の誤判定を抑制できる。

---

## SKILL.md の変更内容

### 変更箇所

`compare` モードの `STRUCTURAL TRIAGE` ブロック（SKILL.md 180〜191 行目）に、必要条件の事前宣言を求める一文を追加する。

### 変更前

```
STRUCTURAL TRIAGE (required before detailed tracing):
Before tracing individual functions, compare the two changes structurally:
  S1: Files modified — list files touched by each change. Flag any file
      modified in one change but absent from the other.
  S2: Completeness — does each change cover all the modules that the
      failing tests exercise? If Change B omits a file that Change A
      modifies and a test imports that file, the changes are NOT EQUIVALENT
      regardless of the detailed semantics.
  S3: Scale assessment — if either patch exceeds ~200 lines of diff,
      prioritize structural differences (S1, S2) and high-level semantic
      comparison over exhaustive line-by-line tracing. Exhaustive tracing
      is infeasible for large patches and produces unreliable conclusions.
```

### 変更後 (追加 1 行、変更 0 行)

```
STRUCTURAL TRIAGE (required before detailed tracing):
Before tracing individual functions, compare the two changes structurally:
  S0: Equivalence preconditions — before reading any code, state what must
      be true for the two changes to be EQUIVALENT, then treat each item as
      a falsification target during S1–S3 and the ANALYSIS that follows.
  S1: Files modified — list files touched by each change. Flag any file
      modified in one change but absent from the other.
  S2: Completeness — does each change cover all the modules that the
      failing tests exercise? If Change B omits a file that Change A
      modifies and a test imports that file, the changes are NOT EQUIVALENT
      regardless of the detailed semantics.
  S3: Scale assessment — if either patch exceeds ~200 lines of diff,
      prioritize structural differences (S1, S2) and high-level semantic
      comparison over exhaustive line-by-line tracing. Exhaustive tracing
      is infeasible for large patches and produces unreliable conclusions.
```

---

## 期待効果

### 改善が見込まれる失敗パターン

EQUIVALENT の誤判定（equiv の偽陽性）は多くの場合、詳細トレースが終盤に差し掛かった段階で反証探索が表面的になることで生じる。推論者が "ほぼ同じ" という印象を早期に持つと、Step 5 の COUNTEREXAMPLE CHECK を通過させる動機が弱まる。

S0 ステップでは、トレース開始前に「何が崩れたら NOT EQUIVALENT になるか」を明示的に列挙させる。これにより:

- 等価性の必要条件が具体的な文言として固定され、推論中の確証バイアスに対する構造的な抑制となる
- 後続の S1/S2/ANALYSIS は、「S0 で列挙した条件を一つひとつ検証する作業」という位置づけになり、反証探索を最後まで維持しやすくなる
- 順方向トレースのみで EQUIVALENT と結論づける前に、S0 の全項目にチェックが入ったかを確認する自然なゲートが生まれる

これは `overall` フォーカスに対しても有効であり、equiv 精度の向上を通じて全体正答率を引き上げることが期待される。

---

## failed-approaches.md との照合

| 汎用原則 | 本提案との関係 |
|---|---|
| 探索すべき証拠の種類をテンプレートで事前固定しすぎる変更は避ける | S0 は「証拠の種類」ではなく「等価性の必要条件」を列挙させる。何を探すかではなく、何が崩れたら結論が変わるかという論理的前提を確立するものであり、探索経路を固定する性質ではない。抵触しない。 |
| 探索ドリフト対策として探索の自由度を削りすぎない | S0 は探索の打ち切り条件や検索パターンを強制しない。あくまで「等価性の前提条件の宣言」であり、探索ルートは引き続き推論者に委ねられる。抵触しない。 |
| 仮説更新を即座の前提修正義務に直結させすぎない | S0 は結論前ではなくトレース開始前に一度だけ行う。仮説が揺れるたびに S0 を更新させる強制は一切含まれない。抵触しない。 |
| 結論直前の自己監査に新しい必須のメタ判断を増やしすぎない | S0 は結論直前ではなくトレース開始前に位置している。また「必要条件を列挙する」という単純な宣言であり、確信度の評価軸の追加ではない。抵触しない。 |

すべての汎用原則に抵触しないことを確認した。

---

## 変更規模の宣言

追加行数: 3 行（S0 の項目本文 2 行 + 空行として S0 ラベル行 1 行）
削除行数: 0 行
合計変更行数: 3 行（hard limit 5 行以内に収まっている）

既存行への追加・精緻化のみ。新規ステップ・新規フィールド・新規セクションの追加には該当しない（STRUCTURAL TRIAGE という既存ブロック内のサブ項目として S0 を追加するものである）。
