# Iteration 22 — Proposal

## Exploration Framework カテゴリ: E（表現・フォーマット改善）

### カテゴリ E を選択した理由

今回の強制カテゴリは E（表現・フォーマットを改善する: 曖昧文言の具体化、簡潔化、例示）。
Objective.md の Exploration Framework セクションに定義されたカテゴリ E の3つのメカニズム
のうち、本提案は「曖昧な指示をより具体的な言い回しに変える」と「冗長な部分を簡潔にして
認知負荷を下げる」を組み合わせる。

具体的なメカニズム選択理由:
Step 3 と Step 4 の境界説明に「Do not reconstruct the table from memory after the fact」
という禁止文が存在する。この文は「in real time」という肯定形の表現と内容が重複しており、
同じ義務を2か所で繰り返すことで文書の認知負荷を高めている。さらに「after the fact」は
何の「事実の後」なのかが曖昧であり、「Step 3 の各読み取りの直後に行」という行動単位が
明示されていない。カテゴリ E の「曖昧文言の具体化」と「冗長部分の簡潔化」が直接適用できる。

---

## 改善仮説

Step 3 と Step 4 の境界説明において、「後から記憶で再構成するな」という禁止形の冗長文を
「各関数定義を読んだ直後に1行追加する」という肯定形・行動単位の指示に置き換えることで、
モデルがテーブル記入のタイミングを誤解するケースを減らし、トレーステーブルの充実度（全体
的な推論品質）が向上する。

---

## SKILL.md のどこをどう変えるか

### 変更対象

SKILL.md の Step 3 末尾にある次の1文（95行目付近）:

```
Steps 3 and 4 work together: Step 3 is your real-time exploration journal. Step 4 is the accumulated function-behavior record you build *during* Step 3 — **add a row to Step 4 each time you read a function definition in Step 3.** Do not reconstruct the table from memory after the fact.
```

### 変更後

```
Steps 3 and 4 work together: Step 3 is your real-time exploration journal. Step 4 is the accumulated function-behavior record you build *during* Step 3 — **add one row immediately after reading each function definition; do not batch-write the table later.**
```

### 変更の要点

- 「Do not reconstruct the table from memory after the fact」を削除し、
  同義の肯定形指示「add one row immediately after reading each function definition」に一本化する。
- 「do not batch-write the table later」を追加し、
  「後から記憶でまとめて書く」という具体的な誤操作パターンを直接禁止する。
- 結果として該当文が1行に収まり、重複義務の記述が解消される。

### 差分イメージ（変更行数の宣言に使用）

変更行数: 1行変更（1行削除 + 1行追加 = 実質1行の文言置き換え）

---

## 一般的な推論品質への期待効果

### 減少が期待される失敗パターン

1. トレーステーブルの後付け記入によるバグ:
   モデルが複数ファイルを読み終えた後にまとめてテーブルを書こうとするとき、
   読み取り順序・関数の対応関係・VERIFIED 条件が混在してエラーになりやすい。
   行動単位を「各関数定義を読んだ直後」に明示することで、この後付けパターンを抑止する。

2. 「in real time」の解釈揺れ:
   現状の「in real time」は「即座に」なのか「探索フェーズ中に」なのか解釈が分かれうる。
   「immediately after reading each function definition」という表現は行動の粒度を特定し、
   解釈揺れを解消する。

3. 全体的な推論品質（overall）への寄与:
   トレーステーブルがより完全かつ正確に記入されることで、Step 5 の反証チェックや
   Step 6 の formal conclusion での前提参照精度が向上し、EQUIVALENT / NOT EQUIVALENT
   いずれの判定においても証拠の抜けが減る。

---

## failed-approaches.md の汎用原則との照合

failed-approaches.md に記載された4つの汎用失敗原則を以下の通り照合する。

1. 「次の探索で探すべき証拠の種類をテンプレートで事前固定しすぎる変更は避ける」
   → 本変更は「証拠の種類」を固定しない。記入タイミングの指示であり、
     何を探すかは変更していない。抵触しない。

2. 「探索の自由度を削りすぎない」
   → テーブル記入のタイミングを具体化するだけで、探索の順序・対象・深度は制限しない。
     抵触しない。

3. 「探索中の局所的な仮説更新を即座の前提修正義務に直結させすぎない」
   → テーブル記入は仮説の更新でも前提の修正でもない。抵触しない。

4. 「結論直前の自己監査に新しい必須のメタ判断を増やしすぎない」
   → 変更箇所は Step 3/4 の境界説明であり、結論前の自己監査（Step 5.5）には触れない。
     抵触しない。

照合結果: 4原則すべてに抵触しない。

---

## 変更規模の宣言

- 変更行数: 1行（既存行の文言精緻化。新規ステップ・新規フィールド・新規セクションなし）
- ハードリミット（5行以内）: 適合
- 削除行: 1文を削除し同義の肯定形に統合（削除行はカウント対象外）
