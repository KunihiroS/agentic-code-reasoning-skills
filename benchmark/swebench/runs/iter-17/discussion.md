# Iteration 17 — 監査ディスカッション

## 総評

提案の狙い自体は理解できる。README.md が示す未解決課題は EQUIVALENT 側の誤判定であり、docs/design.md でも "Incomplete reasoning chains" が明示的な失敗パターンとして挙がっている。そのため、compare モードにおいて「差分が本当にテスト oracle まで届くのか」を意識させたい、という問題設定は妥当である。

ただし、今回の文言は「changed variable を assertion まで追う」という特定の追跡様式を半ば必須化しており、failed-approaches.md が禁じる「探索すべき証拠の種類の事前固定」と実質的にかなり近い。さらに、差分の種類を value propagation に寄せすぎており、control flow・exception・side effect・ordering・resource handling のような非変数中心の差分に対しては汎化性が弱い。

結論として、問題意識は良いが、この具体的な文言のままでは承認しにくい。

---

## 1. 既存研究との整合性

### 参照した Web 情報

1. Agentic Code Reasoning (arXiv)
   - URL: https://arxiv.org/abs/2603.01896
   - 要点:
     - semi-formal reasoning は「explicit premises」「trace execution paths」「formal conclusions」を要求する証明書的な枠組みとして説明されている。
     - patch equivalence / fault localization / code QA の全てで、構造化されたトレースが精度向上に寄与するという主張。
     - よって、「より明示的に下流まで追う」という方向性そのものは、論文のコア思想とは整合的。

2. Data Flow Testing - GeeksforGeeks
   - URL: https://www.geeksforgeeks.org/software-testing/data-flow-testing/
   - 要点:
     - 変数の定義箇所と使用箇所の追跡は、値がどこで定義されどこで利用されるかを確認する一般的手法として整理されている。
     - 「defined but not used」「used but never defined」など、値の伝播追跡がバグ検出に有効であることを説明している。
     - 学術一次資料ではないが、「definition/use を追う」という一般原則の補助線としては妥当。

3. Tracing Logic Without Execution: The Magic of Data Flow in Static Analysis
   - URL: https://www.in-com.com/blog/tracing-logic-without-execution-the-magic-of-data-flow-in-static-analysis/
   - 要点:
     - data flow analysis は、コードを実行せずに「どこで定義され、どう使われ、どの変換を経るか」を追う静的解析の基礎技法として説明されている。
     - downstream での transformation を見る考え方は一般的であり、今回の提案の意図と整合する。
     - こちらも学術一次資料ではないため、補強資料として限定的に扱うべき。

### 監査所見

研究整合性という意味では、提案の方向性はおおむね妥当である。特に Objective.md の Exploration Framework F にある「論文の他モードの手法を compare に応用する」に直接乗っている。

ただし、論文・設計文書が支持しているのは「下流まで追え」という一般原則であって、「changed variable を assertion まで追う」という単一の実装様式ではない。ここは整合している部分と、提案側が過度に具体化している部分を分けて見るべきである。

---

## 2. Exploration Framework のカテゴリ選定は適切か

### 判定

概ね適切。カテゴリ F を選ぶこと自体は妥当。

### 理由

- Objective.md の F には明示的に「論文の他のタスクモード（localize, explain）の手法を compare に応用する」が含まれている。
- proposal.md の中核アイデアは、Appendix D の DATA FLOW ANALYSIS の発想を compare に移植することなので、F に自然に属する。
- 一方で、実際の diff は Guardrail の 1 文追加であり、操作としては E（表現の具体化）にもまたがる。

つまり、カテゴリの主たる発想源は F でよいが、実際に行っていることは「F 発の E 的具体化」である。

---

## 3. EQUIVALENT 判定 / NOT_EQUIVALENT 判定への作用

### EQUIVALENT への作用

強く作用する。しかも主に良い方向に作用する可能性が高い。

- 現行 Guardrail #4 は「差分を見つけたら relevant test を differing path に沿って trace せよ」と言うだけで、どこまで追えば「no impact」と言えるかは曖昧。
- 追加文は「差分が test oracle に届く前に transform/discard されるか」を確認させるため、早すぎる EQUIVALENT 結論を抑制しやすい。
- README.md の「persistent failures remain — both involve EQUIVALENT pairs」とも整合する。

### NOT_EQUIVALENT への作用

直接効果は弱い。間接効果はあるが、主作用ではない。

- NOT_EQUIVALENT は compare テンプレート上、すでに「COUNTEREXAMPLE」「Diverging assertion」を要求しているため、元から test oracle までの差分証明が比較的強い。
- 今回の追加文は「difference has no impact と結論する前に」の条件で発火するため、文面上は EQUIVALENT 側の抑制にかなり偏っている。
- ただし間接的には、「見かけの差分が downstream で吸収される」ことを確認できれば、誤った NOT_EQUIVALENT を減らす余地はある。

### 実効的差分の評価

この変更の実効的差分は、対称的な compare 強化ではなく、EQUIVALENT を出すための証拠要求の増加である。

要するに:
- EQUIVALENT: かなり厳しくなる
- NOT_EQUIVALENT: 既存テンプレートの方が主に効いており、今回の追加効果は限定的

したがって、この提案は実質的に片方向寄りである。README.md の失敗傾向から見ればその狙い自体は理解できるが、「両方向の推論品質改善」とまでは言いにくい。

---

## 4. failed-approaches.md の汎用原則との照合

### 提案者の自己評価

proposal.md は、「探索経路の固定ではなく終端条件の明示なので抵触しない」と主張している。

### 監査評価

この自己評価には同意しきれない。実質的にはかなり近い再演リスクがある。

#### 原則1: 「探索すべき証拠の種類をテンプレートで事前固定しすぎる変更は避ける」

今回の文言は、semantic difference を見つけたときに「changed variable の value propagation」を追うことを求める。これはまさに証拠の種類を value-flow に寄せる。

compare で必要な証拠は常に variable propagation とは限らない。たとえば:
- 例外を投げる / 握りつぶす
- 分岐条件の変化
- 副作用の有無
- 呼び出し順序の変化
- resource cleanup の有無
- 返り値ではなく mutation 対象の違い

こうした差分では「changed variable を assertion まで追う」という指示は不自然、または不十分になりやすい。

したがって、表現を変えていても本質は「特定シグナルの捜索」に寄りうる。

#### 原則2: 「探索ドリフト対策を追加する際は、探索の自由度を削りすぎない」

今回の追加は、探索の幅ではなく深さの制約だ、という提案者の主張には一理ある。しかし実際には、深さの指定が証拠様式の指定と結びついており、compare の思考を value-flow 中心へ引っ張る。結果として、他の差分型の見え方を悪くする可能性がある。

よって、自由度を削りすぎないという原則にも軽微ではなく中程度の抵触リスクがある。

#### 原則3: 「結論直前の自己監査に、新しい必須のメタ判断を増やしすぎない」

この点については、Step 5.5 を増やしていないので proposal の主張どおり直接抵触ではない。

ただし failed-approaches.md には「既存チェック項目への補足に見える形でも、結論前に特定の検証経路を半必須化すると、実質的に新しい判定ゲートとして働きやすい」とある。今回の 1 文は Guardrail 内でそれをやっている側面がある。

### まとめ

形式上は新しい self-check 項目ではないが、実質上は「特定の追跡経路の半必須化」に近い。failed-approaches.md と安全に両立しているとは言いづらい。

---

## 5. 汎化性チェック

### 明示的なルール違反の有無

提案文中に、以下のような露骨な過剰適合シグナルは見当たらない。

- 具体的な数値 ID
- ベンチマーク対象リポジトリ名
- 具体的なテスト名
- 対象リポジトリ由来のコード断片

その点では、Objective.md / Audit Rubric の R1 に対して即失格ではない。

### 暗黙のドメイン・言語仮定

ただし、文言には軽度の暗黙バイアスがある。

- "changed variable's value" という表現は、命令型・変数中心のコードには自然だが、
  - 関数型スタイル
  - 宣言的記述
  - 例外中心の制御
  - state mutation よりイベントやメッセージが本質の系
  ではやや不自然。
- "through to the assertion" は test oracle を明示しており compare には合うが、実際の差分が assertion に値として到達する形で表現されない場合もある。

つまり、露骨な benchmark overfitting ではないが、「value propagation が本質である場面」を暗黙に標準ケースとしている点は汎化性を少し下げる。

### 監査所見

R1 的には 1 ではないが 3 もつけにくい、という印象。問題は固有識別子ではなく、差分の型を狭めることによる潜在的なドメイン偏りである。

---

## 6. 全体の推論品質がどう向上すると期待できるか

### 期待できる向上

- 「差分を見たが downstream handling を見ずに no impact と言う」失敗は減る可能性がある。
- compare における EQUIVALENT 側の証拠水準は上がる。
- Guardrail #5 の「downstream code already handles the edge case」を、より test-oracle 寄りに具体化する補助にはなる。

### 懸念される副作用

- compare の差分理解が value-flow に寄りすぎる。
- 変数として表現しづらい差分を見落としやすくなる。
- 既存 Guardrail #4 と #5 の間にある役割分担を曖昧にし、冗長に近い指示が増える。
- 「どこまで追うか」を明確にしたいという意図に対し、指定した終端条件が narrow すぎる。

### 総合評価

推論品質の改善は「ありうる」が、「一般に improve する」とまではまだ言えない。改善するのは主に propagation-sensitive な EQUIVALENT 誤判定であり、compare 一般の差分理解を底上げするには、文言が特定メカニズムに寄りすぎている。

---

## 補足コメント: どこを直せば承認に近づくか

今回の問題は「下流まで追え」という発想ではなく、「changed variable」という証拠様式の固定にある。

もしこの方向を維持したいなら、次のような一般化が必要だと思う。

- 変数に限定せず、「the changed behavior / state / output / side effect」など、差分の型に応じた表現にする
- value propagation を唯一の追跡法にせず、「reaches, is transformed, is normalized away, or is blocked before the oracle」程度の抽象度に留める
- compare の対称性を保つため、「no impact を結論する前」のみならず、「impact を結論する前」にも oracle への到達証拠を要求する設計の方が筋がよい

今のままだと、良い失敗分析を起点にしているのに、実装文言が narrow になりすぎている。

---

## 最終判断

承認: NO（理由: 方向性は妥当だが、提案文言が compare の証拠収集を "changed variable の value propagation" に寄せすぎており、failed-approaches.md の「証拠種類の事前固定」「特定追跡経路の半必須化」に実質的に近い。EQUIVALENT 側には有効でも作用が片方向寄りで、control flow・exception・side effect など非変数中心の差分への汎化性が不足しているため。）
