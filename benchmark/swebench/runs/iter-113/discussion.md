# Iteration 113 — 監査ディスカッション

## 総評

結論から言うと、この提案は「着眼点そのもの」は理解できるものの、**実効的な作用点が EQUIVALENT 側にしかなく、failed-approaches.md の非対称性ルールに抵触する懸念が強い**。また、compare モードの中心課題は最終的に「既存テスト上の観測可能差異」を判定することであり、そこに対して `explain` モード由来の data-flow 観点を **EQUIV 側の counterexample 不在証明にだけ** 挿入するのは、改善というより EQUIV 主張時の立証負荷の上乗せとして働く可能性が高い。

そのため、現時点では承認しにくい。

---

## 1. 既存研究との整合性

### 1-1. 整合する点

提案の発想自体、つまり「観測可能な差異を見つけるために、値・返り値・副作用の流れを見る」という方向は、一般的なプログラム解析の知見とは整合する。

1. Clang Documentation, "Data flow analysis: an informal introduction"
   URL: https://clang.llvm.org/docs/DataFlowAnalysisIntro.html
   要点:
   - data-flow analysis は、制御フローを考慮しながらプログラム上の値に関する事実を追跡する静的解析手法である。
   - 変数がどの値を取りうるか、分岐合流後にどのような可能値集合になるかを追うことは、挙動理解やバグ発見に有効である。
   - よって「key variable の final value / return value / side-effect に注目する」という発想自体は一般的には妥当。

2. Software Foundations, "Equiv: Program Equivalence"
   URL: https://softwarefoundations.cis.upenn.edu/plf-current/Equiv.html
   要点:
   - プログラム等価性は、全状態に対して同じ結果を返すか、より一般には behavioral equivalence として捉えられる。
   - mutable state を含む場合、単なる式の一致ではなく、状態を通じた観測可能挙動の一致が本質になる。
   - よって return value や state/side effect を観測対象として意識することは、等価性判定の考え方に整合的。

3. Emergent Mind, "Program Equivalence Queries"
   URL: https://www.emergentmind.com/topics/program-equivalence-queries
   要点:
   - program equivalence は、出力だけでなく side effects を含めた indistinguishable behavior を対象にする。
   - 実用上は refactoring verification や translation validation でも、semantic/observational equivalence の観点が重要。
   - 提案の「差異があるなら、最終値・返り値・副作用として観測されるはず」という発想は、研究的には自然。

### 1-2. 整合しない/弱い点

ただし、上記研究は「data-flow が有用」とは言っても、**compare の EQUIV 側のみの記述を強化せよ**とは言っていない。研究的に支持されるのは「観測可能差異までの因果追跡を強化すること」であり、今回の 1 行変更はその一般原則をかなり局所的かつ片側的に実装している。

つまり、研究整合性は
- 発想レベルでは Yes
- 実装位置の選び方としては Weak
という評価になる。

---

## 2. Exploration Framework のカテゴリ選定は適切か

### 判定

**カテゴリ F の選定理由自体は理解可能だが、今回の具体案は F の中でも実装位置の選び方が不適切寄り**。

### 理由

Objective.md の F は「原論文の未活用アイデアを導入する」カテゴリであり、特に
- 論文の他モードの手法を compare に応用する
は今回の提案に形式上合致している。

実際、`explain` テンプレートにある DATA FLOW ANALYSIS を compare に持ち込みたい、という着想は F の定義に沿っている。

しかし問題は、compare に必要なのは `explain` の data-flow 記録をそのまま移植することではなく、**等価性判定の中心ループにおいて「どこで観測差異が出るか」を追わせること**である。今回の変更は compare の本体分析ループではなく、EQUIV 主張時にだけ書く `NO COUNTEREXAMPLE EXISTS` ブロック内の `Searched for:` の文言だけを差し替える。

そのため、カテゴリ F の「未活用アイデアの導入」という大分類は妥当でも、**導入の仕方が compare の主ループではなく EQUIV の停止条件側に偏っている**。この実装位置の選択は、汎用原則としてはあまり筋がよくない。

---

## 3. EQUIVALENT 判定と NOT_EQUIVALENT 判定への作用

## 3-1. 変更前との差分

変更前:
- `NO COUNTEREXAMPLE EXISTS (required if claiming EQUIVALENT)` の中で
  `Searched for: [specific pattern — test name, code path, or input type]`

変更後:
- 同じ場所で
  `Searched for: [data-flow pattern — key variable's final value, return value, or side-effect that would differ; plus test name or code path that would observe the divergence]`

### 実効的差分

この差分の本質は、compare 全体に data-flow 観点を追加したことではない。**EQUIVALENT を主張する場合に限って、反例探索の記述をより具体化・厳格化した**ことにある。

## 3-2. EQUIVALENT への作用

EQUIVALENT 側には直接作用する。

期待される正の効果:
- 「差異なし」と言う前に、何の値・返り値・副作用がズレうるかを考えるので、雑な誤 EQUIV は減る可能性がある。
- Guardrail #4 / #5 系、すなわち subtle difference の見落としや downstream handling の未確認を減らす方向には一応働く。

想定される負の効果:
- EQUIV を出す前の立証負荷が増える。
- しかも焦点が test/input から data-flow に寄るため、compare の本来の判定対象である「既存テスト上の観測結果」に対する注意が、内部状態追跡へズレる可能性がある。
- 結果として、EQUIV を出しづらくし、NOT_EQ あるいは保守的結論へ寄せる非対称圧力になりうる。

## 3-3. NOT_EQUIVALENT への作用

NOT_EQ 側への直接作用はほぼない。

理由:
- 変更箇所は `NO COUNTEREXAMPLE EXISTS (required if claiming EQUIVALENT)` に限定されている。
- `COUNTEREXAMPLE (required if claiming NOT EQUIVALENT)` ブロックには一切変更がない。
- したがって、NOT_EQ を出すための探索・立証・記述の手順は実質据え置きである。

## 3-4. 片方向にしか作用しないか

**はい。実効的には片方向にしか作用しない。**

提案文では「NOT_EQ 判定のロジックには直接触れない」と書かれているが、これは監査観点ではむしろ問題である。failed-approaches.md の原則 #6 が言う通り、評価すべきは「変更後の文言が対称か」ではなく「変更前との差分がどちらに作用するか」である。

今回の差分は
- EQUIV を出すときだけ追加的に強い探索観点を要求する
- NOT_EQ には追加要求を課さない
という意味で、**差分として非対称**。

したがって、原則 #1, #6, #12 に対する懸念は強い。

---

## 4. failed-approaches.md の汎用原則との照合

### 強く懸念される項目

1. 原則 #1「判定の非対称操作は必ず失敗する」
   - 今回の変更は EQUIV 側のみに追加的探索観点を入れる。
   - 文面上は「counterexample 探索の精緻化」でも、実効上は EQUIV の立証負荷を上げる。
   - これは典型的な非対称操作の懸念がある。

2. 原則 #6「対称化は既存制約との差分で評価せよ」
   - 提案は abstract には観測差異を重視するため対称に見える。
   - しかし差分は EQUIV ブロックにしか入っていないため、変更の実効は非対称。
   - この点で原則 #6 にかなり近い失敗再演の構造を持つ。

3. 原則 #12「アドバイザリな非対称指示も実質的な立証責任の引き上げとして作用する」
   - `Searched for:` の精緻化は見た目には軽い advisory change だが、モデルには「EQUIV を言うならこれを満たせ」という要件として作用しやすい。
   - したがって #12 のパターンとも整合する。

4. 原則 #20「目標証拠の厳密な言い換えや対比句の追加は、実質的な立証責任の引き上げとして作用する」
   - 今回はまさに既存文言の言い換えであり、より厳格な観測対象を埋め込んでいる。
   - 意図が明確化であっても、実効としてはハードル上昇になりうる。

### 中程度の懸念

5. 原則 #5「入力テンプレートの過剰規定は探索視野を狭める」
   - 提案は「限定ではなく具体化」と主張しているが、実際には `input type` を消し、`data-flow pattern` を前面化している。
   - compare における重要探索軸は test/input/observable divergence であり、内部 data-flow を強く指定すると探索視野が state-centric に寄る恐れがある。

6. 原則 #22「抽象原則での具体物の例示は、物理的探索目標として過剰適応される」
   - 今回の `key variable's final value, return value, or side-effect` は、固有名ではないので proposal が主張するほど強い違反ではない。
   - ただし compare のたびに「どの key variable を選ぶか」という中間タスクを増やし、物理的探索目標として過剰適応される懸念は残る。

### 比較的問題が小さい項目

- #8 の「受動的記録フィールド追加」には当たらない。新規フィールド追加ではなく既存文言の変更だから。
- #18/#19/#24/#26 ほどの重い証拠義務化ではない。1 行変更なので複雑性増は小さい。

### 小結

提案文は failed-approaches.md を意識して丁寧に反論しているが、**もっとも重要な #1/#6/#12 への反証が不十分**。ここが本監査での最大の否定要因。

---

## 5. 汎化性チェック

### 5-1. 具体的な数値 ID, リポジトリ名, テスト名, コード断片の有無

判定:
- **ベンチマーク対象リポジトリ名、具体的テスト名、対象コード断片の引用は見当たらない**。
- 提案内のコードブロックは SKILL.md 自身の文言差分であり、Objective.md の R1 減点対象外に該当する「SKILL.md 自身の文言引用」とみなせる。
- `Iteration 113` や `Guardrail #4/#5` のような数字はあるが、これは benchmark case ID や対象 repo ID ではなく、メタ情報または内部参照番号である。

したがって、**明示的なルール違反とは判定しない**。

### 5-2. 暗黙のドメイン依存

ここには軽い懸念がある。

- `key variable`、`final value`、`return value`、`side-effect` という語彙はかなり一般的ではある。
- ただし発想の中心が「変数を追える命令型コード」に寄っており、宣言的・高階関数中心・設定駆動・DSL 的なコードでは、どの変数を key とみなすかが曖昧になりやすい。
- compare の判定対象が「既存テストの pass/fail outcome」である以上、汎用的な中心観点は data-flow そのものよりも「observable divergence」であるべき。

よって、露骨な overfitting ではないが、**若干 imperative/style-biased** である。

---

## 6. 全体の推論品質がどう向上すると期待できるか

### 期待できる点

- 誤 EQUIV の一部、特に「内部差異を見つけたが、その差が最終的にどう現れるかを考えずに無害とみなす」タイプには一定の抑止力がある。
- explain モードの data-flow 的観点を compare の refutation に接続する発想は、観測可能結果までの因果追跡を意識させる点では有益。

### 期待しにくい点

- compare 精度全体の改善、特に EQUIV/NOT_EQ の両側改善は期待しにくい。
- 変更が compare の主分析ループではなく EQUIV の停止条件にだけ入るため、根本的に「探索の質を対称に上げる」というより「EQUIV の self-justification を重くする」方向に働く。
- その結果、誤 EQUIV が少し減っても、正しい EQUIV の取りこぼしや UNKNOWN/保守判定が増える回帰リスクがある。

### 監査上の要約

この提案は
- 発想: 妥当
- 差分の置き場所: 不適切
- 実効: 片側作用
という評価である。

本当にこの方向を採るなら、`NO COUNTEREXAMPLE EXISTS` の 1 行精緻化ではなく、compare 全体の per-test tracing の中で「観測可能差異に至る state/return/side-effect の因果連鎖を見る」ような、**両判定に効く主ループ側の改善**として再設計すべきである。

---

## 最終判定

**承認: NO（理由: 変更の実効が EQUIVALENT 側にしか作用せず、failed-approaches.md の原則 #1, #6, #12 に抵触する非対称な立証負荷上昇として働く懸念が強いため。発想自体は研究的に妥当だが、実装位置が compare の主ループではなく EQUIV 側の停止条件に偏っており、全体精度の改善より回帰リスクの方が大きい。）**
