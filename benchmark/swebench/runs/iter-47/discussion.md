# Iter-47 監査ディスカッション

## 総評

提案の狙い自体は理解できる。compare モードの各 Claim に「アサーション地点で観測される値/状態」を明記させることで、単なる call-path 記述から一段進んで、観測可能な意味論に寄せた比較を促そうとしている。

ただし、監査役としては現時点では **承認しない**。
理由は、提案の理論的方向性は妥当でも、実際の変更文言が

1. `assertion` という単一観測点を半固定化しており、
2. `value or expression` という証拠種別を事前固定しており、
3. 実効的には EQUIVALENT 側の補強に偏り、NOT_EQUIVALENT 側には既存要件との重複が大きい

ためである。

---

## 1. 既存研究との整合性

DuckDuckGo MCP による確認では、提案の発想そのものには研究上の整合性がある。

### 参照 URL と要点

1. https://calmops.com/math/alr/semantic-equivalence/
   - 要点: observational equivalence は「全ての入力に対して同じ observable results を生むか」で考える。
   - 提案との関係: compare で「最終的に何が観測されるか」を書かせる方向は整合的。
   - ただし同記事でも observable results には outputs, side effects, termination behavior などが含まれる。したがって観測対象を `assertion` 上の `value or expression` に寄せすぎると、観測可能性の概念を狭める懸念がある。

2. https://www.geeksforgeeks.org/compiler-design/data-flow-analysis-compiler/
   - 要点: data flow analysis は、変数がどこで定義され、どこで参照され、どのように値が変化するかを追跡する技法である。
   - 提案との関係: explain モードの DATA FLOW ANALYSIS を compare に部分移植する発想は、一般的なプログラム理解技法として不自然ではない。
   - ただしこの URL が示すのは「値追跡は有益」という一般論であり、「比較証明の各 Claim に assertion-site value を必須化すべき」とまでは直接支持しない。

3. https://www.cs.odu.edu/~zeil/cs350/latest/Public/analysis/index.html
   - 要点: 静的解析では control flow / data flow がコード理解の主要表現であり、変数の使用先や依存関係を追うことは標準的である。
   - 提案との関係: 単なる関数名推測ではなく、コード上の状態遷移を追わせる方向は妥当。
   - 留意点: ここでも重要なのは data flow を補助表現として使うことなので、compare テンプレートで観測証拠を 1 種類に固定する必然性までは読めない。

4. https://ldra.com/capabilities/data-flowcontrol-flow-analysis/
   - 要点: data flow / control flow analysis はコードの architecture と behavior を理解し、問題箇所の発見に役立つ。
   - 提案との関係: flow だけでなく data/state も見るべき、という補強には沿う。
   - 留意点: 一般には control flow と data flow を併用する話であり、今回提案文のように「assertion 時点の observed value/state」を全 Claim に明示させる具体化が最善とは限らない。

### 研究整合性の結論

- 良い点: 「観測等価性」「データフロー追跡」を compare に取り込む方向は一般研究の流れと整合する。
- 懸念点: 研究上の observables は広く、提案文の `the observed value/state at the assertion is ...` は観測点と観測形式を狭く定義しすぎている。

したがって、研究との整合性は **部分的にはあるが、提案文言はやや過剰に具体化されている** と評価する。

---

## 2. Exploration Framework のカテゴリ選定は適切か

提案者はカテゴリ F「原論文の未活用アイデアを導入する」を選んでいる。
これは **大筋では妥当**。

理由:
- `docs/design.md` では paper task ごとにテンプレートがあり、Code QA には data flow tracking が含まれる。
- 今回はその explain 側の観点を compare 側の Claim 記述へ移植しようとしている。
- Objective.md のカテゴリ F の定義にも「他のタスクモード（localize, explain）の手法を compare に応用する」が明記されている。

ただし、カテゴリ選定が妥当であることと、具体的な実装文言が妥当であることは別問題である。
カテゴリ F としての筋は通っているが、実際の差し込み方が

- `assertion` という観測点固定
- `value or expression` という証拠型固定

になっているため、F の発想自体はよくても、その翻訳は必ずしも最良ではない。

要するに、**カテゴリ F 判定は YES、だが提案文言の具体化は再考余地が大きい**。

---

## 3. EQUIVALENT 判定と NOT_EQUIVALENT 判定の両方にどう作用するか

### EQUIVALENT 側への作用

ここには比較的はっきり効く可能性がある。
現行 compare は「変更箇所からテスト結果への trace」は要求しているが、「なぜ同じ outcome になるのか」を値・状態のレベルで明示しなくても書けてしまう。
そのため、

- 経路は違うが観測値は同じ
- 経路差分はあるが downstream で吸収される

のようなケースで、根拠が曖昧なまま EQUIVALENT に流れる余地がある。

この点で、観測値/状態の明示を要求することは EQUIVALENT の証拠密度を上げうる。

### NOT_EQUIVALENT 側への作用

ここへの追加効果は限定的で、かなり既存要件と重複する。
なぜなら compare にはすでに

- per-test の PASS/FAIL 主張
- Comparison: SAME / DIFFERENT
- COUNTEREXAMPLE
- Diverging assertion の特定

があるため、NOT_EQUIVALENT を成立させるには元々「どこで差が観測されるか」を書く流れが入っているからである。

追加の observed value/state 記述は、差分の説明を多少明確にすることはあっても、既存の counterexample 義務に比べると増分は小さい。

### 実効的差分の評価

結論として、この変更は理論上は両方向に作用しうるが、**実効的には EQUIVALENT 側に強く、NOT_EQUIVALENT 側には弱い**。
「両方に効く」と完全対称に言うのは言い過ぎである。

さらに悪いケースとして、NOT_EQUIVALENT で既に十分な反証がある場面でも、各 Claim で `value or expression` の記述を埋めること自体が目的化し、説明の冗長化や焦点分散を招く可能性がある。

したがって本提案は **片方向にしか作用しないわけではないが、かなり非対称** と判断する。

---

## 4. failed-approaches.md の汎用原則との照合

ここが最大の懸念点である。
提案者は「非抵触」としているが、私はそうは見ない。

### 原則 1: 証拠種別の事前固定を避ける

failed-approaches.md には、
「次の探索で探すべき証拠の種類をテンプレートで事前固定しすぎる変更は避ける」
とある。

今回の提案はまさに各 Claim に
`the observed value/state at the assertion is [value or expression]`
を要求している。
これは

- 観測点: assertion
- 証拠種別: value/state
- 表現形式: value or expression

を明示的に固定しており、かなり直接的にこの失敗原則へ接近している。

提案者は「どの値/状態を見るかを限定しないので非抵触」と主張しているが、監査上は不十分である。
「何を探すか」の粒度は十分固定されている。
特定の変数名までは固定していなくても、証拠の型をテンプレートで半必須化している以上、原則違反リスクは残る。

### 原則 2: 探索の自由度を削りすぎない

今回の変更は読解順序自体は固定しないので、この原則への抵触は強くはない。
ただし、各テスト Claim の着地点を assertion-site observed value に寄せることで、

- 例外の有無
- side effect の有無
- 複数 assertion の総合効果
- setup/teardown を含むテスト全体の振る舞い

よりも、単一地点の値記述に意識を寄せやすくなる。
この意味で、探索経路というより「着目すべき証拠空間」を狭める副作用がある。

### 原則 4: 既存ガードレールの特定方向での具体化を避ける

提案は Guardrail #4 の補強を意図しているが、実質的には「差分が無害かどうかは assertion 時点の value/state で書け」という方向性の具体化になっている。
これは failed-approaches.md が避けるべきと言う「特定方向のトレースを半固定化」に近い。

### 照合結論

提案は failed-approaches.md の失敗原則を完全再演しているとまでは言わないが、**本質的にはかなり近い**。
少なくとも「非抵触」と断言できる内容ではない。

監査としては、ここは明確に減点要素である。

---

## 5. 汎化性チェック

### 明示的なルール違反の有無

提案文を確認した範囲では、以下のような明示的 overfitting 痕跡は見当たらない。

- 特定の benchmark case ID: なし
- 特定リポジトリ名: なし
- 特定テスト名: なし
- ベンチマーク対象コード断片の引用: なし

この点は問題ない。
SKILL.md の自己引用や compare/explain というモード名の記載は、Objective.md の監査基準上も許容範囲である。

### 暗黙のドメイン想定

ただし、提案文には次の暗黙バイアスがある。

1. `assertion` 中心のテスト観
   - 全ての relevant test が「単一の assertion 地点」で観測されるとは限らない。
   - 例外送出、ログ、副作用、DB 状態、ファイル生成、HTTP 応答、順次イベント、複数 assertion の組み合わせなど、観測はもっと多様。

2. `value or expression` 中心の観測観
   - 観測差分は必ずしも単一の値や式で表現できない。
   - たとえば termination behavior、resource cleanup、mutation order、idempotence などは、もっと広い振る舞い記述が必要。

3. 単体テスト的な oracle 前提
   - 「assertion における observed value/state」という表現は、xUnit 系のユニットテストに寄った発想であり、スナップショットテスト、プロパティテスト、システムテスト、承認テスト、差分比較型テストには少し窮屈。

このため、明示的な固有識別子違反はないが、**提案文言はテスト oracle の形をやや狭く仮定している**。
R1 汎化性の観点では軽微ではあるが無視できない懸念である。

---

## 6. 全体の推論品質がどう向上すると期待できるか

期待できる改善はある。
特に以下は妥当な期待値である。

- 「経路は追ったが、最終観測が本当に同じかを言語化していない」タイプの雑な EQUIVALENT を減らす
- compare で call-path と test outcome の間をつなぐ説明密度を上げる
- subtle difference dismissal への注意を、より観測可能な形に落とし込む

一方で、改善量は提案者の主張ほど全面的ではない。
懸念は次の通り。

- 既存の compare にはすでに per-test trace と COUNTEREXAMPLE があり、NOT_EQUIVALENT への増分は限定的
- 追加文言が assertion-site value 記述のテンプレ埋めを誘発し、実質の検証より文面整形を増やす恐れがある
- 観測可能性の概念を狭く持ち込むと、例外・副作用・制御フロー差分などの重要ケースをかえって見落としうる

総合すると、

- 改善の方向性: 良い
- 提案文言の粒度: まだ粗い
- 実装した場合の純増効果: 中程度以下
- 回帰リスク: 低くはない（主に証拠種別固定による探索バイアス）

と評価する。

---

## 結論

この提案は「観測等価性を compare に持ち込む」という発想レベルでは評価できる。
しかし、現行の文案は

- failed-approaches.md の「証拠種別の事前固定」原則にかなり近く、
- EQUIVALENT 側に偏った効果しか実質期待しにくく、
- assertion/value-centric な表現が汎化性を少し損なっている

ため、そのまま採用するには弱い。

もし再提案するなら、`assertion` や `value or expression` を固定せず、もっと広く

- observable behavior
- test oracle における observed outcome
- externally visible effect relevant to the test

のような表現にして、証拠型を狭めない形で compare の Claim を精緻化する方がよい。

承認: NO（理由: 観測等価性を重視する方向性は妥当だが、提案文言が assertion/value という特定の証拠型を半固定化しており、failed-approaches.md の失敗原則に近い。実効効果も EQUIVALENT 側に偏り、NOT_EQUIVALENT 側では既存 COUNTEREXAMPLE 要件との重複が大きい。）
