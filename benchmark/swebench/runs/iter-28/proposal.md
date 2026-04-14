# Iteration 28 — Proposal

## Exploration Framework カテゴリ

カテゴリ: E (表現・フォーマットを改善する)

カテゴリ E 内での具体的メカニズム選択: **曖昧文言の具体化**

Step 5.5 の 3 番目のチェック項目:

```
- [ ] The Step 5 refutation or alternative-hypothesis check involved at least
      one actual file search or code inspection — not reasoning alone.
```

「actual file search or code inspection」は何を指すかが不明瞭である。
「ファイル検索ツールの実行」を意味するのか、「既に読んだコードの再参照」で足りるのかが
読み手によって解釈が分かれる。この曖昧さが、形式的な反証確認（推論のみで
「反証なし」と述べるだけ）を許容する抜け穴となりうる。

具体化によって「推論だけで反証を処理する」失敗パターンを明示的に排除する。
これは既存の曖昧な文言をより正確な言い回しに置き換える純粋なカテゴリ E の適用である。

---

## 改善仮説

反証確認ステップにおいて「推論のみ」と「コードへの直接参照」の境界が不明瞭だと、
実際の証拠参照を伴わない形式的な反証確認が許容される。チェック項目の文言を
「コード内の具体的な箇所（file:line）への参照または明示的な検索を含む確認」と
具体化することで、反証を実質化し、誤った EQUIVALENT 判定を減らすことができる。

---

## 変更内容

### 変更箇所

SKILL.md の Step 5.5 (Pre-conclusion self-check) 内、3 番目のチェック項目。

### 変更前

```
- [ ] The Step 5 refutation or alternative-hypothesis check involved at least
      one actual file search or code inspection — not reasoning alone.
```

### 変更後

```
- [ ] The Step 5 refutation or alternative-hypothesis check involved at least
      one actual file:line reference or explicit search — not reasoning alone.
```

### 変更の説明

「actual file search or code inspection」を「actual file:line reference or explicit search」
に置き換える。

- 「file:line reference」はこのスキル全体で使われる標準的な証拠単位であり、
  読み手が何をすべきかを一意に理解できる。
- 「code inspection」は「コードを眺めること」全般を指しうる曖昧な語で、
  推論のみによる処理との区別が難しかった。
- 「explicit search」は既存の compare テンプレートで使われる「Searched for:」
  フォームと対応し、一貫性が増す。
- SKILL.md 全体で「file:line」を証拠の共通単位としているため、
  この語に統一することで認知負荷が下がる。

---

## 期待効果

### 失敗パターン

- 反証確認を「I searched for the counterexample pattern and found none.」と
  テキストのみで宣言し、実際に file:line を引用しない形式的な処理。
- compare モードで NO COUNTEREXAMPLE EXISTS ブロックを記入するが、
  「Searched for:」行に具体的なパターンを書かず通過させる。

### 期待される改善

チェック項目が「file:line reference または explicit search を含む」と明示されると、
エージェントは Step 5 の反証ブロックで少なくとも 1 件の具体的な参照を記録する
義務があると理解しやすくなる。これにより overall および equiv カテゴリでの
形式的反証による誤 EQUIVALENT 判定が減ると期待される。

---

## failed-approaches.md の汎用原則との照合

1. **「探索で探すべき証拠の種類をテンプレートで事前固定しすぎる」** — 本変更は
   探索中に何を探すかを変えない。Step 5.5 は探索後の自己確認ステップであり、
   探索段階の自由度に干渉しない。非抵触。

2. **「読解順序の半固定」** — 本変更はステップ実行順序を変えない。非抵触。

3. **「局所的な仮説更新を即座の前提修正義務に直結させすぎない」** — 本変更は
   仮説更新プロセスに関与しない。非抵触。

4. **「結論直前の自己監査に新しい必須のメタ判断を増やしすぎない」** —
   本変更はチェック項目の数を増やさず、既存の 1 項目の文言を具体化するのみ。
   「新しい判定ゲート」を追加するものではない。非抵触。

---

## 変更規模の宣言

- 変更行数: 1 行 (既存行の文言置き換え、削除行はゼロ)
- hard limit (5 行) 以内: YES
- 変更種別: 既存行への文言精緻化のみ。新規ステップ・新規フィールド・新規セクションなし。
