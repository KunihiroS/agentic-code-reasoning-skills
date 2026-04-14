# Iteration 43 — Proposal

## Exploration Framework カテゴリ

カテゴリ: **B — 情報の取得方法を改善する**

強制指定理由: 今回のイテレーションはカテゴリ B が強制指定されている。

カテゴリ B 内でのメカニズム選択理由:

Objective.md の Exploration Framework セクションは B を次の 3 つのサブメカニズムに分類する。

1. コードの読み方の指示を具体化する
2. 何を探すかではなく、どう探すかを改善する
3. 探索の優先順位付けを変える

今回はサブメカニズム 2「どう探すか」を選ぶ。

具体的な根拠: SKILL.md の Guardrail #6 は「ソースが入手不可の場合は
test usage first (shows actual behavior), then type signatures, then
documentation」という優先順位を定めているが、これはソース不在時の
二次証拠探索順序に限定されている。一方、ソースが存在する場合でも
「どう読むか」の具体化が Step 4 の UNVERIFIED → VERIFIED の質を左右する。

Step 4 の現行ルールには「Trace through conditionals, mapping tables, and
configuration — not just the happy path」とあるが、このガイダンスは
「何を探すか（条件分岐・マッピングテーブル）」に寄っており、「どのように
読み進めるか」の順序原則を欠いている。複数の出口・分岐が存在する関数を
読む際に「戻り値から逆順にトレース（return-backward reading）」を実施
することで、ハッピーパスへの視線バイアスを構造的に崩せる。

これは新規ステップではなく Step 4 の既存ルール行への精緻化であり、
カテゴリ B のメカニズム 2 に正確に対応する。

---

## 改善仮説

関数定義を読む際に「戻り値・例外出力から逆向きに分岐を辿る」読解方向を
Step 4 のトレースルールに加えると、ハッピーパスのみを前向きに追う視線バイアスが
崩れ、実際の制御フローを見落とす頻度が下がる。
結果として VERIFIED 行の精度が上がり、compare / diagnose モード双方で
誤った EQUIVALENT / PASS 判定が減る。

---

## SKILL.md への具体的な変更

### 変更箇所

Step 4 の Rules セクション、以下の既存行:

```
- Trace through conditionals, mapping tables, and configuration — not just the happy path.
```

### 変更後

```
- Trace through conditionals, mapping tables, and configuration — not just the happy path. When a function has multiple return or raise sites, start from each exit point and trace backward to the branching condition before reading forward.
```

### 変更の性質

既存行への文言追加・精緻化のみ。新規ステップ・新規フィールド・新規セクション
は追加しない。

### 変更規模の宣言

変更行数: 1 行（既存行への追記）
削除行数: 0
合計: 1 行（hard limit 5 行以内 — 適合）

---

## 一般的な推論品質への期待効果

### 減少が期待される失敗パターン

1. ハッピーパス固定バイアス（docs/design.md §Incomplete reasoning chains に対応）
   複数 return / raise が存在する関数をハッピーパスのみ前向きに読んで
   VERIFIED と記録してしまう失敗。exit-backward reading を義務化することで
   「条件 X の場合に先に return する」ような分岐を見落とす確率が下がる。

2. compare モードでの誤 EQUIVALENT 判定
   2 つの変更が同一の関数を呼ぶ場合でも、その関数の内部分岐が
   入力によって異なる出口を通る可能性を early exit パスから検証できるようになる。

3. diagnose モードでの根本原因見落とし
   クラッシュサイトだけを前向きにトレースして「ここで throw が起きた」と
   結論する前に、どの条件でその throw 分岐へ到達するかを逆順で特定できる。

### 影響しないパターン（回帰リスクが低い理由）

この変更は「関数に複数の exit point が存在する場合にのみ」追加の読解アクションを
促す条件付きガイダンスであり、単純な関数の単一 return ケースには余分な手順を
課さない。既存の VERIFIED / UNVERIFIED の記録規則・仮説駆動の書式・
反証必須ルールはいずれも変更しない。

---

## failed-approaches.md 汎用原則との照合結果

### 原則 1: 次の探索で探すべき証拠の種類をテンプレートで事前固定しすぎる

照合結果: **抵触しない**
本提案は「どんな証拠を探すか」ではなく「同じ証拠（exit point）を
どの方向から読み始めるか」を変えるものであり、探索対象の種類を
固定・限定するものではない。仮説更新の余地は維持される。

### 原則 2: 探索の自由度を削りすぎない

照合結果: **抵触しない**
「複数の exit point が存在するとき backward から読む」は読解方向の
優先順位であり、探索対象の絞り込みではない。どこから読み始めるかの
半固定に関する禁止事項（「どの境界を先に確定するか」の早期固定）とも
性格が異なる。本変更はファイル探索経路ではなく関数内部読解の順序に
限定されており、ファイル間の探索幅を狭めない。

### 原則 3: 探索中の局所的な仮説更新を前提修正義務に直結させすぎない

照合結果: **抵触しない**
本変更は仮説・前提の管理プロセスに一切触れない。Step 4 のトレース記録
規則の精緻化であり、仮説更新サイクルとは分離されている。

### 原則 4: 結論直前の自己監査に新しい必須のメタ判断を増やしすぎない

照合結果: **抵触しない**
本変更は Step 5.5 / Step 6 の結論フェーズではなく、Step 4 の
情報収集フェーズにのみ作用する。自己監査ゲートの数・複雑さは変わらない。

---

## まとめ

| 項目 | 内容 |
|------|------|
| カテゴリ | B（強制指定） |
| サブメカニズム | どう探すか（読解方向の具体化） |
| 仮説 | exit-backward reading でハッピーパスバイアスを崩す |
| 変更対象 | Step 4 Rules の既存行への追記 |
| 変更規模 | 1 行追記（5 行以内） |
| failed-approaches との照合 | 全 4 原則に抵触しない |
| 期待効果 | compare での誤 EQUIVALENT 減・diagnose での根本原因見落とし減 |
