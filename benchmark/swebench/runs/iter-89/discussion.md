# Iter-89 監査ディスカッション

## 総論
提案の狙い自体は理解できる。`NO COUNTEREXAMPLE EXISTS` の `Conclusion` を具体化し、「差異を見つけたのに『影響しない』で流す」雑な結論を減らしたい、という問題意識は `SKILL.md` の Guardrail #4 および `docs/design.md` の "Incomplete reasoning chains" / "Subtle difference dismissal" と整合している。

ただし、監査上の重要点は「提案文の見た目」ではなく「現行 SKILL.md との差分が実際にどこへ作用するか」である。今回の差分は、実効的には `EQUIVALENT` を主張する側にのみ追加の説明責任を課す変更であり、`failed-approaches.md` の非対称化原則にかなり近い。しかも、現行 `SKILL.md` にはすでに近い趣旨の強い指示が存在するため、追加効果は限定的で、コストは主に `EQUIVALENT` 側に載る可能性が高い。

このため、現時点では承認しない。

## 1. 既存研究との整合性

DuckDuckGo MCP による検索ツールは今回の環境では検索結果を返さなかったため、同じ DDG MCP サーバの `fetch_content` で関連文献 URL を直接確認した。参照 URL と要点は以下。

1. Agentic Code Reasoning
   - URL: https://arxiv.org/abs/2603.01896
   - 要点:
     - semi-formal reasoning は、明示的な premises、execution path tracing、formal conclusion を要求し、unsupported claim を減らす「certificate」として機能する。
     - patch equivalence では、structured prompting により精度が改善すると報告されている。
     - 提案が狙う「差異を見つけた後も assertion まで追う」は、この論文のコア方向性と整合する。
   - 監査コメント:
     - 方向性は整合的。
     - ただし論文の強みは「追加で何を書くか」より「探索ループ自体をどう強制するか」にある。今回の提案は `Conclusion` の一文の精緻化であり、探索行動そのものをどこまで変えられるかは弱い。

2. Let’s Verify Step by Step
   - URL: https://arxiv.org/abs/2305.20050
   - 要点:
     - outcome supervision より process supervision の方が multi-step reasoning の信頼性を改善した。
     - 中間推論の質を上げるには、最終答えだけでなく途中の reasoning step を監督することが有効。
   - 監査コメント:
     - 今回の提案は「最終ラベルを指示する」のではなく、`EQUIVALENT` 結論前に reasoning を一段具体化させようとしており、この意味では process-oriented な改善に見える。
     - しかし追加される場所が `Conclusion` 行であるため、process そのものの監督というより「最終段の作文制約」に寄りやすい。研究の示唆を十分に活かすなら、結論欄より分析ループ側に効かせる方が自然。

3. Chain-of-Thought Prompting Elicits Reasoning in Large Language Models
   - URL: https://arxiv.org/abs/2201.11903
   - 要点:
     - intermediate reasoning steps の明示は複雑な推論性能を向上させる。
   - 監査コメント:
     - 提案は中間 reasoning の明示化と整合的ではある。
     - ただし CoT 系知見が支持するのは「途中の推論展開」であり、今回の変更は途中の探索ステップ追加ではなく、終端の結論文言の厳格化である。整合はあるが、支持は限定的。

4. Observational equivalence（概念確認）
   - URL: https://en.wikipedia.org/wiki/Observational_equivalence
   - 要点:
     - 2つの対象が observable implication で区別不能なら observationally equivalent とみなされる。
     - プログラミング言語の文脈では、全ての文脈で同じ value / observable effect を示すかが本質。
   - 監査コメント:
     - 提案の「差異が test assertion に到達する前にどこで吸収されるかを説明する」という表現は、観測可能境界に着目しており概念的には筋が良い。
     - ただし compare モードの定義は「既存 tests に対する pass/fail outcome の同一性」であり、すでに observational criterion を採用している。今回の追加は新原理の導入というより既存原理の言い換えに近い。

小結:
- 研究整合性はある。
- しかし、研究が支持しているのは主に「途中の探索・検証手順の強化」であり、今回の変更は終端の `Conclusion` テキストに寄っているため、研究的には中程度の整合に留まる。

## 2. Exploration Framework のカテゴリ選定は適切か

提案者はカテゴリ E（表現・フォーマットの改善）を選んでいる。

形式面では妥当である。実際、変更は 1 行の wording refinement であり、新規ステップや新規フィールドは増やしていない。

ただし、機能面では「単なる表現改善」ではない。これは `EQUIVALENT` 結論時の必要説明内容を変えることで、実質的に compare モードの判定プロセスへ介入する変更である。したがって、分類上は E でもよいが、評価上は「無害な wording polish」として扱ってはいけない。

監査上の結論:
- 管理上のカテゴリ E は許容。
- ただし作用機序は E よりむしろ「判定時の reasoning burden の再配分」であり、failed-approaches の非対称化原則で評価すべき。

## 3. EQUIVALENT / NOT_EQUIVALENT の両方向への作用分析

### 変更前に既にある制約
現行 `SKILL.md` には既に以下がある。

- Guardrail #4:
  - semantic difference を見つけたら、その差異が test outcome に影響するか/しないかを relevant test で trace せよ。
- Compare checklist:
  - changed function で behavioral difference を見つけても、そこで止まらず、その出力を消費する downstream function を読み、propagate か absorb かを記録してから Claim outcome を決めよ。

つまり、「差異を見つけたら assertion まで届くか確認する」という中核原則は、すでに本体に入っている。

### 今回の実効的差分
今回の差分は `NO COUNTEREXAMPLE EXISTS (required if claiming EQUIVALENT)` の `Conclusion` 行だけに作用する。

したがって、実効的には次の形になる。

- `NOT_EQUIVALENT` を主張する場合:
  - 直接の変更なし。
  - counterexample 側テンプレートは不変。
- `EQUIVALENT` を主張する場合:
  - 「difference が見つかったなら、assertion まで届かない吸収メカニズムを説明せよ」
  - 「difference 自体が見つからないなら、behavioral difference が call path に構造的に存在しない理由を述べよ」

これは明らかに `EQUIVALENT` 側にのみ追加の burden を置く。

### 改善しうる点
- false `EQUIVALENT`（本当は `NOT_EQUIVALENT` なのに、差異を軽く退けてしまう誤判定）は、一定程度減る可能性がある。
- 特に「差異は見つけたが downstream 追跡が甘い」タイプには、再考のきっかけになりうる。

### 回帰しうる点
- true `EQUIVALENT` ケースでも、吸収メカニズムを十分に言語化できないと、モデルが `EQUIVALENT` 主張をためらう可能性がある。
- しかも現行ルールでも十分な trace が要求されている以上、今回の変更は「新しい探索」を増やすより「結論欄での自己証明負荷」を増やす方向に働きやすい。
- その結果、`EQUIVALENT` 側だけハードルが上がり、`NOT_EQUIVALENT` 側へのフォールバックや、少なくとも balanced accuracy 上の悪化を招きうる。

### 片方向作用かどうか
結論として、これはほぼ片方向作用である。

- 名目上は reasoning の質向上を目指している。
- しかし変更前との差分で見ると、追加負荷は `EQUIVALENT` 分岐に集中している。
- `NOT_EQUIVALENT` を出すための counterexample 構成能力は直接強化されていない。

よって「両方向に効く一般改善」とは評価しにくい。

## 4. failed-approaches.md の汎用原則との照合

### 原則 #1 / #12: 判定の非対称操作・アドバイザリな非対称指示
最も強く抵触する懸念はここ。

今回の提案は `NO COUNTEREXAMPLE EXISTS`、つまり `EQUIVALENT` を主張する場面にだけ追加説明を課す。提案者は「真の EQUIV なら説明は容易」と述べているが、failed-approaches はまさにその見積もりを危険視している。実際には、モデルは「十分に説明できたか」に慎重になり、片側の立証責任だけが上がりやすい。

### 原則 #6: 「対称化」は既存制約との差分で評価せよ
提案文は一見すると「差異があれば吸収メカニズム、なければ構造的欠如」と両面を書いていて対称的に見える。しかし差分で見ると、現行 SKILL.md はすでに差異発見後の downstream trace を要求している。したがって新規に強く作用するのは、`EQUIVALENT` 結論時の説明義務である。見た目の対称性では救えない。

### 原則 #8: 受動的な記録フィールドの追加は能動的検証を誘発しない
今回の変更は新しい探索ステップではなく、`Conclusion` 欄の記述内容の変更である。そのため、モデルが本当に追加 tracing を行う保証は弱い。最悪の場合、既存の不十分な探索の上に、それらしく「吸収された」と作文するだけになる。これは原則 #8 の典型的懸念と重なる。

### 原則 #20: 目標証拠の厳密な言い換えや対比句の追加
今回の変更はまさに `Conclusion` の wording を、より厳格・より排他的な表現へ置き換えるもの。意図は明確化でも、実効としては `EQUIVALENT` を出すための基準を厳しく読ませる可能性がある。原則 #20 とも近い。

### 原則 #23: 具体的手順を伴わない抽象的問い
今回の文言は「吸収メカニズムを説明せよ」「構造的に absent と述べよ」と方向づけはあるが、追加の具体的検証手順までは与えていない。そのため、思考のフレーミング強化にはなっても、探索行動を確実に変える仕組みとしては弱い。

### 非該当または相対的に軽い点
- 原則 #18/#19/#24/#26 のような、厳密な `file:line` 証拠の追加義務や完全 end-to-end 証明の要求まではしていない。
- 原則 #3 の「探索量削減」はしていない。

小結:
- もっとも重要なのは #1, #12, #6, #8, #20。
- 「過去失敗の本質を言い換えているだけではないか」という懸念はかなり強い。

## 5. 汎化性チェック

### 提案文中の具体物チェック
- ベンチマーク対象リポジトリ名: なし
- テスト名: なし
- 特定の対象コード断片: なし
- 特定ドメイン名・言語名・フレームワーク名: なし

この点は良い。提案の本体は compare モード一般に向けた抽象記述になっており、特定リポジトリを暗黙に狙い撃ちしている痕跡は薄い。

ただし、以下は注記しておく。

1. ファイルタイトルに `Iter-89` という具体的数値ラベルはある。
   - これは提案の管理用メタデータであり、ベンチマーク対象への過剰適合を示す substantive な ID ではない。
   - したがって実質的な overfitting 証拠とは見なさない。

2. 提案文には `SKILL.md` の変更前後文言の引用コードブロックが含まれる。
   - これは対象リポジトリの実装コードではなく、SKILL.md 自身の自己引用である。
   - `Objective.md` の R1 減点対象外の扱いと整合する。

### 暗黙のドメイン依存性
- `test assertion` / `call path` という語はテスト駆動の compare 問題に特化しているが、これは compare モード自体の定義が test outcomes を基準にしているため、許容範囲。
- 特定言語・特定テストフレームワーク・特定パッチパターンへの依存は見当たらない。

結論:
- 汎化性そのものは比較的良い。
- この提案の弱点は overfitting ではなく、非対称作用と既存指示との冗長性にある。

## 6. 全体の推論品質への期待効果

期待できる改善:
- 差異を見つけた後に downstream の観測点まで追い切らず、「たぶん影響なし」と片づける雑な `EQUIVALENT` を抑制する可能性はある。
- 特に、比較対象の差異が実在するのにその扱いが曖昧なケースでは、少なくとも結論文に違和感が出るので、再検討の誘因にはなりうる。

ただし上限は低いと見る。

理由は 2 つある。

1. 既存 SKILL.md にすでに近い原則がある
   - Guardrail #4 と Compare checklist が、実質的に同じことをすでに要求している。
   - したがって今回の差分は「新しい推論能力の導入」ではなく、「既存要求の再強調」に近い。

2. 追加場所が exploration ではなく conclusion である
   - 探索中に downstream trace を増やす保証よりも、結論欄の作文負荷を上げる効果の方が強い。
   - そのため、推論品質の実改善より、`EQUIVALENT` 側だけ慎重化させる副作用の方が前面に出るリスクがある。

総合すると、見込まれる効果は
- false `EQUIVALENT` 減少: 小〜中
- true `EQUIVALENT` 維持: 悪化リスクあり
- `NOT_EQUIVALENT` 側能力向上: ほぼ直接効果なし
- 全体精度: 改善不確実、むしろ悪化リスクあり

## 最終判断

承認: NO（理由: 現行 SKILL.md との差分としては `EQUIVALENT` 側にのみ追加の説明責任を課す片方向作用が強く、`failed-approaches.md` の非対称化原則 #1/#12/#6 に抵触する懸念が大きい。さらに、既存の Guardrail #4 と Compare checklist がすでに同趣旨を含んでいるため、追加効果は限定的で、探索改善より結論欄の burden 増加として働く可能性が高い。）
