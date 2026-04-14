# Iteration 49 — Discussion

## 総論
提案の狙い自体は理解できる。外部ライブラリや未取得ソースに遭遇した際、`test usage first` だけでは実行手続きが曖昧で、探索者が十分に証拠収集しないまま `UNVERIFIED` を維持して結論へ進む、という問題意識は妥当である。

ただし、今回の文言追加は「探索手続きを少し具体化する」だけでなく、実質的には「まず direct call しているテストを探す」という探索経路の半固定化を起こしている。これは汎用性の観点では危うい。テストが対象関数を直接呼ばず、ラッパー、統合経路、設定、fixture、parametrize、matcher、snapshot などを通して振る舞いを規定しているコードベースでは、この追記は効果が薄いか、むしろ探索を狭める。

したがって、方向性は理解できる一方、提案文の現在の粒度では承認しにくい。

---

## 1. 既存研究との整合性

### 参照した外部資料
1. Agentic Code Reasoning
   - URL: https://arxiv.org/abs/2603.01896
   - 要点: 半形式的推論の中心は、明示的前提・実行経路トレース・形式的結論という「証明書」的構造にある。結論の正しさは、探索の構造化と反証可能性で支えられる。したがって、証拠収集手続きの明確化自体は研究の方向性と整合する。

2. The Debugging Book — Introduction to Debugging
   - URL: https://www.debuggingbook.org/html/Intro_Debugging.html
   - 要点: デバッグは系統的なプロセスとして扱うべきであり、症状や期待動作を具体化しながら検証することが重要である。曖昧な当て推量より、観察可能な挙動に結びつく証拠を集める方針は支持される。

3. Martin Fowler — Specification by Example
   - URL: https://martinfowler.com/bliki/SpecificationByExample.html
   - 要点: テストや例は、実装とは別表現の「ダブルチェック」として振る舞う。したがって、テストの assertion を読むことを二次証拠として重視する発想は妥当である。

### 整合性の評価
- 良い点:
  - 「テスト usage を見る」を「assertion を読む」まで具体化するのは、テストを単なる参照箇所ではなく behavioral evidence として扱うという点で妥当。
  - `UNVERIFIED` のまま推測で埋めない、という既存の Guardrail とも整合する。

- 懸念点:
  - 上記文献はいずれも「観察可能な証拠を重視する」ことは支持するが、「対象関数を直接 call しているテストをまず探す」ことまでは支持していない。
  - 研究コアが支持するのは探索の構造化であって、探索経路の過度な狭窄ではない。ここは区別すべき。

結論として、assertion 重視は研究整合的だが、`find tests that call this function` という direct-call 指向は研究からは十分に根拠づけられていない。

---

## 2. Exploration Framework のカテゴリ選定は適切か

提案はカテゴリ B「情報の取得方法を改善する」に属する、という整理自体は概ね妥当である。特に B-2「何を探すかではなく、どう探すかを改善する」に近い。

ただし厳密には、これは B-2 純粋形というより B-1/B-2 の境界にある。
- B-2 的側面: `test usage first` を実行可能な探索手続きへ近づけている。
- B-1 的側面: 読み方の具体化、すなわち「usage を見たら assertion まで読め」という読解指示になっている。

したがって、カテゴリ B 自体は不適切ではないが、提案文が主張するほど「B-2 にしか属さない」とまでは言いにくい。

---

## 3. EQUIVALENT / NOT_EQUIVALENT の双方への作用

### 変更前との実効差分
変更前:
- 二次証拠の優先順位のみを与える。
- `test usage first` はあるが、どのように test usage を見つけ、何を読めばよいかは曖昧。

変更後:
- 「その関数を呼び出しているテストを見つける」
- 「その assertion を読む」
という探索手続きが追加される。

### EQUIVALENT 判定への作用
正の作用:
- 未取得ソース関数について、テスト assertion を behavioral evidence として読める場合、`UNVERIFIED` 依存のまま EQUIVALENT を言う危険は減る。
- 「実際に何が観測されるか」を assertion から拾えるため、結論の根拠が明確になる。

負の作用:
- EQUIVALENT 判定では「反例がない」ことの確認が重要だが、direct-call テスト探索だけでは探索範囲が狭い。
- 対象関数が wrapper 経由・統合経路経由でのみ観測される場合、direct-call テストが見つからないことをもって証拠探索が終わったように感じやすい。
- その結果、EQUIVALENT 側では「広く反証可能性を確かめる」より「直接呼ぶテストがないから判断材料が少ない」という停滞に陥るおそれがある。

### NOT_EQUIVALENT 判定への作用
正の作用:
- もし direct-call テストが存在し、その assertion が差分を直接露出していれば、counterexample 発見は速くなる。
- とくに unavailable source の振る舞い差分がテストで明示されている場合は有効。

負の作用:
- 実際の NOT_EQUIVALENT は、低レベル関数への direct test ではなく、上位 API や end-to-end テストで露出することも多い。
- direct-call 探索に寄ると、そのような間接的反例を見逃す可能性がある。

### 双方向性の判定
この変更は理論上は両方向に作用するが、実効的には対称ではない。
- NOT_EQUIVALENT: direct-call テストがあれば恩恵が出やすい。
- EQUIVALENT: 「反例不在」を支えるには探索の広さが必要で、direct-call 指向はむしろ相性が悪い。

つまり、片方向専用ではないが、片方向優位のバイアスを持ちうる。提案文は「両方向に効く」と述べているが、その対称性はやや楽観的である。

---

## 4. failed-approaches.md の汎用原則との照合

### 原則 1: 証拠の種類をテンプレートで事前固定しすぎない
抵触の懸念あり。

今回の追記は表面上は「test usage の探し方の明確化」だが、実質的には
- direct-call しているテスト
- assertion を読む
という特定シグナルへの寄せを含む。

assertion を読むこと自体はよいが、`call this function` が入ることで、「その関数を直接呼ぶテスト」という証拠類型に探索が寄る。これは failed-approaches の第一原則にかなり近い。

### 原則 2: 探索の自由度を削りすぎない
抵触の懸念あり。

提案者は「探索順序は変えていない」と述べるが、実際には順序よりも探索経路を狭めている。二次証拠としての test usage は本来、
- direct call
- indirect exercise
- wrapper 経由
- integration test
- regression test
など幅広く読める。

そこを `call this function` に狭めると、探索自由度の低下が起こる。

### 原則 3: 既存ガードレールを特定追跡方向で具体化しすぎない
部分的に抵触の懸念あり。

変更箇所は Guardrails ではなく Step 4 だが、実効としては「third-party source unavailable のときはまず direct-call テストを探す」という方向付けを強める。failed-approaches は、場所ではなく効果を問題にしているので、ここは安全とは言い切れない。

### 総合判断
提案は failed-approaches の禁止事項を明確に踏み抜いているとまでは言えないが、かなり近い。少なくとも「表現を変えただけで本質的には探索経路の半固定化」である懸念は強い。

---

## 5. 汎化性チェック

### 明示的ルール違反の有無
- 具体的なベンチマークケース ID: なし
- 特定リポジトリ名: なし
- 特定テスト名: なし
- ベンチマーク対象コード断片の引用: なし

提案文にあるコードブロックは SKILL.md 自身の変更前後引用であり、Objective の R1 注記に照らしても直ちに違反とは言えない。

したがって、明示的なルール違反は認めない。

### 暗黙のドメイン仮定
ただし、暗黙の仮定はある。
- テストが検索可能な形で存在する
- テストが対象関数を直接呼ぶ
- assertion が期待動作を明示している
- unit-test 的構造が主である

これらはすべての言語・フレームワーク・プロジェクトでは成り立たない。
特に次のような環境では弱い。
- 統合テスト中心
- snapshot / golden test 中心
- property-based testing
- generated tests
- assertion が helper に隠蔽されるテスト設計
- DSL や設定駆動で behavior が表現されるコードベース

よって、明示的 overfitting ではないが、暗黙には「直接呼ぶ単体テストがあるコードベース」へやや寄っている。

---

## 6. 全体の推論品質への期待効果

### 期待できる改善
- `test usage` を単なる参照検索で終えず、behavioral evidence として読む意識は強まる。
- unavailable source に遭遇した際の証拠収集が少し具体化され、`UNVERIFIED` 放置を減らす可能性はある。
- assertion を読む、という補足自体は推論の質を上げる方向。

### 限界と回帰リスク
- 改善幅は direct-call テストがある場合に偏る。
- direct-call 指向が強すぎるため、間接利用や上位経路からの証拠拾いを阻害しうる。
- その結果、「探索を少しよくする」よりも「探索を少し狭める」効果が先に出るおそれがある。

### より安全な方向性
もし同じ狙いを維持するなら、より汎用的な文言は例えば以下に近い。
- `test usage first (find tests that exercise this call path and read the assertions that constrain its behavior)`

この表現なら、assertion を読むという利点を保ちつつ、direct-call 前提を外せる。

---

## 最終判断
承認: NO（理由: assertion を読むという方向は妥当だが、`find tests that call this function` は探索経路を direct-call テストへ過度に寄せており、failed-approaches.md の「証拠種類の事前固定」「探索自由度の削減」に近い。EQUIVALENT/NOT_EQUIVALENT の両方に対して対称に効くとは言い難く、汎用原則としてはまだ狭すぎる。）
