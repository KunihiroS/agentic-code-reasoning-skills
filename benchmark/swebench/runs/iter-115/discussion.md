# Iteration 115 — 監査ディスカッション

## 総論

結論から言うと、この提案は「変更コードからテストアサーションまでのコールパスを先に追う」という直感自体には一定の妥当性があるものの、
その埋め込み先が Step 3 の共有フィールド `NEXT ACTION RATIONALE` である点と、文言が compare モード特有の終点（test assertions）を
共有コア手順に持ち込んでいる点に、強い懸念があります。

したがって監査判断は 承認: NO です。

---

## 1. 既存研究との整合性

DuckDuckGo MCP の search は今回うまく結果を返さなかったため、同 MCP の fetch で既知の公開ページを直接取得して確認しました。

### 参照 1
- URL: https://arxiv.org/abs/2603.01896
- 要点:
  - 論文の中核は semi-formal reasoning により「explicit premises」「execution-path tracing」「formal conclusions」を強制し、
    agent が unsupported claims や case-skip をしにくくすること。
  - これは README / docs/design.md に書かれている本リポジトリの設計解釈とも一致する。
  - ただし、この論文要約から直接に導かれるのは「構造化された追跡を要求する」ことまでであり、
    「共有探索ステップで test assertion を探索上の優先終点に固定する」ことまでは支持していない。

### 参照 2
- URL: https://en.wikipedia.org/wiki/Program_slicing
- 要点:
  - program slicing は「ある観測点・変数値に影響する文」を dependency をさかのぼって求める考え方であり、
    debugging や program analysis で有用とされる。
  - この意味では、観測点に影響する中心パスを優先したいという提案の方向性そのものには研究的な整合性がある。
  - ただし slicing は「基準点 (criterion) が明示されている」ことが前提であり、今回の提案は shared Step 3 に
    いきなり `test assertions` を置いているため、compare 以外のモードでは criterion の選び方が不自然になる。

### 参照 3
- URL: https://en.wikipedia.org/wiki/Call_graph
- 要点:
  - call graph は手続き間関係を表し、人間の program understanding に有用。
  - 一方で static call graph は一般に over-approximation であり、正確な call path は自明ではない。
  - したがって「call path 上のファイルを優先せよ」は補助原則としてはよいが、探索開始時点でそれを強く要求すると、
    まだ call path が十分分かっていない段階での先走ったアンカリングを招きうる。

### 小結
研究との整合性は「中心因果連鎖を追うべき」という抽象レベルではある程度あります。
しかし、今回の具体文言はその抽象原則を compare 特有の物理的終点 `test assertions` に落とし込みすぎており、
研究のコアである「構造化された追跡」を超えて「探索上の特定ターゲットへのアンカリング」を導入している点で、整合性は限定的です。

---

## 2. Exploration Framework のカテゴリ選定は適切か

### 判定
- 部分的には B だが、厳密には B と E の境界にあり、しかも shared core への挿入先が不適切。

### 理由
proposal は「探索の優先順位付けを変える」ので、表面的にはカテゴリ B に入ります。
ただし実装としては Step 3 の既存説明文を 1 行だけ言い換えるものであり、実体はかなり E（表現変更）寄りです。

さらに重要なのは、カテゴリ分類以前に「どこへ入れるか」です。
Step 3 は SKILL.md の shared core method であり、compare / localize / explain / audit-improve の全モードにかかります。
そこへ `changed code` と `test assertions` を持ち込むのは、compare モードの局所ヒューリスティックを shared core に昇格させることになります。
これは汎用原則としては不自然です。

### 汎用原則としての妥当性
- 妥当な核: 「中心因果連鎖に近い箇所を優先して読む」
- 妥当でない具体化: 「changed code → test assertions の call path を shared Step 3 の既定優先にする」

つまり、抽象原則は理解できますが、現行 proposal の具体文言は汎用原則としては狭すぎます。

---

## 3. EQUIVALENT / NOT_EQUIVALENT への作用

### 変更前との差分ベースで見るべき点
SKILL.md の compare mode にはすでに以下が存在します。
- relevant tests の定義（D2）
- 各 test ごとの trace from changed code to test assertion outcome
- NOT EQUIVALENT 時の diverging assertion の明示
- EQUIVALENT 時の no counterexample exists の説明

したがって今回の差分は、「最終的に assertion まで辿れ」という新要求ではありません。
すでに要求されている compare の中心ループに対して、Step 3 の探索初期段階で
`call path from changed code to test assertions` を先に読めというアンカリングを追加するだけです。

### NOT_EQUIVALENT 側への作用
- 正に働く可能性:
  - 変更差分から failing/passing divergence のある assertion までの因果連鎖を早めに掴めれば、
    counterexample 構成が速くなる可能性はある。
- 負に働く可能性:
  - 「test assertion」という具体物の探索が目的化し、途中の重要分岐や関連テスト選定の精度より
    先に assertion 行の特定へ走ると、かえって探索が空回りする。

### EQUIVALENT 側への作用
- 正に働く可能性:
  - changed code に関係する relevant path の確認は多少しやすくなる。
- 負に働く可能性:
  - EQUIVALENT 判定は「反例がない」ことの確認が本質であり、単一の中心パスへ早期に収束すると、
    一見 tangential だが実は relevant な pass-to-pass テストや別分岐の見落としを招きやすい。
  - つまり、NO COUNTEREXAMPLE EXISTS の探索幅を狭める危険がある。

### 両方向対称か
対称とは言いにくいです。
理由は、compare template は元々 NOT_EQ 側にとって「diverging assertion」を書きやすい構造をすでに持っており、
今回の差分はその方向の探索をさらに前倒しで後押しします。
一方 EQUIV 側で必要な「反例不在の網羅的確認」を同程度には強化しません。

よって「文言上は中立でも、変更前との差分としては NOT_EQ 側を相対的に押しやすい」懸念があります。
これは failed-approaches.md の原則 #6（差分で見よ）に照らしても注意が必要です。

---

## 4. failed-approaches.md との照合

proposal 本文では非抵触と整理していますが、私は少なくとも以下 4 つに実質的な近さがあると判断します。

### 原則 #8: 受動的な記録フィールドの追加は能動的な検証を誘発しない
今回の変更先は `NEXT ACTION RATIONALE` の説明文です。
これはまさに「記録フィールド」の文言変更であり、探索行動そのものを強制する新ステップではありません。
proposal はこの点を「新規フィールドではなく既存フィールドの説明追記だから別」としていますが、
原則 #8 の本質は“追加か既存か”ではなく、“記録欄の変更だけで探索行動が変わると期待している”点にあります。
本質的にはかなり近いです。

### 原則 #11: 探索順序の固定は、証拠収集ではなく探索の偏りを生む
`prioritize files on the call path ... before reading tangential files` は、完全固定ではないとしても、
明確な探索順序バイアスです。原則 #11 が禁じているのはまさにこの種の start-order anchoring です。
proposal は「優先順位付けであって順序固定ではない」と読めますが、エージェント実行上は十分にアンカリングとして作用しえます。

### 原則 #22: 抽象原則での具体物の例示は、物理的探索目標化を招く
`test assertions` は抽象的な性質ではなく、具体的なコード要素です。
proposal は「関数名やクラス名ではないから具体物ではない」と主張していますが、
原則 #22 の問題は named entity かどうかではなく、“物理的に探しに行く対象が明示される”ことです。
その意味で `test assertions` は十分に具体物です。

### 原則 #6: 「対称化」は既存制約との差分で評価せよ
proposal は EQUIV / NOT_EQ のどちらにも有利化しないと述べますが、
実際には compare mode には既に assertion tracing と counterexample obligation があり、
差分としては assertion 側への探索圧を上げる方向です。
既存制約との重なりを踏まえると、効果は必ずしも対称ではありません。

### 参考: 原則 #25 との関係
独立した pre-check を追加していないので #25 に直撃ではありません。
ただし「まず call path 上かどうかを優先して確認しよう」という探索姿勢を shared Step 3 に入れることで、
事実上それに近い事前確認行動を誘発する危険はあります。

### 小結
proposal 本文の「failed-approaches に抵触しない」という自己評価には賛成できません。
特に #8, #11, #22 はかなり本質的に近いです。

---

## 5. 汎化性チェック

### 明示的なルール違反の有無
- ベンチマーク対象リポジトリ名: なし
- 特定テスト名: なし
- 特定関数名 / クラス名 / 実リポジトリのコード断片: なし
- 数値 ID: proposal タイトルに `Iteration 115` はあるが、これはこの改善サイクルの管理番号であり、
  ベンチマークケース ID や対象リポジトリ識別子ではない
- コード断片: 変更前後の 1 行引用は SKILL.md 自身の文言比較であり、Objective.md の R1 の減点対象外に当たる

以上より、「禁止された固有識別子を露骨に含んでいる」という意味での即時失格ではありません。

### ただし汎化性の実質的懸念は大きい
この提案は明示的固有名詞こそ含みませんが、暗黙にかなり強い compare/test-centric 仮定を置いています。

- `changed code` という始点は compare では自然でも、explain や audit-improve では自然でない
- `test assertions` という終点は compare では自然でも、localize / explain / audit-improve の shared exploration には不適切
- shared Step 3 にこの文言を入れると、全モードの探索開始バイアスとして働く

つまり、形式上の overfitting 証拠は弱い一方で、実質的には「compare モードの問題設定を shared core に漏らしている」ため、
汎化性は高いとは言えません。

---

## 6. 全体の推論品質がどう向上すると期待できるか

### 期待できる限定的な改善
- compare モードで、かつ relevant test と changed code の対応が比較的素直なケースでは、
  周辺ファイルを読む前に中心パスへ寄ることで初動が速くなる可能性はあります。
- 「手近なファイルから何となく読む」よりは、「観測される差異に近い因果連鎖を優先する」ほうが
  一般論としては良い方向です。

### しかし、同等以上に大きい悪化リスク
1. shared core の compare 特化
   - 非 compare モードでノイズになる。
2. 記録欄の追記だけで行動変容を期待している
   - 有効性が低い可能性が高い。
3. assertion という具体物へのアンカリング
   - 物理的探索目標化により、かえってターン消費を招く可能性がある。
4. EQUIV 側の反例不在探索を強化しない
   - 全体精度の底上げより、特定方向の探索バイアスとして作用する懸念がある。

### 総合評価
改善の核アイデアは理解できますが、現行の埋め込み方では「推論品質を安定して底上げする変更」よりも、
「共有探索ループに compare 固有の探索バイアスを足す変更」に見えます。
そのため、全体の推論品質向上への期待は限定的で、回帰リスクの方が目立ちます。

---

## 最終判断

承認: NO（理由: 共有 Step 3 に compare 特有の `changed code → test assertions` という探索終点を持ち込んでおり、
failed-approaches.md の原則 #8, #11, #22, #6 に実質的に近い。さらに EQUIV / NOT_EQ への作用が差分ベースでは対称といえず、
shared core の汎化性も損なうため。）
