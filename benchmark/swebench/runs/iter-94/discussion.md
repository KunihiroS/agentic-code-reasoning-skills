# Iteration 94 — 監査ディスカッション

## 総評

今回の提案は、`Compare checklist` の既存項目を 1 行だけ強化し、差異を見つけた後の伝播トレースを「中間関数で止めない」ようにするものです。方向性自体は、`docs/design.md` が強調する `Incomplete reasoning chains` と `Subtle difference dismissal` への対策として自然です。

ただし、監査上の重要点は「変更後の文言が対称に見えるか」ではなく、「変更前との差分が実効的にどちらの判定に強く作用するか」です。そこを厳密に見ると、この提案は NOT_EQUIVALENT 側の立証を主に強化する一方、EQUIVALENT 側には限定的にしか効かず、しかも探索コスト増による回帰リスクがあります。

そのため、現時点では承認は難しいです。

---

## 1. 既存研究との整合性

DuckDuckGo MCP の `search` はこの環境では結果を返せなかったため、同じ DuckDuckGo MCP の `fetch_content` で既知の関連資料を取得して確認しました。

### 参照 URL と要点

1. https://en.wikipedia.org/wiki/Program_slicing
   - 要点: program slicing は「ある観測点の値に影響しうる文」を遡って求める手法であり、デバッグや program analysis に使われる。
   - 今回提案との関係: 「差異が最終的な観測点に届くか」を追う発想自体は、この系統の研究と整合的。
   - ただし slicing の一般論は「依存関係の追跡」を支持するのであって、毎回「テストアサーション到達」を停止条件として厳格に要求することまでは直ちに支持しない。

2. https://research.cs.wisc.edu/wpis/abstracts/toplas90.abs.html
   - 要点: Horwitz/Reps/Binkley の interprocedural slicing は、procedure 境界をまたいで、ある点の値に影響しうる文を求める問題を扱う。主眼は call context を保った依存追跡にある。
   - 今回提案との関係: 中間関数で止まらず、呼び出し境界を越えて因果連鎖を追うべきだ、という主張には強く整合する。
   - ただし研究の主眼は「適切な interprocedural dependency tracking」であり、「assertion という具体物を毎回探索終点にすること」ではない。

3. https://llvm.org/docs/DependenceGraphs/index.html
   - 要点: LLVM の dependence graph 文書は、data dependency と control-flow dependency の両方を使って program elements 間の関係を解析することを説明している。
   - 今回提案との関係: behavioral difference を downstream consumer に伝播させるかどうかを見る、という観点は依存グラフ的な考え方と一致する。
   - ただし、依存解析は通常「影響関係を効率的に捉える」ための抽象化であり、自然言語プロンプトに「assertion 到達まで継続」と書くと、実装のない人手探索義務に近づく。

4. https://en.wikipedia.org/wiki/Change_impact_analysis
   - 要点: change impact analysis は変更の結果どこに影響が及ぶかを、traceability / dependency の両面から評価する。
   - 今回提案との関係: 「変更差異を outcome まで接続する」問題設定は change impact analysis と整合的。
   - ただし impact analysis は通常、影響先の同定精度とコストのバランスが重要であり、探索停止条件を過度に厳しくするとコスト過大化の懸念が出る。

### 研究整合性の結論

- 良い点: 「中間差異を見ただけで結論しない」「下流の観測点まで因果連鎖を追う」という方向は、program slicing / dependence analysis / impact analysis と整合的。
- 懸念点: 研究が支持しているのは dependency-aware reasoning であって、`test assertion` という具体的・物理的ターゲットへの到達義務化ではない。したがって、研究整合性は「部分的には高いが、提案文の stopping rule は研究から一段厳格化されすぎている可能性がある」と評価する。

---

## 2. Exploration Framework のカテゴリ選定は適切か

提案ではカテゴリ B「情報の取得方法を改善する（コードの読み方の指示を具体化する）」を選んでいます。

これは概ね妥当です。

理由:
- 変更対象は `Compare checklist` の読解・追跡方法であり、結論ラベルそのものを直接いじっていない。
- 本質は「差異発見後に、どこまで downstream を読みに行くか」の探索停止条件の調整であり、これは `how to inspect` の問題。
- したがって A（順序変更）や D（自己チェック）より B が近い。

ただし補足すると、今回の変更は単なる「読み方の具体化」にとどまらず、実質的には「停止条件の厳格化」です。したがってカテゴリ B ではあるが、性質としては E（表現改善）よりも強く、探索量・立証責任に実効差分を与える変更です。この点を軽く見てはいけません。

結論:
- カテゴリ B 選定は妥当。
- ただし「ただの wording clarification」ではなく、実効的には探索要求の強化である。

---

## 3. EQUIVALENT / NOT_EQUIVALENT の両方にどう作用するか

ここが監査上の核心です。

### 変更前の基準

既存文言:
- 差異を見つけたら、その出力を消費する関数を読み、`propagates or absorbs` を記録してから Claim outcome を決める。

既存の `Guardrails` もすでに:
- subtle difference を見つけたら relevant test through the differing code path を trace せよ
と述べています。

つまり変更前から、少なくとも原則としては「差異を見つけた直後に止まるな」は入っています。

### 今回の実効差分

今回追加される差分は:
- `continuing until the trace reaches a test assertion or a confirmed absorption point`

これは見た目は対称的ですが、変更前との差分としてみると、主に次のケースだけを強めます。

1. `propagates` と書いた段階で止まりがちなケース
   - ここでは assertion まで追え、という要求が新たにかかる。
   - これは主に NOT_EQUIVALENT 側の立証を強める。

2. `absorbs` の確証が弱いケース
   - ここでは confirmed absorption point を求める。
   - これは EQUIVALENT 側にも一応効く。

しかし強さは同じではありません。

### NOT_EQUIVALENT への作用

強く作用します。

- 差異を見つけた後、「伝播している」で止める誤りを減らす点は明確。
- test outcome に接続できず SAME に倒れる失敗は減る可能性が高い。
- `docs/design.md` の `Incomplete reasoning chains` と `Subtle difference dismissal` には直接効く。

### EQUIVALENT への作用

限定的です。

- 既存文言でも `absorbs` を記録すれば EQUIV の根拠はある程度作れた。
- 新規差分が追加するのは `confirmed absorption point` の要求だが、これは assertion 到達要求ほど構造的な変化ではない。
- つまり EQUIV 側では「既存の吸収判定を少し厳しくする」程度で、NOT_EQ 側ほどの新しい利得はない。

### 実効的には片方向寄りか

はい。実効差分は NOT_EQ 側に強く寄っています。

理由:
- 変更前から `absorbs` は書けたため、EQUIV の主要ワークフローはすでにある。
- 変更後に本当に新しく強制されるのは、「propagates と分かった後に assertion まで行け」という downstream continuation。
- よって差分の中心効果は NOT_EQ の見落とし防止であり、対称な文面ほどには対称に効かない。

### 回帰リスク

- 複雑な call path では assertion 特定までの探索が重くなりうる。
- そのコストは、差異を見つけた後にのみ発火するとはいえ、フレームワーク系コードや抽象化の深いケースで turn budget を圧迫しうる。
- その結果、「assertion まで行き切れず安全側に倒す」挙動が起きると、EQUIV/UNKNOWN 寄りの回帰を招く。

結論:
- 名目上は両方向に作用する。
- しかし変更前との差分でみると、実効的には NOT_EQ 側への追加強化が中心で、対称性は弱い。
- この点で proposal 内の「両方向に同等に効く」という主張は楽観的すぎる。

---

## 4. failed-approaches.md の汎用原則との照合

提案本文は非抵触と整理していますが、監査としてはそれほど安心できません。

### 原則 #1 / #6: 判定の非対称操作・差分評価

最重要の懸念です。

- proposal は文面の上では SAME / DIFFERENT 両方に使えると主張する。
- しかし差分評価をすると、新しく強化されるのは主に `difference found -> propagates -> assertion まで追う` ルート。
- これは NOT_EQ 側の立証責任を変える操作であり、原則 #6 が警告する「対称化のつもりでも差分は非対称」にかなり近い。

したがって、原則 #1/#6 に「非抵触」とまでは言えません。少なくとも要注意です。

### 原則 #15: 固定長の局所追跡ルール

- 今回は hop 数ではなく意味論的境界なので、この原則には直接は抵触しません。
- この点は proposal の自己評価どおりです。

### 原則 #17: 中間ノードの局所分析義務化

- 提案意図はむしろ中間ノードで止めるな、なので #17 の失敗を避けようとしている点は妥当。
- ここは比較的整合的です。

### 原則 #18 / #19 / #24 / #26: 探索予算枯渇・停止条件への厳格証拠要求

ここは proposal の自己評価より重く見るべきです。

- `test assertion` は「意味論的境界」と言い換えているが、実際にはかなり物理的な探索ターゲット。
- `assertion 到達` を stopping rule にすると、各ケースで「その assertion はどこか」を追加で特定しに行く行動を強く誘発する。
- failed-approaches の #22, #24, #26 が警告する「具体物を終点として義務化すると、探索がその対象の捜索に流れる」リスクがある。
- また #19 の「エンドツーエンドの完全立証義務」そのものではないにせよ、その方向へ一歩近づいている。

したがって、この提案は #18/#19/#24/#26 に対して「軽微なリスク」よりも「無視できない構造的リスク」があります。

### 原則 #20: 厳密な言い換えによる実質的立証責任の上昇

- 今回は既存文の後半に強い限定句を追加している。
- これはまさに「明確化」の名の下に要件を厳格化する類型。
- そのため #20 にも近い。

### 総合

この提案は failed-approaches に正面衝突しているとまでは言わないものの、少なくとも以下の危険帯に入っています。

- #1 / #6 非対称差分
- #18 / #19 / #24 / #26 探索コスト増と停止条件厳格化
- #20 厳格な言い換えによる実効的ハードル上昇

proposal 本文の自己監査はこのリスクを過小評価しています。

---

## 5. 汎化性チェック

### 具体的な数値 ID / リポジトリ名 / テスト名 / コード断片の有無

監査結果:
- ベンチマーク対象リポジトリ名: なし
- テスト名: なし
- 特定ケース ID: なし
- ベンチマーク実コード断片: なし
- SKILL.md 自身の引用: あり

このうち SKILL.md 自身の変更前/後引用は `Objective.md` の R1 減点対象外に明記されているため、ルール違反ではありません。

`Iteration 94` や `checklist 5番目` のような番号表現はありますが、これはベンチマーク個別ケース ID や特定 repo 識別子ではないため、過剰適合の証拠とは言えません。

したがって、明示的なルール違反は見当たりません。

### 暗黙のドメイン仮定

ここには軽い懸念があります。

- `test assertion` を stopping point として明示すると、ユニットテスト的で assertion location が比較的明瞭な世界を暗黙に想定しやすい。
- しかし実際には、golden file 比較、snapshot、例外期待、 helper abstraction 経由の oracle、 framework macro、 property-based checks など、assertion 境界が物理的に見えにくいテストもある。
- さらに言語やフレームワークによっては assertion がテスト本文に露出せず、 matcher / helper / harness 側に埋もれる。

つまり、明示的な固有名詞 overfit はないが、`assertion` という語がやや特定の test style を想定している懸念はあります。

汎化性評価:
- 重大な違反ではない
- ただし `test assertion` という具体物指定は、言語横断・フレームワーク横断の一般性を少し損ねる

---

## 6. 全体の推論品質がどう向上すると期待できるか

期待できる改善は確かにあります。

### 改善が見込める点

- semantic difference を見つけた後に premature stop しにくくなる
- 「propagates」と書いただけで claim を確定する雑なジャンプを減らせる
- difference-to-outcome の接続をより意識させることで、NOT_EQ の見落としは減る可能性がある

### ただし改善の質は混合的

- 本当に欲しい改善は「assertion という具体物を探せ」より、「observable test outcome への因果連鎖を確認せよ」に近いはず
- 現提案は、その望ましい抽象原則を `test assertion` という物理ターゲットに寄せてしまっている
- その結果、推論品質の改善というより、探索コスト増・ターゲット探索への過剰適応が起こる懸念がある

### より妥当だった方向性

もし同じ狙いを維持するなら、より汎用で安全な言い方は次の方向です。

- `test assertion` のような具体物ではなく、`the test's observable outcome` や `the test oracle` のような観測境界ベースにする
- `confirmed absorption point` も、過度な物理探索を誘わないよう `a downstream point where the test-relevant effect is neutralized` など状態ベースに寄せる

これなら、proposal の狙いである「伝播を outcome までつなぐ」を保ちつつ、failed-approaches の #22/#24/#26 のリスクを減らせます。

---

## 最終判断

承認: NO（理由: 変更意図は妥当で研究とも部分整合するが、変更前との差分としては NOT_EQUIVALENT 側に主に作用する非対称な強化になっており、さらに `test assertion` を停止条件として具体化したことで failed-approaches の探索予算枯渇・物理的ターゲット探索の失敗原則に接近しているため。現状の文言では、推論品質向上よりも探索コスト増と回帰リスクの懸念が上回る。）
