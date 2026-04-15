# Iter-52 監査コメント

## 総評

提案の本質は、Step 5 の `Found:` 欄に残っている曖昧さを減らし、「反証が見つかった場合」だけでなく「見つからなかった場合」にも探索内容を記録させることにある。

これは新しい推論ステップを足す変更ではなく、既存の mandatory refutation をより certificate 的に運用しやすくする微修正であり、方向性としては妥当である。

ただし、期待効果の見積もりには補正が必要である。実効上の効きは EQUIVALENT 側により強く、NOT_EQUIVALENT 側への追加効果はあるが限定的である。したがって、提案文にある「両方向に均等に寄与」はやや強すぎる表現である。

---

## 1. 既存研究との整合性

DuckDuckGo MCP の search エンドポイントは今回のクエリで結果を返さなかったため、同 MCP の fetch_content で関連論文 URL を直接確認した。確認した URL と要点は以下。

1. https://arxiv.org/abs/2603.01896
   - Ugare & Chandra, "Agentic Code Reasoning"
   - 要点: semi-formal reasoning は、明示的 premises、execution-path tracing、formal conclusion を要求することで、unsupported claim や case skip を防ぐ「certificate」として機能する。
   - 本提案との関係: `Found:` 欄に「証拠なしの場合の記録様式」を与えるのは、まさに certificate の穴埋めであり、研究のコア思想と整合する。

2. https://arxiv.org/abs/2212.09561
   - "Large Language Models are Better Reasoners with Self-Verification"
   - 要点: いったん出した結論を backward verification で検証することで reasoning performance が改善する。
   - 本提案との関係: 「NONE FOUND」とだけ書かせず、何を探して否定したかを書かせるのは軽量な self-verification に相当する。結論の否定可能性を明示する方向で整合的。

3. https://arxiv.org/abs/2303.11366
   - "Reflexion: Language Agents with Verbal Reinforcement Learning"
   - 要点: エージェントが言語的フィードバックで自分の推論を省察すると、逐次改善が起きる。
   - 本提案との関係: 本変更は学習ループではないが、「探索結果を言語化して残す」ことで雑な結論を抑えるという点で整合する。

4. https://arxiv.org/abs/2201.11903
   - "Chain-of-Thought Prompting Elicits Reasoning in Large Language Models"
   - 要点: 中間推論の明示は複雑推論の品質を上げうる。
   - 本提案との関係: 本提案は CoT 自体ではなく、反証チェックの中間記録を具体化するものなので、直接証拠というより周辺整合性の補強になる。

5. https://arxiv.org/abs/2203.11171
   - "Self-Consistency Improves Chain of Thought Reasoning in Language Models"
   - 要点: 複数の reasoning path を比較して整合する答えを採ると精度が上がる。
   - 本提案との関係: 今回の変更は複数経路比較までは導入しないため、この研究との整合は弱い。むしろ「反証候補を空欄で済ませない」点が主眼であり、self-consistency より self-verification に近い。

小結:
- 研究コアとの整合性は高い。
- ただし、外部研究が直接支持しているのは「検証・構造化の有効性」であり、「`Found:` の 1 行具体化だけで精度が上がる」ことを直接実証しているわけではない。
- よって、研究的には「強く矛盾しない・むしろ自然に整合する」が、効果量の主張は控えめに置くのが妥当。

---

## 2. Exploration Framework のカテゴリ選定は適切か

結論: カテゴリ E（表現・フォーマットを改善する）の選定は適切。

理由:
- 変更対象は Step 5 の既存フィールド 1 行のみであり、推論順序・探索順序・比較単位・新規チェックポイントを変えていない。
- 実質は「曖昧文言の具体化」および「書き方の例示の追加」であり、Objective の Exploration Framework にある E の定義と一致する。
- D（メタ認知・自己チェック強化）に近く見える面もあるが、新しい自己監査項目や必須判定ゲートを追加していない以上、主分類は D ではなく E でよい。

補足:
- この変更は内容的には refutation quality に触れているため重要度は高いが、機構としてはあくまで formatting clarification である。
- したがって、カテゴリ選定は妥当だが、「効果が大きい可能性があるフォーマット改善」と位置づけるのが正確。

---

## 3. EQUIVALENT 判定と NOT_EQUIVALENT 判定への作用

### 変更前との差分

変更前の `- Found: [what — cite file:line]` は、「何か見つかった」場合の書式は自然に導くが、「見つからなかった」場合の最低限の記録要件が曖昧だった。

そのため、実務上は次のような省略が起きうる。
- `Searched for:` が抽象的
- `Found:` に `NONE FOUND` のみ
- 実際にどのファイル・どのパターンを見たのか不明

変更後は、`Found:` に
- 証拠があるなら cite file:line
- 証拠がないなら `NONE FOUND — searched [specific pattern] in [file(s)]`
を明示するため、少なくとも「不在証明のために何を見たか」の痕跡が残る。

### EQUIVALENT への作用

ここが主作用点である。

EQUIVALENT は本質的に「差が効く counterexample が見つからない」ことを示す判定なので、negative evidence の質が弱いと偽 EQUIVALENT が起こりやすい。今回の変更はそこを直接補強する。

期待できる改善:
- `NONE FOUND` の空疎な記載を減らす
- 「何を探したか」を書くことで探索抜けを自己検出しやすくする
- no-counterexample 主張の監査可能性を上げる

### NOT_EQUIVALENT への作用

こちらへの作用は副次的で、ゼロではないが小さい。

理由:
- 変更前でも、NOT_EQUIVALENT を主張するには通常すでに file:line 証拠が必要だった。
- 新 wording の `cite file:line if evidence exists` はその要件をより明示するが、新しい能力を追加するわけではない。
- したがって、曖昧な NOT_EQUIVALENT 記述を多少減らす効果はあるが、EQUIVALENT 側ほどの構造的効き目はない。

### 片方向にしか作用しないか

結論: 片方向のみではない。ただし実効上は EQUIVALENT 側に偏って作用する。

- EQUIVALENT: 明確に強く効く
- NOT_EQUIVALENT: 弱く効く

よって、提案文の「両方向に均等に寄与」は過大。より正確には、
「主に EQUIVALENT 側の negative-evidence 品質を改善し、NOT_EQUIVALENT 側にも証拠引用の明確化として補助的に寄与する」
である。

---

## 4. failed-approaches.md の汎用原則との照合

全体として、過去失敗の本質的再演ではない。

### 原則1: 探索で探すべき証拠の種類をテンプレートで事前固定しすぎる変更は避ける
判定: 概ね非該当

理由:
- 今回は「探索前に何を探せ」と固定していない。
- 変更されるのは Step 5 の記録形式であり、探索終了後に「実際に何を探したか」を残させるもの。

ただし軽微な懸念:
- `specific pattern` という表現は、機械的に grep 風キーワード探索だけを正解に見せる可能性がある。
- もし運用上 shallow pattern matching を誘発するなら、failed-approaches の「特定シグナルの捜索へ寄せすぎる」に部分的に近づく。

### 原則2: 探索の自由度を削りすぎない
判定: 非該当寄り

理由:
- 読み始める順序、境界確定順序、探索経路は固定していない。
- 「何を見たかの記録」を求めるだけで、探索順路自体は拘束しない。

### 原則3: 局所的な仮説更新を即座の前提修正義務に直結させすぎない
判定: 非該当

理由:
- 仮説更新や premises 管理への変更ではない。

### 原則4: 既存ガードレールを特定方向で具体化しすぎない
判定: 大筋で非該当

理由:
- 特定の trace direction を強制していない。
- ただし「pattern in file(s)」を必ず書かせる wording は、反証探索を textual search に寄せて見せる危険がわずかにある。

### 原則5: 結論直前の自己監査に新しい必須のメタ判断を増やしすぎない
判定: 非該当

理由:
- 新しい check item や判定ゲートを追加していない。
- 既存フィールドの曖昧さ解消に留まる。

小結:
- failed-approaches.md のブラックリストを本質的には踏んでいない。
- ただし `specific pattern` の語感だけは、検索シグナルの半固定として誤用されうるため注意。

---

## 5. 汎化性チェック

### 明示的な固有要素の有無

提案文を確認した限り、以下は含まれていない。
- ベンチマーク対象リポジトリ名
- 特定テスト名
- ベンチマーク対象コード断片
- 特定ドメインや言語に依存する API 名・関数名・クラス名

この点では、ベンチマーク過剰適合の匂いは弱い。

### ただし厳密には気になる点

ユーザ指定のチェックを文字通り厳密に適用すると、proposal には以下が含まれている。
- 具体的な数値参照: `Step 5`, `SKILL.md 行 126`, `1 行`, `5 行以内`
- コード断片に見える引用: 変更前/変更後の `Found:` 行の literal quote

これらは benchmark target の固有識別子ではなく、SKILL.md 自身の自己引用であるため、Objective の R1 的には本質的な overfitting 証拠ではない。
しかし、今回の監査観点 5 を厳密に読むなら、proposal 文面上は「完全に抽象化された記述」にはなっていないため、形式面の軽微な違反としては指摘可能である。

### 暗黙のドメイン仮定の有無

大きな問題は見当たらない。
- `specific pattern in file(s)` は言語非依存の表現であり、多くのコードベースに適用可能。
- compare / audit-improve の反証作法としても一般的。
- 特定のテストフレームワーク、特定言語、特定リポジトリ構造を暗黙前提にしていない。

ただし補足:
- 「pattern in file(s)」はテキスト検索可能性の高い静的コードベースを暗に想定しやすい。バイナリ生成物主体、DSL 主体、設定駆動で call path が散る環境では表現がやや狭い。
- そのため wording としては `searched [specific pattern / code path / evidence target] in [file(s)]` のように広げた方がより汎化的。

---

## 6. 全体の推論品質にどう効くか

期待できる改善は「探索能力そのものの増強」より、「探索の省略を表面化させること」にある。

正の効果:
1. negative evidence の記録品質向上
   - no-counterexample 主張の裏付けが強くなる。

2. 偽 EQUIVALENT の抑制
   - `NONE FOUND` のみで済ませる雑な終了を減らせる。

3. 監査容易性の向上
   - 後から見たときに、どの探索が実施されたか検証しやすい。

4. モデル自身の自己抑制
   - フォーマット要求が明確だと、探索不足のまま結論を書くことへの抵抗が少し増す。

限界:
1. 探索の深さそのものは直接は増えない
   - 書き方が丁寧になるだけで、本当に良い反証探索をしたとは限らない。

2. pattern 書式が機械化すると浅い検索を正当化しうる
   - 単なる文字列検索をしただけで「探索した」と思い込みやすい。

3. NOT_EQUIVALENT 側の追加利得は小さい
   - 既存でも file:line 証拠は要求されていたため。

総合すると、
- 回帰リスクは低い
- 改善幅は中程度未満だが、狙いは明確
- とくに EQUIVALENT 側の品質改善には理にかなう

---

## 結論

監査結論:
- 研究コアとの整合性: 良好
- Exploration Framework のカテゴリ選定: 適切（E）
- EQUIVALENT / NOT_EQUIVALENT への作用: 両方に作用するが、主作用は EQUIVALENT
- failed-approaches との整合: 本質的な再演ではない
- 汎化性: 概ね良好。ただし proposal 文面には自己引用由来の具体参照があり、観点 5 を厳密適用すると軽微な形式違反は指摘可能
- 期待効果: modest but real。特に negative evidence の監査可能性が上がる

最終判断としては、提案の実質は妥当で、変更規模に対する期待効果と低リスクのバランスもよい。
ただし、実装者の説明文にある「両方向に均等に寄与」は修正すべきであり、また `specific pattern` は過度に検索語固定へ読まれないよう注意が必要である。

承認: YES
