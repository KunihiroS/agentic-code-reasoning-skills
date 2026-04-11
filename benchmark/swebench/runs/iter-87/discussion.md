# iter-87 監査ディスカッション

## 前提確認
- 監査対象の提案は、Step 3 の HYPOTHESIS UPDATE 行を
  `H[M]: CONFIRMED / REFUTED / REFINED — [explanation]; if REFUTED, state H[M+1] targeting what the refutation exposed before reading the next file`
  に変更する 1 行差分である（proposal.md:21-35）。
- 現行 SKILL.md では Step 3 に HYPOTHESIS UPDATE, UNRESOLVED, NEXT ACTION RATIONALE があるが、REFUTED 後に「次の仮説を必ず立てる」までは明示していない（SKILL.md:51-76）。
- docs/design.md は、研究のコアを「premises → iterative evidence gathering → counterexample/alternative hypothesis check → formal conclusion」と整理し、不完全な reasoning chain を主要失敗パターンとして明示している（docs/design.md:19-27, 33-40）。
- README.md は空ファイルであり、この監査では追加情報源としては使えなかった。

## 1. 既存研究との整合性

DuckDuckGo MCP で確認した範囲では、この提案は「仮説を立て、反証し、次の仮説へ進む」という一般的な探索・デバッグ・推論の知見と整合的である。

1) Agentic Code Reasoning (arXiv)
- URL: https://arxiv.org/abs/2603.01896
- 要点:
  - semi-formal reasoning は「explicit premises, trace execution paths, formal conclusions」を要求する structured prompting であり、エージェントが unsupported claim や case skip をしにくくする、というのが論文の中心主張。
  - したがって、提案がやっている「REFUTED 後の継続を仮説駆動として明示する」は、研究コアの外側に新機構を足すというより、既存の semi-formal / hypothesis-driven な流れを補強する方向である。

2) Hypothesis-driven debugging (Grinnell, course material)
- URL: https://eikmeier.sites.grinnell.edu/csc-151-fall-2025/readings/hypothesis-driven-debugging.html
- 要点:
  - デバッグを ad-hoc にせず、scientific process に寄せるために「予測を立てる → verify/refute する → 得られた結果から further predictions を作る」と説明している。
  - 特に本文は、予測なしに観察を始めると探索が aimless になりやすく、結果からさらに prediction を更新し続けるべきだと述べている。
  - これは今回の「REFUTED なら、何が露呈したかを起点に H[M+1] を立ててから次ファイルへ進む」とほぼ同型である。

3) Controllable Logical Hypothesis Generation for Abductive Reasoning in Knowledge Graphs (arXiv)
- URL: https://arxiv.org/abs/2505.20948
- 要点:
  - 領域はコード推論ではないが、abductive reasoning において hypothesis generation 自体を制御対象とみなし、仮説空間の collapse や oversensitivity を主要課題として扱っている。
  - 今回の提案も、REFUTED のあとに次仮説を要求することで、仮説空間の無目的化や漂流を防ぎたい、という意味で一般推論研究の方向性とは整合する。

総評:
- 「反証後に明示的に次仮説へ接続する」という発想は、研究的には自然であり、SKILL.md のコアと矛盾しない。
- ただし論文の直接主張は「explicit premises / tracing / conclusion」の強化であり、「REFUTED ごとの次仮説生成」は論文から直接引用できる要件ではない。よって、整合的ではあるが、論文の厳密な既知最適解そのものではない。

## 2. Exploration Framework のカテゴリ選定は適切か

結論: 主カテゴリ A「推論の順序・構造を変える」は妥当。

理由:
- この変更は「何を探すか」の対象集合を増減するものではなく、「REFUTED の直後に何をするか」という遷移規則を追加するものなので、Objective.md のカテゴリ A に最も近い（Objective.md:143-147）。
- カテゴリ B「情報の取得方法」よりも、探索のナビゲーション規則の変更という性質が強い。
- カテゴリ D「メタ認知・自己チェック」とも違う。これは「ちゃんと見たか？」という自己評価ではなく、「次に何を仮説として検証するか」という能動的行動要求だからである。
- また副次的には、docs/design.md の error analysis を Step 3 に落とし込む意味で F「原論文の未活用アイデアを導入する」にも接している。ただし主分類としては A で問題ない。

汎用原則としての妥当性:
- 良い点は、探索の継続を generic に規定しており、言語・フレームワーク・タスク固有の観測対象を埋め込んでいないこと。
- さらに `before reading the next file` とあるので、ファイル読みの前に仮説を先置きするという Step 3 の原則と整合している。
- 一方で、この指示は Step 3 の記録テンプレート内に埋め込まれるため、モデルが「形式上 H[M+1] を書くだけ」で満足し、実質的探索改善につながらないリスクは残る。つまり方向性は妥当だが、効き方は wording 依存である。

## 3. EQUIVALENT 判定と NOT_EQUIVALENT 判定の両方への作用

### 変更前との差分
現行でも以下は存在する。
- HYPOTHESIS UPDATE（SKILL.md:67-69）
- UNRESOLVED（SKILL.md:70-72）
- NEXT ACTION RATIONALE（SKILL.md:73）

したがって実効的差分は、単なる「次アクションを書く」から一歩進めて、
- REFUTED になったときは
- refutation が露呈した事実を起点に
- 次仮説 H[M+1] を明示し
- それを立ててから次ファイルへ進む
という点にある。

### EQUIVALENT への作用
- EQUIVALENT を正しく出すには、候補となる差異仮説を複数 refute しつつ、反例不在を構造的に積み上げる必要がある。
- この変更は「一つの差異仮説が外れた後、探索が止まる/漂流する」ことを減らすので、雑な早期 EQUIVALENT や、逆に無目的な探索による未収束を減らす可能性がある。
- 特に compare モードでは、EQUIVALENT 主張時に No Counterexample Exists を書く必要があるため（SKILL.md:195-201）、その前段で refuted hypothesis を連鎖的に整理できるのは有益。

### NOT_EQUIVALENT への作用
- NOT_EQUIVALENT を正しく出すには、表面的差異から即断せず、その差異が relevant tests の outcome difference まで伝播するかを追う必要がある（SKILL.md:183-193, 214-220, Guardrail #4-#5 at SKILL.md:415-416）。
- 途中で立てた「この差異はテストに効くはず」という仮説が refute された場合、次にどの差異仮説へ移るかを明示できるのは、見落とし差異の再探索に役立つ。
- よって false EQUIVALENT の削減にも寄与しうる。

### 片方向にしか作用しないか
厳密には「完全対称」ではなく、「結論方向とは独立だが、発火頻度はデータ次第」という評価になる。

- 良い点:
  - トリガーは結論ラベルではなく `REFUTED` という探索状態であり、文面上は EQUIVALENT / NOT_EQUIVALENT のどちらにも偏っていない。
  - 既存の判定定義や立証責任自体は変更していない。

- 注意点:
  - 実務上、EQUIVALENT を出すまでには複数の「差異が効くはず」仮説を refute する場面が多く、NOT_EQUIVALENT は強い counterexample が見つかった時点で早く収束することがある。
  - そのため、追加負荷が平均的には EQUIVALENT 側に多くかかる可能性はある。

ただし今回の追加は 1 行で、要求しているのも「次仮説を state せよ」という軽量なものにとどまる。よって、failed-approaches.md が禁じるレベルの「片方向の立証責任引き上げ」とまでは言いにくい。私の見立てでは、効果は両方向にありつつ、実効上は EQUIVALENT 側でやや多く発火しうる、という程度である。

## 4. failed-approaches.md の汎用原則との照合

### 明確に抵触しにくい点
- 原則 #1 / #12 判定の非対称操作・アドバイザリな非対称指示
  - 結論ラベルに応じた追加義務ではなく、REFUTED 状態への追加義務なので、直接の非対称操作ではない。
- 原則 #2 出力側の制約
  - 「どう答えるか」ではなく「探索をどう継続するか」の指示なので、出力制約ではない。
- 原則 #3 探索量の削減
  - 探索を減らす方向ではない。
- 原則 #9 メタ認知的自己チェック
  - 自己評価ではなく次の探索行動を要求している。
- 原則 #11 探索順序の固定
  - 先に A 側を読め、後で B 側を読め、のような固定順序ではない。
- 原則 #23 抽象的な問い
  - 「REFUTED なら H[M+1] を state」という具体手順がある。

### 主要な懸念点
- 原則 #8 受動的な記録フィールドの追加
  - 実装者は「能動的な仮説生成の要求」であり受動記録ではないと主張しているが、実装位置は依然として HYPOTHESIS UPDATE の記録行である。
  - したがって、モデルによっては「H[M+1] を書いた」という記録行動に矮小化される危険がある。
  - ただし今回は `before reading the next file` まで含めており、単なる欄追加よりは行動誘発性が高い。この点で原則 #8 の失敗を完全再演しているとは言えないが、近接リスクはある。

- 原則 #6 「対称化」は差分で見よ
  - 提案文は「全モードに等しく適用される」「両方向に対称的」と書いているが、監査上はそのままは受け取れない。
  - 実効差分は `REFUTED` 発生時だけであり、しかも既存に NEXT ACTION RATIONALE がある。つまり新規性は「次行動を hypothesis 形式に固定する」点であって、完全な対称化そのものではない。
  - よって提案文の対称性主張はやや強すぎる。ここは表現を弱めるべき。

- 原則 #21 無目的化された探索空間の拡大
  - 今回はこれを避ける方向の提案であり、むしろ整合的である。REFUTED 後の再方向付けは、無秩序な再探索の抑制として機能しうる。

総合すると、過去失敗の本質的再演ではない。ただし原則 #8 と #6 に対する防御は「完全無罪」ではなく、「軽微な注意点あり」が妥当である。

## 5. 汎化性チェック

結論: 大きなルール違反は見当たらない。

### 明示的チェック
- ベンチマーク対象リポジトリ名: なし
- 特定テスト名: なし
- 特定関数名/クラス名/ファイルパス/コード断片（ベンチマーク対象由来）: なし
- 特定ケース ID: なし

### 含まれている具体物の評価
- `iter-87 Proposal` というタイトルの数値はイテレーション番号であり、ベンチマークケース ID ではない。
- `H[M]`, `H[M+1]` のような記号は SKILL.md の自己引用であり、Objective.md の R1 の減点対象外に近い扱いでよい。
- 変更前/変更後のコードブロックは SKILL.md 自身の文言引用であり、ベンチマーク対象リポジトリの実コード断片ではない。

### 暗黙のドメイン仮定
- 提案は「次ファイルを読む前に仮説を書く」としており、ファイルベース探索を前提にしている。ただし SKILL.md 自体が codebase exploration を前提とする skill なので、この程度は過剰適合ではない。
- 特定言語、特定テストフレームワーク、特定 API、特定バグパターンへの依存は見えない。

よって汎化性は概ね良好。ただし proposal.md:44 の「Subtle difference dismissal の発見率向上」のような期待効果は比較モード寄りであり、全モード同等とまで言い切るよりは、「特に compare に効きやすいが他モードにも害は少ない」と書く方がより厳密である。

## 6. 全体の推論品質がどう向上すると期待できるか

期待できる改善:
1. 仮説駆動探索の連続性が上がる
- 現行でも仮説は立てるが、refutation の直後に何を足場に次へ進むかは曖昧である。
- この変更により、探索の連鎖が `hypothesis -> evidence -> refutation -> successor hypothesis` という形で閉じやすくなる。

2. exploratory drift が減る
- proposal.md が狙っている通り、仮説が外れた後に「とりあえず別ファイルを見る」流れを抑制しやすい。
- docs/design.md の incomplete reasoning chains への局所対策として筋が良い。

3. 反証の情報を前向きに再利用できる
- refutation を単なる失敗記録で終わらせず、「何が露呈したか」を次仮説へ変換するので、探索の累積性が少し上がる。

ただし期待しすぎは禁物:
- これは根本的に新しい観測点や検証ステップを増やす変更ではない。
- 効果の本体は「漂流の抑制」と「次行動の具体化」であり、強い性能改善が出るとしても中程度だと思われる。
- また wording 次第では ceremonial な H[M+1] 生成に流れる可能性があるため、過大評価は避けたい。

## 総合判断

私はこの提案を「小さく、研究コアに沿い、過去失敗の本質再演でもない改善」と評価する。

一方で、提案文にはやや強すぎる主張がある。
- 「全モードに等しく適用される」
- 「compare モードでは EQUIV / NOT_EQ の両方向に対称的に作用する」

これらは文面上はそう見えても、実効差分としては `REFUTED` 発生時だけに働く軽い探索ナビゲーションであり、発火頻度はタスクや正解ラベルで偏りうる。したがって、承認するにしても「完全対称」を強く言い切る表現は弱めた方がよい。

承認: YES

補足条件:
- 実装時の rationale では「完全対称」ではなく「結論ラベルではなく探索状態に作用するため、片方向専用の誘導ではない」と表現するのがより正確。
- また、これは記録欄追加ではなく行動誘発だと明確にするため、必要なら rationale 側で `NEXT ACTION RATIONALE を hypothesis 形式に具体化する変更` と説明するとよい。