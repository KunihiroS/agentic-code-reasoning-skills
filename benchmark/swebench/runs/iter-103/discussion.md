# Iteration 103 — 監査ディスカッション

## 総評

提案の狙い自体は理解できる。差異を見つけた後に中間地点でトレースを止めず、観測可能性まで追うべきだ、という方向性は研究のコアと整合的であり、推論品質を上げうる。

ただし、今回の具体的文言 `to the point of test assertion` は、汎用原則としては少し狭く、かつ既存文言との差分として見ると実効的には対称性が弱い。特に failed-approaches.md の #6, #20, #22, #26 との緊張が強い。

現時点では「観測可能性まで追う」という発想は良いが、「test assertion」という物理的ターゲット指定の仕方は避けるべきであり、このままの案は非承認が妥当と判断する。

## 1. 既存研究との整合性

DuckDuckGo MCP の search は今回の環境では全クエリで結果 0 件だったため、同 MCP の fetch_content で既知の公開 URL を確認した。検索インフラ自体は不調だったが、参照した URL の内容自体は今回の論点に十分関係している。

### 参照 URL と要点

1. https://arxiv.org/abs/2603.01896
   - 要点: Agentic Code Reasoning 論文の要旨は、明示的 premises、execution-path tracing、formal conclusion を要求する semi-formal reasoning が、unsupported claim や case skipping を防ぐというもの。
   - 整合性: 提案が目指す「差異発見後のトレース完結」はこの方向と整合する。
   - ただし: 論文の核は「観測可能な結論までの追跡」であり、特定の構文要素としての `assert` 文探索を義務化することまでは言っていない。

2. https://en.wikipedia.org/wiki/Observational_equivalence
   - 要点: observational equivalence は「observable implications に基づいて区別不能」であること。プログラミング言語意味論でも、文脈中で同じ value を与えるかどうかが本質。
   - 整合性: EQUIVALENT / NOT_EQUIVALENT を考える際に「最終的に何が観測されるか」へ寄せるのは正しい。
   - ただし: ここで重要なのは observable effect であって、必ずしも test file 上の assertion 文そのものではない。

3. https://en.wikipedia.org/wiki/Test_oracle
   - 要点: テストの正しさ判定は assertion だけでなく、postcondition、expected crash、derived oracle、metamorphic relation など広い test oracle 概念で捉えられる。
   - 整合性: 差異が oracle に観測されるかどうかを見る、という発想は強く支持される。
   - 逆に懸念: `test assertion` という語は oracle より狭く、例外期待・スナップショット・golden file・property based test・metamorphic test・helper 越しの失敗判定などを暗黙に弱く扱う危険がある。

4. https://en.wikipedia.org/wiki/Program_slicing
   - 要点: program slicing は point of interest を slicing criterion にして、その点に影響する依存だけを追う。
   - 整合性: 「どこまで追うか」を明示する発想自体は一般に筋がよい。
   - ただし: slicing criterion は意味論的な point of interest であるべきで、固定的な物理ターゲット指定のほうが良いとは限らない。

### 研究整合性の結論

研究的には「差異を observable outcome まで追う」は支持できる。一方で `test assertion` という wording は、研究が支持する抽象度より一段具体的すぎる。したがって、発想は整合的だが、文言の抽象度は最適ではない。

## 2. Exploration Framework のカテゴリ選定は適切か

提案はカテゴリ B「情報の取得方法を改善する」を選んでいるが、完全にはしっくり来ない。

理由:
- 実際の変更は新しい探索行動の追加というより、既存 Guardrail #4 の終端表現の言い換え
- 「何を探すかではなく、どう探すか」の改善という説明は一応成立する
- しかし実体としては、探索手順そのものよりも wording の厳密化・終端の明示化であり、カテゴリ E「表現・フォーマットを改善する」のほうが近い
- また Guardrails は paper error analysis の翻訳層でもあるため、カテゴリ F 的な側面もある

したがってカテゴリ B は「不適切とまでは言わないが第一候補ではない」。監査上は「B と言い切るには弱い、E/F 寄り」という評価になる。

## 3. EQUIVALENT 判定と NOT_EQUIVALENT 判定への作用

## 変更前との差分を厳密に見る

変更前の Guardrail #4 はすでに次を要求している。

- semantic difference を見つけたら
- at least one relevant test を
- differing code path に沿って trace してから
- その差異が test outcomes に impact しない、または pass/fail を変える、と結論せよ

さらに Compare checklist にはすでに、
- 差異を見つけたらそこで止まらず
- consuming function を読んで
- その差異が propagate されるか absorb されるかを記録してから
- Claim outcome を確定せよ

という、かなり近い要件が入っている。

このため、今回の追加の実効的差分は「観測可能な outcome まで追え」という新思想の導入というより、既存の outcome-oriented 指示を `test assertion` というより具体的な語に言い換える点にある。

### EQUIVALENT 側への作用

正の効果が出るとすれば主にこちら。

- 既存文言だと、差異が途中で吸収されそうだと見えた段階で早く安心してしまう可能性がある
- `test assertion` を入れると、少なくとも oracle 近傍まで確認しようという圧は強まる
- その結果、誤 NOT_EQUIVALENT は減る可能性がある

ただし、その利益は「assertion まで」という物理目標を与えなくても、「observable test outcome / oracle まで」で十分得られる種類の利益である。

### NOT_EQUIVALENT 側への作用

提案文は「こちらにも対称的に効く」と主張しているが、差分ベースで見ると強くは支持できない。

理由:
- 変更前の文言でも、`it changes a test's pass/fail result` と結論するには、元々 test outcome との接続が必要
- つまり NOT_EQ の主張には既に outcome 方向の要件がかなり入っている
- 今回の追加で増えるのは、主としてその endpoint を assertion と言い換えること
- よって実効差分は EQUIV 側の「差異が無害であることの立証の厳密化」に寄りやすい

これは failed-approaches.md の原則 #6「対称化は既存制約との差分で評価せよ」に照らすと重要で、文面が対称に見えても、変更前との差分としては片方向に強く作用する可能性がある。

### 回帰リスク

さらに `test assertion` が強く解釈されると、両方向に次のコストがかかる。

- assertion を探す追加検索が発生する
- helper 越し・framework 越し・implicit oracle のテストで物理的ターゲット特定に手間取る
- 結果として、中心因果連鎖ではなく assertion 特定作業に予算を使う

したがって、理論上の狙いは両方向だとしても、実効的には
1) EQUIV 側にやや強く作用し、
2) しかも双方に探索コストを増やす
という形になりやすい。

## 4. failed-approaches.md の汎用原則との照合

提案文は自ら「全原則との抵触なし」としているが、そこまでは言えない。

### 原則 #6 との緊張

「文言は対称だが差分は非対称」という問題がある。既存 Guardrail #4 はすでに NOT_EQ 側にはかなり強い要件を持っているため、今回の追加分は主として EQUIV 側の追加制約として働く可能性が高い。

### 原則 #20 との緊張

今回の変更は、既存文の厳密化・排他的な言い換えに近い。意図は明確化でも、モデルにとっては「そこまで行っていないなら結論するな」というより強い警告として作用しうる。これは立証責任の引き上げになりやすい。

### 原則 #22 との緊張

`test assertion` は「状態・性質」ではなく、かなり具体的なコード要素寄りの語である。モデルがこれを「必ず assertion 文を見つけよ」という物理探索目標として過剰適応するリスクがある。

### 原則 #26 との強い類似

原則 #26 は、中間ステップで結論根拠となる具体コード要素を命名・特定させる要求が、探索予算の枯渇や安全側誤判定を招くと述べている。今回の案は完全一致ではないが、かなり近い方向である。

- 目的: 観測点までの因果追跡強化
- 実装: `test assertion` という具体ターゲットを義務化

この「良い目的を具体要素の探索義務に落とす」パターンが、まさに過去失敗と近い。

### 原則 #15, #17 との関係

ここは提案の良い点でもある。

- #15: 固定 hop 数ではなく意味論的終端を置こうとしている
- #17: 中間ノードで止めず end-to-end に寄せようとしている

したがって、提案の問題は「狙い」ではなく「終端の表現選択」にある。

## 5. 汎化性チェック

### 明示的なルール違反の有無

提案本文には、禁止されている次の種別は見当たらない。

- 特定ベンチマークのケース ID
- 特定リポジトリ名
- 特定テスト名
- 特定関数名・クラス名
- ベンチマーク対象のコード断片

この点では明示的 overfitting は見られない。

補足:
- `Iteration 103`、`5 語追加`、`1 行変更` といった数値はあるが、これは提案メタデータであり、禁止対象の「ベンチマーク固有識別子」ではない
- SKILL.md 自身の変更前後引用も監査基準上は許容される自己引用の範囲

### 暗黙のドメイン仮定

ただし、暗黙の前提はやや狭い。

`test assertion` という言い方は、以下を暗に前提しやすい。

- テストには明示的 assertion site がある
- その assertion site が比較的容易に特定できる
- pass/fail の oracle が assertion 文に局在している

これは次のような一般的テスト様式では必ずしも成立しない。

- expected exception / error type を見るテスト
- snapshot / golden file テスト
- property-based testing
- metamorphic testing
- fuzzing
- helper / matcher / macro 越しに失敗が発生するテスト
- integration / system test で status code, side effect, log, artifact を見るテスト

よって、明示的な固有識別子は含まれないが、抽象度としてはまだ十分に汎化的ではない。

## 6. 全体の推論品質はどう向上すると期待できるか

### 期待できる改善

- 差異発見後の premature stop を減らす
- 「局所差異がある」から即「NOT_EQ」と飛ぶ短絡を抑える
- 観測可能性ベースの reasoning を促す

### 期待しにくい点

- 既存 Compare checklist にすでに propagation / absorption 確認があるため、純増効果は限定的
- Guardrail #4 も元から outcome ベースなので、新規性は小さい
- 改善の本体が「何を追加で検証するか」ではなく「assertion という言い換え」に寄っている

### 想定される副作用

- assertion の物理的特定に探索予算を使う
- assertion が明示的でないテスト様式で迷走する
- 「assertion まで辿れないなら結論保留」と解釈され、不要な慎重化を起こす

総じて、
- 発想レベルでは中程度のプラス
- 文言レベルでは過具体化によるマイナス
- ネットでは改善不確実、むしろ回帰リスクあり
という評価になる。

## 提案に対する具体的コメント

もしこの改善方向を残すなら、`test assertion` ではなく、より抽象度の高い表現にするべきである。例えば次の方向ならまだ検討余地がある。

- `to the relevant test oracle or observable pass/fail boundary`
- `until you can determine whether the difference is observed by the relevant test`
- `through the differing code path far enough to establish whether the relevant test observes or absorbs the difference`

これなら
- observable outcome への到達という本質は保ちつつ
- assertion という具体物への過剰適応を避けやすい
- failed-approaches #22, #26 との衝突も弱められる

## 最終判断

承認: NO（理由: 狙いは妥当だが、`test assertion` という具体的ターゲット指定が汎化性を損ない、failed-approaches.md の #6・#20・#22・#26 と緊張する。変更前との差分としても主に EQUIV 側へ偏って作用しうるため、「両方向に対称な改善」とは言い切れない。）
