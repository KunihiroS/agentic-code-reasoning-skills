# Iteration 11 — 監査ディスカッション

## 総評
提案の中核アイデア自体は理解できる。compare モードにおいて「差異を見つけたら、その差異がどのコード地点から生じるかを明示させる」という方向は、既存研究の「証拠を局所化してから結論する」という流れと整合的であり、特に subtle difference dismissal の抑制には理にかなっている。

ただし、今回の提案文のままでは 3 点の重要な問題がある。

1. 効果の説明が対称的すぎる。実効的には NOT_EQUIVALENT 側への作用が主で、EQUIVALENT 側への直接効果は弱い。
2. compare 既存構造との噛み合わせがやや曖昧で、「first divergence」を新たに求める理由が現在の COUNTEREXAMPLE 要件との差分として十分に詰められていない。
3. 汎化性ルール違反がある。proposal.md 自体に具体的な行番号と変更文面のコードブロックが含まれている。

以上により、現時点では承認しない。

## 1. 既存研究との整合性

注: DuckDuckGo MCP の search は複数クエリで結果 0 件だったため、同 MCP の fetch_content で既知 URL を取得して確認した。

### 研究 1
URL: https://arxiv.org/abs/2603.01896
要点:
- Agentic Code Reasoning 論文は、explicit premises, execution-path tracing, formal conclusion を要求する semi-formal reasoning が、patch equivalence / fault localization / code QA の各タスクで精度を上げると述べている。
- つまり「結論の前に、証拠を明示的に固定する」方向は研究のコアと整合する。
- docs/design.md でも、Fault Localization Appendix B の 4-phase pipeline に Divergence Analysis が含まれると整理されており、提案の「diagnose 由来の divergence analysis を compare に移植する」という発想自体は F カテゴリに沿っている。

### 研究 2
URL: https://en.wikipedia.org/wiki/Counterexample-guided_abstraction_refinement
要点:
- CEGAR は、反例を生成し、それが本物かスプリアスかを点検し、必要なら精密化するという枠組み。
- 細部は本件と異なるが、「差異や反例を具体物として持ち、その妥当性を検査しながら判断を精密化する」という思想は今回の提案に近い。
- compare において「差異がある」と言うだけでなく「どこで分岐したか」を要求するのは、反例の実体化という意味で一般的に妥当。

### 研究 3
URL: https://en.wikipedia.org/wiki/Program_slicing
要点:
- Program slicing は、ある観測点や値に影響しうる文だけを依存関係に沿って遡る手法で、デバッグやプログラム解析に使われる。
- 今回の提案は厳密な slicing ではないが、「テスト結果の差」という観測点に対して、その差を生むコード地点を特定するという点で、依存起点を明確化する発想と整合する。
- よって「差のあるテストに対し、その差の原因となる地点を明示する」は、汎用プログラム解析原則と矛盾しない。

### 研究 4
URL: https://link.springer.com/chapter/10.1007/3-540-48166-4_16
要点:
- Delta Debugging は failure-inducing change を絞り込む科学的デバッグ手法として要約されている。
- 「失敗を起こす差分を局所化する」こと自体が長年の一般原則であり、今回の提案の方向性はその系譜にある。
- ただし delta debugging は差分を縮約する方法論であり、今回の compare certificate 改善とは目的粒度が異なる。よって強い直接根拠ではなく、補助的整合性の位置づけが妥当。

小結:
- 研究整合性は概ねある。
- 特に「証拠をファイル/行レベルに落とす」「差異を抽象的に済ませず、具体的な分岐点として記録する」という方向は、semi-formal reasoning の設計思想と合う。
- ただし、研究整合性があることと、compare モードでの追加義務が本当に両方向の精度を上げることは別問題である。

## 2. Exploration Framework のカテゴリ選定は適切か

判定: 概ね適切。

理由:
- Objective.md の F は「論文に書かれているが SKILL.md に反映されていない手法を探す」「他モードの手法を compare に応用する」と定義されている。
- 今回の提案は、docs/design.md が整理している Fault Localization Appendix B の Divergence Analysis を compare に移すという主張なので、カテゴリ F に素直に入る。
- たしかに見方によっては C（比較の枠組み変更）にも接するが、変更の根拠が「論文の未活用要素の導入」にある以上、主分類を F に置くのは自然。

留保:
- ただし compare 側で本当に追加すべきなのが diagnose の Divergence Analysis そのものなのか、それとも既存 COUNTEREXAMPLE 要件の精緻化なのかは分けて考えるべき。
- 現状の提案は、この 2 つをやや混同している。つまり「新しい観点の導入」なのか「既存 compare 要件の粒度上げ」なのかが完全には分離されていない。

## 3. EQUIVALENT 判定と NOT_EQUIVALENT 判定の両方への作用

ここが最重要の懸念点である。

### 3.1 変更前との差分
現行 compare checklist には既に以下がある。
- Trace each test through both changes separately before comparing
- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact
- NOT EQUIVALENT のときは COUNTEREXAMPLE で diverging assertion を明記
- EQUIVALENT のときは NO COUNTEREXAMPLE EXISTS で反証探索を記述

提案変更は、これに加えて
- outcome が異なる各テストについて
- 両変更が最初に分岐する specific file:line を identify する
ことを要求するもの。

したがって実効差分は、「差異があると判断した後の causal localization を compare checklist に埋め込む」点にある。

### 3.2 NOT_EQUIVALENT への作用
これは比較的明確にプラス方向。

期待できる利点:
- 「差異は見えたが無影響そう」と雑に捨てる経路を減らせる。
- COUNTEREXAMPLE の説得力が増す。既存は test assertion の分岐点までは必須だが、提案後は production code 側の分岐起点も要求できる。
- subtle difference dismissal にはかなり直接に効く。

ただし注意点もある:
- 「first divergence」は静的比較では必ずしも一意に定まらない。分岐が複数箇所に現れる、片方だけ追加ヘルパーを通る、観測可能差異は後段で初めて顕在化する、などのケースがある。
- そのため、first divergence を強く義務化すると、正しく NOT_EQUIVALENT だが起点特定が曖昧なケースで説明負荷だけ増える可能性がある。

### 3.3 EQUIVALENT への作用
提案文は「equiv / not_eq の両方向の根拠が強化される」と主張しているが、これはやや過大評価。

理由:
- 提案文の変更対象は「for each test where outcomes differ」で発火する。
- つまり、EQUIVALENT 判定では本来 outcome difference がないので、この追加義務は直接には発火しない。
- EQUIVALENT の品質向上に効くとすれば、モデルが差異候補を見つけたときに安易に dismiss せず、より丁寧に trace する副次効果だけである。
- しかしその役割は、現行の Guardrail #4 と compare checklist の「semantic difference を見つけたら relevant test を trace して no impact と結論せよ」が既に相当部分を担っている。

したがって、実効的には
- 主作用: NOT_EQUIVALENT 強化
- 副作用: EQUIVALENT での軽微な慎重化
であり、対称的な両方向改善とは言いにくい。

### 3.4 片方向にしか作用しないか
結論として、「ほぼ片方向寄り」である。

厳密にはゼロではないが、提案文の現在の書き方では作用の中心は NOT_EQUIVALENT 側に偏る。
EQUIVALENT 側にも明確に効かせたいなら、例えば
- outcome difference がない場合でも、重要な semantic difference 候補について reconvergence/no-impact の根拠をより具体化する
- COUNTEREXAMPLE 不在の説明で、差異候補が downstream で吸収される理由を file:line で示す
のように、EQUIVALENT 用の明示的な受け皿が必要である。

現提案はそこまで踏み込んでいないため、「両方向に効く」という説明は弱い。

## 4. failed-approaches.md の汎用原則との照合

### 原則 1: 特定シグナルの捜索へ寄せすぎない
部分的に注意が必要。

- 提案は「diverge point」という特定シグナルを明示的に探させる。
- ただし発火条件は「差異が見つかったテスト」であり、探索全体を最初からそのシグナル探索に固定するわけではない。
- よって failed-approaches の失敗をそのまま再演しているとは言いにくい。

一方で懸念もある。
- compare の本質は最終的な test outcome 同一性であり、最初の分岐点そのものではない。
- 「first divergence」を強く意識させると、観測差に直結する後段の処理よりも、早い段階の局所差に注意を吸われる可能性がある。
- これは Guardrail #5 の「downstream handling を見落とすな」と軽く緊張関係にある。

結論:
- 直ちに blacklist 該当ではない。
- ただし wording 次第では「特定シグナルの捜索」寄りに滑る危険がある。

### 原則 2: 探索の自由度を削りすぎない
大きくは抵触しない。

- 1 行追加であり、新規セクションも新規手順もない。
- compare モード内の局所的強化としては軽量。

ただし、first divergence の同定を常に要求すると、難しいケースで無駄な探索コストが増える可能性はある。自由度を壊すほどではないが、説明コストは上がる。

### 原則 3: 結論直前のメタ判断を増やしすぎない
この点は概ね問題なし。

- 追加先は pre-conclusion self-check ではなく compare checklist。
- したがって「新しいメタ判断」を最後に足す失敗パターンとは別。
- むしろ証拠粒度の追加であり、性質はメタ評価より tracing 義務に近い。

総合すると:
- failed-approaches の本質的再演とは断定しない。
- ただし「first divergence」を必須化する wording は、signal fixation に寄る危険を少し持つ。

## 5. 汎化性チェック

### 5.1 proposal.md の明示的ルール違反
提案文には以下の問題がある。

- 具体的な数値 ID: 「SKILL.md 行 258」
- 具体的なコード断片: 変更前/変更後の文言をコードブロックで提示

ユーザー指定ルールでは、提案文中に具体的な数値 ID やコード断片が含まれていれば違反として指摘すべき、とされている。したがってこれは明確に指摘対象。

補足:
- ここでの line number はベンチマーク対象 repo 固有の業務コードではないが、今回の監査ルールは proposal 文面に具体的数値 ID を入れないこと自体を求めているため、違反判定になる。

### 5.2 リポジトリ名・テスト名・固有コードの混入
- 提案文中にベンチマーク対象リポジトリ名や特定テスト名は見当たらない。
- その点は良い。

### 5.3 暗黙のドメイン依存
大きなドメイン依存は薄い。

- file:line ベースの分岐記述は、主要言語の静的読解に広く適用可能。
- compare モードにおける test-outcome ベース判定とも整合する。

ただし軽い依存はある。
- 「first divergence」を file:line 単位で安定に表現しやすいのは、比較的ソース対応が明確な通常のテキスト言語である。
- 生成コード、大規模設定駆動、宣言的 DSL、メタプログラミング中心のコードでは、最初の分岐点が source line として素直に表せないことがある。

結論:
- 提案内容そのものは概ね汎用的。
- しかし proposal 文面はルール違反を含むため、そのままでは監査通過不可。

## 6. 全体の推論品質への期待効果

見込みのある改善点:
- semantic difference を「ある/ない」の感想で終わらせず、根拠をコード地点まで固定できる。
- NOT_EQUIVALENT の説明責任が増し、subtle difference dismissal を減らしやすい。
- compare モードの証拠粒度が diagnose モードに少し近づくため、結論の監査可能性は上がる。

限定的または不明な点:
- EQUIVALENT 側の改善は間接的で、明示的メカニズムが弱い。
- 既存の Guardrail #4, #5, COUNTEREXAMPLE, NO COUNTEREXAMPLE EXISTS との役割分担がまだ粗い。
- 「first divergence」を求めることが、かえって初期差分に注意を寄せ、downstream での吸収有無の確認を甘くする危険もある。

よって期待値としては
- NOT_EQUIVALENT precision/recall には一定の改善余地あり
- EQUIVALENT には限定的
- overall 改善はありうるが、提案文の説明ほど自明ではない
と評価するのが妥当。

## 監査結論

結論:
- アイデアの方向性自体は研究整合的で、カテゴリ F も妥当。
- しかし、現 proposal は「両方向に効く」という効果主張が実効差分に比べて強すぎる。
- さらに proposal 文面に具体的な行番号とコード断片が含まれており、今回の汎化性ルールに違反している。

承認: NO（理由: 効果が実質的に NOT_EQUIVALENT 側へ偏っており両方向改善の根拠が弱いこと、ならびに proposal.md に具体的数値 ID とコード断片が含まれるルール違反があるため）
