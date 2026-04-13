# Iteration 23 — 監査コメント

## 総評
提案の発想自体は理解できる。`explain` モードの `SEMANTIC PROPERTIES` 的視点を `compare` に輸入し、`subtle difference dismissal` を減らしたいという筋は、原論文の設計思想とは整合する。

ただし、今回の文言は `compare` の判定基準である「既存テストに対する観測可能な差分」よりも、「変更が触る意味的差分そのもの」に注意を寄せやすい。結果として、NOT_EQUIVALENT 側の差分検出には少し効く可能性がある一方、EQUIVALENT 側では「意味的には違うが既存テストでは同値」というケースを過剰に NOT_EQUIVALENT 寄りに読む回帰リスクがある。

結論として、現行案のままでは承認しない。

---

## 1. 既存研究との整合性

### 参照URLと要点
1. https://arxiv.org/abs/2603.01896
   - 要点: Agentic Code Reasoning 論文の中核は、明示的 premises、execution-path tracing、formal conclusion を要求する semi-formal reasoning にある。
   - 監査コメント: 提案は「意味的性質を明文化する」方向なので、structured reasoning を強めるという意味では整合的。

2. https://en.wikipedia.org/wiki/Loop_invariant
   - 要点: 不変条件は、表面的な入力境界ではなく、ループやアルゴリズムのより深い正しさ・状態保証を捉えるための標準的な考え方である。
   - 監査コメント: `semantic invariants` を考慮対象に入れること自体は、一般的なプログラム検証の発想として妥当。

3. https://en.wikipedia.org/wiki/Hoare_logic
   - 要点: 正しさ推論は precondition / postcondition / assertion で状態変化を捉える。入力だけでなく状態保証を追うのが本筋。
   - 監査コメント: `state constraints` を見るという方向性は Hoare 的な正しさ推論と整合する。

4. https://en.wikipedia.org/wiki/Equivalence_checking
   - 要点: 等価性検証では、最終的には観測可能な出力列や振る舞いの一致が基準であり、内部差分そのものではない。
   - 監査コメント: ここが今回案の弱点。`compare` は D1 上「テスト結果が同じか」が基準なので、意味的差分の列挙は必ず観測可能差分へ再接続される必要がある。

5. https://en.wikipedia.org/wiki/Counterexample-guided_abstraction_refinement
   - 要点: 重要なのは、見つけた差分候補が真の counterexample か、spurious かを切り分けること。
   - 監査コメント: 今回案は差分候補の発見には寄与しうるが、「その差分が実テストで反例になるか」を強制する文言ではない。研究的にはここまで踏み込んで初めて compare 強化として安定する。

### まとめ
研究整合性は「部分的に YES」。
- YES: 意味的性質・不変条件を追う発想自体は、プログラム検証・コード推論の主流原則と整合。
- ただし: 等価性判定では、意味的差分そのものではなく「観測可能な反例」に結びつける必要がある。今回の文言はそこが弱い。

---

## 2. Exploration Framework のカテゴリ選定は適切か

カテゴリ F の選択は概ね妥当。

理由:
- `explain` モードの `SEMANTIC PROPERTIES` を `compare` に持ち込む、という主張は Objective の F「他モードの手法を compare に応用する」に一致する。
- `subtle difference dismissal` という論文のエラー分析を根拠にしており、F「エラー分析セクションの知見を反映する」にも一致する。

ただし補足:
- 実装としては新しい推論機構の導入というより、既存コメント行の精緻化であり、実質は F と E の中間に近い。
- つまりカテゴリ誤りではないが、「F だから強い改善になる」とまでは言えない。変更の強さはかなり限定的。

結論:
- カテゴリ F 判定: 妥当
- ただし改善の実効性はカテゴリ選定とは別問題で、そこには懸念が残る

---

## 3. EQUIVALENT 判定 / NOT_EQUIVALENT 判定の両方への作用

### 提案が効く方向
この変更が効くとすれば主に以下。
- 変更間に微妙な意味的差分がある
- その差分が既存テストの assertion や control-flow に実際につながっている
- しかし従来の agent は「境界値ではないので無視してよい」と早合点していた

この場合、`semantic invariants or state constraints` を見るよう促すことで、真の NOT_EQUIVALENT を拾いやすくなる可能性はある。

### 提案が悪化させうる方向
一方で `compare` の定義はあくまで「既存テストの pass/fail outcome が同じか」である。ここで意味的差分の列挙を前面に出すと、以下の回帰がありうる。
- 実装の意味論的説明は違う
- だが既存テストがその差分を観測していない
- 本来は EQUIVALENT modulo tests
- しかし agent が差分の存在自体を重く見て NOT_EQUIVALENT に寄る

特に今回の文言には `that each change modifies` が入っており、test-centric というより change-centric に読める。これは compare モードの基準と少しズレる。

### 実効的差分の評価
変更前:
- EDGE CASES は主に「実テストが踏む境界条件」を確認する欄として読める

変更後:
- 実テストが踏む境界条件に加え、「変更が影響する semantic invariants / state constraints」も列挙対象になる

この差分は中立ではない。差分検出方向に圧をかける。

### 片方向にしか作用しないか
かなり片方向に近い。
- 正方向: subtle difference の発見、すなわち NOT_EQUIVALENT の根拠補強
- 逆方向: EQUIVALENT を積極的に守る仕組みは増えていない

つまり、提案者が書いている「EQUIVALENT 誤判定の減少」は論理的に弱い。むしろ自然な一次効果は「誤って EQUIVALENT と言うケースを減らす」ことであり、これは benchmark 上は NOT_EQUIVALENT 側に効く方向である。EQUIVALENT 側には、下手をすると逆風になりうる。

結論:
- 両方向に均等には作用しない
- 実質的には NOT_EQUIVALENT 側へ寄る変更
- EQUIVALENT 側の改善主張は現状の文言だけでは弱い

---

## 4. failed-approaches.md の汎用原則との照合

### 原則1: 探索で探す証拠の種類を事前固定しすぎない
ここに軽い抵触懸念がある。

今回案は「境界条件に加えて semantic invariants / state constraints を見よ」としており、証拠の種類を一段具体化している。提案者の言う通り特定の関数名やパターンを指定しているわけではないが、それでも compare の探索を特定の証拠型へ寄せる作用はある。

完全に同じ失敗の再演ではないが、方向としては近い。

### 原則2: 探索の自由度を削りすぎない
ここも軽い懸念あり。

文言は「広げている」ように見えるが、実際には compare の思考フレームを「意味的不変条件を見るべき」という方向へ誘導する。これにより、本来見るべき API contract、例外の有無、 import path、 data-shape 差分などを agent がすべて invariants 語彙に回収してしまうおそれがある。

### 原則3: 局所的仮説更新を前提修正義務に直結させすぎない
これは抵触しない。今回の変更は Step 3 の premise/hypothesis 更新規律には触れていない。

### 原則4: 結論直前の自己監査に新しい必須判定ゲートを増やしすぎない
これは抵触しない。Step 5.5 には手を入れていない。

### まとめ
- 原則3, 4: 問題なし
- 原則1, 2: 弱いが無視できない緊張あり

したがって「表現を変えただけの過去失敗の再演」とまでは言わないが、過去失敗原則から完全に安全とは言えない。

---

## 5. 汎化性チェック

### 明示的ルール違反の有無
提案文中を確認した限り、以下のような強い違反は見当たらない。
- 特定のベンチマークケース ID
- 特定リポジトリ名
- 特定テスト名
- 対象リポジトリ由来のコード断片

含まれているのは主に以下。
- SKILL.md 自身の文言引用
- 論文の Appendix / section 参照
- 一般概念名 (`semantic invariants`, `state constraints`, `control flow` など)

この範囲なら、過剰適合の直接証拠とは言いにくい。

### 暗黙のドメイン想定
ただし、文言にはやや偏りがある。
- `state constraints` は命令的・状態遷移的コードには自然だが、純関数型、宣言的変換、データクエリ、型レベル制約中心のコードにはやや不自然。
- `that each change modifies` という表現は、変更差分が「何かの状態や不変条件を変える」と読めるケースに寄っており、リファクタ・名前変更・表現差し替え・ error-message 差分などには適用像が弱い。

### 汎化性の結論
- 露骨な overfitting 証拠: なし
- ただし語彙選択はやや stateful / imperative 偏重
- より汎化するなら `semantic obligations, observable guarantees, or state constraints` のように広げた方がよい

---

## 6. 全体の推論品質がどう向上すると期待できるか

限定的な改善は期待できる。

期待できる点:
- agent が「境界値だけ見て終わる」ことを防ぎ、より深い意味差分を言語化しやすくなる
- テストが暗黙に依存している順序保証、例外保証、状態保存則のような性質を見落としにくくなる

期待しにくい点:
- compare の最重要論点である「その差分が既存テストで観測されるか」を直接強化していない
- したがって、真の反例探索よりも「差分候補の発見」に寄った改善になっている
- その結果、EQUIVALENT 判定の安定化よりは、差分過検出の方へ振れやすい

総合すると、推論品質の改善幅は小〜中程度で、しかも改善方向が偏っている。

---

## 最終判断
不承認。

理由の要約:
1. 研究との整合性はあるが、equivalence checking の核心である「観測可能な反例」への接続が弱い。
2. 実効的には NOT_EQUIVALENT 側へ片寄る変更で、EQUIVALENT 側の改善根拠が弱い。
3. failed-approaches の「証拠型の事前固定」「探索自由度の狭窄」に軽く触れており、安全圏と言い切れない。
4. 現状の benchmark 文脈では、EQUIVALENT 側の誤判定をむしろ悪化させる回帰リスクがある。

もし修正版を出すなら、`semantic invariants` 自体を EDGE CASES に追加するより、
「意味的差分を見つけたら、必ずその差分に依存する既存テスト assertion / call path を 1 本具体的に追跡せよ」
のように、差分発見ではなく test-observable counterexample 接続を強化する方が安全。

承認: NO（理由: 変更の一次効果が差分検出方向に片寄っており、EQUIVALENT と NOT_EQUIVALENT の両側をバランスよく改善する設計になっていないため）
