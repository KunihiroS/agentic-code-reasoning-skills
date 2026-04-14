# Iteration 18 — Discussion

## 総評

結論から言うと、この提案は発想自体は理解でき、既存研究の「反証を先に意識させる」という流れとも一定の整合はあります。しかし、現在の文言のままでは「探索の方向付け」を超えて「探索対象の事前固定」に近づいており、`failed-approaches.md` の原則 1・2 と本質的に衝突する懸念が強いです。

特に問題なのは、追加文が単に「反証可能性を意識せよ」と言っているのではなく、

- `minimal behavioral difference`
- `This defines the target of the per-test search below`

という形で、以後の per-test 探索の主ターゲットを先に 1 本立てさせている点です。これは compare モードの探索を広げるより、むしろ先入観で狭める方向に働く可能性があります。

そのため、現状案には承認を出しません。

---

## 1. 既存研究との整合性

DuckDuckGo MCP の search は今回クエリで安定した結果を返せなかったため、MCP の fetch_content で既知の関連文献ページを直接参照した。

### 1-1. Agentic Code Reasoning 論文
- URL: https://arxiv.org/abs/2603.01896
- 要点:
  - 論文の核は、明示的な premises、execution path tracing、formal conclusion、counterexample/counterfactual 的な確認を含む semi-formal reasoning を「certificate」として機能させることにある。
  - したがって、「EQUIVALENT 判定の前に反証可能な差異を意識させる」という方向性そのものは、研究コアとは整合的。
- ただし:
  - 論文の強みは「探索の証拠化・逐次化」であって、「分析開始前に単一の差異ターゲットを固定すること」までは直接支持していない。
  - よって、本提案は研究コアの延長線上にはあるが、文言次第では研究コアを強化するというより、探索の柔軟性を削る逸脱に転びうる。

### 1-2. Counterfactual thinking
- URL: https://en.wikipedia.org/wiki/Counterfactual_thinking
- 要点:
  - 実際と異なる代替結果を先に考えることは、改善・計画・原因理解に資することがある。
  - 提案の「NOT EQUIVALENT なら何が起きるはずかを先に言語化する」は、この一般的な counterfactual thinking と整合する。
- ただし:
  - 代替結果を先に置くことは、同時に「どの代替結果を思い浮かべたか」へのアンカリングも生みうる。
  - したがって、counterfactual を early-stage に導入すること自体は合理的でも、「1 つの minimal difference を探索ターゲットとして固定する」設計まで正当化するものではない。

### 1-3. Counterexample-Guided Abstraction Refinement (CEGAR)
- URL: https://en.wikipedia.org/wiki/Counterexample-guided_abstraction_refinement
- 要点:
  - 検証系では、まず反例候補を考え、それが本物かスプリアスかを確かめながら精密化していく、という counterexample-driven な考え方が一般に有効。
  - 本提案も「反例になる振る舞いを先に考える」という意味で、検証一般の発想とは整合する。
- ただし:
  - CEGAR は反例が外れたら抽象を洗い直して refinement するループが本体である。
  - 今回の提案には refinement の仕組みがなく、最初に思いついた差異候補が外れた時に別の差異候補へ柔軟に切り替える保証がない。
  - そのため、counterexample-driven の「良い部分」だけでなく、「最初の仮説への固定化」という悪い副作用も出うる。

### 小結

研究との整合性は「部分的にはある」が、「現行文言のままで強く支持される」とまでは言えない。特に、既存研究が支持するのは

- 反証を重視すること
- 反例を具体化すること
- 結論前に counterexample を探すこと

であって、

- 分析開始前に単一の探索ターゲットを定義すること

ではない。

---

## 2. Exploration Framework のカテゴリ選定は適切か

### 判定
概ね Category A ではあるが、純粋な A というより A と D の中間。

### 理由

この変更は compare モードの per-test tracing の「前」に逆方向推論を置くので、確かに

- 推論の順序・構造を変える
- 結論から逆算して必要証拠を考える

という点では Category A に入る。

一方で、実際に追加される命令は「探索前に 1 つメタな問いを立てる」ものであり、機能としては

- 自己チェック
- 仮説の前景化
- 反証観点の事前宣言

にも近い。したがって、カテゴリ選定は完全に不適切ではないが、「A だから failed-approaches の探索固定化原則から外れる」とは言えない。

### 汎用原則としての妥当性

「逆方向推論」自体は汎用原則として妥当。実際、等価性判定・バグ診断・検証では

- もし結論が誤りなら何が観測されるはずか
- その反証はどこに現れるはずか

を先に考えるのは有効である。

ただし、本提案の具体文言は「逆方向推論」一般ではなく、「minimal behavioral difference を 1 つ定め、それを per-test search の target にする」というかなり強い具体化になっている。問題はカテゴリ A であることではなく、この具体化の強さである。

---

## 3. EQUIVALENT 判定と NOT_EQUIVALENT 判定の両方への作用

### 提案文の主張
提案文は、主に EQUIVALENT 判定の弱さを狙い、NOT EQUIVALENT 判定には実質無影響だと述べている。

### 監査判断
その理解は甘い。実効的には両方向に作用する。

### 変更前との実効差分
変更前:
- per-test tracing を行う
- EQUIVALENT なら最後に「NO COUNTEREXAMPLE EXISTS」を書く
- NOT_EQUIVALENT なら COUNTEREXAMPLE を書く

変更後:
- per-test tracing に入る前に、「NOT EQUIVALENT ならどんな最小差異があるはずか」を先に定める
- その差異が per-test tracing の探索ターゲットになる
- その後で通常の各 test 分析と counterexample/no-counterexample セクションに進む

つまり、差分は最終セクションだけでなく、ANALYSIS OF TEST BEHAVIOR 全体の探索の仕方を変える。したがって、EQUIVALENT だけに効いて NOT_EQUIVALENT には効かない、という設計ではない。

### EQUIVALENT への作用
プラス面:
- 「差異が見つからなかった」だけで安心する受動的判定を減らせる可能性がある。
- no-counterexample 記述が後付けの形式ではなく、探索初期から反証志向になる。

マイナス面:
- 最初に思いついた minimal difference が外れていた場合、「その差異は無い」ことをもって広く「差異は無い」に近い心理状態になりうる。
- すると false EQUIVALENT を減らすどころか、別種の差異を見落として false EQUIVALENT を残す可能性もある。

### NOT_EQUIVALENT への作用
プラス面:
- 先に差異候補を言語化するので、counterexample を見つけるまでの到達が早くなる可能性はある。
- subtle difference dismissal の抑制に一定の効果はありうる。

マイナス面:
- 先に 1 つの差異型を target 化すると、実際の counterexample が別の差異型にある場合、それを見落とす危険がある。
- つまり、NOT_EQUIVALENT 側でも recall を落とすリスクがある。

### 結論
この変更は片方向にしか作用しない変更ではない。EQUIVALENT と NOT_EQUIVALENT の両方に効く。
しかも、両方に対して

- 反証の明確化による改善可能性
- 初期仮説へのアンカリングによる悪化可能性

の両面を持つ。提案文の「NOT EQUIVALENT 判定: COUNTEREXAMPLE セクションは変更しないため影響なし」は、実効差分の見積もりとして不十分。

---

## 4. failed-approaches.md の汎用原則との照合

## 原則 1: 探索の証拠種類をテンプレートで事前固定しすぎない

提案文は「証拠種類ではなく方向性」と説明しているが、実際の追加文には

- `state the minimal behavioral difference`
- `This defines the target of the per-test search below`

とある。これは運用上、「差異の種類」を先に 1 つ立てて、その差異に沿って探索することを求めるに等しい。

つまり、表現上は「方向性」でも、機能上はかなり強い target fixation であり、failed-approaches の原則 1 に相当程度抵触している。

特に compare モードでは、本来必要なのは
- 差異 A があるか
- 差異 B があるか
- 差異 C は downstream で吸収されるか

といった複数候補の往復であることが多い。ここで singular な `the minimal behavioral difference` を先に置くと、探索が「想定した差異の確認/否定」へ縮退しやすい。

## 原則 2: 探索ドリフト対策で探索の自由度を削りすぎない

これも抵触懸念がある。

提案文は「手順は変えない、目的を明確にするだけ」と述べるが、compare モードでは per-test tracing が実質的な探索本体である。そこに「search target」を前置きすることは、自由探索を目的志向探索へ変える。

目的志向そのものは悪くないが、今回の文言は
- target が単数形
- minimal difference を要求
- tracing の前に mandatory に置く

という 3 点が重なり、自由度削減が強い。

## 原則 3: 結論直前の自己監査に新しい必須メタ判断を増やしすぎない

ここは提案文の主張通り、直接の抵触ではない。
この変更は Step 5.5 の直前チェックには入らず、分析冒頭の追加なので、failed-approaches 原則 3 との衝突は弱い。

### 小結
failed-approaches との照合では、最大の懸念は原則 1 と原則 2。現案は「過去失敗の再演ではない」と言い切れない。むしろ、文言の中核部分がその失敗原則にかなり近い。

---

## 5. 汎化性チェック

### 形式面の違反有無
明示的なルール違反は見当たらない。

提案文には
- ベンチマーク対象リポジトリ名
- 具体的なテスト名
- ケース ID
- ベンチマーク実コード断片

は含まれていない。

含まれているのは
- SKILL.md 自身の引用
- SKILL.md 内の行番号参照
- 抽象的な例示（return value / exception / side effect）

であり、これは Objective.md の R1 の減点対象外の考え方とも整合する。

### 暗黙のドメイン依存性
大きなドメイン依存は弱い。提案は compare モード固有ではあるが、それはモードの仕様上当然であり、特定言語や特定フレームワークには寄っていない。

ただし、暗黙のバイアスはある。

- 「minimal behavioral difference」という表現は、差異が比較的局所・単発・観測可能であることを暗に想定しやすい。
- 実際には、等価性を破る差異は複合的で、単一の return value / exception / side effect に還元しにくいこともある。
- したがって、言語依存ではないが、「差異は 1 つの最小観測差として先に要約できる」という問題設定寄りの仮定を置いている。

これは即 overfitting ではないが、汎化性の強さをやや下げる要素。

---

## 6. 全体の推論品質がどう向上すると期待できるか

### 期待できる改善
- EQUIVALENT 判定での受動的な「差異なし」宣言を減らす可能性
- 反証ターゲットを早めに明確化することによる、証拠探索の明確化
- subtle difference dismissal を減らす可能性

### 期待しにくい点 / 懸念
- 既存 compare テンプレートには、すでに
  - per-test tracing
  - COUNTEREXAMPLE
  - NO COUNTEREXAMPLE EXISTS
  - Step 5 の refutation check

  がある。つまり「反証を考えること」自体は未導入ではない。
- 今回の変更で追加されるのは、反証の有無そのものではなく、「反証候補を tracing 前に 1 つ固定する」ことに近い。
- そのため、純粋な品質向上というより、探索の配向を変える変更であり、改善幅は不確実。
- 特に、既存の failure mode が「反証を考えていない」ことではなく、「広く trace し切れていない」「downstream handling を落としている」「意味差を早く dismiss している」ことなら、単一ターゲット化は対症療法になっても根治にはならない。

### 監査者としての見立て
最良ケースでは、EQUIVALENT 側の false positive を少し減らす可能性はある。しかし現行文言のままでは、

- 最初の差異仮説へのアンカリング
- singular target による探索の狭窄
- NOT_EQUIVALENT 側 recall 低下の潜在リスク

があり、全体正答率を安定改善する変更だとはまだ言いにくい。

---

## 最終判断

承認: NO（理由: 逆方向推論そのものは妥当だが、現行文言は `minimal behavioral difference` を `the target of the per-test search` として事前固定しており、failed-approaches.md の「探索の証拠種類を事前固定しすぎない」「探索の自由度を削りすぎない」という原則に本質的に近い。加えて、提案文が主張するほど EQUIVALENT 側だけに限定して作用する変更ではなく、NOT_EQUIVALENT 側にもアンカリング由来の回帰リスクがあるため。）

## 補足

もし同じ方向性を残したいなら、承認可能性があるのは「単一の target を定義させる」案ではなく、例えば

- 反証候補を 1 つに限定しない
- `This defines the target of the per-test search` のような固定化表現を避ける
- `what evidence would refute equivalence?` のように、探索を狭めない形で counterfactual を前倒しする

といった、より弱い wording にした場合だと思われる。
