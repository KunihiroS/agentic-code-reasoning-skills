# Iter-40 監査ディスカッション

## 総評

提案は非常に小さい差分で、compare モードの `NO COUNTEREXAMPLE EXISTS` における `Searched for:` の粒度を具体化するものです。方向性としては「EQUIVALENT を言う前に、実際の assertion や condition を見よ」という促しであり、Guardrail #4 の補強意図は理解できます。

ただし、監査観点では 2 つの懸念が強いです。

1. 効果が実質的に `EQUIVALENT` 側にしか作用せず、compare タスク全体の対称性改善ではない
2. `failed-approaches.md` が禁じている「探索で探す証拠の種類の事前固定」にかなり近い

そのため、私は現時点では承認に慎重で、結論は NO です。

---

## 1. 既存研究との整合性

### 参照 1
- URL: https://arxiv.org/abs/2603.01896
- 要点:
  - Semi-formal reasoning の本質は、明示的 premises、execution path tracing、formal conclusion という「証拠に基づく構造化推論」にある。
  - 論文要約では「templates act as a certificate: the agent cannot skip cases or make unsupported claims」とされており、テンプレート具体化そのものは研究コアと整合する。
  - 一方で、論文のコアは「特定の証拠型を探せ」と狭く固定することではなく、証拠を伴う tracing を要求することにある。

### 参照 2
- URL: https://www.infoworld.com/article/4153054/meta-shows-structured-prompts-can-make-llms-more-reliable-for-code-review.html
- 要点:
  - 記事は semi-formal reasoning を「explicitly state assumptions and trace execution paths before deriving a conclusion」と要約している。
  - ここでも価値の中心は tracing と justification であり、検索対象を assertion に寄せること自体が主眼ではない。
  - また、structured reasoning には token/latency overhead の tradeoff があると指摘しており、細かな追加指示は効果対象が狭いなら慎重であるべき。

### 参照 3
- URL: https://link.springer.com/article/10.1007/s10009-025-00794-1
- 要点:
  - Assertions は program behavior を確認するための重要な自動化手段であり、ソフトウェアテスト研究でも中心的テーマの 1 つである。
  - よって、assertion text や assertion condition に着目させる発想自体は一般論として妥当。
  - ただしこの知見が直接支持するのは「assertion は重要な観察対象である」という点までであり、「テンプレートで assertion を明示列挙すると全体性能が上がる」までは言えない。

### 小結
研究との整合性は部分的にはあります。特に「根拠なき EQUIVALENT 宣言を減らす」という意図は、README.md と docs/design.md が強調する certificate-based reasoning と矛盾しません。

しかし、研究コアが求めるのは tracing の厳密化であって、探索シグナルの型を増やすことではありません。したがって、整合性は「弱く肯定」、強い裏付けまではありません。

---

## 2. Exploration Framework のカテゴリ選定は適切か

### 提案者の主張
proposal.md ではこの変更を
- カテゴリ E. 表現・フォーマットを改善する
- メカニズム: 曖昧文言の具体化
と分類しています。

### 監査所見
この分類は形式上は妥当です。実際、変更対象は SKILL.md compare テンプレートの 1 行の文言であり、手順追加でも順序変更でもありません。したがって、見た目の diff は明らかにカテゴリ E です。

ただし、機能面ではカテゴリ B. 情報の取得方法を改善する との境界上にあります。なぜなら、今回の変更は単なる言い換えではなく、「何を search すべきか」の証拠種別を 1 つ増やしており、探索行動そのものを誘導するからです。

つまり:
- 表層分類: E でよい
- 実効メカニズム: B 的でもある

この点は重要です。failed-approaches.md が警戒しているのは主に探索自由度を狭めるタイプの変更であり、見かけ上 E でも、実効として B の「証拠種別の事前固定」に寄るなら注意が必要です。

### 小結
カテゴリ E というラベル自体は不自然ではありません。しかし、監査上は「実際には exploration steering を伴う E」と見なすべきで、単なる harmless な wording tweak として扱うのは危険です。

---

## 3. EQUIVALENT 判定と NOT_EQUIVALENT 判定の両方への作用

## 実効的差分
変更箇所は SKILL.md compare モードの以下だけです。

変更前:
- `Searched for: [specific pattern — test name, code path, or input type]`

変更後:
- `Searched for: [specific pattern — assertion text or condition, test name, code path, or input type]`

この行は `NO COUNTEREXAMPLE EXISTS (required if claiming EQUIVALENT)` ブロックの内部にあります。SKILL.md 234-240 行が示す通り、このブロックは EQUIVALENT を主張する場合にのみ使われます。

### EQUIVALENT 側への作用
直接作用します。期待できる効果は以下です。

- 抽象的な `Searched for: any behavioral difference` のような記入を減らす
- テスト oracle としての assertion 条件に目を向けさせる
- subtle difference が assertion 差分として顕在化するケースで、偽陽性 EQUIVALENT を減らす

つまり、proposal.md の主張どおり、主作用は「EQUIVALENT の過剰宣言抑制」です。

### NOT_EQUIVALENT 側への作用
直接作用しません。NOT_EQUIVALENT では compare テンプレートの `COUNTEREXAMPLE` ブロックを使い、必要なのは
- diverging assertion
- A/B での PASS/FAIL の差
です。今回の変更行はそこに入っていません。

したがって、NOT_EQUIVALENT 側に対する改善効果は原理的にかなり限定的です。ありうるのはせいぜい間接効果です。

- モデルが compare 全体をより assertion-centered に理解し、差分を見る際に assertion を意識するようになる
- ただしそれはテンプレート上の明示要求ではなく、副次的学習に期待しているだけ

### 片方向性の確認
はい、この変更は実質的に片方向です。

- 直接効果: EQUIVALENT のみ
- 間接効果: NOT_EQUIVALENT にもゼロではないが、弱く不確実

### 片方向変更としての懸念
ベンチマーク全体で compare を改善するなら、理想的には
- EQUIVALENT 側の false positive を減らしつつ
- NOT_EQUIVALENT 側の検出力も維持または改善
であるべきです。

しかし今回は、NOT_EQUIVALENT 側には触れず、EQUIVALENT 側だけに認知負荷を足します。そのため、効果が出るとしても局所的です。さらに、assertion text を先頭に置いたことで、モデルが「まず assertion を探す」方向に寄り、構造差分や call path 差分の初期検出が弱まるリスクもあります。

要するに、この変更は compare モードの左右対称性を改善していません。むしろ「EQUIVALENT を言う時だけ、見よ」という片肺強化です。

---

## 4. failed-approaches.md の汎用原則との照合

### 原則 1: 探索で探すべき証拠の種類をテンプレートで事前固定しすぎない
failed-approaches.md 8-9 行:
- 「次の探索で探すべき証拠の種類をテンプレートで事前固定しすぎる変更は避ける」

今回の提案は、まさに `Searched for:` の候補に `assertion text or condition` を追加するものです。提案者は「追加列挙であり、既存選択肢は残るから抵触しない」と述べていますが、監査上はそれだけでは十分ではありません。

なぜなら、LLM は列挙された語の先頭や具体度の高い語に強く引っ張られやすく、しかも今回追加されるのは test name / code path / input type よりも意味的に強いシグナルだからです。結果として、自由度は形式上維持されても、実効上は assertion-centric な探索に寄る可能性があります。

よって、「本質的に同じ失敗の再演ではない」とは言い切れません。むしろかなり近縁です。

### 原則 2: 探索ドリフト対策を追加する際は、探索の自由度を削りすぎない
failed-approaches.md 11-13 行は、局所的具体化が探索幅を狭めうると警告しています。

今回の変更は 1 行で小規模ですが、まさに局所的具体化です。しかも compare では
- test name
- code path
- input type
- assertion text/condition
という複数粒度を扱う必要がある中で、assertion を追加することは exploration bandwidth の再配分を起こします。

それ自体は悪ではありませんが、「どの未検出失敗を埋める確実な証拠があるか」が proposal.md だけではまだ弱いです。

### 原則 3, 4
- 前提修正義務の強化ではないので、原則 3 への抵触は薄い
- 新しい必須フィールドや新規判断ゲートを増やしてはいないので、原則 4 への抵触も薄い

### 小結
最重要の原則 1 には近いです。提案者の自己評価より厳しく見るべきです。私は「文面を変えただけなのでセーフ」ではなく、「探索シグナルの型追加という意味で、failed approach の危険域に踏み込んでいる」と判断します。

---

## 5. 汎化性チェック

### 明示的なルール違反の有無
proposal.md を確認した限り、以下のような禁止要素は見当たりません。

- 具体的な数値 ID
- 特定リポジトリ名
- 特定テスト名
- ベンチマーク対象コード断片
- 特定関数名やクラス名

含まれているのは
- `Searched for:` など SKILL.md 自身の文言引用
- `Guardrail #4` という内部一般概念
- 抽象例としての `any behavioral difference`
程度で、これは Objective.md の R1 で明示的に減点対象外に近い扱いです。

### 暗黙のドメイン依存性
一方で、暗黙の偏りはあります。

`assertion text or condition` は主に
- テストコード内に assertion が明示的に書かれるスタイル
- assertion 文言や条件式が読みやすく残るテスト文化
を想定しています。

これは Python / xUnit 系にはよく合いますが、以下では相対的に弱くなります。
- snapshot テスト中心
- golden file 比較中心
- property-based testing
- fuzz / metamorphic testing
- 明示 assert より helper abstraction が深いテストコード
- テスト名と fixture 構成の方が oracle を表しているケース

つまり、提案は露骨な overfitting ではないが、「assertion が主要 oracle である」文化をやや前提化しています。

### 小結
明示的ルール違反はありません。R1 的に即失格ではないです。ただし、assertion-centered な暗黙バイアスはあり、完全に言語・テスト様式中立とは言いにくいです。

---

## 6. 全体の推論品質がどう向上すると期待できるか

### 見込める改善
限定的には改善が見込めます。

- EQUIVALENT 主張時の refutation check が少し具体的になる
- test oracle を assertion/condition レベルで確認する習慣が強まる
- 「広い概念だけ書いて検索したことにする」形式的充填を減らす可能性がある

特に、README.md 47-57 行および docs/design.md 33-55 行が強調する「certificate の anti-skip 機能」を、EQUIVALENT 側の最後の反証確認で少しだけ補強する効果はありえます。

### 限界
ただし、全体の推論品質向上としては限定的です。

- compare 全体ではなく EQUIVALENT 側に偏った強化
- assertion に寄りすぎると code path / input type / structural gap の探索を相対的に弱めうる
- 「何を search したか」の記述品質は上がっても、実際の tracing 品質が上がる保証はない

つまり、改善が起きるとしても
- tracing 自体の質を上げる変更ではなく
- trace 後の自己記述を少し良くする変更
に留まる可能性があります。

---

## 結論

### 判断
私はこの提案を現時点では承認しません。

### 理由の要約
1. 変更の直接作用先が `NO COUNTEREXAMPLE EXISTS` だけであり、実質的に EQUIVALENT 側への片方向修正である
2. failed-approaches.md の最重要警戒事項である「証拠種類の事前固定」にかなり近い
3. assertion は重要な観点だが、研究的裏付けは「assertion は重要」までであり、「テンプレートで assertion を追加列挙すると compare の汎用性能が上がる」までは支持されていない
4. 形式上は小差分だが、実効上は探索バイアスを変えるため、 harmless な wording tweak より重い

### 条件付きで再提案するなら
もしこの方向を続けるなら、次の条件が必要です。

- EQUIVALENT 側だけでなく compare 全体の対称性を保つこと
- assertion を特権化するのではなく、「test oracle / observed check」など、より汎用でテスト文化中立な表現にすること
- failed-approaches.md の原則 1 に対して、なぜこれは事前固定ではなく探索補助に留まるのかをより厳密に説明すること

承認: NO（理由: EQUIVALENT 側への片方向修正に留まり、かつ failed-approaches.md が禁じる「探索証拠種別の事前固定」に本質的に近いため）
