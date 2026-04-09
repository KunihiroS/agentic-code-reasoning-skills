# Iter-110 Discussion

## 総評
提案の狙い自体は理解できる。`compare` モードにおける観測境界を「実行パス上の差異」から「テストオラクルが実際に観測する差異」へ寄せたい、という方向は研究的にも自然である。

ただし、今回の変更は「比較の枠組みを対称化する改善」という説明に対して、実効的な差分は `NO COUNTEREXAMPLE EXISTS` 側だけを厳しくする 1 行変更である。したがって、文面上は対称性を語っていても、運用上は EQUIVALENT 側の立証責任だけを引き上げる可能性が高い。

そのため、現時点の監査判断は 承認 NO とする。

---

## 1. 既存研究との整合性

補足: DuckDuckGo MCP の `search` は今回の環境では繰り返し no results だったため、同じ DuckDuckGo MCP の `fetch_content` で基礎資料を直接確認した。

### 参照した外部資料

1. Test oracle — Wikipedia  
   URL: https://en.wikipedia.org/wiki/Test_oracle
   - 要点: テストオラクルは「入力に対して何が正しい出力か」を与える仕組みであり、テストでは実際の結果を期待結果と比較する。
   - 関連性: 提案が「挙動差」より「どの assertion で pass/fail が変わるか」を重視するのは、差異をオラクル境界へ寄せる発想として妥当。

2. Observational equivalence — Wikipedia  
   URL: https://en.wikipedia.org/wiki/Observational_equivalence
   - 要点: 2つの対象が observable implications に関して区別不能なら observationally equivalent とみなされる。
   - 関連性: D1 の「既存テストに対する同一 pass/fail」を観測可能な差異の基準とみなす方向は、観測可能性ベースの等価性と整合する。

3. Counterexample-guided abstraction refinement (CEGAR) — Wikipedia  
   URL: https://en.wikipedia.org/wiki/Counterexample-guided_abstraction_refinement
   - 要点: 反例は「本当に性質違反を示す反例」か「抽象化が粗すぎて生じた見かけ上の反例」かを区別すべきである。
   - 関連性: 「中間挙動差」と「実際に判定結果を変える差」を区別したいという提案の問題意識は、spurious counterexample を落としたいという一般原則と整合する。

### 研究整合性の監査所見

この提案の核にある「観測境界を test oracle に揃える」という発想は、README は空だが、`docs/design.md` が述べる「per-test iteration」「formal definitions of equivalence」「counterexample obligation」とは矛盾しない。むしろ compare モードの定義 D1 を、反例記述の粒度にも一貫させたいという発想としては理解可能である。

ただし、研究整合性があることと、今回の 1 行差分が実際に有効であることは別問題である。研究的に妥当な方向性でも、フレームワークへの差分としては片方向にしか作用しないなら、全体精度の改善保証にはならない。

---

## 2. Exploration Framework のカテゴリ選定は適切か

### 判定
部分的には妥当だが、選択したメカニズム C2 との対応は弱い。

### 理由
提案者はカテゴリ C「比較の枠組みを変える」を選び、C2「差異の重要度を段階的に評価する」を採用している。

しかし実際の変更は、差異の重要度を段階的に評価する手順を追加していない。変更しているのは `NO COUNTEREXAMPLE EXISTS` 内の反例記述の粒度であり、
- 「どこで実行が分岐するか」ではなく
- 「どの assertion で pass/fail が変わるか」
を記述させるものになっている。

これは「重要度の段階評価」というより、
- 観測境界の再定義
- 反例の記述フォーマットの厳格化
- 比較時に採用する差異概念の限定
に近い。

したがってカテゴリ C 自体はまだ理解できるが、C2 というメカニズム名は実態より良く見せている印象がある。より正確には「比較対象の差異を oracle-visible な差異へ限定する変更」であって、「段階的評価」ではない。

汎用原則としては、観測可能な差異を基準にすること自体は理にかなっている。ただし、その原則を `NO COUNTEREXAMPLE EXISTS` 側だけに追加すると、原則の良さより片方向制約の副作用が前面に出る。

---

## 3. EQUIVALENT 判定と NOT_EQUIVALENT 判定の両方への作用

### 実効的差分
変更前:
- EQUIVALENT を主張する際、仮想反例は「what test, what input, what diverging behavior」でよかった。

変更後:
- EQUIVALENT を主張する際、仮想反例は「what test assertion would produce a different pass/fail, and what diverging value at that assertion would cause it」まで要求される。

NOT_EQUIVALENT 側の `COUNTEREXAMPLE` は元々、
- divergent assertion
- differencing PASS/FAIL
を要求している。

### 監査所見
このため、差分は実質的に EQUIVALENT 側だけに作用する。

提案文は「反証構造を揃えるので双方に効く」と述べるが、`failed-approaches.md` の原則 #6 が言う通り、評価すべきなのは変更後の見た目の対称性ではなく、変更前との差分である。

差分ベースで見ると:
- NOT_EQUIVALENT 側: 既存のまま。ほぼ変化なし。
- EQUIVALENT 側: 仮想反例の具体化要求が強まる。

### 期待される実際の作用
1. EQUIVALENT への作用
   - 正の可能性: 「何となく差異なし」と雑に言うショートカットは減るかもしれない。
   - 負の可能性: assertion と diverging value まで特定できないと EQUIVALENT を出しにくくなり、UNKNOWN や NOT_EQUIVALENT 側への逃避が増える可能性がある。

2. NOT_EQUIVALENT への作用
   - 直接効果は弱い。テンプレート上の必要条件は既に満たされているため、今回の 1 行差分で NOT_EQUIVALENT 側の推論品質が大きく上がる根拠は薄い。

3. 全体としての非対称性
   - 提案の説明は双方向改善だが、実効差分は片方向である。
   - したがって「EQUIVALENT の偽陽性も NOT_EQUIVALENT の偽陽性も抑える」という期待は、少なくともこの差分単体では過大評価である。

結論として、この変更は片方向にしか強く作用しない可能性が高い。

---

## 4. failed-approaches.md の汎用原則との照合

### 原則 #1 判定の非対称操作
抵触懸念が強い。  
文面上は対称化でも、差分としては EQUIVALENT 側だけの立証責任を引き上げるため、実効的には非対称操作になりうる。

### 原則 #4 同じ方向の変更は表現を変えても同じ結果になる
懸念あり。  
「EQUIVALENT を出すにはもっと強い反証不在の説明をしろ」という方向の変更であり、過去の片方向 tightening と本質的に近い可能性がある。

### 原則 #6 「対称化」は既存制約との差分で評価せよ
かなり強く抵触。  
今回もっとも重要なのはここで、提案者は「COUNTEREXAMPLE 節と揃うから対称化」と説明しているが、差分評価では新規拘束は EQUIVALENT 側にしか入っていない。

### 原則 #18 特定証拠カテゴリへの厳格な物理的裏付け要求
中程度の懸念。  
提案は `file:line` の assertion 引用を明示的には要求していないが、「どの test assertion」「どの diverging value」とかなり具体的な証拠カテゴリを指定している。これにより、エージェントが assertion 単位の再探索にターンを使う可能性がある。

### 原則 #20 目標証拠の厳密な言い換えや対比句の追加
懸念あり。  
これはまさに既存の `diverging behavior` を、より厳格で排他的な言い回しへ変更する提案である。明確化のつもりでも、モデルには「より強い証明責任」として作用しうる。

### 原則 #22 抽象原則での具体物の例示
軽度から中程度の懸念。  
proposal は「assertion」を観測境界として使っており、これは概念的には理解できる一方、モデルがそれを「必ず assertion 行を特定しなければならない物理的探索目標」として過剰適応する危険がある。

### 原則 #26 中間ステップでの過剰な物理的検証要求
関連懸念あり。  
提案者は final refutation step だから問題ないと書くが、実際には compare 証明書の中で EQUIVALENT を成立させるための必須要件である以上、運用上は強いゲートになる。各候補差異について assertion レベルの具体化が必要になるなら、探索予算消費と安全側誤判定の増加を招く。

### 小結
提案者の自己評価よりも、failed-approaches との衝突は大きい。特に #1, #6, #20 が本質的な懸念点である。

---

## 5. 汎化性チェック

### 具体的な ID・リポジトリ名・テスト名・コード断片の有無
ベンチマーク対象リポジトリの固有識別子、具体的テスト名、ケース ID、実装コード断片は見当たらない。  
この点では大きなルール違反はない。

補足:
- `Iter-110`, `C2`, `C3`, `Guardrail #4`, `failed-approaches #7` などの番号は、内部の管理ラベルや文書参照であり、ベンチマーク対象リポジトリ固有 ID とは異なる。
- 変更前後の SKILL 文言引用も、Objective の減点対象外の扱いと整合する。

### 暗黙のドメイン想定
ただし、汎化性には別の懸念がある。

この提案は「どの test assertion が異なる pass/fail を生むか」を中心に据えているため、暗黙に以下を想定しやすい。
- xUnit 型の明示的 assertion 行がある
- pass/fail が単一 assertion で分かりやすく説明できる
- 差異を値レベルで局所化しやすい

しかし実際のテストオラクルはもっと広い。
- 例外発生自体が oracle になるケース
- snapshot / golden file 比較
- property-based testing
- stateful / multi-step integration test
- implicit oracle（クラッシュしない、タイムアウトしない、整合条件を破らない等）

こうした環境では、「どの assertion 行か」を強く要求する表現は汎用性を落とす。D1 は pass/fail outcome ベースで十分に一般的なのに、今回の差分はそれを assertion-centric な表現へ狭めている。

したがって、ベンチマーク固有性の問題は薄いが、テスト様式の多様性に対する汎化性には懸念が残る。

---

## 6. 全体の推論品質がどう向上すると期待できるか

### 良い方向に働く可能性
- エージェントが「中間挙動差」をそのまま decisive difference と誤解するのを減らす可能性はある。
- D1 の「既存テストの pass/fail が同一か」という基準に、反証記述の粒度を近づけたいという狙いは理解できる。
- compare モードで「何が観測可能差異なのか」を意識させる点は、抽象的には有益。

### 期待効果が限定的な理由
- 実装差分が 1 行で、しかも EQUIVALENT 側だけを厳しくするため、改善が出るとしても局所的。
- NOT_EQUIVALENT 側の推論の質を直接改善する仕組みは増えていない。
- assertion と diverging value の具体化が困難なケースでは、正しい EQUIVALENT まで出しにくくなる。
- 「観測境界に着目せよ」という認知的狙いは良いが、今回の形では「より厳格な記述義務」に変換されており、推論支援よりゲート化に近い。

### 監査上の総合評価
方向性そのものは悪くないが、差分の入れ方が悪い。  
もし本当に汎用的に改善したいなら、EQUIVALENT 側だけの必須文言 tightening ではなく、compare 全体で「観測可能差異」と「中間差異」をどう見分けるかを、片方向でない形で支援する必要がある。

---

## 最終判断
承認: NO（理由: 変更の説明は対称化だが、変更前との差分としては EQUIVALENT 側だけを厳しくする片方向の tightening であり、failed-approaches.md の原則 #1・#6・#20 に抵触する懸念が強い。さらに assertion-centric な表現はテストオラクルの多様性に対する汎化性をやや損なうため。）
