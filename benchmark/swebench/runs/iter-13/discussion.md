# Iter-13 Discussion

## 総評

提案は、`SKILL.md` のコア構造を変えずに、`UNVERIFIED` な第三者ライブラリの挙動推定で使う二次証拠の探索順を明示化するものです。変更対象は `SKILL.md` Step 4 の 1 行のみであり、`Objective.md` が求める「1イテレーション1仮説」「最小限の diff」に整合しています（`proposal.md` 22-45, `Objective.md` 31-35）。

監査結論としては、これは Exploration Framework の B「情報の取得方法を改善する」に概ね適合し、研究コアも維持しています。ただし、`failed-approaches.md` の「探索シグナルの事前固定」への近接リスクはゼロではありません。したがって、承認は可能ですが、効果は限定的かつ条件付きです。

## 1. 既存研究との整合性

注: DuckDuckGo MCP の search エンドポイントはこの実行環境では複数回 `No results were found` を返したため、同じ DuckDuckGo MCP の `fetch_content` で直接公開資料を取得して確認した。

### 参照URLと要点

1. https://arxiv.org/abs/2603.01896
   - 要点: Agentic Code Reasoning 論文は、明示的 premises、execution-path tracing、formal conclusion からなる semi-formal reasoning が精度を改善すると述べている。
   - 本提案との関係: 提案はこのコアを壊さず、Step 4 の「unavailable source をどう扱うか」という補助規則を精緻化するだけである。`README.md` と `docs/design.md` が要約する研究コア（premises / iterative evidence / interprocedural tracing / refutation）とも矛盾しない。

2. https://docs.python.org/3/library/doctest.html
   - 要点: doctest は interactive examples を実行して、文書内の例が「実際にその通り動く」ことを検証する仕組みであり、公式に「executable documentation」「regression testing」と位置づけられている。
   - 本提案との関係: 仕様文や型だけでなく、実例ベースの証拠が実挙動に近い、という考え方を支持する。test usage を優先する方針は、「実際の呼び出し例は静的な説明より挙動に近い証拠である」という一般原則と整合する。

3. https://go.dev/blog/examples
   - 要点: Go の examples は documentation と tests を兼ね、API 変更で陳腐化しにくい「testable examples」として扱われる。実行・検証される例は API の実使用形を強く表す。
   - 本提案との関係: test/example usage を優先することは、単なる説明文よりも「観測された利用形」に基づいて挙動を推定するという点で妥当。

4. https://documentation.divio.com/
   - 要点: Divio の documentation framework は technical reference と tutorials/how-to/explanation を区別する。reference は網羅性に強いが、利用文脈や実例の意味づけは別の文書種別が担う。
   - 本提案との関係: type signatures / reference docs は有用だが、それだけでは実際の使用文脈が薄い。test usage を先に見るという提案は、reference 偏重を少し是正する方向として理解できる。

### 研究整合性の評価

- `docs/design.md` 5-7, 33-55 は、研究の本質を「証拠を先に集め、definition を読み、skip を防ぐ構造」に置いている。
- `SKILL.md` 106-111, 450-459 でも、名前からの推測禁止・source unavailable の明示・二次証拠の探索が既に要求されている。
- よって今回の提案は、研究コアの置換ではなく、既存補助規則の優先順位づけであり、整合的。

一方で、既存研究から直接「test usage を docs/type signatures より必ず先にせよ」という強い優先順位までは読み取れません。したがって、研究に「強く支持される」よりは、「研究コアに反しない実務的精緻化」と評価するのが正確です。

## 2. Exploration Framework のカテゴリ選定は適切か

結論: カテゴリ B で妥当です。

理由:
- `Objective.md` 148-152 によれば B は「コードの読み方の指示を具体化する」「どう探すかを改善する」「探索の優先順位付けを変える」カテゴリ。
- 提案は新しい判定軸を増やしていない。
- compare の定義や formal conclusion の枠組みも変えていない。
- Step 4 の unavailable-source 時における二次証拠の探索順だけを変更している。

したがって、A（推論順序・構造変更）や C（比較枠組み変更）ではなく、B と見るのが最も自然です。

## 3. EQUIVALENT 判定と NOT_EQUIVALENT 判定への作用

### 変更前との実効的差分

変更前の `SKILL.md` は、source unavailable の場合に `type signatures, documentation, or test usage` を並列列挙していました（`proposal.md` 28-32, `SKILL.md` 109, 458）。
変更案は、それを `test usage first, then type signatures, then documentation` という優先順に変えます（`proposal.md` 34-38）。

つまり実効差分は次の 1 点です。
- 「二次証拠の集合」は不変
- 「最初に見る証拠」が変わる

### EQUIVALENT への作用

改善しうる点:
- EQUIVALENT 誤判定の典型には、名前・型・一般的 API イメージから差異を過大視して false NOT_EQUIVALENT に寄るケースがある。
- 実際の test usage を先に見ると、「少なくとも既存 tests が通る文脈では同様に使われている」ことを掴みやすく、差異の過大視を抑えやすい。
- `README.md` 90-94 では persistent failures が EQUIVALENT 側に残っていると要約されており、方向感としては EQUIVALENT 改善にやや寄与しやすい。

悪化しうる点:
- test usage が sparse だったり代表性を欠くと、観測された usage に引きずられて「そのテスト文脈では同じ」を「一般に同じ」と過度に見なし、false EQUIVALENT のリスクもある。
- ただし compare 定義そのものは `modulo the existing tests` なので、既存 tests ベースの判断に限ればこのリスクはある程度制限される（`SKILL.md` 169-178）。

### NOT_EQUIVALENT への作用

改善しうる点:
- docs や type signatures では見えない実使用上の前提条件や例外的振る舞いが tests に現れていれば、diverging path を早く見つけられる。
- その場合、counterexample をより具体的に立てやすくなり、NOT_EQUIVALENT の根拠は強くなる。

限界:
- test usage を優先する変更は、存在しない使用例を発明してくれるわけではない。relevant tests が薄いケースでは、結局 type signatures / documentation へ降りるだけで、改善は小さい。
- したがって NOT_EQUIVALENT 側での利益は「実際に relevant usage が test に露出している」ケースに依存する。

### 片方向にしか作用しないか

結論: 片方向専用の変更ではないが、対称でもありません。

- 理論上は EQUIVALENT / NOT_EQUIVALENT の双方に作用します。
- ただし実効的には、「既存 tests 上で観測可能な usage を先に掴む」変更なので、compare の定義上、EQUIVALENT 側の calibration 改善にやや効きやすい可能性があります。
- 一方で relevant tests に差分が現れている NOT_EQUIVALENT では、counterexample 発見の早さにも寄与しうるため、片側専用ではありません。

監査上の判断としては、「両側に作用するが、均等な改善を約束するほどではない」が妥当です。

## 4. failed-approaches.md の汎用原則との照合

### 原則1: 探索シグナルの事前固定を避ける

最も重要な論点はここです。

`failed-approaches.md` 8-10 は、探索すべき証拠の種類をテンプレートで事前固定しすぎると、確認バイアスを強めると警告しています。
今回の提案は新しい証拠種を追加していないため、実装者の主張どおり「固定対象の追加」ではありません。しかし、優先順位を明示すること自体が探索の初期アンカーを作るのも事実です。

評価:
- セーフ寄りの理由: 既存の 3 種類を残したまま順序だけをつける小変更であり、排他的ルールではない。
- リスク要因: `test usage first` が強く解釈されると、「まず tests に都合のよい usage を探し、docs/types の反証確認が後回しになる」運用を誘発しうる。

結論:
- 本質的に同じ失敗の再演とまでは言えない。
- ただし失敗原則1に“近い方向”ではあるため、無警戒には承認できない。

### 原則2: 探索自由度を削りすぎない

- 今回は 3 種類すべての証拠を引き続き許容しており、禁止規則ではない。
- そのため自由度の削減は限定的。
- ただし unavailable-source の場面で毎回 test usage を最優先させると、言語・プロジェクトによっては最初の探索コストが増える可能性はある。

総合すると、この原則には概ね抵触しません。

### 原則3: 結論直前のメタ判断を増やしすぎない

- 提案は Step 5/5.5 や conclusion に新しい必須メタ判断を足していない。
- よってこの原則には抵触しません。

## 5. 汎化性チェック

### 明示的ルール違反の有無

提案文には以下は含まれていません。
- ベンチマーク対象リポジトリ名
- 特定テスト名
- 特定ケース ID
- ベンチマーク対象コードの断片

含まれている具体物は以下です。
- `Iter-13` という今回の作業番号
- `Step 4`, `行 109`, `Guardrail #5` のような SKILL/文書内参照
- SKILL.md の変更前後 1 行の自己引用

これらは benchmark 対象固有識別子ではなく、`Objective.md` の R1 の減点対象外に近い自己参照です（`Objective.md` 202-213）。したがって、監査観点 5 の意味でのルール違反は見当たりません。

### 暗黙のドメイン依存性

- 提案は「third-party library source unavailable」という一般状況を扱っており、特定言語専用ではない。
- `test usage` という概念も多くの言語・フレームワークで成立する。
- ただし、テスト資産が薄いプロジェクト、生成コード中心のリポジトリ、使用例が docs に偏るエコシステムでは効果が弱い。

したがって、汎化性は高いが、効果の強さはプロジェクト特性に依存します。

## 6. 全体の推論品質がどう向上すると期待できるか

期待できる向上:
- unavailable-source 関数に対する「名前・型・一般知識からの推測」を減らす
- compare において、既存 tests が実際に観測している使用文脈を先に押さえることで、推論をより test-grounded にする
- `UNVERIFIED` 項目の根拠の質を少し上げる

改善幅が限定される理由:
- 作用範囲は Step 4 の unavailable-source ケースに限られる
- relevant test usage が存在しない案件では、すぐ type signatures / documentation にフォールバックするため差分が小さい
- 研究コアの主要ボトルネックである premises, trace completeness, refutation を直接強化する変更ではない

総合すると、これは「高インパクトな構造改革」ではなく、「誤推測を少し減らす低リスクの探索順序調整」です。期待改善は小〜中程度で、主に calibration 改善として現れるはずです。

## 最終判断

判断:
- 研究コアとの整合: 良好
- カテゴリ選定: 妥当（B）
- EQUIVALENT / NOT_EQUIVALENT への作用: 双方向だが非対称、EQUIVALENT 側にやや効きやすい
- failed-approaches との関係: 原則1に近接する注意点はあるが、同一失敗の再演とまでは言えない
- 汎化性: 概ね良好、明示的な過剰適合の兆候なし
- 期待効果: 限定的だが合理的

承認: YES

補足条件:
実装時または rationale では、「test usage first」を排他的規則としてではなく、「最初に当たるが、疎・非代表的なら速やかに type signatures / documentation に広げる優先探索」と説明しておくと、`failed-approaches.md` の原則1への近接リスクをさらに下げられます。
