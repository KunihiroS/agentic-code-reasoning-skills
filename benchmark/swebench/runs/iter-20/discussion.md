# Iteration 20 — 監査ディスカッション

## 総評
提案の狙い自体は理解できる。構造トリアージの直後に「見つかった差異がどれくらい重要そうか」を明示させる発想は、change impact analysis 的な考え方と整合し、微細差分の早期握りつぶしを減らしたいという問題意識も妥当である。

ただし、提案文の S4 は「重要度を明示する」だけでなく、MINOR/INERT を full ANALYSIS からスキップできる新しい分岐を導入している。この点が大きい。現行 SKILL.md には既に、
- Guardrail #4: semantic difference を見つけたら relevant test を trace してから影響なしと言え
- Compare checklist: 差異を見つけたら differing path を少なくとも1本 trace してから no impact を結論せよ
- Step 5.5: semantic difference 発見時に relevant test trace を要求
という anti-skip の仕組みが入っている。

そのため、提案は「不足している新能力の追加」というより、「既存ガードレールより前段で新しい予備判定ゲートを置く」変更になっている。しかもそのゲートは、証拠がまだ十分でない段階で MINOR/INERT と判断して除外する経路を作る。これにより、狙いとは逆に subtle-but-real な差異を早い段階で処理済みにしてしまう危険がある。

結論として、カテゴリ選定は概ね妥当だが、提案された具体文言は as written では承認しにくい。

## 1. 既存研究との整合性

### 参考URLと要点
1. https://arxiv.org/abs/2603.01896
   - Agentic Code Reasoning の中核は、premises・execution path tracing・formal conclusion を要求する semi-formal reasoning を「certificate」として使い、skip や unsupported claim を防ぐ点にある。
   - この観点からは、「差異の影響を明示的に考えさせる」方向性は整合的。
   - ただし同論文の強みは per-item tracing と refutation obligation にあるので、early triage による skip 経路を新設するのは、研究の anti-skip メカニズムとはやや緊張関係にある。

2. https://en.wikipedia.org/wiki/Change_impact_analysis
   - change impact analysis は「変更の潜在的帰結を特定する」「何が影響を受けるかを見積もる」営みとして説明されている。
   - 提案の「difference significance」を差異発見後に考える発想は、この一般原則には整合する。
   - 一方で impact analysis は traceability / dependency の裏づけを重視するので、test path への実証がない早期分類だけで skip するのは弱い。

3. https://en.wikipedia.org/wiki/Regression_testing
   - change impact analysis は regression testing で実行すべきテスト集合の選定に使われることがある。
   - これは「どの差異が test outcome に効きうるか」を考える発想を支持する。
   - ただし regression の文脈では、変更はしばしば間接影響を持つ。したがって「untested branches だけ」と早期に断定するのは、まさに危険な種類の省略である。

### 監査所見
研究・実務一般の観点から、差異の影響度を見る発想自体は妥当。しかし proposal の S4 は「impact を考える」だけでなく「その分類をもとに detailed tracing を省略できる」点で一歩踏み込みすぎている。これは Agentic Code Reasoning の certificate 的設計と完全には噛み合わない。

## 2. Exploration Framework のカテゴリ選定は適切か
カテゴリ C（比較の枠組みを変える）は、分類上は妥当。

理由:
- 提案は compare モード内部で「見つかった差異をどう比較・扱うか」を変えるもの。
- 新しい file discovery 方法や search order の変更ではないので B ではない。
- self-check を最後に増やす話ではないので D でもない。
- wording polish だけではなく comparison logic に触れているので E でもない。

ただし実質的には、C と D の境界に少し乗っている。なぜなら S4 は単なる comparison lens ではなく、新しい judgment gate として働くからである。つまりカテゴリ選定は acceptable だが、メカニズムの設計は慎重さが足りない。

汎用原則として見たときの問題は、カテゴリ自体ではなく分類粒度にある。
- CRITICAL = return value / exception type / control flow on a known test path
- MINOR = only untested branches
- INERT = cosmetic / whitespace / log-only
という3分類は分かりやすい反面、重要な差異の型をかなり狭く表現している。

例えば以下はこの3分類に収まりにくいが、実際には test outcome に効きうる。
- state mutation の順序差
- object identity / aliasing 差
- iterator / collection ordering 差
- resource lifecycle 差
- protocol / contract 準拠性の差
- caching / memoization による observable effect の差
- downstream handler が前提とする data shape 差

したがって、「汎用原則として理にかなうか」という問いには、「影響度を見るという原則は理にかなうが、その具体分類はやや粗く、汎化の観点で十分に抽象化されていない」と答えるのが妥当。

## 3. EQUIVALENT 判定と NOT_EQUIVALENT 判定の両方への作用

### 変更前の実効的挙動
現行 SKILL.md は、semantic difference を発見した後の扱いについて既にかなり明確である。
- 差異を見つけたら relevant test path を trace する
- no impact と言うには counterexample 不在を示す
- subtle difference を dismiss してはならない

つまり現行版の burden of proof は「差異を dismiss する側」に重い。

### 変更後の実効的挙動
提案後は burden of proof が一部変わる。
- まず S4 で差異を CRITICAL / MINOR / INERT に分類する
- full ANALYSIS が必須なのは CRITICAL のみ
- MINOR / INERT は justification があれば skip できる

この差は小さく見えて、実効的には大きい。現行は「trace してから dismiss」、提案後は「early classify して justified skip が可能」になる。

### 真に NOT_EQUIVALENT なものへの作用
狙いとしては、subtle difference を CRITICAL として早く拾い、見逃しを減らしたいのだと思われる。

ただし proposal の CRITICAL 定義には
- known test path
- alters return value / exception / control flow
という条件が入っている。

問題は、構造トリアージ直後の段階では、まだその差異が known test path に乗るかどうかが十分分かっていないことが多い点である。すると、本来は重要な差異でも、
- まだ test path への接続が示せていない
- 影響形態が return value / exception / control flow として直ちに言語化できない
という理由で MINOR 扱いされ、skip の対象になりうる。

これは NOT_EQUIVALENT を EQUIVALENT と誤る方向のリスクをむしろ増やす。

### 真に EQUIVALENT なものへの作用
一方で INERT 分類は、cosmetic/log-only 差分への過剰反応を抑えうる。これは EQUIVALENT を NOT_EQUIVALENT と誤るケースには効く可能性がある。

ただしこの利点は限定的である。なぜなら現行 SKILL.md でも、
- D1 により equivalence は test outcome basis で定義済み
- counterexample obligation がある
- subtle difference があっても relevant test trace を経て no impact を言う構造になっている
からである。

つまり proposal が新たに得る利得は主に「benign-looking difference を早く畳める」ことであって、「危険な difference を確実に拾う」能力ではない。

### 片方向にしか作用しないか
実効的には、かなり片方向である。

提案文は両方向改善を主張しているが、実際の差分は
- CRITICAL 差異の trace を新たに義務化する
よりも
- MINOR / INERT 差異を skip 可能にする
ことの方が強い作用を持つ。

しかも CRITICAL に分類できるには既にある程度の理解が必要であり、そこが満たせない subtle diff ほど MINOR 側に落ちやすい。したがって、この変更は対称的な改善ではなく、実務上は「差異を早めに捨てる側」に寄りやすい。

## 4. failed-approaches.md の汎用原則との照合

### 原則1: 探索シグナルの捜索への偏り禁止
提案者は「発見済み差異の重要度分類だから抵触しない」と主張しているが、完全には同意しない。

S4 は、何が重要差異かのシグナルをかなり具体的に固定している。
- return value
- exception type
- control flow
- untested branches
- cosmetic/whitespace/log-only

これにより、エージェントは「影響があるか」を広く考えるより、「この差異は上のどれに当てはまるか」を先に考えやすくなる。結果として、上記ラベルに乗りにくい差異が相対的に見落とされる危険がある。これは failed-approaches のいう「特定シグナルの捜索」への寄りと無縁ではない。

### 原則2: 探索ドリフト対策の自由度削減禁止
ここはより懸念が強い。

提案は表向き「新しい探索義務は課していない」と書いているが、実際には
- S4 分類を挟む
- MINOR/INERT なら skip justification を書く
という新しい早期判定経路を導入している。

これは探索の自由度を削るというより、「探索に入る前に省略可能性を判定する」ゲートであり、ドリフト抑制のつもりで exploration breadth を狭める類型に近い。

### 原則3: 自己監査チェックの増殖禁止
これは直接の自己監査追加ではないので、大きな抵触ではない。

ただし機能的には、新しい必須判断軸を structural triage に埋め込んでいる。場所が Step 5.5 でないだけで、実質的には pre-analysis gate である。したがって「形式的にはセーフ、実質的にはやや危うい」という評価になる。

### 総合
failed-approaches の3原則のうち、特に 1 と 2 に近い再演リスクがある。表現は違うが本質的には「探索前に重要/不要の判定を強める」方向であり、過去に避けるべきとされた傾向と無関係ではない。

## 5. 汎化性チェック

### 明示的ルール違反の有無
提案文中に、禁止対象である
- ベンチマークケース ID
- リポジトリ名
- テスト名
- ベンチマーク対象実装コード断片
は見当たらない。

含まれているのは主に
- SKILL.md 自身の行番号参照
- Guardrail #4 という内部参照
- 既存文言の自己引用
であり、Objective.md の監査基準上は原則セーフ。

したがって、明示的なルール違反としての overfitting 証拠はない。

### 暗黙のドメイン仮定の有無
ただし汎化性の懸念は残る。

1. test-path 中心の重要度定義
   - compare モード自体が test-modulo equivalence なので test path を見ること自体は妥当。
   - しかし S4 は「known test path」に乗るかどうかを早い段階で重要度の定義に使っており、test reachability がまだ不明な差異を軽く扱いやすい。

2. 影響タイプの狭さ
   - return value / exception / control flow への寄せは、多くのケースでは有効でも、汎用的な semantic effect を尽くしていない。

3. cosmetic/log-only の即時 INERT 化
   - logging 差分は多くの場合 benign だが、テストが log output や side effect を観測する環境では inert と断定できない。もちろん compare の relevant tests に閉じれば大半は無害だが、早期ラベルとしてはやや強すぎる。

結論として、「明示的 overfitting はない」が、「分類語彙の設計が少し狭く、汎用性 3 点満点ではなく 2 点寄り」という評価になる。

## 6. 全体の推論品質にどう効くと期待できるか

### 期待できる正の効果
- 差異を見つけた後に「それが何を変える差異なのか」を一度言語化させる点は良い。
- large patch で line-by-line に沈むのを避け、比較の焦点を立てる補助にはなりうる。
- 「どうでもよさそうに見える差異も、なぜ無害なのかを述べよ」という意識づけ自体は有益。

### 想定される負の効果
- 現行の Guardrail #4 / Compare checklist / Step 5.5 と役割が重複し、純増の改善幅が小さい。
- 一方で skip path だけは新たに増えるため、差異 dismissal を制度化してしまう。
- 特に large patch で S3 と結びつくと、「exhaustive trace はしない」+「MINOR/INERT は skip」で、結局 subtle but outcome-relevant diff を落としやすくなる。

### 監査結論
「差異の重要度を考える」という発想自体は前向きだが、as written の S4 は reasoning quality を安定的に上げるより、分析の早期打ち切りを正当化する方向に働く可能性が高い。改善効果は不確実で、回帰リスクの方が無視できない。

## 代替提案（この方向を残すなら）
この方向を活かすなら、skip authorization を消すのが安全。

例えば以下のような弱い形なら、研究コアと矛盾しにくい。
- 「semantic difference を見つけたら、tentative に likely-impact / unclear / likely-no-impact を書け」
- 「ただしこの分類だけを根拠に ANALYSIS を省略してはならない」
- 「no impact を結論するには現行どおり relevant test trace が必要」

これなら early focus aid にはなるが、dismissal gate にはなりにくい。

## 最終判断
承認: NO（理由: S4 が単なる観点追加ではなく、MINOR/INERT の早期スキップ経路を作っており、現行の anti-skip guardrail と緊張する。実効的には EQUIVALENT/NOT_EQUIVALENT の両方向に対称に効く変更ではなく、 subtle difference の早期除外を制度化する回帰リスクがあるため。）
