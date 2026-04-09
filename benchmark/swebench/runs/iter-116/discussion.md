# Iter-116 Discussion

## 総評
提案の狙い自体、すなわち「差異の存在」と「その差異がテストの観測点まで伝播するか」を分けて考えようという発想は、観測可能な振る舞いに基づいて等価性を判定するという一般原則とは整合的です。proposal は compare モードの `EDGE CASES RELEVANT TO EXISTING TESTS` に 1 行だけ追加し、`Difference propagates to test assertion: YES / NO — [how or why not]` を記録させる変更を提案しています（proposal.md:34-63）。

ただし、監査観点では「発想の正しさ」と「この diff が実効的に効くか」は分けて見る必要があります。今回の案は前者では筋が良い一方、後者では強い懸念があります。主な懸念は次の 2 点です。

1. 変更の実効差分が EQUIVALENT 側に偏っており、failed-approaches の非対称性原則に抵触する可能性が高いこと。
2. 追加されるのが検証行動ではなく記録フィールドであり、failed-approaches #8 が禁じる「受動的な記録フィールドの追加」の再演にかなり近いこと。

そのため、現状のままの承認は難しいです。

## 1. 既存研究との整合性

注: DuckDuckGo MCP の search エンドポイントは今回の実行では結果を返さなかったため、同じ DuckDuckGo MCP の `fetch_content` を使って汎用的な参考ページを直接取得しました。

### 参考 URL と要点
1. https://en.wikipedia.org/wiki/Observational_equivalence
   - 要点: 観測可能な含意が同一であれば区別不能、というのが observational equivalence の基本定義。プログラミング言語意味論でも「全ての文脈で同じ値を返すなら観測的に等価」とされる。
   - 本提案との関係: proposal が言う「差異がテスト観測点に伝播するか」を問う発想自体は、この観測的等価性の考え方と整合する。

2. https://en.wikipedia.org/wiki/Test_oracle
   - 要点: テストオラクルは、ある入力に対して何が正しい出力かを与える仕組みであり、実際のテストでは SUT の結果とオラクルが与える期待結果を比較する。さらに oracle problem は「正しい出力をどう知るか」が難しいことを示す。
   - 本提案との関係: 変更差分がテスト assertion に伝播するかを区別することは、「差異の存在」そのものではなく「オラクルが観測する結果の差」を問うという意味で妥当。

3. https://en.wikipedia.org/wiki/Metamorphic_testing
   - 要点: 重要なのは内部差異そのものではなく、複数実行のあいだで観測される性質違反があるかどうかである。観測可能な関係違反がなければバグ検出につながらない。
   - 本提案との関係: 差異の有無と観測可能な結果差を分離するという proposal の意図は、ここでも一般原則として支持される。

### 研究コアとの関係
README.md は空ですが、docs/design.md では論文のコアを「明示的 premises」「per-item tracing」「formal conclusion」からなる certificate 化だとまとめています（docs/design.md:3-7, 31-55）。SKILL.md の compare モードも per-test tracing と counterexample/no-counterexample を中核にしています（SKILL.md:138-227）。

この観点では、今回の提案は研究コアを壊してはいません。むしろ「差異を見つけた後に観測結果まで追う」という観点は、既存 Guardrail #4「semantic difference を見つけたら、それが impact を持たないと結論する前に relevant test を trace せよ」と整合しています（SKILL.md:421-422）。

ただし重要なのは、SKILL.md にはすでにこの guardrail が存在する点です。今回の追加は研究コアの新規導入というより、既存 guardrail を別の欄で再表現している側面が強いです。

## 2. Exploration Framework のカテゴリ選定は適切か

proposal はカテゴリ C「比較の枠組みを変える」を選んでいます（proposal.md:3-5, Objective.md:153-157）。

この分類は半分は妥当、半分は危ういです。

- 妥当な面:
  - 「差異の存在」と「観測点への伝播」を分離するのは、比較の評価軸を二段階化するという意味で確かに比較フレームの変更です。
  - そのため、カテゴリ C の「差異の重要度を段階的に評価する」に概念的には乗っています。

- 危うい面:
  - 実際の diff は compare ロジックの手順変更ではなく、テンプレートの記録欄を 1 行増やすだけです（proposal.md:49-63）。
  - したがって実装レベルでは C というより E（表現・フォーマット変更）に近いです。カテゴリ上は C を名乗っていても、実効は「問いの追加」というフォーマット改変にとどまります。

要するに、アイデアは C 的だが、diff の作用点は E 的です。このズレが後述する「理屈は良いが効きが弱い」問題につながっています。

## 3. EQUIVALENT / NOT_EQUIVALENT の両方にどう作用するか

ここが最大の論点です。proposal 自身は「EQUIV/NOT_EQ 両方向に等しく適用される」と主張します（proposal.md:97-100）。しかし、failed-approaches は「対称的な文言であっても、変更前との差分が非対称なら効果も非対称」と警告しています（failed-approaches.md:20-21）。

### 変更前との差分
変更前の compare テンプレートには既に以下があります。
- test ごとの PASS/FAIL 追跡（SKILL.md:167-187）
- edge case ごとの `Test outcome same: YES / NO`（SKILL.md:189-195）
- NOT_EQ のときは counterexample 必須（SKILL.md:196-199）
- EQUIVALENT のときは no-counterexample exists 必須（SKILL.md:201-207）
- Guardrail #4 により、semantic difference を見つけたら impact の有無を relevant test で trace するよう求めている（SKILL.md:421-422）

この状態から新たに追加される差分は、「edge case 欄に propagation を明示記録させる」ことだけです（proposal.md:51-57）。

### EQUIVALENT 判定への作用
EQUIVALENT 側には比較的大きく作用します。理由は、既に差異を見つけた後でも「でも assertion までは届かない」と明示的に書かせることで、差異の過大評価を抑えたいからです。proposal の狙いもここにあります（proposal.md:67-81）。

つまりこの追加は、主として「誤 NOT_EQ を減らす」方向に働きます。ここは proposal の自己分析と一致します。

### NOT_EQUIVALENT 判定への作用
NOT_EQ 側への新しい利得はかなり限定的です。なぜなら、真に NOT_EQ のケースでは、もともと
- test 単位の outcome 比較
- counterexample 記述
が必要であり、propagation は事実上すでに必要条件だからです（SKILL.md:167-199）。

今回の 1 行は、その既存要件に対して新しい探索行動をほとんど増やしません。せいぜい「既に分かっている counterexample の因果説明をもう一言書く」程度です。

### 結論: 実効差分は片方向寄り
したがって、文面は対称でも実効差分は EQUIVALENT 側にほぼ片寄っています。これは failed-approaches #1, #4, #6, #12 が警戒するパターンに近いです（failed-approaches.md:10-10, 16-16, 20-21, 32-32）。

特に #6 の観点では、「既に NOT_EQ には counterexample obligation がある」ため、今回の追加は既存の弱い側、すなわち EQUIV 側の擁護にのみ実質的に作用します。proposal の「両方向に等しい」という自己評価は甘いです。

## 4. failed-approaches.md との照合

proposal は多数の原則に「抵触なし」と書いています（proposal.md:93-107）。しかし、監査としては少なくとも次の 3 点は再検討が必要です。

### 4.1 原則 #8「受動的な記録フィールドの追加」
failed-approaches #8 はかなり直接的で、「関係性を記述する列」を足しても、AI はもっともらしいテキストを生成するだけで、追加の検証行動は生まれにくいと述べています（failed-approaches.md:24-24）。

今回の変更はまさに compare テンプレート内の記録欄 1 行追加です（proposal.md:49-63）。proposal は「これは能動的検証を誘発する」と主張しますが（proposal.md:103-103）、その根拠は弱いです。なぜなら:
- 新しい search / trace / refutation ステップは増えていない
- 具体的に何を確認すべきかも増えていない
- 単に `Test outcome same` の前に別ラベルを挿入しているだけ

つまり「何を書くか」は増えるが、「何を調べるか」は実質変わっていません。原則 #8 との類似性は強いです。

### 4.2 原則 #6「対称化は既存制約との差分で評価せよ」
前述の通り、既に NOT_EQ には counterexample 構成という強い義務があります。そこへ propagation 欄を足しても新味は薄く、EQUIV 側にのみ実効的差分が出ます。これは proposal 自身の対称性主張よりも、failed-approaches #6 の警告の方が当たっています（failed-approaches.md:20-21）。

### 4.3 原則 #23「具体的検証手順を伴わない抽象的な問い」
今回の新行は `YES / NO — [how or why not]` という問いを増やしますが、どのような検索や追跡でその問いに答えるかは規定しません。これは failed-approaches #23 の「ソフトフレーミング」の弱点に近いです（failed-approaches.md:54-54）。

### 補足: proposal の自己弁護で妥当な点
proposal が #25, #18, #26 への抵触を避けようとしている点は理解できます（proposal.md:105-106）。たしかに file:line や assertion 名の強制までは行っておらず、過剰な事前検証ゲートも追加していません。この点はプラスです。

しかし、それは「害が少ない」ことを示すにとどまり、「効く」ことまでは示しません。今回の主問題は、強すぎることより弱すぎることです。

## 5. 汎化性チェック

### 5.1 露骨なルール違反の有無
proposal 内には以下は見当たりません。
- ベンチマーク対象リポジトリ名
- 特定のテスト名
- 特定の関数名・クラス名
- 実リポジトリ由来のコード断片

この点では Objective.md の R1 が禁じる固有識別子の混入には当たりません（Objective.md:184-213）。

### 5.2 軽微な注意点
以下はありますが、監査上は即 NG ではありません。
- `Iter-116` というイテレーション番号
- `Guardrail #4` や `failed-approaches #25` のような内部文書参照番号
- SKILL.md の自己引用としてのテンプレート断片

これらはベンチマーク対象リポジトリ固有識別子ではなく、今回の改善文脈を示す内部参照なので、R1 の即失格条件には当たりません。

### 5.3 暗黙のドメイン依存性
提案は `test assertion` を強く前面に出しています（proposal.md:55）。これは一般には妥当ですが、表現上やや xUnit 的・テストコード中心的です。とはいえ compare モード自体が「existing tests modulo」での等価性判定なので、ここで assertion を観測境界として扱うこと自体はモードに整合しています。言語・フレームワーク・テストパターンへの過剰依存とまでは言えません。

結論として、汎化性違反はありません。ただし「assertion への伝播」という phrasing はテストコードが明示的 assertion を持つ前提に少し寄っているため、より汎用には「test oracle / observable outcome」寄りの表現の方が望ましいです。

## 6. 全体の推論品質がどう向上すると期待できるか

期待できる改善は限定的です。

### 改善が期待できる点
- 差異の発見直後に NOT_EQ へ飛ぶ短絡を、少し抑える可能性はあります。
- compare モードのエッジケース欄で、内部差異と観測差異を分けて言語化させるため、EQUIV の説明品質はやや上がるかもしれません。
- docs/design.md のいう certificate 的性質、すなわち「スキップしにくくする」効果は、ごく弱くですが増える可能性があります（docs/design.md:5-7, 42-55）。

### 限界
- すでに SKILL.md には同趣旨の guardrail と counterexample/no-counterexample が存在するため、純増の情報量は小さいです（SKILL.md:196-207, 421-422）。
- 新しい探索行動を要求していないので、モデルが単にもっともらしい propagation 説明を付け足すだけで終わる危険があります。これは failed-approaches #8 の懸念そのものです（failed-approaches.md:24-24）。
- 作用方向は主に「誤 NOT_EQ を減らす」側であり、NOT_EQ の質を同程度には底上げしません。全体精度改善より、しきい値移動に近い挙動になるリスクがあります。

## 7. 最終判断

発想レベルでは良いです。観測的等価性、テストオラクル、observable outcome という一般原則には整合していますし、露骨な overfitting も見当たりません。

しかし監査対象は「アイデア」ではなく「この diff」です。今回の diff は、
- 実効差分が EQUIV 側寄りで非対称
- 追加されるのが検証行動ではなく記録欄
- 既存 guardrail の再表現にとどまりやすい
という理由で、failed-approaches の再演リスクが高いです。

承認: NO（理由: failed-approaches #8「受動的な記録フィールドの追加」に実質的に近く、さらに変更前との差分で見ると EQUIVALENT 側に偏って作用するため、#1/#6 の非対称性リスクも高い。発想の一般妥当性はあるが、この 1 行 diff の実効改善は弱い）
