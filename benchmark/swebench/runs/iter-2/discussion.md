# Iter-2 監査ディスカッション

## 総評
提案の狙い自体、すなわち「見つかった差異をテスト観測可能性の観点で整理する」は、観測可能な振る舞いに基づいて等価性を判断するという大原則には整合している。しかし、今回の具体的な差分はその原則を安全に実装できていない。

結論から言うと、この変更は「比較の枠組みを少し精緻化する」よりも、「差異発見直後に observable / non-observable という中間ラベルを付け、そのラベルに応じて探索量を変える」変更として作用する。これは failed-approaches.md にある複数の失敗原則と本質的に衝突しており、特に EQUIVALENT 側にだけ実効的な影響を与える危険が高い。

## 1. 既存研究との整合性

DuckDuckGo MCP の search は今回 no results だったため、同じ DuckDuckGo MCP の fetch_content で既知 URL を取得して確認した。

1. Agentic Code Reasoning
   - URL: https://arxiv.org/abs/2603.01896
   - 要点:
     - semi-formal reasoning は「explicit premises」「trace execution paths」「formal conclusions」により、ケース飛ばしや unsupported claim を防ぐ certificate として働く。
     - この論文の中心メカニズムは、ラベル付けよりも「明示的なトレース義務」にある。
   - 整合性評価:
     - 提案が「差異を見つけたらテスト側まで追う」という方向を維持する限り、論文の中心思想とは整合する。
     - しかし「先に observable / non-observable に分類し、tracing effort を配分する」という部分は、論文が強く押している end-to-end tracing の代替として使われうるため、整合は部分的にとどまる。

2. Program slicing
   - URL: https://en.wikipedia.org/wiki/Program_slicing
   - 要点:
     - program slicing は「ある観測点の値に影響しうる文」を、依存関係を遡って集める考え方。
     - 重要なのは、観測点を固定して依存関係を追うことであり、局所差分を先に軽い/重いとラベル付けすることではない。
   - 整合性評価:
     - 「テストの assertion に到達するか」という発想自体は slicing 的で妥当。
     - ただし実装案のように差異点から observable / non-observable を先に判定すると、観測点ベースではなく局所状態ベースのヒューリスティックになりやすい。

3. Observational equivalence
   - URL: https://en.wikipedia.org/wiki/Observational_equivalence
   - 要点:
     - observational equivalence は、観測可能な含意が区別不能なら等価とみなすという考え方。
     - 区別できるかどうかは「文脈に置いたときの observable implication」で決まる。
   - 整合性評価:
     - 提案が狙う「観測可能差異に優先度を置く」は、この原則には合っている。
     - ただし observational equivalence は本来、局所的に internal state に見える差異でも、文脈次第で観測可能化しうることを前提にする。したがって、早い段階で non-observable とみなして tracing effort を下げる実装は、理論の安全な使い方ではない。

小結:
高レベルの着想は研究知見と整合するが、今回の具体的 wording は「観測可能性の確認」ではなく「観測可能性の先行ラベル化」に寄っており、研究コアとの整合は限定的である。

## 2. Exploration Framework のカテゴリ選定は適切か

提案は Category C「比較の枠組みを変える」を選んでいる。形式上は理解できる。実際、差異の有無だけでなく、その差異がテスト観測に到達するかで粒度を上げるという発想は C の説明文にある「差異の重要度を段階的に評価する」に一致する。

ただし、実効的には Category C 単独というより、Category B と D の失敗形に接近している。

- C らしい部分:
  - 差異を binary に扱わず、観測可能性で粒度化する点。
- C から逸脱している部分:
  - 「first classify ... then allocate tracing effort accordingly」は、比較枠組みの変更というより探索予算の配分ルール変更である。
  - しかもその配分は、差異点から観測点までの因果追跡を強めるのではなく、場合によっては弱める方向に働く。

したがってカテゴリ名としては C で説明可能だが、提案本文の実体は「比較の枠組み変更」より「探索量の条件付き削減」に近い。カテゴリ選定は表面上は適切だが、汎用原則としての実装は不適切である。

## 3. EQUIVALENT 判定と NOT_EQUIVALENT 判定の両方にどう作用するか

ここは提案文の自己評価と実効差分が最もズレている。

### 変更前
現行文:
- When a semantic difference is found, trace at least one relevant test through the differing code path before concluding it has no impact

この義務は、明確に「差異はあるが no impact と言いたいとき」に発火する。つまり主に EQUIVALENT 側の誤判定防止ガードである。

### 変更後
提案文:
- ... before concluding it has no impact; first classify the difference as observable (reachable by a test assertion) or non-observable (internal state only), then allocate tracing effort accordingly

### 実効差分
新たに追加される実効は次の2点。

1. 差異発見後に中間ラベル observable / non-observable を作る
2. そのラベルに応じて tracing effort を変える

この差分は対称ではない。理由は、元の文自体が EQUIVALENT 側の no impact 結論にだけかかるガードだからである。そこへ「non-observable なら tracing effort を軽くしてよい」という運用余地を足すと、実質的には EQUIVALENT 側にだけ新しい近道を与える。

### EQUIVALENT 側への作用
- 作用は大きい。
- 差異を見つけても「これは internal state only だ」と早期分類できれば、従来より浅い確認で no impact に進みやすくなる。
- そのため、偽の EQUIVALENT を増やすリスクがある。
- 特に compare タスクでは、局所状態の違いが後段の assertion へ届くかは tracing しないと分からないことが多く、non-observable ラベルはしばしば premature になりうる。

### NOT_EQUIVALENT 側への作用
- 作用は限定的、またはほぼ間接的。
- 既に observable と見えた差異はそのまま NOT_EQUIVALENT の候補になるが、これは現行でも relevant test を追えば十分に扱える。
- 変更によって NOT_EQUIVALENT 側に新しく追加される強い検証手順はない。
- むしろ誤って non-observable とラベル付けされた差異が NOT_EQUIVALENT 反例候補から早期に落ちるため、NOT_EQUIVALENT 側の recall を下げる恐れがある。

### 結論
この変更は「両方向に同等に作用する」のではなく、変更前との差分ベースで見ると EQUIVALENT 側にのみ実効的に強く作用する。failed-approaches.md の原則 #6 がまさに警告しているパターンである。

## 4. failed-approaches.md の汎用原則との照合

提案文の自己申告では非抵触とされているが、監査上はそう見ない。

### 原則 #1 判定の非対称操作
抵触懸念が強い。

追加文は形式上は対称的に見えるが、差分としては EQUIVALENT 側の「no impact」結論にだけ新しい運用ルールを加えている。したがって実効は非対称。

### 原則 #3 探索量の削減は常に有害
抵触懸念あり。

proposal では「non-observable に対しては浅い確認で済ませる」と明記しており、これは探索量削減そのもの。全探索を減らしていない、優先度配分だ、と書いているが、実効としては一部の差異に対する追跡を薄くする指示である。failed-approaches.md の観点では危険側。

### 原則 #6 「対称化」は既存制約との差分で評価せよ
実質的に抵触。

現行 Guardrail #4 は既に「差異を軽視しない」側をカバーしている。そこへ observable / non-observable 分類を足しても、observable 側は既存義務と大差なく、non-observable 側だけが新しく軽く扱われる。差分は非対称。

### 原則 #7 分析前の中間ラベル生成
抵触懸念が非常に強い。

proposal は「差異を発見した後なので分析前ではない」と主張するが、本質はそこではない。問題は「最終結論の前に、中間ラベルが後続推論をアンカリングするか」である。observable / non-observable はまさにその種のラベルで、しかも tracing effort を変える意思決定に直結している。これは危険な中間ラベル生成である。

### 原則 #8 受動的な記録フィールド追加
部分抵触ではない。

新規フィールド追加ではないので #8 そのものではない。ただし、classification 自体が行動誘発よりラベル記述へ流れる危険は同質である。

### 原則 #15 固定長の局所追跡で観測境界を近似するな
部分的に近い懸念。

今回 N-hop 指示はないが、「internal state only」という局所ラベルで観測境界を先に推定している点は、本質的には同じ危険を持つ。

### 原則 #17 中間ノードの局所的な分析義務化
抵触懸念あり。

difference を observable / non-observable と差異点近傍で評価させるため、最終的な assertion への end-to-end tracing より、差異直後の局所状態解釈に注意が固定される。これは #17 の警告と近い。

### 原則 #23 抽象的な問いだけでは改善しない
軽度の懸念。

「reachable by a test assertion」という方向は良いが、具体的にどう検証するかは増えていない。結果として、有用な探索ステップではなく soft framing に留まる可能性がある。

小結:
この提案は、failed-approaches.md の自己照合結果よりかなり危険側に見える。特に #1, #3, #6, #7, #17 との衝突が大きい。

## 5. 汎化性チェック

### ルール違反の有無
- 特定のベンチマーク用リポジトリ名: なし
- 特定のテスト名: なし
- 特定のケース ID: なし
- ベンチマーク対象コード片の引用: なし

したがって、ベンチマーク固有識別子の混入という意味での overfitting ルール違反は見当たらない。

ただし以下は留意点。

1. proposal には SKILL.md の具体的行番号と文言引用が含まれる。
   - これは Objective.md の R1 基準上は「SKILL.md 自身の文言引用」に当たり、通常は減点対象外。
   - よって監査上は rule violation とはみなさない。

2. 「reachable by a test assertion」「internal state only」という言い回しは、やや xUnit 的・assertion-centric なテスト観を暗黙に前提している。
   - 多くの言語・フレームワークには適用できるが、観測点が明示的 assertion ではなく、例外、ログ、出力フォーマット、プロトコル応答、メタデータ、副作用の有無などで定まるケースでは表現がやや狭い。
   - よって厳密には「test assertion」という語は「test-observable outcome」など、より一般化された表現の方が安全。

### 汎化性の総合評価
着想自体は汎用的だが、文言は「assertion」という具体物に少し寄りすぎており、また internal state only という分類が言語・実装様式をまたいで安定に機能する保証は弱い。

## 6. 全体の推論品質がどう向上すると期待できるか

期待できる潜在的な改善はある。

- 良い方向の仮説:
  - 差異発見後に、最終的なテスト観測点との接続を意識させる
  - 無関係な実装差異へ無制限に深入りするのを防ぐ
  - compare モードで「差異の有無」から「観測可能差異かどうか」へ粒度を上げる

しかし、今回の wording ではその利益より副作用が大きい。

主な理由:
- observable / non-observable の先行分類がアンカリングになる
- allocate tracing effort accordingly が探索削減の合図として読まれる
- 現行 Guardrail #4 が守っている「差異を見つけたら relevant test まで追う」という強みを、例外付きの弱い義務へ変えてしまう

したがって、推論品質の改善期待は「概念レベルではあるが、今回の具体案では低い」。むしろ EQUIVALENT 側の偽陽性と NOT_EQUIVALENT 側の見逃しを増やす回帰リスクがある。

## 最終判断
承認: NO（理由: 変更前との差分として見ると EQUIVALENT 側にだけ実効的に作用する非対称変更であり、observable / non-observable の中間ラベル生成と tracing effort の条件付き変更が failed-approaches.md の原則 #1, #3, #6, #7, #17 に強く抵触するため。高レベルの着想は妥当でも、今回の 1 行追加の形では汎用的改善としては不十分かつ回帰リスクが高い。）
