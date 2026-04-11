# Iter-96 監査ディスカッション

## 総評
提案の狙い自体は理解できる。`compare` モードで「中間挙動の差」を見つけた瞬間に NOT_EQUIVALENT へ飛躍する誤りを減らしたい、という問題設定は `docs/design.md` の「incomplete reasoning chains」と整合する。

ただし、今回の差分は「本当に新しい探索行動を生むか」という点で弱い。既存文言の

- trace through changed code to the assertion or exception

に対し、

- show how the condition evaluates

を追加するだけでは、実効的には「証明要求の厳格化」に近い。変更の名目上は対称でも、変更前との差分で見ると主に EQUIVALENT 側の誤判定抑制を狙った調整であり、`failed-approaches.md` の非対称化・厳格言い換え系の失敗原則にかなり近い。

結論から言うと、現時点では承認しない方がよい。

## 1. 既存研究との整合性

DuckDuckGo MCP の search は複数回試したが bot detection/0件で結果取得不能だった。そのため、同じ DuckDuckGo MCP の `fetch_content` で既知の公開URLを取得し、汎用原則との整合だけを確認した。

### 参考URLと要点

1. https://arxiv.org/abs/2603.01896
   - 要点: semi-formal reasoning の核は「explicit premises, trace execution paths, derive formal conclusions」であり、証拠付きの構造化推論によってケース飛ばしや unsupported claims を減らすことにある。
   - 本提案との関係: 「終端までトレースする」方向性自体はこの研究のコアと整合する。

2. https://en.wikipedia.org/wiki/Observational_equivalence
   - 要点: observational equivalence とは、観測可能な結果が同一であれば内部表現や途中の振る舞いが違っても区別できない、という考え方。
   - 本提案との関係: 「中間差分ではなく最終的な assertion/exception で判断すべき」という主張の一般原則は妥当。

3. https://en.wikipedia.org/wiki/Test_oracle
   - 要点: テスト oracle は入力に対する正しい出力/期待結果を与えるもので、design by contract では assertion が oracle に相当する。
   - 本提案との関係: テストの pass/fail を決める最終観測点として assertion 条件に着目する、という考え方は一般的に支持できる。

4. https://en.wikipedia.org/wiki/Counterexample-guided_abstraction_refinement
   - 要点: counterexample を見つけたら、それが本物の反例か偽反例かを吟味し、spurious なら抽象を精緻化する。
   - 本提案との関係: 「途中で見えた差分が本当にテスト結果差へ到達するかを確かめる」という発想は、反例の妥当性確認という意味で整合的。

### 整合性評価

研究・一般原則との方向性は概ね整合している。特に「内部差分ではなく観測可能なテスト結果まで追え」という主張は妥当。

ただし、研究が支持しているのは「推論構造の改善」であって、「既存の証明要求をさらに厳密な言い換えにすること」そのものではない。今回の提案は研究の目的には沿うが、研究が有効だと示したメカニズムそのものを強めているとは言い切れない。

## 2. Exploration Framework のカテゴリ選定は適切か

### 判定
部分的には適切だが、説明としてはやや弱い。

### 理由
提案者はカテゴリ E（表現・フォーマットの改善）を選んでいる。実際、変更形式だけ見れば 2 行の wording refinement なので E に分類するのは自然。

ただし、提案が主張している効能は単なる wording 改善ではない。実際に狙っているのは:

- どこまでトレースするかの終点を明確化する
- 中間差分から最終観測点へのジャンプを防ぐ
- テスト oracle の評価値まで到達させる

であり、これは本質的には「情報取得方法 / トレースの到達点の具体化」であって、カテゴリ B または F 的な中身を持つ。

したがって、
- 編集種別としては E
- 効能の理屈としては B/F 寄り

というのがより正確。

このズレ自体は致命的ではないが、カテゴリ E を理由に「低コストで高効果」と見積もっている点は楽観的すぎる。厳格化 wording はしばしば実効差分が非対称になるため、コストゼロではない。

## 3. EQUIVALENT 判定と NOT_EQUIVALENT 判定の両方への作用

ここが最重要の懸念点。

### 変更前の状態
既存 SKILL.md でも Compare の claim はすでに

- trace through changed code to the assertion or exception

を要求している。つまり「最終観測点まで行け」という骨格はもうある。

### 今回の実効的差分
新規差分は

- assertion/exception まで行くだけでなく
- assertion 条件がどう評価されるかまで明示せよ

という追加要求。

### EQUIVALENT への作用
ここには比較的直接効く可能性がある。

典型的には:
- Change A と Change B が途中で違う分岐や中間値を通る
- しかし最終 assertion の真偽は同じ
- それでもエージェントが「途中が違うから NOT_EQ」と飛躍する

という失敗を減らしたいわけで、その点では提案の狙いは明確。

### NOT_EQUIVALENT への作用
こちらへの純増効果はかなり限定的。

真に NOT_EQ のケースでは、既存文言でも assertion/exception まで辿れば十分に差分を立証できることが多い。今回の追加で得られるのは主に「差分証拠の詳述」であり、新しい検出能力ではない。

さらに、失敗が assertion 評価ではなく例外・副作用・到達不能・タイムアウト相当の振る舞いで現れるケースでは、「show how the condition evaluates」という wording はやや assertion 偏重に見える。既存文言は assertion と exception を並列に置いていたのに、新文言は assertion 条件の評価へ焦点を寄せるため、exception 主体の NOT_EQ ではむしろノイズになりうる。

### 実効差分の対称性評価
文面は両側 Claim C[N].1 / C[N].2 に同じ変更を入れるので「表面的には対称」。しかし `failed-approaches.md` 原則 #6 が言う通り、評価すべきは変更後の見た目ではなく変更前との差分。

差分ベースで見ると今回の変更は:
- EQUIVALENT 側: 「中間差分で止まるな」を追加で強く要求するので効果がある
- NOT_EQUIVALENT 側: 既存でも十分だった証明をより厳しく書かせるだけで、増分効果は小さい

つまり、実効的には EQUIVALENT 側に主に作用する。これは片方向バイアスのリスクがある。

## 4. failed-approaches.md の汎用原則との照合

提案文では非抵触と自己評価しているが、私はそうは見ない。

### 原則 #1 判定の非対称操作
明示的に「EQUIV を増やせ」とは書いていないが、実効差分としては EQUIVALENT 側の誤判定是正に主に効く。よって非対称化リスクはある。

### 原則 #6 「対称化」は既存制約との差分で評価せよ
今回もっとも直接当たる原則。Claim A/B 両方に同じ wording を追加しても、既存テンプレートがすでに assertion/exception までのトレースを要求している以上、新規差分は「どちらの判定に何を新しく強いるか」で見る必要がある。ここでは実質的に EQUIVALENT の立証補強に偏っている。

### 原則 #20 目標証拠の厳密な言い換えや対比句の追加
今回の差分はまさに既存表現の stricter rewording。提案者は「精緻化」と呼んでいるが、実体は証拠要求の厳格化である。failed-approaches はこのタイプが、意図に反して立証責任の引き上げとして働きうると警告している。

### 原則 #17 中間ノードの局所的な分析義務化
提案者は「アサーション条件は最終観測点だから中間ではない」と主張している。これは半分正しい。しかし wording が実際に指しているのは assertion 条件の評価という特定の内部説明形式であり、例外・副作用・他の観測境界を持つケースでは、その形式への固定が局所分析の義務化として働く可能性がある。

### 原則 #18/#26 物理的裏付け要求の強化
今回の提案は新しい `file:line` 要求を足してはいないので、ここは強くは当たらない。ただし「condition evaluates を示せ」は、各 claim ごとに追加説明コストを増やすため、探索予算を間接的に圧迫する懸念は残る。

### 総合
「完全な再演」とまでは言わないが、原則 #6 と #20 にかなり近い。過去失敗と本質的に無縁とは評価できない。

## 5. 汎化性チェック

### 明示的ルール違反の有無
違反あり。

1. 提案文タイトルに `Iter-96` という具体的数値 ID が含まれている。
   - これはベンチマーク対象 repo の識別子ではないが、「具体的な数値 ID を含めるな」という今回の監査条件には形式的に抵触する。

2. 提案文に 2 行の diff コード断片が含まれている。
   - 監査条件では「コード断片が含まれていれば指摘」とあるため、これは明確に指摘対象。
   - しかも内容がそのまま実装変更そのものなので、一般原則の説明というより具体的パッチ提示になっている。

### 暗黙のドメイン依存
ここにも軽い懸念がある。

提案は「assertion condition の評価」を最終観測点の代表として扱っているが、実際のテスト oracle は:
- 例外送出
- 戻り値比較
- state mutation の確認
- mock interaction
- snapshot/serialization 比較
- property-based な relation 検証

など多様。したがって「condition evaluates」を中心に据える表現は、xUnit 型の boolean assertion を暗黙の標準形にしており、ややテストパターン依存である。

既存文言の `assertion or exception` はまだ抽象度が高かったが、今回の wording は assertion の内部評価様式に踏み込むため、任意の言語・フレームワーク・テスト様式に対する汎化性を少し落とす。

## 6. 全体の推論品質への期待効果

### 期待できる改善
- 中間差分から早計に NOT_EQ を出す誤りの一部は減る可能性がある。
- 「最終観測点で何が真/偽になるか」を意識させる点は、compare モードの因果連鎖を少し長く保つ効果がありうる。

### 期待しにくい点
- 既存の失敗原因が「本当に assertion 直前で止まっていたこと」なのか、「そもそも relevant tests 選定や downstream handling の追跡が弱いこと」なのかが分離されていない。
- wording 追加だけで能動的な探索行動が増える保証はない。`failed-approaches.md` 原則 #8, #23 が警告する通り、書く内容が増えても調べる内容が増えるとは限らない。
- exception 主体・副作用主体の差分では、assertion condition を強調することでかえって reasoning format mismatch を起こす恐れがある。

### 私の評価
改善余地はあるが、効果の中心は「EQUIVALENT 側の誤爆抑制」であり、compare モード全体の推論品質をバランスよく底上げする提案としては弱い。よりよい方向は、assertion 固有の wording ではなく、「最終観測可能結果まで到達し、その結果が同一/相違である理由を書く」のように、assertion・exception・他の oracle 形式を抽象化して扱うことだと思う。

## 最終判定
承認: NO（理由: 変更の実効差分が EQUIVALENT 側に偏って作用する可能性が高く、`failed-approaches.md` の原則 #6・#20 に近い。さらに proposal 自体が具体的数値 ID と diff コード断片を含み、汎化性監査条件にも軽度だが抵触しているため。）
