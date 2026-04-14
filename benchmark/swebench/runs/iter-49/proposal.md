# Iteration 49 — Proposal

## Exploration Framework カテゴリ: B（強制指定）

カテゴリ B「情報の取得方法を改善する」を選択する。

### カテゴリ B 内でのメカニズム選択理由

カテゴリ B には以下の三メカニズムが存在する。

  (B-1) コードの読み方の指示を具体化する
  (B-2) 何を探すかではなく、どう探すかを改善する
  (B-3) 探索の優先順位付けを変える

今回は (B-2)「どう探すか」を選ぶ。

理由: compare モードの overall 精度低下の主因は「非公開ソース関数の扱い
の不一致」にある。Step 4 では三次証拠の探索順序として
「test usage first, then type signatures, then documentation」
を既に規定しているが、これは "what to search" の優先順位リストであり、
"how to search" の具体的な手続きを欠く。探索者はリストを眺めても
「test usage をどのように見つけるか」が不明確なため、曖昧な文字列検索や
名称推測に頼り、結果として UNVERIFIED ラベルを付けたまま結論を固める。

この「探索手続きの曖昧さ」はカテゴリ B-2 が正確に標的とする失敗パターンであり、
B-1（読み方）や B-3（順序）への変更では解消されない。
また failed-approaches.md の「特定の追跡方向や観点で具体化しすぎない」原則との
抵触を避けるため、方向は固定せず、探索の「実行手続き」のみを一行で補足する。

---

## 改善仮説

「外部ライブラリ等、ソースが入手不可な関数に対して行うセカンダリ証拠探索は、
探索の実行手続きを明示しないと確認バイアスに陥りやすい。
"test usage" を探す際に『その関数を呼び出しているテストを検索する』という
具体的な動詞レベルの指示を一行追加することで、
証拠収集の再現性が上がり、根拠なき UNVERIFIED 据え置きによる
overall 誤判定が減少する。」

---

## SKILL.md の変更内容

### 対象箇所

SKILL.md の Step 4 (Interprocedural tracing) の以下の行:

```
- If source is unavailable (third-party library), mark UNVERIFIED and note the assumption. Search for secondary evidence in priority order: test usage first (shows actual behavior), then type signatures, then documentation. Optionally probe language behavior with an independent script.
```

### 変更案（変更は既存行への文言追加）

変更前:
```
Search for secondary evidence in priority order: test usage first (shows actual behavior), then type signatures, then documentation.
```

変更後:
```
Search for secondary evidence in priority order: test usage first (find tests that call this function and read their assertions), then type signatures, then documentation.
```

### 変更規模宣言

変更行数: 1 行（既存行の括弧内語句を差し替え）
追加行: 0 行 / 削除行: 0 行（純粋な文言置換）
5 行制限: 遵守

---

## 一般的な推論品質への期待効果

### 減少が期待されるカテゴリ的失敗パターン

1. 根拠なき UNVERIFIED 据え置き誤判定（overall）
   ソース不在関数に対して、テスト呼び出しを探索せずに UNVERIFIED と
   マークしたまま結論を下す。変更後は「テストを探して assertion を読む」
   という具体的な手続きが示されるため、一次ソース代替証拠が増加する。

2. 確認バイアスによる equiv/not_eq 方向の固定
   「test usage first」という順序だけでは何を読めばよいか曖昧で、
   既知の仮説を支持する証拠のみ拾いがちだが、assertion を読む行為は
   期待動作と実動作の差分を直接照合させるため、反証としても機能する。

### 悪化リスク

Step 4 の既存構造（VERIFIED / UNVERIFIED 区別、探索三優先順序）は保持。
括弧内の補足語句の差し替えであり、他ステップへの波及はない。

---

## failed-approaches.md の汎用原則との照合

| 原則 | 抵触有無 | 判定根拠 |
|------|----------|----------|
| 探索を「特定シグナルの捜索」へ寄せすぎない | 抵触なし | 「assertion を読む」は手続き具体化であり、探索すべき証拠の種類をテンプレートで事前固定していない |
| 探索の自由度を削りすぎない | 抵触なし | 「どこから読み始めるか」「どの境界を先に確定するか」などの探索順序は変更していない |
| 局所的な仮説更新を前提修正義務に直結させない | 抵触なし | 変更は Step 4 の証拠収集手続きのみで、仮説更新や前提管理の構造に触れない |
| 既存のガードレールを特定追跡方向で具体化しすぎない | 抵触なし | 変更は Guardrails セクションではなく Step 4 の証拠探索補足であり、かつ方向非依存（「assertion を読む」はあらゆるライブラリ関数に適用可能） |
| 結論直前の自己監査に新しい必須判定ゲートを増やさない | 抵触なし | Step 5.5 (Pre-conclusion self-check) は無変更 |

---

## 変更規模の宣言

- 変更対象: SKILL.md Step 4、既存行の括弧内語句の差し替え
- 変更行数: 1 行（hard limit 5 行に対して 1 行）
- 新規ステップ・新規フィールド・新規セクション: なし
- 削除行: なし
