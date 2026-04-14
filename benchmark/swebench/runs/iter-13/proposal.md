# Iter-13 Proposal

## Exploration Framework カテゴリ: B

### 今回のカテゴリ選択理由

カテゴリ B は「情報の取得方法を改善する（読み方の具体化、探索の優先順位付けを変える）」と定義されており、今回の変更はその定義内の「探索の優先順位付けを変える」メカニズムに該当する。

具体的には、サードパーティライブラリなどソースが取得できない関数の二次証拠として、SKILL.md が現行で「type signatures, documentation, or test usage」と列挙しているものの、探索順序が不定のままになっている点に着目した。カテゴリ A（構造の変更）でも C（比較枠組みの変更）でも D（メタ認知チェック追加）でもなく、純粋に「どの順で探すか」という情報取得の優先順位の精緻化であるため、カテゴリ B に適合する。

---

## 改善仮説

ソースが入手できない（UNVERIFIED）関数について二次証拠を探す際、
テストコードでの実際の使われ方（test usage）を最初に探索することで、
関数の実際の振る舞いを最も直接的に観察できる証拠が先に得られ、
名前や型宣言からの推測に依存する確認バイアスを軽減できる。

---

## SKILL.md の変更内容

### 変更対象

Step 4（Interprocedural tracing）の Rules 内、行 109 の文言。

### 変更前

```
If source is unavailable (third-party library), mark UNVERIFIED and note the assumption. Search for type signatures, documentation, or test usage as secondary evidence. Optionally probe language behavior with an independent script.
```

### 変更後

```
If source is unavailable (third-party library), mark UNVERIFIED and note the assumption. Search for secondary evidence in priority order: test usage first (shows actual behavior), then type signatures, then documentation. Optionally probe language behavior with an independent script.
```

### 差分の要約

- 既存行への文言追加・精緻化のみ
- 変更行数: 1行（既存 1 行を書き換え）
- 削除行数: 0
- 変更規模宣言: **1行**（hard limit の 5行以内に適合）

---

## 期待効果

### どのカテゴリの失敗が減るか

- **関数名からの推測（Function name guessing）**: docs/design.md §4.1.1 が指摘する失敗パターン。ソースがない関数について、型シグネチャや名前から先に推測するのではなく、テストコードの実際の呼び出し例から振る舞いを帰納することで、名前依存の誤推測が減る。
- **不完全な推論チェーン（Incomplete reasoning chains）**: Guardrail #5 に対応。UNVERIFIED 関数の仮定が誤っている場合でも、テスト使用例を先に参照することで、その仮定がコードパスに与える影響を早期に検知できる。
- **overall 品質への影響**: UNVERIFIED 関数を持つ compare タスクで、二次証拠の質が高まることで EQUIVALENT / NOT_EQUIVALENT の誤判定が減る。equiv 方向・not_eq 方向のいずれについても、証拠の信頼性が均等に向上するため overall に寄与する。

---

## failed-approaches.md との照合

| 禁則原則 | 適合性 | 理由 |
|----------|--------|------|
| 探索シグナルの事前固定による確認バイアスの強化 | 適合 | 探索対象（test usage / type signatures / documentation）はすでに既存行で定義済みであり、今回は「何を探すか」を新たに固定したのではなく、既存の三要素間の「どの順で探すか」を整理したのみ |
| 探索自由度の削りすぎ | 適合 | 優先順位はガイドラインであり、三要素すべての探索を禁止するものではない。自由度は維持される |
| メタ判断の増加 | 適合 | 結論直前の自己監査チェックへの追加ではなく、中間探索ステップの読み方の精緻化であり、新しい必須評価軸は増えていない |

---

## 変更規模の宣言

- 追加・変更: **1行**
- 削除: 0行
- 合計変更規模: 1行（hard limit 5行以内に適合）
