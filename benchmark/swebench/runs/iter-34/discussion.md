# Iteration 34 — 監査ディスカッション

## 総評

提案の狙い自体は理解できる。SKILL.md の Guardrail #4 は現在も「差分を見つけたら少なくとも1つの relevant test を trace せよ」と要求しているが、proposal はそこに「no impact と言うには、差分経路を実際に通る concrete test を特定し、両変更で assertion outcome が同一であることまで確認せよ」という明示条件を足そうとしている（proposal.md:43-45）。

これは「差分を雑に無害扱いするな」という方向では妥当だが、監査上は次の問題がある。

1. 既存の compare テンプレートが許している「その差分を通る test が存在しないことを検索で示して EQUIVALENT を支える」経路を、実質的に塞いでしまう。
2. その結果、改善効果は主に false EQUIVALENT 抑制に偏り、NOT_EQUIVALENT 側にはほぼ直接効かない。
3. failed-approaches.md が禁じる「証拠種類の事前固定」「既存チェックへの補足に見えて実質ゲートを増やす」方向にかなり近い。
4. 汎化性の観点では内容自体は比較的一般的だが、proposal 文面には厳格読みにおいてルール違反とみなし得る具体的な文言引用・行参照が含まれている。

以上から、現時点では承認しない。

---

## 1. 既存研究との整合性

### 参照 URL と要点

1. https://arxiv.org/abs/2603.01896
   - Agentic Code Reasoning 論文。README.md:9-11 および docs/design.md:5-8, 33-40 と整合的に、semi-formal reasoning のコアは「explicit premises」「execution path tracing」「formal conclusion」であり、テンプレートは証明書のように unsupported claim を防ぐ、という立場。
   - この意味では proposal の「no impact の根拠を明示化したい」という発想自体は研究の方向性と整合する。

2. https://en.wikipedia.org/wiki/Regression_testing
   - 回帰テストの基本目的は「変更後も従前の期待動作が保たれるか」を確認すること。特定の変更について、既存テストの pass/fail や assertion outcome を比較する考え方は自然。
   - proposal が assertion outcome の同一性を重視する根拠にはなる。

3. https://en.wikipedia.org/wiki/Test_oracle
   - テストオラクルは expected result を与える仕組みであり、regression test suites は derived test oracle の一種と説明されている。
   - したがって「assertion outcome が同一か」を見ること自体は一般的な testing 原理に沿う。

4. https://en.wikipedia.org/wiki/Observational_equivalence
   - 観測可能な含意が区別不能であることが equivalence の本質であり、プログラミング言語文脈でも「すべての context で同じ value」を返すかが焦点。
   - 重要なのは、equivalence は本来「観測可能な差がないこと」であって、「必ず差分経路を実際に通る concrete test が1つ存在すること」ではない。ここが proposal の狭すぎる点である。

### 整合性評価

研究全体の方向性とは「部分整合」である。

- 整合する点:
  - unsupported な no-impact 判断を減らしたい。
  - テスト assertion を観測可能挙動の代理として扱う。
  - compare モードの証拠水準を上げたい。

- 整合しない/ずれる点:
  - 現行 SKILL は compare において、relevant tests の特定（SKILL.md:171-178）と、counterexample search / no-counterexample search（SKILL.md:232-238）を両方許す設計になっている。
  - Step 5 でも「No test exercises this difference」と言うなら、そのような test があるはずのパターンを述べ、まさにそのパターンを search せよと書かれている（SKILL.md:116-119）。
  - proposal の新条件 (a) は、差分経路を実際に exercise する concrete test の存在を no-impact の必要条件にしてしまうため、現行設計の「exercise する test が存在しないことを示す」ルートと衝突する。

結論として、研究コアとの整合性はあるが、現行テンプレートの設計意図にはやや逆行している。

---

## 2. Exploration Framework のカテゴリ選定は適切か

proposal は Objective.md の Category E「表現・フォーマットを改善する」を選んでいる（proposal.md:3-19, Objective.md:163-170）。

この分類は形式上は妥当。

- ステップ順序変更ではないので A ではない。
- 情報取得方法の直接変更でもないので B 主体ではない。
- 比較単位の変更でもないので C ではない。
- 新しい self-check 項目の追加だと D 寄りだが、proposal は Guardrail 文言の追記として実施しようとしている。
- したがって「曖昧な指示をより具体的にする」という E の説明には確かに乗る。

ただし、実効としては E に見えて D 的に働く。

理由は、追加文が単なる言い換えではなく、no-impact conclusion のための二要件
- (a) concrete test が differing path を exercise する
- (b) assertion outcome が両変更で identical
を新たな必要条件として導入しているためである（proposal.md:43-45）。

つまりカテゴリラベルは E で説明可能だが、作用としては「メタ判断の新ゲート追加」に近い。ここは監査上の重要懸念点。

---

## 3. EQUIVALENT 判定と NOT_EQUIVALENT 判定の両方への作用

### 変更前との差分

変更前の Guardrail #4:
- semantic difference を見つけたら、difference has no impact と結論する前に、少なくとも1つの relevant test を differing code path まで trace する（SKILL.md:456-456）

変更後 proposal:
- さらに no-impact conclusion には
  - concrete test の特定
  - その assertion outcome が両変更で identical であることの確認
  を要求する（proposal.md:43-45）

### EQUIVALENT への作用

主作用はここに出る。

良い面:
- semantic difference を見つけたのに「たぶん同じ」と雑に丸める false EQUIVALENT を減らす可能性はある。
- 特に、test trace はしたが assert まで詰めない、という浅い分析には効く。

悪い面:
- 現行 compare テンプレートでは、EQUIVALENT を主張する際に「counterexample があるならこういう test のはず」と具体化し、その pattern を search して見つからないことを示す道がある（SKILL.md:232-238）。
- proposal はその道を実質的に弱める。差分経路を exercise する concrete test が無いケースでは、no-impact conclusion を出せなくなるからである。
- しかしそれは compare の本旨とズレる。D2 では pass-to-pass tests は「changed code lies in their call path」のときだけ relevant であり（SKILL.md:174-178）、差分が relevant tests に reach しないなら、それもまた equivalence の重要な根拠である。

したがって EQUIVALENT 側では
- false EQUIVALENT は減るかもしれない
- その代わり、正しい EQUIVALENT を出せるケースまで狭め、 unnecessary な NOT_EQUIVALENT/LOW CONFIDENCE/未決着を増やすリスクがある

### NOT_EQUIVALENT への作用

こちらへの直接効果はかなり弱い。

- NOT_EQUIVALENT を出すには、もともと compare テンプレートが counterexample と diverging assertion を要求している（SKILL.md:226-230）。
- proposal の追加条件は「no impact conclusion」の条件なので、主に EQUIVALENT 側の証明条件を重くするだけで、NOT_EQUIVALENT 側の証明力はほぼ増やさない。
- せいぜい、差分を軽率に無害扱いしなくなることで、間接的に NOT_EQUIVALENT を拾いやすくなる程度。

### 片方向性の判定

はい。実効的にはかなり片方向である。

- 強く作用するのは EQUIVALENT 側
- NOT_EQUIVALENT 側への直接改善は限定的

監査観点では、これは「両方向の推論品質改善」ではなく「EQUIVALENT 側の判定閾値を引き上げる変更」に近い。

---

## 4. failed-approaches.md の汎用原則との照合

proposal 自身は非抵触と主張しているが（proposal.md:82-91）、私はそうは見ない。

### 原則1: 「次の探索で探すべき証拠の種類をテンプレートで事前固定しすぎる変更は避ける」

抵触懸念あり。

proposal は no-impact conclusion のための証拠を
- differing path を exercise する concrete test
- assertion outcome identical
に固定している。

これは「何をもって no impact とみなすか」の証拠タイプをかなり狭く前固定している。現行 SKILL は
- relevant test を trace する
- もし no test がその差分を exercise しないなら、その不在を search で示す
という、より広い証拠経路を認めている。proposal はその幅を狭める。

### 原則2: 「探索の自由度を削りすぎない」

抵触懸念あり。

差分の無害性を示す方法を「実際に差分経路を通る concrete test の assertion 同一性」に寄せると、構造差分や call-path 不在の確認から EQUIVALENT を支える経路が細る。これは探索順序の固定ではないが、探索の出口を狭める変更である。

### 原則3: 「局所的な仮説更新を、即座の前提修正義務に直結させすぎない」

これは直接は抵触しない。

proposal は premise 管理や hypothesis update の義務を増やしていないため、この点は大きな問題ではない。

### 原則4: 「結論直前の自己監査に、新しい必須のメタ判断を増やしすぎない」

かなり近い。

proposal は Step 5.5 に項目追加していないので形式上は self-check 追加ではない。しかし実質的には、no-impact conclusion 前に
- concrete test の存在確認
- assertion 同一性確認
を必須化している。

failed-approaches.md:18-20 が警戒している「既存チェック項目への補足に見える形でも、結論前に特定の検証経路を半必須化すると、実質的に新しい判定ゲートとして働きやすい」にほぼ該当する。

### 小結

failed-approaches との照合結果は「全面非抵触」ではない。むしろ主要2原則 + 実質ゲート追加の原則に抵触懸念がある。

---

## 5. 汎化性チェック

### 明示的な固有性/違反表現の有無

厳格に見ると、proposal には以下が含まれる。

- SKILL.md の具体的な行番号参照（proposal.md:33, 97-101）
- 変更前後の文言の直接引用ブロック（proposal.md:35-45）
- Step 5.5 という内部参照（proposal.md:89）
- 具体的な文字数/行数の記述（proposal.md:47-55）

ここで、監査観点 5 は「提案文中に具体的な数値 ID, リポジトリ名, テスト名, コード断片が含まれていないか。含まれていればルール違反」としている。

- リポジトリ名: なし
- テスト名: なし
- ベンチマーク case ID: なし
- コード断片: あり（少なくとも変更前後の文言引用は strict reading では該当しうる）
- 具体的数値参照: あり（行番号・変更行数など）

ただし、公平のため補足すると、Objective.md の R1 では「SKILL.md 自身の文言引用」は overfitting の減点対象外と明記されている（Objective.md:202-213）。よって overfitting の証拠としては弱い。

それでも、今回の監査指示の文言を厳格に適用するなら、proposal は完全クリーンではない。少なくとも「コード断片ゼロ」とは言えない。

### 暗黙のドメイン依存の有無

提案内容は特定言語・特定フレームワーク・特定テストランナーを明示的には想定していない。assertion outcome, relevant test, differing path という語彙も一般的で、Python/Java/Django 等への露骨な依存はない。

ただし暗黙には
- 既存テストがあり
- call path と assertion の対応が静的にある程度追える
- test oracle が assertion ベースで表現される
という環境を想定している。

これは大半の compare タスクでは自然だが、テストが sparse、indirect、property-based、snapshot-based、or multi-stage harness の場合にはやや相性が悪い。つまり一般性は中程度で、最大限ではない。

---

## 6. 全体の推論品質がどう向上すると期待できるか

限定的な向上は期待できる。

期待できる改善:
- semantic difference を見つけた後の雑な no-impact 判断の抑制
- trace が assertion まで届いていない浅い compare 分析の抑制
- 「テストを見た」だけで終わる説明不足の減少

一方で予想される悪化/副作用:
- no-impact を示す証拠ルートを狭めるため、正しい EQUIVALENT を出しにくくなる
- difference が test-relevant でないことを search で示す既存の refutation style と衝突する
- compare の一部ケースで、必要以上に concrete test 依存となり、構造差分・非到達性・coverage absence の論証が弱化する
- 「明確化」に見えて、実質的には新たな判定ゲートとなるため、複雑性と保守負荷をわずかに増やす

総合すると、「false EQUIVALENT 抑制」という局所品質は少し上がるかもしれないが、「compare モード全体のバランスのよい推論品質向上」とまでは言いにくい。

---

## 結論

この提案は、問題意識自体は妥当であり、研究コアとも完全には矛盾しない。しかし、実際の文言追加は単なる具体化ではなく、no-impact conclusion の許容根拠をかなり狭める。現行 SKILL が持っている
- relevant tests の call-path relevance に基づく判断
- 「その差分を exercise する test がない」ことの検索ベース証明
という経路と衝突し、効果も主に EQUIVALENT 側へ片寄る。

さらに、failed-approaches.md の
- 証拠種類の事前固定を避ける
- 既存チェック補足に見えて実質ゲートを増やさない
という原則への抵触懸念がある。

したがって、現提案のままでは承認しない。

承認: NO（理由: 「no impact」の証拠を『差分経路を実際に通る concrete test の両変更での同一 assertion outcome 確認』に狭めており、現行 compare テンプレートが許容する『その差分を exercise する relevant test が存在しないことを検索で示す』経路を阻害するため。結果として EQUIVALENT 側へ片方向に強く作用し、failed-approaches の禁止原則にも近い。また、監査観点 5 の厳格読みにおいては proposal 内の具体的文言引用・数値参照も完全にはクリーンでない。）