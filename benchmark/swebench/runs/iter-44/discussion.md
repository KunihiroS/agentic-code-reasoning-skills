# Iter-44 Discussion

## 監査結論

現案は「差異の存在」から一歩進めて「その差異がテスト上の観測可能な差になるか」を問おうとしており、狙い自体は妥当です。しかし、提案された具体文言 `Difference reaches a test assertion` は比較対象を「assertion 到達」に狭めすぎています。既存の `compare` 定義はテストの pass/fail outcome 全体を比較対象としているため（`SKILL.md` の D1/D2）、この文言は研究コアと完全には噛み合いません。

そのため、現状の文言のままでは承認しません。

## 1. 既存研究との整合性

### 参照した Web 情報

DuckDuckGo MCP の search エンドポイントでは今回複数回 `No results were found` が返り、検索結果一覧の取得はできませんでした。そのため、同じ DuckDuckGo MCP の fetch_content を用いて既知の公開 URL を取得し、整合性を確認しました。

1. https://arxiv.org/abs/2603.01896
   - 要点: Agentic Code Reasoning は、明示的 premises、execution-path tracing、formal conclusion を要求する semi-formal reasoning により、patch equivalence を含む複数タスクで精度改善を示している。
   - 含意: 今回の提案は「差異を見つけた後に、その差異が観測結果へ届くかを明示する」という方向なので、structured evidence chain を強める点では論文の精神に整合する。

2. https://en.wikipedia.org/wiki/Program_slicing
   - 要点: program slicing は、ある観測点の値に影響しうる文や依存関係を遡って特定する考え方であり、debugging や program analysis に使われる。
   - 含意: 「差異がどこに効くか」を観測点基準で絞る発想自体は一般的で、テスト観測点への到達性を問うことには理論的な自然さがある。

3. https://en.wikipedia.org/wiki/Change_impact_analysis
   - 要点: change impact analysis は、変更の結果どこに影響が及ぶかを dependency / traceability の観点から評価する。
   - 含意: 差異の重要度を、依存やトレースを通じて評価するという着眼は妥当。

4. https://en.wikipedia.org/wiki/Regression_testing
   - 要点: regression testing は変更後も既存機能が期待通りかを再確認するもので、ときに change impact analysis により適切なテスト部分集合を選ぶ。
   - 含意: 「差異の有無」だけでなく「その差異が既存テストの観測結果に影響するか」を問うのは regression testing の文脈でも自然。

5. https://en.wikipedia.org/wiki/Observational_equivalence
   - 要点: observational equivalence は、観測可能な含意が同一なら区別不能とみなす考え方。
   - 含意: compare モードの本質は内部差分の有無ではなく、既存テストから見た観測可能差分の有無にある。したがって「重要度」を問う方向は正しい。

### 研究整合性の評価

方向性は整合的です。特に `README.md` と `docs/design.md` が強調するのは、
- 明示的 premises
- per-item tracing
- mandatory refutation
- 観測可能な結果に基づく formal conclusion

であり、提案はこのうち「trace から観測結果までのつながり」を明文化しようとしています。

ただし問題は、提案文言が「observable test outcome」ではなく「test assertion」へ狭く固定している点です。論文・README・design が定義している compare の対象は test outcome であり、assert 文だけではありません。例外で途中失敗するテスト、fixture/setup 失敗、タイムアウト、フレームワーク側の失敗、`raises` 期待などは、必ずしも「assertion 到達」で表現できません。このため、研究のコアと完全整合とは言い切れません。

結論: 方向性は整合、文言は狭すぎる。

## 2. Exploration Framework のカテゴリ選定は適切か

提案者はカテゴリ C「比較の枠組みを変える」を選んでいます。これは概ね妥当です。

理由:
- 変更対象は `compare` モードの EDGE CASES 欄であり、探索順序そのものではない。
- 追加しようとしている判断軸は「差異の重要度評価」で、Objective.md のカテゴリ C の例示そのものに近い。
- `difference exists?` から `difference matters to observed test outcome?` へ比較粒度を変える発想なので、B や D より C の方が近い。

ただし副作用として、これはカテゴリ D 的な「必須の追加判断」にも少し踏み込みます。1 行追加ではあるものの、実質的には compare の各 edge case に対して新しい判定項目を増やします。そのため、C として妥当だが、D 的な複雑化リスクがゼロではありません。

## 3. EQUIVALENT 判定と NOT_EQUIVALENT 判定への作用

### 変更前との差分

現行テンプレートでは、EDGE CASES で求められているのは:
- Change A behavior
- Change B behavior
- Test outcome same: YES / NO

だけです（`SKILL.md` の EDGE CASES 節）。

一方、現行でも NOT_EQUIVALENT を結論する場合は、すでに COUNTEREXAMPLE 節で
- diverging assertion の特定
- 具体的な PASS/FAIL 分岐の記述

が要求されています（`SKILL.md` の COUNTEREXAMPLE 節）。

つまり、提案の実効差分は「差異が assertion に届くか」を COUNTEREXAMPLE より前、edge-case 記録段階で先に明示させる点です。

### EQUIVALENT への作用

ここへの効果は比較的大きいです。

期待できる改善:
- 小さな意味差や構造差を見つけた瞬間に `NOT EQUIVALENT` へ倒れるのを防ぎやすい。
- 「差異はあるが、既存テストの観測点には届かない」という説明が書きやすくなる。
- `README.md` にある observational な比較発想と整合する。

つまり、偽陽性の NOT_EQUIVALENT を減らし、EQUIVALENT 判定の精度を上げる方向には効きやすいです。

### NOT_EQUIVALENT への作用

ここへの追加効果は限定的です。

理由:
- 現行でも true NOT_EQUIVALENT を出すには、COUNTEREXAMPLE で diverging assertion を示す必要がある。
- したがって、提案が加えるのは本質的に新しい証拠義務というより「その義務を前倒しで意識させる」効果。

改善可能性はあるものの、EQUIVALENT 側ほど大きくはありません。

### 片方向にしか作用しないか

完全に片方向だけ、とは言いません。ただし実質的には非対称です。

- 主効果: false NOT_EQUIVALENT の抑制 = EQUIVALENT 側の改善
- 副効果: true NOT_EQUIVALENT の根拠を早めに整理 = NOT_EQUIVALENT 側にも少し寄与

よって、提案文の「両方向の精度が向上する」は言い過ぎです。正確には「両方向に理論上は寄与しうるが、主効果は EQUIVALENT 側」であり、左右対称の改善とは見なしにくいです。

さらに重要な懸念として、assertion 中心の文言は true NOT_EQUIVALENT を取りこぼす危険もあります。差異が
- assertion 実行前の例外
- setup/fixture の失敗
- timeout / hang
- framework-level failure

として現れる場合、「Difference reaches a test assertion: NO」でも test outcome は DIFFERENT になりえます。このため、文言次第では NOT_EQUIVALENT 側に回帰リスクがあります。

## 4. failed-approaches.md の汎用原則との照合

提案文は「すべて非抵触」と主張していますが、そこまでは言えません。限定的な緊張関係があります。

### 原則 1: 探索シグナルを事前固定しすぎない

軽度の抵触リスクがあります。

今回の追加は「差異を見たら assertion 到達性を見る」という特定の証拠型を新たに固定します。読解順序や探索開始点を固定するものではありませんが、compare における重要証拠を assertion-chain にやや寄せます。

ただし、compare の定義自体が test outcome 中心なので、完全に不適切とは言いません。問題は assertion という狭い語で固定している点です。もし `observable test outcome / test oracle` のような表現なら、この原則との緊張はかなり弱まります。

### 原則 2: 探索の自由度を削りすぎない

大きな抵触はありませんが、少し注意が必要です。

1 行追加なので探索順序や読み始めを縛るものではありません。ただし「差異の重要度」を assertion-chain でしか表現しにくくすると、差異の現れ方が assertion 以外であるケースを見落とす可能性があります。

### 原則 3: 局所仮説更新を前提修正義務に直結させすぎない

ほぼ非抵触です。今回の追加は premises 修正義務を増やしていません。

### 原則 4: 結論直前の自己監査に新しい必須メタ判断を増やしすぎない

形式上は Step 5.5 ではないので直接抵触ではありません。しかし compare の各 edge case に新しい必須欄を足すため、実質的には micro-gate です。規模が小さいので致命的ではないものの、「まったく非抵触」という提案者評価は甘いです。

総合すると、failed-approaches との関係は「非抵触」ではなく「小さな追加であるため許容可能だが、assertion への固定は原則 1 と 4 に軽い緊張がある」が正確です。

## 5. 汎化性チェック

### 明示的なルール違反の有無

提案文には以下は含まれていません。
- ベンチマーク対象リポジトリ名
- 特定テスト名
- ケース ID
- 対象リポジトリの実装コード断片

一方で、以下は含まれています。
- `SKILL.md` 内部の line 参照
- `SKILL.md` テンプレートの引用
- `file:line` といった一般表現

これらは提案対象である SKILL.md 自身の自己引用・差分指定であり、過剰適合の証拠とは言いません。したがって、この観点での明確なルール違反はありません。

### 暗黙のドメイン仮定

ここには懸念があります。

`Difference reaches a test assertion` という文言は、暗黙に以下を強く想定しています。
- テストの主要 oracle が明示的 assertion で表現される
- 差異の観測点が assertion line に集約できる
- pass/fail 差が assertion 到達性でうまく説明できる

しかし汎用的には、テストの観測可能差分は assertion 以外でも生じます。
- assertion 前例外
- framework matcher / context manager による成功失敗
- property-based test の反例検出
- snapshot / golden file 差分
- timeout / non-termination
- setup / teardown / fixture failure

よって、提案は benchmark 固有名詞では過剰適合していない一方で、テスト様式としては「assertion-centric unit test」にやや寄っています。これは汎化性の弱点です。

## 6. 全体の推論品質への期待効果

### 良い点

- 差異発見直後に「その差は本当に重要か」を問わせるため、浅い差分過大評価を抑える。
- `compare` モードで、観測可能差分までの証拠チェーンを前倒しで意識させる。
- 現行の `Test outcome same: YES / NO` より一段細かい中間表現になるため、EQUIVALENT 判定の説明品質は上がりやすい。

### 悪い点 / リスク

- 「assertion に届くか」が重要度評価の唯一の言語になると、observable outcome 全体より狭い。
- 既存の COUNTEREXAMPLE と役割重複があり、NOT_EQUIVALENT 側の純増効果は小さい。
- モデルが `file:line if YES` を満たせないときに、安易に `NO` と書いてしまうと false EQUIVALENT の温床になりうる。

### 総合評価

狙いは良いが、現文言は少し狭いです。改善したい本質は
「差異がある」ではなく
「その差異が既存テストの観測可能な oracle / outcome を変えるか」
を問うことです。

もしこの本質に合わせて文言を一般化できれば、全体推論品質への寄与は十分見込めます。

## 監査上の最終判断

現案のままでは不承認です。

主理由:
1. `assertion` への固定が compare の定義である test outcome より狭い。
2. 改善効果は主に EQUIVALENT 側で、提案文ほど対称ではない。
3. failed-approaches との関係を「完全非抵触」とする評価は甘い。
4. assertion 前例外や framework-level failure を扱いにくく、汎化性に穴がある。

### 承認判断

承認: NO（`Difference reaches a test assertion` が汎用比較基準として狭すぎ、observable test outcome 全体を表せていないため。主効果も EQUIVALENT 側に偏っており、提案理由の対称性主張は過大。）
