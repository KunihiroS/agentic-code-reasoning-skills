# Iteration 19 — Proposal

## Exploration Framework カテゴリ: B（強制指定）

### カテゴリ B 内でのメカニズム選択理由

カテゴリ B は「情報の取得方法を改善する」であり、以下の3つのメカニズムを含む:

- コードの読み方の指示を具体化する
- 何を探すかではなく、どう探すかを改善する
- 探索の優先順位付けを変える

今回は **「コードの読み方の指示を具体化する」** を選択する。

理由: SKILL.md の Step 4 では UNVERIFIED 関数に対して二次証拠の探索順序（test usage first, then type signatures, then documentation）を定義しているが、VERIFIED 関数（ソースが手元にある場合）に対しては本体を読む前に何を先に確認すべきかという読み順の指針が存在しない。その結果、エージェントが関数本体の先頭から逐語的に読み始め、最初に目についた分岐でトレースの方向を固定してしまう（暗黙的確認バイアス）リスクがある。シグネチャ・戻り型・主要分岐を本体精読の前に一覧することで、full body読解の前にコードパスの優先順位を立て、その後のトレースが仮説に偏りにくくなる。


## 改善仮説

関数定義を読む際に本体全体を逐語的に追う前にシグネチャ・戻り型・主要分岐の形状を先に把握する習慣を Step 4 の読み方指示として明示することで、最初に目に入った実行経路への過度な固着を防ぎ、代替経路を見落とす確率を下げることができる。


## SKILL.md のどこをどう変えるか

### 変更対象

SKILL.md Step 4 の Rules セクション内、現在の以下の行:

```
- Read the actual definition. Do not infer behavior from the name.
```

### 変更後

```
- Read the actual definition. Do not infer behavior from the name.
  Before reading the full body, note the return type, parameter types, and the top-level branch structure (if/switch/try-catch shape). This primes the trace direction without committing to a path prematurely.
```

### 変更の性質

既存行「Read the actual definition. Do not infer behavior from the name.」への文言追加・精緻化。
新規ステップ・新規フィールド・新規セクションは一切追加しない。

### 変更規模

追加行数: 2行（既存1行の直後に2行の補足文を追記）
削除行数: 0行
合計変更行数: 2行（hard limit の 5行以内）


## 一般的な推論品質への期待効果

### 減少が期待される失敗パターン

1. **暗黙的経路固着（Implicit Path Anchoring）**
   - 現象: エージェントが関数本体の最初の条件分岐を「主経路」と思い込み、テストが実際に通る経路（後半の分岐・例外処理・デフォルトケース）を追わない
   - 改善機序: 本体精読前に top-level branch structure を一覧することで、どの分岐が存在するかを把握した上でトレースを開始できる

2. **シグネチャ誤読による型混乱**
   - 現象: 戻り型や引数型を本体中盤で初めて把握し、すでに構築した前提と矛盾したときに修正コストが高い
   - 改善機序: 先行確認により型情報を Step 3 の HYPOTHESIS 更新に組み込みやすくなる

3. **compare モードにおける NOT_EQUIVALENT 見落とし（overall 改善）**
   - 二つの変更が分岐の異なる腕を通る場合に等価と誤判定するケースは、分岐形状を事前に把握していれば早期に気づきやすい

### 影響するモード

全モード（compare / diagnose / explain / audit-improve）に共通する Step 4 の変更であるため、全体推論品質への波及が期待できる。
特に compare モードの overall 精度に寄与する（フォーカスドメイン: overall と整合）。


## failed-approaches.md の汎用原則との照合

### 原則1: 探索ドリフト対策時に探索自由度を削りすぎない

照合結果: 抵触しない。
本変更は「読む順序の事前整理」であり、読む対象ファイルや関数の選択を制限するものではない。探索の幅（どのファイルを読むか）には干渉せず、個々の関数を読む際の内部手順に限定している。

### 原則2: 次の探索で探すべき証拠の種類をテンプレートで事前固定しすぎない

照合結果: 抵触しない。
「シグネチャと主要分岐を先に見る」は証拠の種類を固定するのではなく、関数定義という同一の情報源を読む順序を提案している。どの情報を証拠として使うかの判断はエージェントに委ねたまま。

### 原則3: 結論直前の自己監査に新しい必須のメタ判断を増やしすぎない

照合結果: 抵触しない。
本変更は Step 4 の読み方指示であり、Step 5.5 の自己監査チェックリストへの追加ではない。


## 変更規模の宣言

- 追加: 2行
- 削除: 0行
- 合計: 2行
- hard limit (5行): 満たす
