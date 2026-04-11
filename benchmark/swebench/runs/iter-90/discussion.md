# Iteration 90 — 監査コメント

## 総評

結論から言うと、この提案の狙い自体は妥当です。Step 4 の反事実トレース条件を「より一般の非自明制御フロー」に拡張したい、という問題意識は、README/設計文書が強調する「推論の飛躍を防ぐための構造化された検証」を強める方向にあります。特に、SKILL.md の現行文言が `exception handling inside loops or multi-branch control flows` に限定されているため、ループ外の例外処理や単純ループが trigger から漏れる、という指摘には合理性があります（SKILL.md:87-93）。

ただし、現提案には 1 点だけ無視できない懸念があります。提案は「拡張」だけでなく、同時に `multi-branch control flows` を `multi-branch conditionals` へ狭めています（proposal.md:43-45）。この narrowing は、提案本文の主張である「適用範囲の不足を補う」とは逆向きの差分であり、failed-approaches.md の「探索量の削減は常に有害」「変更の評価は変更前との差分で見よ」という原則に抵触するリスクがあります（failed-approaches.md:14-20）。

したがって、現行案のままの承認は難しく、"拡張部分だけを残し、 narrowing を含まない表現に直す" なら承認寄り、という評価です。

## 1. 既存研究との整合性

### DuckDuckGo MCP による調査

DuckDuckGo MCP の search エンドポイントで複数回検索を試みましたが、今回は結果が返らず、bot detection 由来と思われる失敗になりました。実行した検索例:
- `semi-formal reasoning code analysis explicit premises counterexample code reasoning paper`
- `counterfactual reasoning software debugging`
- `program comprehension exception handling control flow empirical`
- `Ugare Chandra 2603.01896`

そのため、DuckDuckGo MCP の fetch_content を用いて既知の研究 URL を直接取得しました。

1) https://arxiv.org/abs/2603.01896
- DuckDuckGo MCP で取得できた要点:
  - semi-formal reasoning は、明示的 premises、execution path tracing、formal conclusions を要求する structured prompting である。
  - unstructured chain-of-thought と異なり、agent が「cases を飛ばす」「unsupported claims をする」ことを防ぐ certificate として機能する。
  - patch equivalence / fault localization / code QA の 3 タスクで一貫して精度向上を示している。
- 本提案との整合:
  - Step 4 の trigger を、より多くの「非自明な制御フロー」に適用するのは、この論文のコアである「trace execution paths を省略させない」方向と整合的です。

2) https://doi.org/10.48550/arXiv.2603.01896
- 上記 arXiv 論文の DOI。
- 本提案との関係:
  - 研究コアは「出力制約」ではなく「分析プロセスの構造化」にあります。提案がやっているのは、結論の誘導ではなく、Step 4 の検証発火条件の修正なので、方向性は研究コアと一致します。

### 研究整合性の評価

README.md は空ですが、docs/design.md では、論文の本質を「explicit premises / per-item code tracing / formal conclusion」という certificate 化に置いています（docs/design.md:3-8, 31-55）。また、SKILL.md の Guardrails でも incomplete reasoning chains を既知失敗として扱っています（SKILL.md:421-424）。

このため、
- 反事実トレースの発火範囲を適切に広げる
- その結果、局所的な trace の誤りを確定前に潰す
という発想自体は研究の延長線上にあります。

一方で、研究整合性は「より広く trigger すること」であり、「別の非自明制御フローを trigger 対象から外すこと」までは支持しません。したがって、proposal の前半仮説は研究整合的ですが、後半の narrowing は研究からは積極的に支持されません。

## 2. Exploration Framework のカテゴリ選定は適切か

提案者はカテゴリ E「表現・フォーマットを改善する」を選んでいます（proposal.md:3-9）。

これは半分正しく、半分不十分です。

適切な点:
- 実際の変更は SKILL.md の 1 行文言修正であり、Objective.md の E カテゴリにある「曖昧な指示をより具体的な言い回しに変える」に合致します（Objective.md:163-167）。
- 新規ステップや新規フィールドを追加していないため、形式上は E です。

不十分な点:
- 実効的には単なる wording polish ではなく、「どの関数で追加の反事実トレースを強制するか」という探索行動の発火条件変更です。
- したがって本質的には B「情報の取得方法を改善する」にも跨っています（Objective.md:148-152）。

監査上の結論:
- E として提出すること自体は許容できます。
- ただし、これは「単なる表現改善」ではなく「探索トリガーの範囲変更」である、と認識して評価すべきです。

## 3. EQUIVALENT / NOT_EQUIVALENT の両方への作用

### 変更前後の実効差分

現行 SKILL.md:
- `For exception handling inside loops or multi-branch control flows ...`（SKILL.md:92）

提案後:
- `For non-trivial control flows — including exception handling, loops, and multi-branch conditionals ...`（proposal.md:30-32）

この差分を実効的に分解すると、以下です。

1) 拡張
- ループ外の例外処理が新たに対象になる
- 例外処理を伴わない単純ループが新たに対象になる

2) 縮小
- `multi-branch control flows` から `multi-branch conditionals` への変更により、dispatch 的・match/switch 的・テーブル駆動的な多分岐が trigger 対象から外れる可能性がある

### EQUIVALENT への作用

正の作用:
- 誤って「差がある」と見えていた trace を、反事実入力で潰せるため、偽の NOT_EQUIVALENT を減らす可能性がある。
- 特に、ループ外例外処理や単純ループでの戻り値/例外の見落としを補正できる。

負の作用:
- narrowing により、一部の多分岐制御が反事実チェックされなくなるなら、既存より甘い trace が残り、誤った EQUIVALENT を増やす可能性がある。

### NOT_EQUIVALENT への作用

正の作用:
- 新たに対象化されたループ・例外経路で、実際の差分が見つかりやすくなる。
- 具体入力を 1 回通すことで、diff が本当に observable difference に繋がるかの見極めが改善する。

負の作用:
- narrowing により、dispatch 系の非自明分岐で差分を取り逃す可能性がある。

### 片方向にしか作用しないか？

提案本文は「両方向に均等に寄与する」と主張しています（proposal.md:56-60）。
しかし、変更前との差分で見ると、厳密には「完全対称」とは言えません。

理由は 2 つあります。

1) 追加部分は対称的
- ループ外例外処理と plain loop を対象化する点は、EQUIV / NOT_EQ の両方に効きうる。

2) narrowing 部分は対称ではない
- `control flows` → `conditionals` の変更は、ある種の分岐でチェックを外す方向であり、その影響はケース分布次第で片寄りうる。
- failed-approaches.md が強調する通り、効果は「変更後の文言の見た目」ではなく「変更前との差分」で評価すべきです（failed-approaches.md:16-20）。

監査結論:
- 提案の拡張部分だけなら、両方向にかなり対称的です。
- しかし現行案全体としては、narrowing が混ざっているため、"片方向にしか作用しないとは断定しないが、完全対称とまでは評価できない" です。

## 4. failed-approaches.md の汎用原則との照合

### 抵触しにくい点

1) 原則 #1 判定の非対称操作
- 本提案は表面上、EQUIV / NOT_EQ のどちらかにだけ高い立証責任を課しているわけではありません。
- 追加されるのは intermediate trace の検証であり、結論方向の直接誘導ではないため、この点は比較的健全です（failed-approaches.md:10-12）。

2) 原則 #8 受動的な記録フィールドの追加
- 新しい列やテンプレート欄を足していないので非該当です（failed-approaches.md:24）。

3) 原則 #9 メタ認知的自己チェック
- 「自分はやったか？」ではなく「もしこの trace が間違っているならどの入力でズレるかを通せ」という、外部化された検証行動なので、この点も比較的良いです（failed-approaches.md:26）。

### 懸念がある点

1) 原則 #3 探索量の削減は常に有害
- 提案全体は拡張寄りですが、`multi-branch control flows` を `multi-branch conditionals` に狭める部分は、局所的な探索削減です（failed-approaches.md:14）。
- 提案者はこれを「過剰適用を抑制」と説明していますが（proposal.md:43-45）、この repository の失敗原則では、その種の narrowing は強く疑うべきです。

2) 原則 #6 「対称化」は既存制約との差分で評価せよ
- 提案文は変更後の文言が対称的に見えることを根拠に両方向効果を主張していますが、実際には既存より増える trigger と減る trigger が混在しています。
- したがって、この原則に照らすと説明がやや甘いです（failed-approaches.md:20）。

3) 原則 #20 厳密な言い換えは実質的な立証責任の引き上げになりうる
- 今回は主として拡張なので #20 そのものではありません。
- ただし `non-trivial control flows` という上位概念を導入しつつ、例示を `conditionals` に狭める構文は、モデルに「どこまでが対象か」を逆に悩ませる可能性があります（failed-approaches.md:48）。

総合すると、過去失敗の完全な再演ではありませんが、narrowing の一手が #3 と #6 に触れうるため、無条件承認はしにくいです。

## 5. 汎化性チェック

### ルール違反の有無

提案文には、以下のような overfitting の直接証拠は見当たりません。
- 特定のベンチマーク case ID
- 特定リポジトリ名
- 特定テスト名
- ベンチマーク対象コード断片

含まれている具体物は以下ですが、いずれも許容範囲です。
- `SKILL.md` 内の既存文言引用（proposal.md:24-32）
- 論文の一般的失敗カテゴリ名 `Incomplete reasoning chains`（proposal.md:54）
- Step/Section 番号

### 軽微な懸念

- proposal には `try/except` と読める Python 寄りの説明が一部ありますが（proposal.md:40）、これは actual diff の文言ではなく rationale 側です。
- 実際の提案文言は `exception handling, loops, multi-branch conditionals` であり、概念レベルではかなり言語非依存です。

### 監査結論

- 汎化性の重大違反はありません。
- ただし、`multi-branch conditionals` への限定は、言語によっては `switch/match/pattern dispatch` を条件分岐として扱うか曖昧で、汎用原則としては `control flows` より弱くなる可能性があります。

## 6. 全体の推論品質がどう向上すると期待できるか

### 改善が期待できる点

1) Step 4 の「VERIFIED」品質が上がる
- 現在の Step 4 は「actual definition を読め」「VERIFIED は source を読んでから」と強い要件を置いています（SKILL.md:87-91）。
- そこに、非自明制御フローで 1 回の反事実トレースを必須化する対象を広げると、VERIFIED の中身がより実証的になります。

2) incomplete reasoning chains の局所補正になる
- docs/design.md でも SKILL.md でも、下流ハンドリングや複雑経路の見落としは中心的失敗です（docs/design.md:19-27, SKILL.md:421-424）。
- 具体入力を 1 つ通す習慣は、この種の飛躍を減らす可能性があります。

3) compare だけでなく explain / localize にも副次効果がある
- Step 4 は共通コア手順なので、compare モード以外でも、複雑な戻り値や例外経路の取り違えを減らす可能性があります（SKILL.md:32-36, 78-93）。

### 改善幅が限定される点

- 変更は 1 行で、しかも Step 4 内の局所 trigger 修正です。したがって改善は「大きな戦略転換」ではなく「小さな誤トレース減少」に留まるはずです。
- また、narrowing を伴う現案のままだと、改善と回帰が同時に起こりえます。

## 最終判断

承認: NO（理由: 提案の中核仮説、すなわち「反事実トレースの適用範囲をループ外の例外処理や単純ループまで広げる」は妥当で研究コアとも整合する一方、同じ 1 行変更の中に `multi-branch control flows` を `multi-branch conditionals` へ狭める差分が混在しており、これは failed-approaches.md の原則 #3/#6 に照らして回帰リスクを持つため。承認するなら、拡張のみを残し narrowing を含まない文言に修正すべきです。）
