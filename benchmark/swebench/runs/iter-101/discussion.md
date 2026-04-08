# Iter-101 監査コメント

## 総評
提案の問題意識自体は理解できる。SKILL.md の compare モードには既に「コード差分だけで NOT EQUIVALENT と結論しない」「異なる observable test outcome を確認せよ」という強い原則があり、この提案はその方向を `NO COUNTEREXAMPLE EXISTS` の `Searched for:` にも反映したい、という発想である。

ただし、監査観点ではこの提案をそのまま承認するのは難しい。主な理由は、変更の名目は「表現の明確化」だが、実効的には EQUIVALENT 側の counterexample 不在証明のハードルを一方向に動かす変更として作用する可能性が高く、`failed-approaches.md` の非対称化原則にかなり近いからである。

---

## 1. 既存研究との整合性

DuckDuckGo MCP の fetch で確認した一般研究・一般概念:

1. https://en.wikipedia.org/wiki/Observational_equivalence
   - 要点: observational equivalence は「観測可能な含意に基づいて区別不能であること」とされる。
   - この提案の「different observable outcomes」という語彙自体は、この一般概念とは整合的。
   - ただし研究上の observational equivalence は通常「全ての relevant contexts / observable consequences」に関わる概念であり、単に一つの局所的な assertion 文言だけを見る発想より広い。

2. https://en.wikipedia.org/wiki/Test_oracle
   - 要点: テスト oracle は、入力に対する expected result を与え、actual result と expected result の比較で正否を判定する。
   - 提案の「assertion での observable outcome に着目する」は、テスト oracle 中心の発想として自然。
   - ただし oracle は PASS/FAIL の二値だけでなく、expected values / behaviors の比較全体を含む。したがって「observable outcomes」と書くなら、PASS/FAIL への過度な還元ではなく、assertion が観測している値・例外・副作用の全体を保つ必要がある。

3. https://en.wikipedia.org/wiki/Differential_testing
   - 要点: differential testing は同一入力に対する複数実装の出力差分を観測して semantic bugs を見つける。
   - 提案が「semantic differences」より「different observable outcomes」を重視する方向は、差分を最終観測結果で判断するという意味では一般的 testing の考え方と合う。
   - しかし differential testing でも重要なのは「同じ入力に対して比較可能な観測点を適切に選ぶこと」であり、観測点の選び方を誤ると差分を見落とす。したがって wording 変更だけで改善できる範囲には限界がある。

参考補足:
4. https://arxiv.org/abs/1907.01257
   - 要点: observational equivalence の証明では local reasoning と robustness が重要だと述べる。
   - これは「観測可能結果で比較する」という方向性の一般妥当性を支持するが、同時に equivalence 証明は単なる言い換えではなく、どの観測文脈が relevant かを慎重に扱う必要があることも示唆する。

結論:
- 提案のキーワード自体は既存研究・一般概念と整合する。
- ただし「observable outcomes」という表現が妥当であることと、「SKILL.md のこの特定欄をその文言に置き換えるとベンチマーク上で健全に働く」ことは別問題である。

---

## 2. Exploration Framework のカテゴリ選定は適切か

提案者はカテゴリ E（表現・フォーマットの改善）としているが、これは半分だけ正しい。

妥当な点:
- 実際の diff は 1 行の wording change であり、形式上はカテゴリ E に入る。
- 曖昧語 `propagate` をより具体化したい、という説明も E の定義には合う。

懸念点:
- この変更は単なる表現調整ではなく、「何を反証探索すべきか」を実質的に再定義している。
- したがって実効的には E だけでなく、B（情報の取得方法を改善する）にも跨っている。
- 監査上重要なのはラベルではなく実効差分であり、実効差分が探索目標の変更である以上、「表現の明確化だから安全」という評価はできない。

監査判断:
- カテゴリ E として提出すること自体は不当ではない。
- ただし「E なので低リスク」という主張は成立しない。これは exploration target を変える提案であり、E の名目より実効を優先して評価すべき。

---

## 3. EQUIVALENT / NOT_EQUIVALENT の両判定への作用

### 変更前との差分で見た実効作用
既存 SKILL.md にはすでに compare checklist に以下がある。
- 「When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact」
- 「Do not conclude NOT EQUIVALENT from a code difference alone — verify that the difference produces a different observable test outcome」

このため、proposal が新たに導入する原則の大半は、既存フレームワークの“全体方針”としてはすでに存在している。

よって実効的差分は限定される。どこにだけ効くかというと、`NO COUNTEREXAMPLE EXISTS` の `Searched for:` 欄、つまり EQUIVALENT を主張する時の refutation phrasing にだけ追加で強く効く。

### EQUIVALENT への作用
期待される正の効果:
- 構造的到達と観測差異を混同して、差分が call path 上にあるだけで NOT_EQ としてしまう誤りは減る可能性がある。
- 「assertion で最終的に何が観測されるか」を言語化するため、局所差分からの短絡的な NOT_EQ を抑制する方向には働く。

しかし限界も大きい:
- その機能は既存 compare checklist の 219-220 行でかなりカバー済み。
- したがって改善余地は「既にある原則の再強調」に留まりやすく、純増効果は限定的。

### NOT_EQUIVALENT への作用
提案者は「NOT_EQ 精度は中立か微増」と書くが、これは楽観的すぎる。

懸念:
- 変更箇所は `COUNTEREXAMPLE` ではなく `NO COUNTEREXAMPLE EXISTS` 側のみである。
- したがって、NOT_EQ を正しく出すための探索ループそのものは強化していない。
- 逆に、モデルが「observable outcome の差が明示できない限り、ひとまず no counterexample とまとめる」方向へ寄ると、本来は NOT_EQ にすべき微妙な差分を EQUIVALENT に寄せる圧力が生じうる。

実効評価:
- この変更は両方向に均等には作用しない。
- 差分としては EQUIVALENT 側の結論を出しやすくする方向に主として働く。
- よって「片方向にしか作用しないか確認する」という監査観点では、かなり片方向寄りと判断する。

---

## 4. failed-approaches.md との照合

提案文は適合を主張しているが、監査としては以下の原則と衝突または近接がある。

### 原則 #1 判定の非対称操作
最重要懸念。
- 変更対象が `NO COUNTEREXAMPLE EXISTS` 側のみである時点で、差分は EQUIVALENT 経路に集中している。
- 既存 SKILL.md がすでに observable outcome を compare checklist で要求している以上、今回の追加差分は EQUIVALENT 側の再フレーミングとして働く可能性が高い。
- したがって「立証責任を上げていない」ではなく、「EQUIVALENT 側に有利な認知誘導を追加している」と見る方が自然。

### 原則 #4 同じ方向の変更は表現を変えても同じ結果になる
- 提案者はこれを“明確化”と呼ぶが、効果の方向は「局所差分から NOT_EQ に飛ぶのを抑える」ことである。
- これは方向として EQUIVALENT 寄りであり、過去失敗群と同方向である可能性を否定できない。

### 原則 #6 対称化は既存制約との差分で評価せよ
- 提案者は「観測差異を正確に捉えるようになるから NOT_EQ にも効く」と述べるが、差分で見ると NOT_EQ 側には新しい要求は入っていない。
- したがって、変更後の文言が見かけ上バランス良く見えても、変更前との差分は非対称。

### 原則 #12 アドバイザリな非対称指示
- 変更は必須セクション内の wording であり、単なる注釈より強い。
- しかも EQUIVALENT 主張時にのみ現れる欄であるため、実効的には片側の自己正当化テンプレートを変える提案になっている。

### 原則 #20 目標証拠の厳密な言い換え
- ここは提案者と見解が異なる。
- `propagate to a test assertion` から `produce different observable outcomes at a test assertion` への変更は、「より狭く、より結論志向の phrasing」になっている。
- 意図は明確化でも、モデルへの実効としては「差分が見えなければ equivalence 側へ倒してよい」という強いメッセージになりうる。

### 原則 #22 具体物の例示による過剰適応
- これは大きな違反ではない。
- `final values or behaviors` は抽象度が保たれており、この点は比較的健全。

総合すると、提案は failed-approaches のブラックリストを完全に回避しているとは言えない。特に #1, #6, #12, #20 に対してリスクが残る。

---

## 5. 汎化性チェック

### 明示的なルール違反の有無
提案文には以下が含まれる。
- `Iter-101` という数値 ID

これは文書管理上の見出しであり、改善メカニズムの中身そのものが特定ベンチマークケースを参照しているわけではない。ただし、依頼文のルールを厳密に読むなら「具体的な数値 ID が含まれている」ので形式的には指摘対象になる。

一方で、以下の重大な違反は見当たらない。
- 特定リポジトリ名: なし
- 特定テスト名: なし
- ベンチマーク対象コード断片: なし
- 特定関数名 / クラス名 / ファイルパス（対象 repo 由来）: なし

### 暗黙のドメイン依存性
軽微な懸念はある。
- 提案文は `PASS/FAIL` と `assertion point` をかなり中心に据えている。
- これは xUnit 型の単体テスト・アサーションベースのテストを暗黙に標準形とみなしている。
- もちろん SKILL.md 自体が test-outcome ベースの equivalence を扱うので完全な逸脱ではないが、例外、ログ、状態遷移、非同期イベント、 snapshot diff, property-based failure など assertion 文の形を取らない観測も存在する。

汎化性判断:
- 致命的な過剰適合ではない。
- ただし「assertion における observable outcomes」という phrasing は少し xUnit 的で、完全に言語・テスト形式非依存とまでは言いにくい。

---

## 6. 全体の推論品質はどう向上すると期待できるか

期待できる改善:
- 構造差分と観測差分の区別を明示し、局所差分からの短絡的な NOT_EQ を減らす可能性がある。
- compare モードにおける「最終観測結果まで追う」という姿勢を補強する。

ただし期待値は限定的:
- 同趣旨の guardrail / checklist が既に SKILL.md にあるため、新規情報量が少ない。
- 変更が探索手順そのものを増やすわけではなく、既存テンプレート中の 1 フィールドの framing を変えるだけなので、改善幅は小さいはず。
- その小さい改善可能性に対して、EQUIVALENT 側への片寄りという回帰リスクが相対的に大きい。

より安全な方向性があるとすれば:
- `NO COUNTEREXAMPLE EXISTS` だけではなく、`COUNTEREXAMPLE` と compare checklist を含めた compare 全体で、同じ観測境界の概念を対称に整理すること。
- ただしそれをやる場合も、failed-approaches の #1/#6 を避けるため、「変更前との差分」が本当に両方向に効くように設計する必要がある。

---

## 最終判断
承認: NO（理由: 変更の名目は wording clarification だが、実効差分は `NO COUNTEREXAMPLE EXISTS` 側にのみ強く作用し、EQUIVALENT 判定を出しやすくする片方向の誘導になりうる。既存 SKILL.md にはすでに observable outcome を重視する guardrail が存在するため追加の純増効果は限定的である一方、`failed-approaches.md` の #1, #6, #12, #20 に近い回帰リスクが残る。また proposal 文中には厳密には `Iter-101` という数値 ID も含まれている。）
