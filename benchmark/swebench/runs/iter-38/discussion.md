# Iter-38 監査コメント

## 総論
提案は compare モードの STRUCTURAL TRIAGE に「変更意図の事前分類」を追加し、以後の詳細トレースの向きを安定させようとするものです。発想自体は理解できますが、現行文言のままでは「意図分類」が探索の補助ではなく先入観の固定として働く危険があり、汎用改善としては弱いです。特に `this classification anchors the expected direction of behavioral divergence` という一文は、比較の前に「どちら向きの差を探すべきか」を半ば決めてしまい、compare モードの中立性を崩しやすいです。

## 1. 既存研究との整合性

### 参照URLと要点
1. https://arxiv.org/abs/2603.01896
   - 要点: Agentic Code Reasoning の中心は、明示的な前提、実コードのトレース、形式的結論、反証可能性を通じて「証拠を先に集めてから判断する」ことにある。
   - 整合性評価: 提案はこのコア構造を直接壊してはいませんが、論文の主要メカニズムとして「変更意図の事前分類」は提示されていません。したがって直接的な研究裏付けは弱く、整合性は「矛盾しないが、強く支えられてもいない」程度です。

2. https://martinfowler.com/bliki/DefinitionOfRefactoring.html
   - 要点: Fowler は refactoring を「observable behavior を変えずに内部構造を改善する変更」と定義している。
   - 整合性評価: 「refactoring」というラベル自体は振る舞い不変の期待と結びつくため、分類が正しい場合には EQUIVALENT 側の仮説形成に役立ちうる、という点では提案を部分的に支持します。

3. https://en.wikipedia.org/wiki/Software_maintenance
   - 要点: 保守作業の分類は corrective / adaptive / perfective / preventive など、より広く多面的に整理される。
   - 整合性評価: 提案の 3 分類（refactoring / bug-fix / feature-addition）は直感的ではあるものの、既存の一般的分類体系と比べると非網羅的で、互いに排他的でもありません。したがって「汎用フレームワークの必須前処理」としては粗いです。

### 小結
既存研究と完全に不整合ではありません。しかし、研究のコアにあるのは「証拠中心の追跡」であり、提案のような意図分類の先行義務化を直接支える根拠は弱いです。さらに refactoring の研究的定義は有益でも、bug-fix / feature-addition まで含めた 3 分類を compare の汎用前処理にする妥当性は十分に裏づけられていません。

## 2. Exploration Framework のカテゴリ選定は適切か
結論: カテゴリ C を選んだこと自体は妥当ですが、提案メカニズムの一般原則としての完成度は高くありません。

理由:
- この変更は「どう読むか」より「どう比較枠組みを切るか」を変えるので、A/B より C に属するという整理は自然です。
- ただし、compare モードで重要なのは最終的に「既存テスト上の結果が同じかどうか」であり、変更の作者意図は補助情報にすぎません。
- `primary intent` という単数ラベル化は、混合パッチに弱いです。実務の変更は refactor + bug-fix、feature + compatibility fix、test adaptation + behavior change のように複合化しがちです。
- 意図分類は、しばしば詳細トレースの後でないと確定できません。つまり「トレース前に意図を確定する」は認識論的に順序が逆転しやすいです。

したがって、カテゴリ C の選択自体は適切でも、「3 分類の primary intent を detailed tracing 前に必須化する」具体案は、汎用原則としてはやや無理があります。

## 3. EQUIVALENT 判定と NOT_EQUIVALENT 判定への作用

### 変更前との実効的差分
変更前の S3 は、大規模パッチでは構造差分と高レベル意味比較を優先せよ、というスケール制御だけでした。
変更後はそこに、パッチサイズに関わらず「各変更の primary intent を分類し、それを behavioral divergence の期待方向のアンカーにする」という新しい事前バイアスが入ります。

これは単なる説明追加ではなく、compare の初期仮説の向きを明示的に与える変更です。

### NOT_EQUIVALENT 側への作用
正に働く可能性:
- bug-fix / feature-addition と分類された場合、「差がテスト結果に出る可能性がある」という視点で counterexample 探索を始めやすい。
- subtle difference dismissal を減らす方向には働きうる。

負に働く可能性:
- bug-fix と分類しただけで、実際にはテスト結果が同じケースでも差分を過大評価しやすい。
- feature-addition と分類しても、既存テストの観測範囲では EQUIVALENT なことは普通にありうる。

### EQUIVALENT 側への作用
正に働く可能性:
- refactoring と分類でき、かつ分類が正しいなら、「observable behavior は変わらないはず」という仮説を持って no-counterexample を組み立てやすい。

負に働く可能性:
- refactoring ラベルが早すぎると、EQUIVALENT を先に信じてしまい、差分の実害検証が甘くなる。
- 逆に bug-fix / feature-addition と分類されると、既存テスト上は EQUIVALENT でも「差があるはず」という方向に探索が引っ張られる。

### 片方向にしか作用しないか
完全な片方向ではありませんが、実効的には NOT_EQUIVALENT 側を強めやすい非対称性があります。

理由は、追加文が `anchors the expected direction of behavioral divergence` と明言しているからです。これは compare の中立的な「同じか/違うかの両探索」ではなく、先に divergence の向きを持たせる表現です。refactoring が当たれば EQUIV にも寄与しえますが、3 分類のうち refactoring 以外は基本的に「差が出る側」へ推論を押しやすく、全体としては対称ではありません。

よって、「EQUIV と NOT_EQ の両方をバランスよく改善する」という主張は現状の文言では弱いです。

## 4. failed-approaches.md の汎用原則との照合
提案文は非抵触を主張していますが、私は少なくとも原則 1 と 2 に近接していると見ます。

### 原則 1 との関係
原則 1: 次の探索で探すべき証拠の種類をテンプレートで事前固定しすぎる変更は避ける。

今回の提案は一見すると「証拠そのもの」ではなく「文脈ラベル」の追加です。しかし実質的には、
- refactoring → 振る舞い不変の証拠を探しやすくする
- bug-fix / feature-addition → 振る舞い差の証拠を探しやすくする
という形で、探す証拠の向きを事前固定します。

特に `expected direction of behavioral divergence` という表現は、まさに「どの種類の証拠を期待して探すか」を先に与えるものです。したがって本質的には原則 1 に近いです。

### 原則 2 との関係
原則 2: 探索ドリフト対策を追加する際は、探索の自由度を削りすぎない。

提案は読解順序を固定していないものの、探索の初手に primary intent という単数ラベルを置くことで、後続探索の幅を心理的に狭めます。特に compare のような両仮説併走が重要な場面では、こうしたアンカーは自由度低下として作用しやすいです。

### 原則 3, 4 との関係
- 原則 3 には比較的非抵触です。仮説更新と前提修正義務を直結する変更ではありません。
- 原則 4 にも直接は当たりません。結論直前の自己監査ではなく、前段の triage 追加だからです。

### 小結
表現を変えていても、本質的には「探索前に見たい証拠の方向を決める」変更であり、failed-approaches の 1/2 の再演リスクがあります。

## 5. 汎化性チェック

### 明示的なルール違反の有無
明示的な違反は見当たりません。
- 特定のベンチマーク case ID: なし
- 特定のリポジトリ名: なし
- 特定のテスト名: なし
- ベンチマーク対象実装コード断片: なし

含まれているコードブロックは SKILL.md 自身の変更前後引用であり、Objective.md の基準上は許容範囲です。

### 暗黙のドメイン仮定
ただし、暗黙の汎化性懸念はあります。
- 変更が 3 分類でだいたい整理できる、という前提が強い。
- 実際には performance tuning, compatibility adjustment, config change, dependency bump, test-only adaptation, API surface restriction, migration/data handling など、3 分類に収まりにくい変更が多い。
- 言語・フレームワークに依らず混合意図パッチは一般的なので、`primary intent` という単数化は汎化性を損ねます。

したがって、形式的違反はないが、設計思想には汎化性の弱点があります。

## 6. 全体の推論品質がどう向上すると期待できるか
限定的な改善余地はあります。
- 変更意図を仮説レベルで軽く意識させるだけなら、探索の初期整理として有益かもしれません。
- 特に大規模パッチで「何が主戦場か」をざっくり掴む補助線にはなります。

しかし、提案文のままでは改善より副作用が気になります。
- 意図分類が誤ると、その後の detailed tracing 全体を誤誘導する。
- mixed-intent patch で単数分類を求めると、重要な副次的変更を見落としやすい。
- compare の本来の目的は test outcomes の一致/不一致確認であり、作者意図の推定ではない。
- 「behavioral divergence の期待方向をアンカーにする」という phrasing が、証拠収集より先に結論方向のバイアスを与える。

総合すると、推論品質の向上は「うまく当たるケースではありうる」が、汎用的・安定的改善としては期待値が高くありません。

## 最終判断
承認: NO（理由: 変更意図の事前分類を compare の必須アンカーにする現行文言は、研究コアの直接補強よりも探索の先入観固定として働く可能性が高い。特に `expected direction of behavioral divergence` という表現は EQUIVALENT/NOT_EQUIVALENT に対して対称ではなく、failed-approaches.md の「証拠種類の事前固定」「探索自由度の縮小」に本質的に近い。明示的な overfitting 違反はないが、汎用改善としては承認しにくい。）
