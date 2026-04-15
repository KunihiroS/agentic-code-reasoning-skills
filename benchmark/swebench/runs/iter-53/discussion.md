# Iteration 53 監査ディスカッション

## 総評
提案の問題意識自体は妥当です。差分の意味的差異は、テスト名・コードパス・入力型だけでなく、副作用、例外条件、状態遷移、不変条件の変化として現れることがあり、EQUIVALENT 判定ではそこを見落とすと誤判定しやすくなります。

ただし、今回の実装位置は `compare` モードの `NO COUNTEREXAMPLE EXISTS` という「EQUIVALENT を主張する最終段」の記録欄であり、ここに特定の証拠種類を明示追加するのは、failed-approaches.md が警戒している「探索対象の半固定化」「反証不在時の記録様式の過規定」にかなり近いです。概念としては良いが、テンプレートへの落とし込み方としては回帰リスクがあります。

## 1. 既存研究との整合性

### 参照した外部情報
1. https://arxiv.org/abs/2603.01896
   - `Agentic Code Reasoning` の要旨では、semi-formal reasoning の核を「explicit premises」「execution path tracing」「formal conclusions」と説明している。
   - 研究全体として、構造化テンプレートが unsupported claims を防ぐ「certificate」として働く、という整理になっている。
   - 提案が `explain` 系の semantic evidence を `compare` に持ち込もうとする発想自体は、この論文の枠内にある。

2. https://api.emergentmind.com/topics/program-equivalence-queries
   - Program equivalence は「identical outputs and side effects under all inputs」と説明されており、出力だけでなく副作用も等価性の観測対象に含まれる。
   - したがって、等価性の検討で side effects / state changes / exception behavior を意識すること自体は一般的な意味論の整理と整合する。

3. https://www.sciencedirect.com/science/article/pii/S2667305326000153
   - `GEM-LLM: Identifying contextual equivalent mutants via large language models; A global invariant-based approach`
   - 要旨では、表面的には異なるが「broader constraints」や「global invariants」の下で等価になるケースを扱い、inter-procedural slicing と invariant inference を組み合わせて contextual equivalence を判定するとしている。
   - これは「差分が semantic invariant を変えるか」を見る視点が、等価性判定で有効たりうることを支持する。

4. https://uwplse.org/2025/01/06/ems.html
   - Equivalent mutants の議論として、構文差分だけではなく、実際に意味差が観測されるかどうかが本質であることを説明している。
   - 直接に今回のテンプレート変更を支持するものではないが、「見かけ上の差分」と「実効的な意味差」を区別する必要性は一致している。

### 評価
研究整合性は「概念レベルでは高い」です。特に、等価性を output だけでなく side effects / exceptions / state transitions まで含めて考えるのは妥当です。

ただし、既存研究が支持しているのは「そうした意味的観点が重要」という点であって、「それを EQUIVALENT 側の最終記録欄に例示追加するのが最善」という実装形式までは支持していません。研究整合性はあるが、テンプレート変更の位置と強さは別問題です。

## 2. Exploration Framework のカテゴリ選定は適切か

カテゴリ F（原論文の未活用アイデアを導入する）という説明は、発想源としては妥当です。`explain` の `SEMANTIC PROPERTIES` を `compare` に応用したい、という筋は Objective.md の F の定義に合っています。

一方で、実際の変更は `NO COUNTEREXAMPLE EXISTS` の `Searched for:` の例示を 1 行だけ広げるものです。これは機械的にはカテゴリ E（表現・フォーマット改善）にもかなり近いです。

結論としては:
- 発想の出どころとしては F で説明可能
- 実装の実体としては E 寄り
- よって「完全に不適切」ではないが、「F のメカニズム導入」と言うには少し弱い

つまり、カテゴリ選定は大筋で許容可能ですが、提案の効き方は「未活用アイデアの本格導入」ではなく「既存テンプレート文言への軽微な埋め込み」です。

## 3. EQUIVALENT 判定と NOT_EQUIVALENT 判定の両方への作用

### EQUIVALENT への作用
直接効くのはほぼこちらだけです。

今回の変更は `NO COUNTEREXAMPLE EXISTS (required if claiming EQUIVALENT)` の中にしか入らないため、EQUIVALENT を主張する際に:
- テスト名
- コードパス
- 入力型
に加えて
- semantic invariant altered by the diff
- side effects
- exception conditions
- state mutations
を検索対象として意識させる効果があります。

そのため、以下の誤りには一定の予防効果が期待できます。
- 「テストが直接触っていないから同じ」と早く閉じる誤り
- 戻り値だけ見て副作用差を見落とす誤り
- 例外発火条件の差を無視して等価とする誤り

### NOT_EQUIVALENT への作用
こちらへの直接効果はかなり限定的です。

理由は単純で、NOT_EQUIVALENT を主張する時に使うのは `COUNTEREXAMPLE` ブロックであり、今回そこは変わっていません。したがって:
- どのテストが分岐するか
- どの assertion が割れるか
- どの call path で差が顕在化するか
を構成する能力は、変更前と本質的に同じです。

### 実効差分の評価
実効的には「EQUIVALENT 側の反証探索を少しだけ厳しくする」変更です。片方向性は明確にあります。

したがって、提案文の「NOT_EQUIVALENT への影響は限定的」という自己評価は正しいです。しかし監査観点では、ここはそのまま長所にはなりません。Objective.md は EQUIV と NOT_EQ の両面影響を見ることを求めており、この変更は実質的に EQUIVALENT 側のみに作用します。

さらに注意点として、`I searched for exactly that pattern` の欄に invariant 系の例示が入ると、モデルが「検索報告の充実」に寄ってしまい、構造差分やテスト到達性の確認よりも invariant というラベル付けを優先する可能性があります。これは EQUIVALENT 側の慎重さを増す代わりに、探索の自然さを損なうリスクです。

結論: この変更は両方向に均等には作用しません。主作用は EQUIVALENT 側で、NOT_EQUIVALENT 側への直接寄与は小さいです。

## 4. failed-approaches.md の汎用原則との照合

ここが最大の懸念点です。提案文は「例示拡充にすぎないので抵触しない」と主張していますが、監査上は完全には同意できません。

### 原則1: 「次に探すべき証拠の種類をテンプレートで事前固定しすぎる変更は避ける」
かなり近いです。

今回の変更は、まさに `Searched for:` に「semantic invariant altered by the diff」を追加し、反証不在時に探すべき証拠種類をテンプレート側から示しています。`or` で緩めてはいるものの、位置が `I searched for exactly that pattern` の直下であるため、実運用ではかなり強い誘導になります。

### 原則2: 「探索ドリフト対策を追加する際は、探索の自由度を削りすぎない」
部分的に近いです。

読解順序そのものは固定していませんが、EQUIVALENT 結論直前の探索対象に invariant 系観点を半必須化する方向なので、自由度を削る圧力はあります。特に compare は構造差分・到達性・既存テスト・assertion 分岐など複数観点のバランスが大事であり、そこに特定観点を明示追加するのは無害とは言い切れません。

### 原則4: 「既存の汎用ガードレールを、特定の追跡方向や観点で具体化しすぎない」
これにも一部接触しています。

今回の文言は guardrail 本体ではなく証明書テンプレートの例示欄ですが、compare における refutation の具体的な観点を invariant 方向へ寄せています。形式上はガードレールではなくても、実質上は探索方向の具体化です。

### 原則5: 「結論直前の自己監査に、新しい必須のメタ判断を増やしすぎない」
これにもかなり近いです。

新しい欄は増えていないものの、failed-approaches.md は「反証が見つからなかった場合の記録様式を細かく規定しすぎると、探索の質の改善よりテンプレート充足が目的化しやすい」と明記しています。今回の変更箇所はまさに `NO COUNTEREXAMPLE EXISTS` の記録様式です。

### 総合判断
「表現を変えただけで本質は同じ過去失敗の再演ではないか」という観点では、再演リスクが高いです。完全一致ではないものの、少なくとも failed-approaches.md の警戒線にかなり接近しています。

## 5. 汎化性チェック

### 明示的なルール違反の有無
提案文を確認した範囲では、以下のような明確な overfitting 痕跡は見当たりません。
- 特定ベンチマークケース ID
- 特定リポジトリ名
- 特定テスト名
- ベンチマーク対象コードの断片引用

含まれているのは:
- SKILL.md の自己引用
- 論文の Appendix / Section 番号
- 一般概念名（side effects, exception conditions, state mutations）
であり、Objective.md の R1 基準に照らして基本的には許容範囲です。

### 暗黙のドメイン想定
例示は十分に汎用的です。特定言語や特定フレームワークを直接仮定していません。

ただし軽微な懸念として、`semantic invariant` の具体例が
- side effects
- exception conditions
- state mutations
に寄っているため、やや命令的・状態遷移中心のコードを想起させやすいです。純関数型、宣言的設定、型レベル制約中心のコードでは、同じ観点をどう表現するかが少し曖昧です。

もっとも、これは致命的ではありません。語の選び方としては概ね汎用的です。

## 6. 全体の推論品質がどう向上すると期待できるか

期待できる改善は「あるとしても限定的」です。

### 良い方向
- EQUIVALENT 判定で、戻り値一致だけを見て終わる浅い比較を減らす可能性がある
- 副作用や例外条件の差のような、テスト未直撃の意味差に意識を向けさせる
- `explain` の semantic-properties 的視点を compare に少し輸入することで、比較の意味論的粒度を上げる

### 限界
- 変更箇所が最終段の 1 行なので、探索の初期・中盤に invariant 観点を本当に持ち込める保証は弱い
- 実際の推論改善より「Searched for 欄を invariant 風に埋める」だけで終わる危険がある
- NOT_EQUIVALENT 側の証拠構築にはほぼ寄与しない
- failed-approaches.md が警戒する「テンプレート充足への過適応」を招きうる

したがって、推論品質改善の見込みは
- 局所的には理解できる
- しかし全体最適としては不確実
という評価です。

## 最終判断
承認: NO（理由: 発想自体は研究整合的で汎用性も概ね保たれているが、変更の効き方が実質的に EQUIVALENT 側へ片寄っており、しかも `NO COUNTEREXAMPLE EXISTS` の記録欄で特定の証拠種類を明示することで、failed-approaches.md が禁じる「探索対象の半固定化」「反証不在時の記録様式の過規定」を再演するリスクが高いため）
