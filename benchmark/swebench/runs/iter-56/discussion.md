# Iter-56 Discussion

## 総評

提案の中心アイデア自体は妥当です。つまり、「差異がある」という事実と「既存テストの pass/fail が変わる」という結論の間に、
- その差異はテスト経路に到達するのか
- 到達しても観測可能な差を生むのか

という中間層を置く発想は、比較推論の品質改善として自然です。

ただし、今回の具体的な実装案（STRUCTURAL TRIAGE に S4 を追加し、3分類を必須化し、しかも "Only class (c) justifies NOT EQUIVALENT" と書く案）は、その良い発想をやや強すぎるテンプレート義務として固定しており、既存の failed-approaches.md の警告に部分的に接触しています。とくに placement と wording がよくありません。

以下、監査観点ごとに述べます。

---

## 1. 既存研究との整合性

### 1-1. Agentic Code Reasoning 論文との整合性
- URL: https://arxiv.org/abs/2603.01896
- 要点:
  - 論文の主張は、明示的 premise、コード経路 tracing、formal conclusion を要求する semi-formal reasoning が、patch equivalence を含む複数タスクで精度を上げる、というもの。
  - README.md と docs/design.md でも、このスキルのコアは「番号付き前提」「仮説駆動探索」「手続き間トレース」「必須反証」にあると整理されている。
- 整合性評価:
  - 今回提案している reachability / observability の明示化は、論文のコアを壊す方向ではない。
  - むしろ「差異を見つけても即結論に飛ばず、証拠の粒度を一段増やす」という意味では、論文の certificate 的発想に沿っている。
  - ただし論文が推しているのは per-test tracing と counterexample obligation であって、triage 段階での固定3分類そのものではない。したがって「発想は整合」「実装位置は論文から直接は強く支持されない」という評価になる。

### 1-2. Observational equivalence との整合性
- URL: https://en.wikipedia.org/wiki/Observational_equivalence
- 要点:
  - 観測可能な含意が同一なら、内部構造が異なっても区別できない、という考え方。
  - プログラミング言語意味論でも、すべての文脈で同じ observable value を返すなら observationally equivalent とみなす考え方がある。
- 整合性評価:
  - 提案中の「REACHABLE だが identical observable outputs」は、まさに観測可能差分に注目する観点であり、概念としては筋が良い。
  - ただし SKILL.md の compare が定義しているのは「既存テストに対する pass/fail outcome の同一性」であり、一般的な observational equivalence よりも狭い。したがって "observable outputs" という語は少し広すぎる。
  - ここは「test-relevant observable outcome」または「assertion-relevant behavior」くらいまで絞らないと、意味論的概念と benchmark 上の判定基準がずれる恐れがある。

### 1-3. Regression testing / change impact analysis との整合性
- URL: https://en.wikipedia.org/wiki/Regression_testing
- 要点:
  - 変更後に再実行すべきテストを考えるとき、change impact analysis により適切な subset を選ぶ、という考え方がある。
  - つまり「変更がどのテストに影響しうるか」を考えるのは一般的な発想。
- 整合性評価:
  - 差異の reachability を確認する、という発想は regression testing の change-impact 的な考え方と整合的。
  - ただし regression testing は通常「どのテストを走らせるか」の問題であり、今回の compare は「既存テスト outcome が等価か」を静的に推論する問題。関連はあるが、そのままテンプレート義務化の正当化にはならない。

### 1-4. Program slicing / local reasoning との整合性
- URL: https://en.wikipedia.org/wiki/Program_slicing
- 要点:
  - program slicing は、ある観測点の値に影響しうる statement 集合を追う考え方。
- URL: https://arxiv.org/abs/1907.01257
- 要点:
  - observational equivalence の fragility を local reasoning によって扱う、という方向性がある。
- 整合性評価:
  - 「差異が assertion に効く経路へ届くか」を見る提案は、slicing 的・impact-analysis 的な発想として一般論に沿っている。
  - したがって改善仮説の基礎概念は妥当。
  - しかし、それを STRUCTURAL TRIAGE の固定三択に落とすところまでは、既存研究から強く導かれていない。

結論として、研究との整合性は「概念レベルでは良い、具体 wording/placement は弱い」です。

---

## 2. Exploration Framework のカテゴリ選定は適切か

### 判定
概ねカテゴリ C でよいが、純粋な C だけではなく B/D の成分も混ざっています。

### 理由
Objective.md のカテゴリ C は「比較の枠組みを変える」であり、その例として
- 比較粒度の変更
- 差異重要度の段階評価
- 変更分類

が挙がっています。

今回の提案は、差異を
- 到達不能
- 到達するが観測同値
- 到達し観測差分あり

に分けるので、たしかに「差異重要度の段階評価」に属します。この意味ではカテゴリ C の選択は妥当です。

ただし実際には、単なる比較枠組み変更に留まらず、
- 何を確認すべきかを reachability / observability にかなり強く寄せる（カテゴリ B 的）
- triage 段階で新しい必須分類判断を追加する（カテゴリ D 的）

という性質もあります。

したがって「C を選んだこと自体は適切だが、提案の実体は C の中でもかなり強い強制」であり、カテゴリ名の穏当さに比して実装案の拘束力が大きい、という見立てです。

---

## 3. EQUIVALENT 判定と NOT_EQUIVALENT 判定の両方にどう作用するか

### 3-1. EQUIVALENT 側への作用
これは比較的明確にプラスです。

現状では、semantic difference を見つけた瞬間に「何か違うなら NOT EQUIVALENT では」と短絡する余地があります。提案の S4 は、その間に
- テスト経路に乗らない差異
- テスト経路に乗るが既存 assertion に差を出さない差異

という中間状態を明示するため、過剰 NOT_EQUIVALENT を減らす方向に働く可能性が高いです。

つまり EQUIVALENT の精度改善仮説としてはかなり自然です。

### 3-2. NOT_EQUIVALENT 側への作用
ここは提案文ほど自明ではありません。

提案文は、「REACHABLE and producing divergent outputs」を class (c) として強調することで、差異の軽視による誤 EQUIVALENT も減ると述べています。これは理屈としては分かります。

しかし実務上は逆方向のリスクもあります。

1. agent が reachability を早い段階で浅く見積もると、class (a) に逃がしてしまう可能性がある
2. agent が "observable outputs" を狭く解釈すると、assertion へ最終的に波及する差異を class (b) に誤分類する可能性がある
3. "Only class (c) justifies NOT EQUIVALENT" という表現が強すぎ、既存の S1/S2 structural gap による早期 NOT_EQUIVALENT と緊張する

特に 3 点目は重要です。compare の定義 D1 は「既存テストの pass/fail outcome が異なるか」です。したがって NOT_EQUIVALENT を支えるべきなのは本来「差異そのもの」ではなく「異なる test outcome を導く反例」です。class (c) はその補助概念であって、独立の判定ゲートとして強く書くと、S1/S2 と D1 の間に二重基準を作ります。

### 3-3. 変更前との実効的差分
変更前:
- semantic difference を見つけたら、Guardrail #4 により relevant test を trace せよ、という要求はすでにある
- compare template では per-test analysis と counterexample/no-counterexample が最終的な判定根拠

変更後提案:
- semantic difference を見つけた時点で、まず triage 内で 3 クラスに分類することを要求
- class (c) だけを NOT_EQUIVALENT の正当化条件として前景化

この差分は、「新しい概念を導入した」だけではなく、「差異発見後の思考順序を半固定化した」点が本質です。

### 3-4. 片方向にしか作用しないか
はい、実効的には EQUIVALENT 側に強く、NOT_EQUIVALENT 側には弱い、あるいは場合によってはマイナスです。

- EQUIVALENT 側: 明確に benefit がある
- NOT_EQUIVALENT 側: benefit はあるが、誤って class (a)/(b) に倒す新しい逃げ道も作る

したがって「両側に同程度に効く」とまでは言いにくいです。少なくとも対称ではありません。

---

## 4. failed-approaches.md の汎用原則との照合

### 4-1. 「探すべき証拠の種類をテンプレートで事前固定しすぎない」
部分的に抵触します。

提案文では S4 が
- NOT_REACHABLE
- REACHABLE but identical observable outputs
- REACHABLE and divergent outputs

の 3 種を必須分類として与えます。これは「どの差異を探すか」までは固定していないものの、差異発見後に集めるべき証拠の種類をかなり強く reachability / observability に寄せています。

これは軽微な抵触ではなく、failed-approaches.md の最初の警告にかなり近いです。

### 4-2. 「探索の自由度を削りすぎない」
これも部分的に抵触します。

提案の三段階
- 差異がある
- テスト経路に乗るか
- どの assertion に影響するか

は、もっともらしい一方で、差異評価の探索順序を実質的に固定します。failed-approaches.md は、読解順序や境界確定の半固定でも探索幅を狭めうると警告しています。

今回の案はまさに「差異発見後はこの順で考えよ」を triage に埋め込むため、この原則に近づいています。

### 4-3. 「既存の汎用ガードレールを特定の追跡方向で具体化しすぎない」
ここが最も懸念です。

既存 Guardrail #4 は方向非依存で、
- subtle difference を dismiss するな
- relevant test を trace せよ

とだけ要求しています。

提案 S4 はこれを
- reachability
- observability
- divergence

という特定方向の枠に落とし込んでいます。これは failed-approaches.md が避けるべきとした「特定の追跡方向の半固定」にかなり近いです。

### 4-4. 「結論直前の自己監査に新しい必須メタ判断を増やしすぎない」
この点については、提案文の自己評価どおり、直前自己監査の肥大化ではありません。場所は STRUCTURAL TRIAGE なので、この原則には直接は抵触しません。

### 小結
failed-approaches.md との照合結果は、「完全適合」ではありません。少なくとも以下 2 点で再演リスクがあります。

- 証拠種類の事前固定
- 特定追跡方向の具体化

提案文の自己評価は甘めです。

---

## 5. 汎化性チェック

### 5-1. 具体的な数値 ID / リポジトリ名 / テスト名 / コード断片の有無
判定: 明確なルール違反は見当たりません。

確認結果:
- ベンチマークケース ID: なし
- 特定リポジトリ名: なし
- 特定テスト名: なし
- ベンチマーク対象コード断片: なし

提案文に含まれる
- S1/S2/S3/S4
- Guardrail #4
- ~200 lines
- 4 lines / 5 lines

といった数値やラベルは、SKILL.md 自体の構造や diff 制約の自己参照であり、Objective.md の R1 でも減点対象外に近い扱いです。したがってこれ自体を overfitting の証拠とは見ません。

### 5-2. 暗黙のドメイン依存性
大きな問題はありませんが、少しだけ注意点があります。

- "relevant test path"
- "observable outputs"
- "which assertion it affects"

という表現は、ユニットテスト中心・assertion 中心の発想をやや強く前提しています。

ただし compare モード自体が「既存テスト outcome」を基準にする設計なので、この程度は許容範囲です。少なくとも特定言語・特定フレームワーク・特定テストパターンにしか効かない表現ではありません。

### 5-3. 総合評価
汎化性そのものは比較的良好です。問題は overfitting というより、汎用テンプレートとして強制が強すぎる点です。

---

## 6. 全体の推論品質がどう向上すると期待できるか

### 期待できる改善
- semantic difference を見つけた瞬間の premature NOT_EQUIVALENT を減らせる
- compare における「差異はあるが test outcome は同じ」という中間状態を言語化できる
- per-test tracing と counterexample obligation の間に、差異の test relevance を明示する補助レイヤーを置ける

この意味で、狙っている failure mode は理解でき、改善方向も合理的です。

### ただし現行提案のままでは懸念が残る点
- STRUCTURAL TRIAGE に入れるには重すぎる
- semantic difference を見つける前提と、その reachability/observability を各差異について分類する前提が、triage としては負荷が高い
- "Only class (c) justifies NOT EQUIVALENT" が強すぎ、D1 と S1/S2 の既存基準を曖昧にする
- 既存 Guardrail #4 の direction-agnostic な良さを、reachability 中心の one-track 手順に狭める恐れがある

要するに、改善したい問題設定は正しいが、テンプレート化の仕方が強すぎます。

---

## 最終判断

承認: NO（理由）

理由:
1. 発想自体は妥当だが、STRUCTURAL TRIAGE への固定3分類追加は強制力が強すぎる
2. failed-approaches.md の「証拠種類の事前固定」「特定追跡方向の具体化」に部分的に再接近している
3. 効果は主に EQUIVALENT 側で、NOT_EQUIVALENT 側への改善は対称ではない
4. "Only class (c) justifies NOT EQUIVALENT" という文言が、既存の D1（test outcome 基準）および S1/S2（structural gap による早期 NOT_EQUIVALENT）と緊張する

したがって、この提案は「reachability / observability を比較補助観点として導入する」というレベルなら再検討の価値がありますが、今回の wording / placement のままでは承認しません。