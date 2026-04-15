# Iteration 55 — Improvement Proposal

## Exploration Framework カテゴリ: B

カテゴリ B「情報の取得方法を改善する」の中から、今回は
**「コードの読み方の指示を具体化する」** メカニズムを選択する。

### 選択理由

カテゴリ B の 3 つのメカニズムのうち、
「探索の優先順位付けを変える」は failed-approaches.md の
「探索ドリフト対策として探索の自由度を削りすぎない」原則に
触れやすい。「何を探すかではなく、どう探すかを改善する」は
カテゴリ A（順序変更）や C（比較枠組み）と混同しやすい。

「コードの読み方の指示を具体化する」は、
現行 SKILL.md の Step 4 が持つ "UNVERIFIED 時の代替探索" 手順
（テスト用途 → 型シグネチャ → ドキュメント）に注目する。
この優先順位は既に明示されているが、
「なぜその順序か」の根拠が書かれていないため、
実際の探索時に順番が曖昧になりやすい。
根拠を一言付記することで読み方を具体化し、
探索の自由度は削らずに判断軸を与えられる。


## 改善仮説

ソースが入手不能な関数の代替証拠を探す際、
検索順序の根拠が明示されていないと、
推論エージェントは最も情報量の少ない証拠から探索を始めたり、
順序を任意に入れ替えたりしやすい。
探索優先順位の「理由」を一語で付記するだけで、
エージェントは実際の動作を最も直接的に示す証拠
（テスト用途）を先に当たる習慣を維持しやすくなり、
UNVERIFIED 行に対する代替根拠の信頼性が安定して向上する。


## SKILL.md の変更内容

### 変更箇所

Step 4「Interprocedural tracing」の Rules セクション、
UNVERIFIED 時の代替探索手順を記述した一文。

### 変更前（SKILL.md line 109）

```
- If source is unavailable (third-party library), mark UNVERIFIED and note the assumption. Search for secondary evidence in priority order: test usage first (shows actual behavior), then type signatures, then documentation. Optionally probe language behavior with an independent script.
```

### 変更後（変更規模: 1 行の文言追加・精緻化）

```
- If source is unavailable (third-party library), mark UNVERIFIED and note the assumption. Search for secondary evidence in priority order: test usage first (shows actual behavior most directly), then type signatures (constrain possible behaviors), then documentation (least reliable, may be stale). Optionally probe language behavior with an independent script.
```

### 差分要約（追加テキストのみ抜粋）

- "shows actual behavior" → "shows actual behavior most directly"
- "then type signatures" → "then type signatures (constrain possible behaviors)"
- "then documentation" の後ろに "(least reliable, may be stale)" を追加

変更行数: 1 行（既存行への文言追加のみ）


## 一般的な推論品質への期待効果

### 対象となる失敗パターン

1. **Third-party library guessing（ドキュメント先読みバイアス）**
   — docs/design.md §4.1.1 が列挙する「サードパーティライブラリの
   動作を名前や公式ドキュメントから推測する」失敗。
   ドキュメントが "least reliable, may be stale" と明示されることで、
   エージェントはドキュメントへの過信を抑制しやすくなる。

2. **Subtle difference dismissal（微細差分の軽視）**
   — テスト用途が "most directly" と明示されることで、
   実際の呼び出し文脈を先に確認する動機が高まり、
   テストが関数の差異を実際に行使しているかどうかの
   見落としが減る。

### EQUIV / NOT_EQ への影響

- EQUIV 誤判定の一因として「UNVERIFIED 関数の動作を
  ドキュメントベースで安易に同一とみなす」パターンが挙げられる。
  テスト用途を最優先で確認する習慣の強化は、
  この誤判定の抑制に直接寄与する（EQUIV 精度向上）。
- NOT_EQ 判定への悪影響はほぼない。
  検索順序の根拠付記は判定方向を変えず、
  証拠収集の質を高めるだけであるため。


## failed-approaches.md との照合

| 汎用原則 | 本提案との関係 |
|---|---|
| 探索シグナルの事前固定による確認バイアス強化 | 非抵触: 探索先の種類を固定しておらず、既存順序の根拠を付記するだけ |
| 探索の自由度を削りすぎない | 非抵触: 優先順位は既に存在しており、その変更ではなく根拠明示のみ |
| 局所的な仮説更新を前提修正義務に直結させすぎない | 非抵触: 仮説更新のサイクルには無関係 |
| 既存ガードレールを特定の追跡方向で具体化しすぎない | 非抵触: Step 4 の UNVERIFIED 処理は "方向非依存" のまま; 根拠の明示は探索経路を半固定しない |
| 結論直前の自己監査に新しいメタ判断を増やしすぎない | 非抵触: 変更は Step 5.5 および Step 5 とは無関係 |

全ての汎用原則との抵触なし。


## 変更規模の宣言

- 変更行数（追加・変更）: **1 行**
- 削除行数: **0 行**
- 上限 5 行以内: **適合**
- 新規ステップ・新規フィールド・新規セクション: **なし**
- 変更の性質: 既存行への文言追加（根拠語句の挿入）のみ
