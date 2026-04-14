# Iter-25 改善案 監査コメント

## 対象提案の要約

提案は compare checklist の

- `Identify changed files for both sides`

を

- `Identify changed files for both sides; for each changed file, locate the enclosing function or method boundary before tracing callers or callees`

へ 1 行だけ精緻化し、changed file を見つけた後の「読み始める位置」を明示するもの。

結論から言うと、これは「結論の誘導」ではなく「探索順序の微修正」であり、改善カテゴリとしては概ね妥当である。ただし、`function or method boundary` という表現は、関数境界が明確でない言語・設定ファイル・宣言的記述への汎化性にやや注意が必要。

## 1. 既存研究との整合性

DuckDuckGo MCP で直接参照した URL と要点:

1. https://arxiv.org/abs/2603.01896
   - Agentic Code Reasoning の原論文。
   - 要点: 明示的前提、実コードの経路追跡、形式的結論から成る semi-formal reasoning が、unstructured な推論より高精度。
   - 本提案との関係: 提案は「証拠を取る前の読み方」を微調整するもので、論文のコアである explicit premises / path tracing / formal conclusion を壊していない。むしろ、path tracing に入る前の起点を安定させる補助として整合的。

2. https://en.wikipedia.org/wiki/Program_slicing
   - 要点: program slicing は、ある関心点に影響しうる文や依存を起点から遡って集める考え方で、関係のある依存へ局所的に広げる。
   - 本提案との関係: changed line を含む局所単位から外側へ広げる、という読み方は、ファイル全体を平板に読むよりも依存中心の探索に近い。厳密な slicing ではないが、発想としては自然。

3. https://en.wikipedia.org/wiki/Call_graph
   - 要点: call graph は手続き間の呼び出し関係を表し、人間のプログラム理解にも用いられる。静的 call graph は一般に過近似であり、精度には限界がある。
   - 本提案との関係: callers/callees を追う前に、まず「どの手続き単位の変更なのか」を固定するのは call-graph 的探索の前提整理として妥当。ただし、call graph 自体が過近似になりうるのと同様、この手順も万能ではなくヒューリスティックとして扱うべき。

評価:
- 研究コアとの整合性はある。
- ただし、原論文や design 文書が直接「まず enclosing function/method boundary を取れ」と主張しているわけではない。
- よって位置づけとしては「研究と矛盾しない軽量な探索ヒューリスティック」であり、「研究から強く導かれる必須手順」とまでは言えない。

## 2. Exploration Framework のカテゴリ選定は適切か

提案者の分類 `B — 情報の取得方法を改善する` は概ね適切。

理由:
- 変えているのは compare の判定基準そのものではなく、「changed file を見つけた後にどこから読むか」という探索順序。
- これは Objective.md の B にある
  - 「コードの読み方の指示を具体化する」
  - 「何を探すかではなく、どう探すかを改善する」
  - 「探索の優先順位付けを変える」
  にそのまま対応している。
- C（比較の枠組み変更）や D（メタ認知強化）ではない。比較単位も反証ゲートも変えていない。
- E（表現改善）要素も少しあるが、本質は wording polish ではなく探索順序の指定なので、主カテゴリは B でよい。

## 3. EQUIVALENT / NOT_EQUIVALENT の両判定への作用

### 変更前との実効的差分

現行 compare checklist には既に以下がある。

- Structural triage first
- Identify changed files for both sides
- For each function called in changed code, read its definition and record in the interprocedural trace table
- Trace each test through both changes separately before comparing

したがって今回の追加は、完全な新機能ではなく、

- changed file 特定
n- callers/callees 追跡

の間に

- changed line が属する局所的な意味単位を先に特定する

という中間アンカーを入れるもの。

### EQUIVALENT 判定への作用

主な改善先はむしろこちら。

期待できる効果:
- 同一ファイル内の無関係な関数・分岐へ先に注意が飛ぶことを減らし、見かけ上の差分を過大評価しにくくなる。
- 「変更 A と変更 B が同じ意味単位を変えているのか」を早い段階で揃えやすくなり、誤って別スコープ同士を比較するリスクを下げる。
- 結果として、偽の NOT_EQUIVALENT を減らす方向に働く可能性が高い。

限界:
- EQUIVALENT の立証には最終的に relevant tests の同一 outcome を示す必要があり、この 1 行だけでそこが一気に強くなるわけではない。
- したがって改善幅は「中程度以下の局所改善」と見るのが妥当。

### NOT_EQUIVALENT 判定への作用

こちらにも一定のプラスはあるが、効果は相対的に小さい。

期待できる効果:
- 差分がどの関数単位に属するかを明確にしてから callers/callees を辿るため、実際の差異点を局所化しやすい。
- 同じファイル内の別関数にある無関係差分と、本当にテスト outcome を変える差分を取り違えにくくなる。

ただし:
- 現行 SKILL は既に structural triage、per-test tracing、counterexample 義務を持っており、NOT_EQUIVALENT 側の検出機構は比較的強い。
- そのため、この提案の追加効果は EQUIVALENT 側より小さい可能性が高い。

### 片方向にしか作用しないか

結論:
- 完全に片方向ではない。
- ただし、実効的には EQUIVALENT 側への寄与が大きく、NOT_EQUIVALENT 側への寄与は補助的。

つまり「両方向に作用するが、非対称」。
この非対称性自体は問題ではないが、提案書はやや EQUIVALENT 改善に寄った説明になっており、その点は率直に認識しておくべき。

## 4. failed-approaches.md の汎用原則との照合

### 原則 1: 証拠の種類を事前固定しすぎる変更は避ける

概ね非抵触。

- この提案は「assert を探せ」「例外経路を探せ」のように証拠タイプを固定していない。
- 指定しているのは読み始める起点であり、証拠カテゴリの固定ではない。

### 原則 2: 探索の自由度を削りすぎない

ここは軽微な懸念あり。

- 提案者の主張どおり、これは自由度を全面的に奪うものではない。
- ただし wording が `before tracing callers or callees` と強めなので、実装次第では「まず絶対に関数境界を見つけなければ進めない」という半必須ゲートとして読まれる可能性がある。
- 特に、変更が module-level code / config / template / schema / SQL / declarative DSL にある場合、`enclosing function or method boundary` は存在しないか、探索の主軸として不自然。

したがって本質的には blacklist の再演ではないが、文言が硬すぎると「探索自由度の削減」に寄る危険はある。

### 原則 3: 局所的な仮説更新を即座の前提修正義務に直結させすぎない

非抵触。
- 仮説更新や premise 再管理には触れていない。

### 原則 4: 結論直前の自己監査に新しい必須メタ判断を増やしすぎない

非抵触。
- Step 5 / 5.5 には手を入れていない。
- compare checklist の探索フェーズの補助に留まっている。

総評:
- failed-approaches.md の失敗原則を本質的に踏み直しているとは言いにくい。
- ただし「関数境界の先行特定」を rigid rule として読む余地があるため、そこだけはブラックリスト 2 に近づくリスクがある。

## 5. 汎化性チェック

### 5-1. 禁止される具体例の混入有無

確認結果:
- ベンチマークの具体的ケース ID: なし
- 対象リポジトリ名: なし
- テスト名: なし
- ベンチマーク実コード断片: なし

補足:
- 提案文には `SKILL.md` の既存文言と変更案の引用、ならびに SKILL.md の行番号参照がある。
- これは benchmark 対象リポジトリの固有識別子や実コードではなく、「変更対象文書自身の自己引用」に過ぎないため、Objective.md の監査基準に照らして rule violation とまでは言えない。

### 5-2. ドメイン・言語・テストパターンへの暗黙の依存

ここは小さくない注意点。

懸念点:
- `function or method boundary` という表現は、手続き型・オブジェクト指向コードには自然だが、
  - モジュール初期化コード
  - 設定ファイル
  - SQL
  - テンプレート
  - ルールベース DSL
  - 宣言的 UI
  などでは不自然、または存在しない。
- compare タスク全体を任意言語・任意アーティファクトへ汎化するなら、「最小の enclosing semantic unit」や「when one exists」のような逃げ道がある方が安全。

したがって:
- 明確なルール違反ではない。
- ただし R1 的には満点の 3 ではなく、2 寄りの軽い汎化懸念がある。

## 6. 全体の推論品質がどう向上すると期待できるか

期待できる改善:
1. 読み始めの局所性が上がる
   - changed file を見つけた後、いきなりファイル全体の制御フローへ散らず、まず局所単位を掴める。

2. スコープ混同が減る
   - 同名変数・似た処理・複数関数が同居する大きなファイルで、別スコープの挙動を混ぜにくい。

3. callers/callees tracing の起点が明確になる
   - どこから外側へ広げるかが明確になるため、interprocedural tracing の質が少し安定する。

4. compare モードの early-phase drift を抑える
   - 詳細 tracing 前の読み散らかしを抑え、以後の証拠収集がやや引き締まる。

ただし期待値は限定的:
- これは 1 行のローカルな優先順位付けであり、反証可能性や per-test tracing の核を強化する変更ではない。
- したがって、推論品質への寄与は「小さいが方向性はよい」タイプ。
- ベンチマーク改善が出るとしても、劇的改善よりは、誤読の一部を削る安定化寄りの効果を見込むべき。

## 総合判断

長所:
- 変更が非常に小さく、研究コアを壊さない。
- compare の探索順序にだけ作用するため複雑性の増加がほぼない。
- 「証拠の種類固定」や「新しいメタ監査の追加」ではなく、過去の失敗原則からは比較的安全。

懸念:
- 効果は主に EQUIVALENT 側に寄る非対称な改善で、NOT_EQUIVALENT 側の上積みは限定的。
- `function or method boundary` という表現は、汎用コード推論フレームワークとしてはややプログラム言語寄りで、非手続き的アーティファクトへの一般性が少し弱い。
- よって「提案の方向は妥当だが、文言の一般化余地はある」という評価になる。

承認: YES
