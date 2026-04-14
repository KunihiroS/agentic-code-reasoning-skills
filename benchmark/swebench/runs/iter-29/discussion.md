# Iter-29 監査コメント

## 総評

提案の着眼点自体は妥当です。`compare` モードの Claim 記述は現在「changed code から assertion outcome までの trace」を要求していますが、`explain` モードには存在する `DATA FLOW ANALYSIS` 的な視点（どの値・型・副作用がどう変わるか）の明示はありません。したがって、「差分は見つけたが、その差分が何を変えるのかを曖昧なまま PASS/FAIL を言い切る」失敗を減らしたい、という問題設定は研究の方向性と整合しています。

ただし、提案文のまま承認するには懸念が残ります。とくに `EQUIVALENT` 判定側では、「何が変わるか」を必須で書かせる文言が、実際には観測可能な差がないケースでも差異の捏造圧力になりえます。結果として、この変更は `NOT_EQUIVALENT` 側には効きやすい一方で、`EQUIVALENT` 側には片方向のバイアスを生む可能性があります。

以下、観点ごとに述べます。

---

## 1. 既存研究との整合性

### 結論
概ね整合的です。特に「明示的なトレース」「データ依存の可視化」「反例ベースの確認」は、原論文および古典的な静的解析の考え方と矛盾しません。

### DuckDuckGo MCP で確認した URL と要点

1. https://arxiv.org/abs/2603.01896
   - `Agentic Code Reasoning` の要旨では、semi-formal reasoning の本質を「explicit premises」「execution path tracing」「formal conclusions」に置いています。
   - これは README の要約（`README.md:49-57`）および design 文書の要約（`docs/design.md:33-40`）とも一致しています。
   - 提案は compare に「より具体的な意味論の記述」を足すだけで、前提・トレース・結論というコア構造を壊していません。

2. https://en.wikipedia.org/wiki/Data-flow_analysis
   - データフロー解析は「program 中の各点で変数にどの値が到達しうるか」を追う技法であり、定義・変更・使用の追跡が中心です。
   - 提案が compare の Claim に「value/type/side-effect の具体的変化」を要求する発想は、この一般的な静的解析の考え方と整合しています。
   - 特に「差分の存在」ではなく「何が伝播するか」を問う点は妥当です。

3. https://en.wikipedia.org/wiki/Program_slicing
   - プログラムスライシングは、ある観測点の値に影響する文だけを依存関係から追う発想です。
   - compare で assertion outcome に届く差分だけを見たい、という問題設定は slicing 的な観点と相性がよく、提案の狙いは汎用原理として理解できます。

### 補足
DuckDuckGo の search API 自体は今回のクエリで結果が返らず、同じ MCP の fetch_content で上記の正規 URL を確認しました。少なくとも研究方向の妥当性確認としては十分です。

---

## 2. Exploration Framework のカテゴリ選定は適切か

### 結論
カテゴリ F の選定は妥当です。ただし、見た目としては E（表現・フォーマット改善）にも見えるため、その点は区別して整理した方がよいです。

### 理由
- 提案の核は単なる wording tweak ではなく、`explain` モードにある `DATA FLOW ANALYSIS` の発想を `compare` に移植することです（`proposal.md:12-29`）。
- 実際、`SKILL.md` では `explain` にだけ `DATA FLOW ANALYSIS` があり（`SKILL.md:347-352`）、`compare` の Claim には存在しません（`SKILL.md:205-213`）。
- design 文書も、Code Question Answering 由来のテンプレート特徴として「Function trace table + data flow tracking」を明示しています（`docs/design.md:15-18`）。

したがって、「論文の別モードの未活用アイデアを compare に応用する」という意味で F に当たります。

### 但し書き
- 実装の形は 2 行の wording 変更なので、表面的にはカテゴリ E 的です。
- しかし、改善メカニズムの出所が原論文 Appendix D にある以上、主カテゴリを F と見る判断は自然です。

---

## 3. EQUIVALENT / NOT_EQUIVALENT の両方にどう作用するか

### 結論
この変更は両方向に同程度には作用しません。主に `NOT_EQUIVALENT` 側を押し上げる変更であり、`EQUIVALENT` 側には改善もありうるが、同時に誤差分検出を増やす危険があります。

### NOT_EQUIVALENT 側への作用
ここは比較的明確にプラスです。

- 現在の compare は「changed code から assertion outcome まで trace せよ」とは言っていますが、差分の意味論を一言で固定する欄がありません（`SKILL.md:205-213`）。
- そのため、「コードが違うのは見えたが、何が変わるのかを曖昧にしたまま『たぶん同じ結果』で済ませる」失敗が起きやすい、という提案の問題意識はもっともです。
- `docs/design.md:21-28` の failure pattern には `Subtle difference dismissal` と `Incomplete reasoning chains` があり、提案は前者にはかなり直接に効きます。

要するに、潜在的な差分を assertion まで届く意味論として言語化させることで、`NOT_EQUIVALENT` の見落としを減らす期待はあります。

### EQUIVALENT 側への作用
ここは要注意です。

提案は Claim の because 節に
- value
- type
- side-effect
のどれが具体的に変わるかを書かせます（`proposal.md:57-64`）。

しかし `EQUIVALENT modulo tests` では、正しい説明がしばしば
- 変化はあるが assertion に届かない
- 実行パス上では観測可能な値差がない
- 下流で吸収されるので test outcome は同じ
であるはずです。

このとき「何が変わるか」を必須で求める文言は、モデルに対して「何か変化を書かなければならない」という圧力をかけます。すると、
- 実際には観測差がないのに差を誇張する
- 型や副作用の差を無理に捏造する
- “difference exists, therefore likely NOT_EQUIVALENT” へ寄りやすくなる
という片方向バイアスが発生しえます。

### 実効的差分の分析
変更前:
- 「trace from changed code to test assertion outcome」を要求
- 差分の意味論は暗黙

変更後:
- 上記に加えて「value/type/side-effect の具体的変化」を要求
- 差分の意味論を明示化

この差分は、実際には「差分がある場合の説明力」を上げる変更です。
一方で、「差分が test outcome に現れないこと」を説明するテンプレートにはなっていません。

したがって、現状の wording では両方向対称ではありません。

### 監査上の判断
「EQUIVALENT と NOT_EQUIVALENT の双方に改善方向に働く」という提案文の主張（`proposal.md:87-91`）は、やや強すぎます。より正確には、
- `NOT_EQUIVALENT` 側には直接的に効きやすい
- `EQUIVALENT` 側には、ゼロ変化や吸収済み変化を明示的に許す wording がない限り、逆効果の余地がある
です。

---

## 4. failed-approaches.md の汎用原則との照合

### 結論
完全な再演ではありませんが、原則1に部分的に接近しています。提案文の自己評価ほど「完全に非抵触」とは言い切れません。

### 原則1: 証拠種類の事前固定を避ける
`failed-approaches.md:8-10` は、「次の探索で探すべき証拠の種類をテンプレートで事前固定しすぎる変更は避ける」と言っています。

今回の提案は、探索ステップ自体は増やしていません。ここは提案文の主張どおりです。

ただし、Claim の必須記述として
- value
- type
- side-effect
を固定することは、実質的には「証拠の見方」をかなり具体的に先指定しています。
つまり、探索順や探索入口は固定していなくても、観察すべきシグナルの型は固定している、ということです。

したがって、これは原則1と無関係ではありません。危険度は高くないが、同じ方向を少し踏んでいます。

### 原則2: 探索自由度を削りすぎない
`failed-approaches.md:11-14`

この提案は読み始める順序や境界確定順序を縛らないため、原則2とは大きくは衝突しません。ここは概ね非抵触です。

### 原則3: 局所仮説更新を即時の前提修正義務に結びつけすぎない
`failed-approaches.md:15-17`

今回の変更は Step 3 や premise 管理を触っていないため、非抵触です。

### 原則4: 結論直前の自己監査に必須メタ判断を増やしすぎない
`failed-approaches.md:18-20`

Pre-conclusion self-check をいじっていないので、ここも非抵触です。

### 総合評価
- 「過去失敗の完全再演」ではない
- ただし「証拠種類の事前固定」という失敗方向に少し寄っている

つまり、提案文の「4原則すべてと非抵触」は言い過ぎです。より妥当な表現は「原則2〜4とは概ね非抵触、原則1には軽度の接近リスクあり」です。

---

## 5. 汎化性チェック

### ルール違反の有無
重大な違反は見当たりません。

### 明示的に確認した点
- 具体的なベンチマーク case ID: なし
- 対象リポジトリ名: なし
- 特定のテスト名: なし
- ベンチマーク対象の実コード断片: なし

提案に含まれるコードブロックは `SKILL.md` の自己引用であり、Objective の R1 の減点対象外ルールにも合致します（`Objective.md:202-212`）。この点は問題ありません。

### ただし残る汎化性上の懸念
提案文の必須語彙が
- value
- type
- side-effect
に固定されている点は、やや言語・パラダイム依存です。

例:
- 動的型付け言語では「type」の重要性が低いケースがある
- 宣言的設定やテンプレートでは「side-effect」が主軸でないことがある
- 純粋関数型の比較では「副作用」より「返り値・例外・観測可能状態」の方が自然

そのため、完全に一般化された wording にするなら、
- value / return / exception / observable state / side-effect
のように「観測可能な意味論の変化」へ寄せた表現の方がよいです。

### この観点での監査判断
- ベンチマーク固有化はしていない
- ただし wording はやや特定のコード形態を想起させる

R1 的には 2.5〜3 に近いが、完璧ではありません。

---

## 6. 全体の推論品質がどう向上すると期待できるか

### 期待できる改善
1. 差分の意味論を assertion-level の結果へ接続しやすくなる
   - いまの compare は trace 要求はあるが、「何が変わるか」の粒度が曖昧です。
   - そのため、構文差分から outcome への橋が弱くなりやすい。
   - 提案はこの橋を少し太くします。

2. subtle difference dismissal の抑制
   - `docs/design.md:21-28` の failure pattern にかなり直接に対応しています。
   - 特に戻り値の具体値、例外、可変状態、外部可視な副作用がズレるケースには有効そうです。

3. compare モードの説明責任が上がる
   - 「same/different」と言うだけでなく、その判定根拠として具体的なプログラム状態の差を言わせるのは監査可能性を上げます。

### 限界
1. gain は増分的であり、構造的な改善ではない
   - 既存 compare もすでに `trace from changed code to test assertion outcome` を要求しています（`SKILL.md:209-212`）。
   - したがって今回の改善は、ゼロから新能力を足すのではなく、既存 trace を少し意味論寄りにするものです。

2. downstream handling を保証する文言ではない
   - 提案は「何が変わるか」を書かせるが、「その変化が下流で吸収されるか」を明示させる wording にはなっていません。
   - そのため `Incomplete reasoning chains` への効き方は、提案文が主張するほど強くはありません。

3. EQUIVALENT 側での誤差分生成リスク
   - 前節の通り、ここを抑えないと全体品質の改善が片肺になります。

---

## 総合判断

### 良い点
- 原論文の未活用アイデアを compare に移すという発想は筋が良い
- 微小変更で、研究コアを壊さない
- `NOT_EQUIVALENT` の見落とし防止にはかなり自然に効く

### 懸念点
- 「何が変わるか」を必須にする wording が、`EQUIVALENT` 側で差異の捏造圧力になる
- 原則1の「証拠種類の事前固定を避ける」に部分的に接近している
- value/type/side-effect という三分類が、汎用原則としてはやや狭い

### 承認可否
承認: NO（理由: 提案の方向性は妥当だが、現行 wording のままだと `NOT_EQUIVALENT` 側に主に作用する片方向バイアスがあり、`EQUIVALENT` 側で誤差分検出を増やすリスクがあるため。さらに、証拠種類を `value/type/side-effect` に固定する点は failed-approaches の原則1に軽度に接近している。承認するなら、少なくとも「tested path 上で何が変わるか、または変化が assertion に到達しないことを明示せよ」のように、ゼロ変化・吸収済み変化を正解として書ける wording に修正すべき。）
