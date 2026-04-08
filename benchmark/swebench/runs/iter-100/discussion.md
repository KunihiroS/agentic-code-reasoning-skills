# Iter-100 Discussion

## 総評

提案の狙い自体は理解できる。`compare` テンプレートの per-test Claim で、単に「差分がある」と述べるだけでなく、変更点からテスト観測点まで因果連鎖を追わせたい、という問題設定は妥当である。特に SKILL.md と design 文書が重視している「observational equivalence = 既存テストの pass/fail 一致」という定義に照らすと、テストの観測境界まで到達しない不完全トレースを減らしたい、という意図は研究コアと整合している。

ただし、今回の案は「探索行動の追加」ではなく、既存プレースホルダーの文言をより厳格に言い換える変更である。このタイプの変更は、過去失敗原則にかなり近い危険を含む。とくに「より厳格・より排他的な言い換え」が、実質的には立証責任の引き上げとして作用する可能性が高い。

結論として、私は現時点では承認しない。

---

## 1. 既存研究との整合性

注: DuckDuckGo MCP の `search` は今回のセッションでは結果を返さなかったため、同じ DuckDuckGo MCP の `fetch_content` を使って既知の公開 URL を取得した。

### 参考1: Agentic Code Reasoning
- URL: https://arxiv.org/abs/2603.01896
- 要点:
  - semi-formal reasoning は、明示的 premises、execution path tracing、formal conclusion を要求することで、ケース飛ばしや unsupported claim を防ぐ「certificate」として機能するとされる。
  - 本提案の「change point から assertion outcome まで追え」は、この論文の tracing 重視と方向性は一致する。
  - ただし論文の強みは、単なる厳格表現ではなく、構造化された探索・反証・per-item iteration 全体にある。したがって、文言強化だけで同等の改善が出るとは限らない。

### 参考2: Program Slicing
- URL: https://en.wikipedia.org/wiki/Program_slicing
- 要点:
  - program slicing は、ある観測点の値に影響する文を、その観測点から依存関係を辿って特定する考え方である。
  - 提案の「change point → ... → assertion outcome」は、変更と観測点を因果的に接続したいという意味で、impact/slicing 的な発想と整合する。
  - 一方で slicing は通常、観測基準を明確にしつつも、それを計算・探索の対象として扱う。今回の提案は探索戦略の明示ではなく、出力文言の強化に留まるため、理論整合性はあるが実装力は弱い。

### 参考3: Test Oracle
- URL: https://en.wikipedia.org/wiki/Test_oracle
- 要点:
  - テストは、入力に対する期待結果を oracle と比較する行為であり、最終的な観測点は assertion / expected-vs-actual の比較結果である。
  - よって「assertion outcome」を意識させること自体は、テスト意味論に合っている。
  - ただし実務的には、観測点の明示だけでは不十分で、そこへどう到達するかの検証手順が必要になる。

### 参考4: Change Impact Analysis
- URL: https://en.wikipedia.org/wiki/Change_impact_analysis
- 要点:
  - change impact analysis は、変更の潜在的帰結を依存関係や traceability に基づいて評価する。
  - 提案の「変更点からアサーション結果まで影響を追え」という考えは generic に妥当。
  - しかし impact analysis も、単なる記述欄の変更ではなく dependency/tracing を実際に行うことが本体である。そこが今回の懸念点。

### 参考5: Chain-of-Thought Prompting
- URL: https://arxiv.org/abs/2201.11903
- 要点:
  - intermediate reasoning steps の明示は一般に reasoning 精度を上げうる。
  - したがって、曖昧な `trace through code` より、より方向づけされた trace 指示の方が有利である可能性はある。
  - ただし CoT 系の知見も、「中間ステップを増やせば常に良い」ではない。悪い phrasing はアンカリングや過剰拘束を招く。

### 小結
提案の基本思想は、研究的にはかなり自然である。特に ACR 論文、program slicing、test oracle、change impact analysis の観点から、「差分から観測点まで追う」は筋が良い。

ただし、研究整合性があることと、この 2 行差分が実効的に効くことは別問題である。今回の案は前者は満たすが、後者には強い不確実性が残る。

---

## 2. Exploration Framework のカテゴリ選定は適切か

### 判定
- 主カテゴリ E: 妥当
- 副次的に F と関連: ある程度妥当

### 理由
今回の変更は、本質的には新しい探索ステップや新フィールドの追加ではなく、既存テンプレート文言の精緻化である。したがって第一義的には E「表現・フォーマットを改善する」に属する。

同時に、SKILL.md / docs/design.md が強調する観測的等価性の考え方を compare テンプレートの wording により忠実に反映する、という意味では F「原論文の未活用アイデアを導入する」との関連づけも理解できる。

ただし F としては弱い。論文コアの新規導入というより、既存コアの言い換えに近い。分類としては「E が主、F は補助説明」が適切で、proposal の書き方は概ね妥当である。

---

## 3. EQUIVALENT / NOT_EQUIVALENT の両方への作用分析

## 3.1 変更前との差分
変更前:
- `because [trace through code — cite file:line]`

変更後:
- `because [trace: change point → ... → assertion outcome — cite file:line]`

差分として実際に増えるのは次の 2 点だけである。
1. 起点として `change point` が明示される
2. 終点として `assertion outcome` が明示される

つまり、これは新しい分析ステップではなく、既存 Claim の証拠欄に「起点と終点を指定する」変更である。

## 3.2 NOT_EQUIVALENT への作用
NOT_EQUIVALENT では、「差分を見つけた」時点で早めに結論へ飛びやすい失敗がありうる。この変更は、差分の存在だけでなく、その差分が fail/pass の違いとして assertion まで届くことを書かせるので、局所差分からの短絡は抑制しうる。

この点ではプラスに作用する可能性がある。

ただし、SKILL.md には既に:
- Guardrail 2: test outcomes を tracing せよ
- Guardrail 4: subtle difference を見つけたら relevant test を trace せよ
- COUNTEREXAMPLE: divergence が assertion にどう効くか書け

がある。したがって今回の追加は、NOT_EQUIVALENT の論理要件を新設するというより、既存要件を per-test Claim 段階で再掲する効果に近い。増分効果はあるとしても限定的である。

## 3.3 EQUIVALENT への作用
EQUIVALENT では、「見つかった差分が test outcome まで届かない」ことを示す必要があるため、assertion outcome までの tracing を意識させることは理屈の上では有益である。

ただし EQUIVALENT 側には変更前から既に `NO COUNTEREXAMPLE EXISTS` があり、そこでは:
- どの test / assertion が違う結果になるはずか
- そのコード差分がどう違いを生むか

をかなり具体的に考えさせている。よって、EQUIVALENT 側に対する純増分は特に小さい。

## 3.4 真に両方向か、それとも片方向寄りか
proposal では「両方向に効く」と述べているが、実効的には完全対称ではない。

理由は 3 つある。

1. 既存の formal sections がすでに assertion レベルを要求している
   - EQUIVALENT には `NO COUNTEREXAMPLE EXISTS`
   - NOT_EQUIVALENT には `COUNTEREXAMPLE`
   したがって今回の差分は、最終結論より前の per-test Claim を少し厳密化するだけである。

2. pass-to-pass tests の Claim 形式は未変更
   - compare テンプレートでは pass-to-pass tests も relevant である。
   - しかし proposal 自身が認める通り、そこは `behavior is [description]` のままである。
   - そのため、回帰や微妙な差異が pass-to-pass 側に現れるケースでは、この改善は効かない。

3. `change point` 明示は、差分起点への注意を強める
   - これは主に「差分を見たら影響を追え」という方向へ効く。
   - そのため、既に差分を見つけた後の NOT_EQ 候補の検証には比較的自然に効くが、EQUIVALENT 側の「差分はあるが outcome は同じ」を広く検討する場面では、むしろ差分ノードへのアンカリングを強める恐れもある。

### 小結
「片方向にしか作用しない」とまでは言わないが、「完全に両方向へ均等に効く」とも言えない。実効差分は、主に fail-to-pass の per-test Claim における差分→観測点連結の再強調であり、既存構造との重複が大きい。全体としては、限定的かつやや NOT_EQ 寄りの効き方になる可能性が高い。

---

## 4. failed-approaches.md の汎用原則との照合

proposal は多くの原則に「抵触なし」としているが、そこはやや楽観的すぎる。

### 抵触懸念が弱いもの
- #1 判定の非対称操作
  - 文面自体は A/B 両側に同じ変更を入れるので、表面的な非対称性はない。
- #3 探索量の削減
  - 探索を減らす意図ではない。
- #7 分析前の中間ラベル生成
  - ラベル付け導入ではない。
- #8 受動的な記録フィールド追加
  - 新しいフィールド追加ではない。

### 抵触懸念が強いもの

#### 原則 #20
- 原則: 「目標証拠の厳密な言い換えや対比句の追加は、実質的な立証責任の引き上げとして作用する」
- 今回の変更との関係:
  - まさに `trace through code` を `change point → ... → assertion outcome` に厳格化している。
  - proposal はこれを「明確化」と呼んでいるが、実働上は「そこまで書け」という要求水準の引き上げである。
  - したがって、原則 #20 にかなり近い。

#### 原則 #22
- 原則: 抽象原則の中で具体物を例示すると、物理的探索目標として過剰適応される。
- 今回の変更との関係:
  - `assertion outcome` は `assertion` そのものよりは抽象的で、proposal の擁護には一定の説得力がある。
  - しかし compare task では agent がしばしば「どの assertion か」を特定しに行く行動を取りやすく、この phrasing がテスト本文の assertion 探索を過度に目的化するリスクは残る。
  - 原則 #22 に完全抵触とは言わないが、無視できるほど安全でもない。

#### 原則 #18 / #19 / #26
- 原則群: 中間ステップや特定証拠カテゴリに対する過剰な物理的裏付け要求は探索予算を枯渇させる。
- 今回の変更との関係:
  - 各 per-test Claim で「変更点から assertion outcome まで」を要求すると、複雑なフレームワークでは end-to-end に近い追跡を毎回書こうとする可能性がある。
  - proposal は `...` により固定長でないから safe と言うが、問題は hop 数ではなく、各 Claim に課される追跡の到達要求そのものである。
  - よって #19/#26 系のリスクは現実にある。

#### 原則 #2 / #23
- 原則群: 出力側・ソフトフレーミングの変更だけでは推論行動が改善しない。
- 今回の変更との関係:
  - これは新しい探索ステップではなく、最終的に Claim 欄へ何を書くかの指定である。
  - そのため、探索行動を本当に変えるかは不明。もっともらしい矢印列を作文するだけの危険もある。

### 小結
proposal の自己評価よりも、failed-approaches との距離は近い。特に #20 への近さが大きい。私は「本質が同じ過去失敗の再演と断定まではしない」が、「その危険が高い案」と評価する。

---

## 5. 汎化性チェック

### 5.1 禁止された具体物の混入チェック
確認した範囲では、proposal に以下の禁止事項は見当たらない。
- ベンチマークケース ID
- 特定リポジトリ名
- 特定テスト名
- ベンチマーク対象コード断片

含まれているのは主に:
- SKILL.md 自身のテンプレート文言引用
- `Guardrail #4` などの内部一般概念
- 一般概念としての `assertion outcome`, `change point`

これは Objective の R1 の「減点対象外」に概ね収まる。したがって、実装者のルール違反とは言わない。

### 5.2 暗黙のドメイン仮定
ここには軽微な懸念がある。

- `assertion outcome` という語は、xUnit 的な明示 assertion を持つテスト文化にはよく適合する。
- しかし観測点が snapshot diff、golden file、property-based failure、exception expectation、HTTP status + body contract などで表現されるケースでは、agent が「assert 文を探す」方向へ寄る恐れがある。
- もっと抽象的に `observable test outcome` や `test-observed result` とした方が、言語・フレームワーク非依存性は高い。

したがって、明示的な overfitting ではないが、用語選択は若干テストスタイル依存である。

---

## 6. 全体の推論品質がどう向上すると期待できるか

期待できる改善はあるが、幅は限定的だと見る。

### 改善が期待できる点
- 差分発見だけで結論へ飛ぶ短絡を抑える
- test outcome を観測境界として意識させる
- compare モードでの「何のために trace するのか」を少し明瞭にする

### 改善が限定的な理由
- 既存の Guardrails / Counterexample sections と重複が大きい
- pass-to-pass 側の分析形式は未変更
- 新しい探索行動を追加していないので、記述の厳格化に留まる
- 過去失敗原則 #20 系の「厳格化による立証責任増大」を再発する恐れがある

### 期待値の総合判断
- 局所的には改善余地あり
- ただしベンチマーク全体の正答率を押し上げるだけの安定したレバーかは疑わしい
- 回帰リスクは小〜中程度だが、改善幅も小さく、失敗原則との衝突リスクが無視できない

---

## 監査結論

### 良い点
- 研究コアとの方向整合はある
- 変更規模が小さく、過度な複雑化ではない
- ベンチマーク固有識別子を含まず、露骨な overfitting ではない

### 問題点
- 実質は「より厳格な言い換え」であり、failed-approaches 原則 #20 に近い
- 探索行動ではなく記述要求の強化であり、実効改善が不透明
- pass-to-pass 側を変更していないため、compare 全体への効き方が部分的
- `assertion outcome` がややテストスタイル依存で、物理的探索目標化のリスクを残す

承認: NO（理由: 研究方向としては妥当だが、実装差分は wording の厳格化に留まり、failed-approaches の #20・#18/#19 系リスクに近い。さらに pass-to-pass 側が未変更で compare 全体への作用が部分的なため、汎用的な改善としては根拠が弱い。）
