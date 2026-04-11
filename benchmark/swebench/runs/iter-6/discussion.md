# Iter-6 監査ディスカッション

## 総評
提案の狙いは理解できる。STRUCTURAL TRIAGE と ANALYSIS の間に「何が一致していれば EQUIVALENT と言えるのか」という観点を先に置くことで、前向きトレースを漫然と行わず、差異に敏感な追跡へ寄せたいという発想である。

ただし、現行案の文言のままでは「テスト等価性の判定」に必要な条件ではなく、「意味的に同じであるための一般条件」を先に書かせる方向へモデルを誘導しやすい。SKILL.md の compare モードは D1 で明示的に "EQUIVALENT MODULO TESTS" を定義しており、判定対象はあくまで既存テストに対する観測的等価性である。ここを外すと、等価だが実装上は少し異なる変更を NOT EQUIVALENT に倒す回帰リスクがある。

結論として、発想自体は妥当だが、現提案の文言はまだ片方向で、しかも D1 の test-scoped な定義より強い条件を書かせる危険があるため、そのままの承認は見送りたい。

## 1. 既存研究との整合性
DuckDuckGo MCP で確認できた範囲では、提案の方向性そのものには研究的な整合性がある。

1) Agentic Code Reasoning
- URL: https://arxiv.org/abs/2603.01896
- 要点: 構造化テンプレートにより、明示的 premises、execution path tracing、formal conclusion を要求すると精度が改善するという主張。提案の S4 は「結論に必要な証拠を先に意識させる」という意味で、この semi-formal reasoning の補強としては自然。
- 監査上の解釈: 既存研究のコアである「証拠先行・未根拠主張の抑制」とは整合する。

2) Hypothesizer: A Hypothesis-Based Debugger to Find and Test Debugging Hypotheses
- URL: https://dl.acm.org/doi/fullHtml/10.1145/3586183.3606781
- DuckDuckGo 要約: 開発者は仮説を立て、その仮説がどの証拠収集を導くかによって調査を進める、という仮説駆動デバッグを扱う。
- 監査上の解釈: 提案の S4 は「EQUIVALENT 仮説が真なら必要な証拠は何か」を先に言語化させるので、証拠収集の方向付けという点ではこの系譜に乗っている。

3) Counterfactual Reasoning for Retrieval-Augmented Generation
- URL: https://openreview.net/forum?id=9U51rOnGko
- DuckDuckGo 要約: counterfactual query を生成・評価して、因果的に重要な差異を切り出す枠組み。
- 監査上の解釈: 本提案の「成立条件を先に置き、そこから外れる差異を探す」という構図は、一般的な counterfactual / backward-style reasoning と整合する。

以上より、研究との整合性はある。ただし、研究が支持しているのは「証拠探索を構造化すること」であって、「EQUIVALENT 側に有利な前提を先に固定すること」までは直接支持していない。したがって、整合性はあるが、現在の文言には慎重さが必要である。

## 2. Exploration Framework のカテゴリ選定は適切か
結論: 主カテゴリ A は概ね妥当。ただし D の要素も混ざっている。

理由:
- 提案の本体は、ANALYSIS 前に「EQUIVALENT が成立するための必要条件」を書かせることで、探索順序を前向きトレース一辺倒から、結論先行の backward reasoning に少し寄せることにある。これは Objective.md の A「推論の順序・構造を変える」に合う。
- 一方で、実際に追加される内容は「事前チェックポイント」の性格も強く、D「メタ認知・自己チェック」にも接している。

したがって、カテゴリ A とすること自体は不自然ではない。ただし説明としては、
- 主: A（結論から必要証拠を逆算する）
- 副: D（事前に見るべき観点を固定して思い込みを減らす）
という整理のほうが正確。

## 3. EQUIVALENT 判定と NOT_EQUIVALENT 判定の両方への作用
ここが最重要の懸念点である。

### 3-1. 提案が直接狙っているのは EQUIVALENT 側
proposal.md 自身が、"等価と誤判定する（EQUIV 方向の誤り）を減らす" と明言している。つまり一次効果は、証拠不足のまま EQUIVALENT と言ってしまう誤りの抑制である。

この点は README.md にある現状分析とも整合している。現行 skill は NOT_EQUIVALENT 側はすでに強く、残課題は EQUIVALENT 側に寄っている。

### 3-2. ただし、実効的には NOT_EQUIVALENT 側へ倒れやすくなる
S4 の文言は次のようになっている。
- "state what behavioral properties both changes must share for EQUIVALENT to hold"
- "focus tracing on the properties most likely to diverge"

この書き方だと、モデルは ANALYSIS 前に「等価であるための必要条件」を自分で定義する。ここで条件を強く置きすぎると、実際には D1 の意味で等価なのに、途中の意味差・内部差・非観測差を見つけて NOT EQUIVALENT に倒す危険がある。

言い換えると、変更は見かけ上 "EQUIVALENT を安易に出さないための安全策" だが、判定境界を test-observable equivalence から semantic sameness に広げるなら、false negative な NOT_EQUIVALENT を増やしうる。

### 3-3. 片方向にしか作用しないか
厳密には、片方向だけではない。

- 正方向の主作用: false EQUIVALENT を減らす
- 副作用の方向: false NOT_EQUIVALENT を増やす可能性がある

つまり、片方向改善ではなく、実質的には判定閾値を保守的側へ動かす変更になりうる。

### 3-4. なぜ現行文言が危険か
compare モードの D1 は「関連テストの pass/fail outcome が identical なら EQUIVALENT」である。ところが S4 の "behavioral properties" は test-scoped であることが明示されていない。

このズレにより、モデルが例えば以下のように過剰一般化する恐れがある。
- 内部状態遷移が同じでなければならない
- 補助関数レベルの挙動が同一でなければならない
- 例外処理の局所的差異があるなら等価ではない

しかし compare の定義では、これらは「既存テストの outcome が変わらないなら」直接の非等価根拠ではない。

### 3-5. 監査上の結論
提案は EQUIVALENT と NOT_EQUIVALENT の両方に作用する。しかも対称ではなく、主作用は EQUIVALENT 抑制、副作用は NOT_EQUIVALENT への過剰シフトである。よって「EQUIV 側だけの改善」と見なして安全視することはできない。

## 4. failed-approaches.md の汎用原則との照合
failed-approaches.md には現時点で具体的ブラックリストはない。そのため、文書上は直接抵触なし。

ただし、そこに書かれている唯一の強い原則は「具体 benchmark 依存の失敗談ではなく、汎用原則だけを書く」という編集方針である。Objective.md でも overfitting 禁止が明記されている。

この観点から見ると、本提案は以下の点でグレー寄りの注意が必要:
- README.md の現状分析にある「残課題は EQUIVALENT 側」という実験結果に強く引っ張られている
- 提案文も EQUIV 方向の誤り削減を主目的としている

ただし、提案文そのものは特定ケースの構文・特定テスト・特定リポジトリの癖には触れておらず、発想自体は benchmark 固有ではない。よって「過去失敗の再演」とまでは言えないが、「現在残っている失敗傾向に最適化された片寄り」はある。

## 5. 汎化性チェック
結論: 明白なルール違反は見当たらない。ただし軽微な注意点はある。

### 5-1. 禁止される具体性の有無
proposal.md を確認した範囲では、以下は含まれていない。
- ベンチマーク対象リポジトリ名
- 特定テスト名
- 特定関数名・クラス名
- ベンチマークケース ID
- 対象コードベースの実コード断片

したがって、Objective.md / Audit Rubric の R1 で明確に禁止される種類の overfitting 表現には該当しない。

### 5-2. 数値 ID について
文中には iter-6, Step 1-6, S1-S4, ~200 lines, Guardrail #4 といった番号が出てくるが、これは SKILL.md や提案自体の内部構造の参照であり、ベンチマークケース ID やテスト ID ではない。よって直ちに違反とは言えない。

### 5-3. 暗黙のドメイン依存性
提案の言葉遣いは比較的一般的で、特定言語・特定フレームワーク前提は薄い。ただし "behavioral properties" が抽象的すぎるため、言語によりモデルが想起する典型がぶれやすい。

例えば:
- 動的言語では API レベル挙動
- 静的言語では型・例外・内部契約
- テスト駆動の強いプロジェクトでは observable behavior

のように、モデルが何を「等価性前提」と読むかが揺れる。これは汎化性違反というより、汎化のための定義不足である。

## 6. 全体の推論品質がどう向上すると期待できるか
良い効果は確かにある。

1. STRUCTURAL TRIAGE と per-test ANALYSIS の橋渡しになる
- 現行 compare テンプレートは構造差の確認とテスト単位の精密トレースの間に、何を重点観察するかの中間層が薄い。
- S4 により、観察すべき差異軸を先に言語化できれば、トレースの焦点が改善する。

2. Guardrail #4 を実務上守りやすくする
- subtle difference を見たとき、"これは自分が先に置いた等価条件を破るか" と確認できるため、差異の見落としは減る可能性がある。

3. large patch での探索効率を上げうる
- S3 の scale assessment の直後に置くため、大規模差分で全部を追えないときも、「少なくともどの性質が一致していればよいのか」を先に定めることで、探索の優先順位が立つ。

ただし、これらの利点は S4 が D1 と整合している場合に限る。つまり、列挙すべきなのは一般的な behavioral properties ではなく、テスト等価性に直接関係する "test-relevant observational properties" であるべきである。

## 追加コメント: 修正すれば有望な点
監査としては、発想を否定するというより、文言のスコープを修正すべきだと考える。

現案:
- "state what behavioral properties both changes must share for EQUIVALENT to hold"

このままだと広すぎる。少なくとも以下の方向に狭める必要がある。
- 既存テストで観測される性質に限定する
- EQUIVALENT だけでなく、NOT_EQUIVALENT の反証探索にもつながる形にする
- 先に書いた preconditions が D1 を上書きしないことを明示する

例えば意図としては、
- "before ANALYSIS, state which test-relevant observational properties must match for D1 equivalence to hold"
のような限定が必要である。

これなら backward reasoning の利点を残しつつ、semantic sameness への逸脱を抑えられる。

## 最終判断
承認: NO（理由: 現行文言の S4 は compare モードの D1 が定義する "EQUIVALENT MODULO TESTS" より強い条件をモデルに自作させやすく、false EQUIVALENT を減らす一方で false NOT_EQUIVALENT を増やす回帰リスクがあるため。発想自体は有望だが、"behavioral properties" を test-relevant observational properties に限定し、EQUIVALENT 側だけに偏らない表現へ修正してから再提案すべき。）
