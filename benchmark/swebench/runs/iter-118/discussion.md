# iter-118 監査コメント

## 総評
提案の狙い自体は理解できる。`NO COUNTEREXAMPLE EXISTS` 節の結論行を具体化し、EQUIVALENT 判定の論拠を「見つからなかった」から「なぜ観測可能差分にならないのか」へ押し上げたい、という発想は研究のコアである semi-formal reasoning の方向性とは整合的である。

ただし、今回の差分は `compare` テンプレート中の **EQUIVALENT を主張する場合にだけ使う節** に対する変更であり、変更前との差分としてみると実効的には EQUIVALENT 側の立証責任だけを引き上げる。failed-approaches.md のブラックリスト原則に照らすと、この非対称性は見逃せない。したがって、監査結論は現状では不承認寄りである。

## 1. 既存研究との整合性

### 1-1. 原論文との整合
URL: https://arxiv.org/abs/2603.01896
要点:
- 論文の要旨は、explicit premises、execution-path tracing、formal conclusion を要求する semi-formal reasoning が、unsupported claim を減らす「certificate」として機能するというもの。
- 今回の提案は、結論欄の placeholder を具体化して unsupported な EQUIVALENT 結論を減らしたい、という方向なので、研究の大枠とは整合する。
- 一方で論文の主効果は「構造化された推論全体」にあり、単独の conclusion 行の書き換えだけで大きな改善が出るとまでは読めない。したがって研究整合性はあるが、効果量の期待は限定的。

### 1-2. プロンプト具体化・構造化との整合
URL: https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview
要点:
- Anthropic の prompt engineering overview は、明確な success criteria、評価方法、構造化された instructions を前提にプロンプトを調整すべきだと述べている。
- 曖昧な placeholder を、より具体的な評価観点に置き換えること自体は一般的な prompt engineering の原則に合う。
- ただし同資料は、prompt engineering は eval とセットで反復最適化すべきだと示しており、今回も「明確化だから安全」とは言えず、実効差分が片側に偏るかを別途見る必要がある。

### 1-3. 中間推論の明示化との整合
URL: https://www.promptingguide.ai/techniques/cot
要点:
- Chain-of-Thought / structured intermediate reasoning は、複雑タスクで reasoning performance を改善しうる。
- 今回の提案も「結論の前に、差分が観測点へ届くかという中間意味論を意識させる」点ではこの流れに沿う。
- ただし CoT 系知見が支持するのは「中間推論の追加・明示化」であって、特定ラベル側の最終結論テンプレートだけを厳しくすることではない。したがって、研究一般は今回の変更の動機を支持するが、実装位置の非対称性までは正当化しない。

## 2. Exploration Framework のカテゴリ選定は適切か
結論: カテゴリ E を選んだこと自体は妥当だが、実効メカニズムは E 単独ではなく「E 的な表現変更が compare モードの判定バランスに触れる」タイプであり、監査上は中身を厳しく見る必要がある。

根拠:
- proposal の変更対象は 1 行の placeholder 置換であり、形式上は Objective.md のカテゴリ E「表現・フォーマットを改善する」に当てはまる。
- 実際にも、新規ステップ追加・新規欄追加・探索順序変更ではなく、「曖昧文言の具体化＋例示追加」である。
- ただし compare テンプレートでは、その 1 行が EQUIVALENT 主張時の最後の justification に直結している。ゆえに「単なる wording 改善」ではなく、判定時の心理的ハードルを動かしうる。

したがってカテゴリ分類としては E でよいが、「E だから安全」とは言えない。カテゴリは形式分類にすぎず、実効差分は failed-approaches 原則に照らして別に評価すべきである。

## 3. EQUIVALENT 判定と NOT_EQUIVALENT 判定への作用

### 3-1. 変更前との差分
変更前の `SKILL.md` では `NO COUNTEREXAMPLE EXISTS` 節の結論は単に:
- `Conclusion: no counterexample exists because [brief reason]`
だった。

変更案ではこれが:
- 差分が test observation point に届かない理由を述べよ
- 例として unreachable path / output unused / no test assertion captures changed value
を要求する文に置き換わる。

この差分は、表面上は「良い説明を書け」と言っているだけに見えるが、実際には EQUIVALENT 主張時に必要な論証の型をかなり具体化している。

### 3-2. EQUIVALENT への作用
直接作用は強い。
- 良い方向: 根拠の薄い EQUIVALENT、特に「反証が見つからないから同じだろう」という雑な結論を抑制しうる。
- 悪い方向: EQUIVALENT を出すために、観測境界まで届かないことの積極的説明を毎回要求するため、正しい EQUIVALENT でも躊躇・過剰探索・安全側回避を招きうる。

つまり precision を上げる可能性はあるが recall を落とすリスクがある。

### 3-3. NOT_EQUIVALENT への作用
直接作用はほぼない。`COUNTEREXAMPLE` 節や per-test tracing の要求は変わっていないため、NOT_EQUIVALENT を正しく導く主ループは原文のまま。

ただし間接作用はある。
- EQUIVALENT のハードルだけが上がると、モデルは証明し切れないケースで NOT_EQUIVALENT へ逃げやすくなる。
- あるいは compare モード全体で conclusion 直前の負荷が上がり、UNKNOWN 相当の逡巡や不安定化を招く可能性がある。

重要なのは、proposal が主張する「到達性の判断は双方向に使われるため、NOT_EQ を阻害しない」は、変更後の文面そのものだけを見た説明であり、**変更前との差分** を見ていない点である。実際の差分は EQUIVALENT 側の結論欄にだけ追加要件を課しているので、作用は片方向である。

### 3-4. 監査結論
この変更は実効的に片方向に作用する。少なくとも「両方向に同程度に効く」とは評価できない。

## 4. failed-approaches.md との照合
proposal 本文は「抵触なし」としているが、私はそうは見ない。

### 原則 #1 判定の非対称操作は必ず失敗する
抵触懸念あり。
- 今回の変更は EQUIVALENT 主張時のみに追加説明責任を課す。
- それ自体が立証責任の非対称化であり、原則 #1 の典型パターンに近い。

### 原則 #6 「対称化」は既存制約との差分で評価せよ
抵触懸念が強い。
- proposal は「到達性は双方向に使えるから非対称ではない」と説明する。
- しかし監査すべきなのは変更後の文面の抽象的対称性ではなく、変更前との差分。
- 差分としては EQUIVALENT 側だけが強化されており、原則 #6 に正面から触れる。

### 原則 #12 アドバイザリな非対称指示も実質的な立証責任の引き上げとして作用する
抵触懸念あり。
- これは追加の mandatory section ではないが、compare テンプレートの conclusion 行なので、実運用上はかなり強い拘束力を持つ。
- 「観測点に届かない理由」を EQUIVALENT 側だけに具体要求する時点で、実質的には片側だけの追加検証要求になりやすい。

### 原則 #20 目標証拠の厳密な言い換えや対比句の追加は、実質的な立証責任の引き上げとして作用する
抵触懸念あり。
- `[brief reason]` から長い instruction への置換は、まさに「既存表現のより厳格な言い換え」に該当する。
- 意図が clarification でも、モデルには「そのレベルまで言えなければ EQUIVALENT を出すな」という警告として働きうる。

### 原則 #22 抽象原則での具体物の例示は、物理的探索目標として過剰適応される
軽度の懸念あり。
- 例示のうち `no test assertion captures the changed value` は比較的抽象的で許容範囲。
- ただし「output is unused」や「assertion captures changed value」を毎回物理的に特定しようとして追加探索コストを生む可能性はある。
- 重大違反とまでは言わないが、探索コスト増の副作用は無視しづらい。

総合すると、proposal が述べる「既知の失敗原則への抵触なし」という自己評価には賛成できない。少なくとも #1, #6, #12, #20 は明確に再検討が必要である。

## 5. 汎化性チェック

### 5-1. 露骨なルール違反の有無
重大な違反は見当たらない。
- 特定のベンチマーク case ID、特定リポジトリ名、特定テスト名は proposal 本文に含まれていない。
- 変更前後のコードブロックは SKILL.md 自身の文言引用であり、Objective.md の R1 注記上も原則許容範囲。
- line number 参照や原則番号参照は、ベンチマーク固有識別子ではないため、これ自体を違反とは言わない。

### 5-2. 暗黙のドメイン依存性
軽微な偏りはあるが、致命的ではない。
- `test observation point`、`assertion captures changed value` という表現は、テストオラクル中心の比較タスクに最適化されている。
- ただし compare モード自体が `EQUIVALENT MODULO TESTS` を定義しているので、この観測境界の語彙はタスク定義に整合している。
- 言語・フレームワーク依存の語彙ではなく、一般的なテスト意味論の語彙である点は良い。

したがって汎化性そのものは大きく崩れていないが、「テスト観測点へ届かないことを言語化させる」発想が compare の EQUIVALENT 側にだけ埋め込まれている点が、本質的な問題である。

## 6. 全体の推論品質の向上見込み
期待できる改善は限定的、回帰リスクは無視できない、という評価である。

期待できる点:
- EQUIVALENT 結論の文章が、単なる不在証明ではなく観測可能差分の不在へ寄る。
- compare モードで「差分を見つけたが影響不明」というケースに対し、観測境界を意識させる効果はありうる。

限界:
- 変更箇所は最終 conclusion 行だけで、探索行動そのものは直接増やしていない。
- failed-approaches.md の原則 #8 が指摘する通り、記述欄の要求強化は必ずしも能動的検証を誘発しない。
- 既存の Step 5 refutation check と compare checklist ですでに「counterexample を探す」「差分が本当に relevant test に影響するかを追う」要求は存在する。今回の追加はその上に EQUIVALENT 側だけ説明負荷を載せる構図になりやすい。

要するに、改善余地は「論拠の言語化の質」にはあるが、「推論プロセスの質」を安定的に押し上げるとはまだ言いにくい。しかもその副作用は片側判定に偏る。

## 最終判断
承認: NO（理由: 変更の狙いは理解でき、研究の方向性とも大筋では整合するが、実際の diff は `NO COUNTEREXAMPLE EXISTS` すなわち EQUIVALENT 側にのみ追加の説明責任を課しており、failed-approaches.md の原則 #1, #6, #12, #20 が警告する「実効的な非対称化」に該当する懸念が強い。推論品質の改善よりも、EQUIVALENT 側の立証責任引き上げによる回帰リスクの方が大きい。）
