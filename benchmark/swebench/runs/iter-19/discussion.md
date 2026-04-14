# Iteration 19 — 監査ディスカッション

前提: この監査では、指定された 6 ファイルのみを参照した。
外部根拠は DuckDuckGo MCP による Web 検索結果のみを使った。

## 総評

提案は `SKILL.md` Step 4 の既存ルール
`Read the actual definition. Do not infer behavior from the name.`
に対し、関数本体の逐語読解の前に
- return type
- parameter types
- top-level branch structure
を先に把握するよう補足するもの（proposal.md:23-49, SKILL.md:106-112）。

これは「定義を読め」という既存原則を壊さず、読み順を少し具体化するという意味では小さく安全な変更である。一方で、現状のベンチマーク上の主要弱点が `EQUIVALENT` 側にあること（README.md:81-94）を踏まえると、この提案が主に効きそうなのはむしろ `NOT_EQUIVALENT` 側であり、ボトルネックとの整合が弱い。また、固定的に「何を先に見るか」を 3 点へ寄せるため、failed-approaches.md の「証拠種類の事前固定」への警戒と部分的に重なる。

結論として、方向性自体は理解できるが、現行文言のままでは承認しにくい。

## 1. 既存研究との整合性

### 1-1. Agentic Code Reasoning 論文との整合
URL: https://arxiv.org/abs/2603.01896
要点:
- 論文の要旨は、明示的 premises、execution path tracing、formal conclusion を要求する semi-formal reasoning が精度を改善する、というもの。
- 提案はこのコア構造を変えず、Step 4 の tracing 前の読み方を微修正するだけなので、研究コアとは矛盾しない。
- 特に `docs/design.md` が強調する「interprocedural tracing as structure, not advice」（docs/design.md:52-55）とは整合する。つまり、実定義を読んで VERIFIED behavior を積む枠組み自体は維持されている。

評価:
- 整合: ある
- ただし、論文が直接支持しているのは「構造化された tracing の有効性」であって、「return type / parameter types / branch shape を必ず先に見る」という個別読解順までは直接支持していない。ここは論文からの演繹であり、実証の強さは一段弱い。

### 1-2. Top-down code comprehension 研究との整合
URL: https://tobiasduerschmid.github.io/SEBook/development_practices/topdown.html
要点:
- line-by-line の機械的読解から離れ、先に高水準の mental model を作る top-down comprehension を重視している。
- 開発者は hypothesis formulation と searching for beacons によって読解効率と正確性を上げる、という整理になっている。
- 提案の「本体精読前に signature と branch shape を先に把握する」は、まさに line-by-line anchoring を避けて高水準の見取り図を先に作る、という意味でかなり整合的。

評価:
- 整合: 比較的強い
- ただしこの資料は一般的な top-down comprehension を支持するのであって、提案の 3 項目を最適な固定チェックリストとして支持しているわけではない。

### 1-3. Program comprehension の一般論との整合
URL: https://www.sciencedirect.com/topics/computer-science/program-comprehension
要点:
- program comprehension は code から出発しつつ、より高い abstraction へ持ち上げる過程と整理されている。
- code concept assignment や feature location のように、「細部に入る前に概念レベルで何を見ているかを整理する」ことは一般に自然である。
- 提案の interface/branch の先行把握は、その抽象化の初手としては妥当。

評価:
- 整合: ある
- ただしこちらも提案の具体的な読み順 3 点を直接立証するものではなく、抽象化先行の一般原則を支持する程度。

### 小結
研究との整合性は「ある」。
ただし根拠の強さは
- semi-formal reasoning との整合: 強い
- top-down comprehension との整合: 中程度〜強い
- 提案文そのものの 3 点固定チェックリストの妥当性: 間接支持
に留まる。

## 2. Exploration Framework のカテゴリ選定は適切か

結論: カテゴリ B の選定は概ね妥当。

理由:
- Objective.md のカテゴリ B は「情報の取得方法を改善する」であり、例として
  - コードの読み方の指示を具体化する
  - 何を探すかではなく、どう探すかを改善する
  - 探索の優先順位付けを変える
  が挙がっている（Objective.md:148-152）。
- 今回の変更は、Step 4 内で「関数定義をどう読むか」の順序を具体化するものであり、まさに B の中核に入る。
- A（推論順序の変更）ほど大きくない。D（自己チェック追加）でもない。E（表現改善）に見える面もあるが、本質は wording の改善ではなく探索手順の具体化なので B が最も近い。

ただし留保:
- 「暗黙的確認バイアスを抑える」という狙い自体は D 的にも見える。
- しかし実装箇所が Step 5.5 の自己監査ではなく Step 4 の読み方規則なので、分類としては B でよい。

## 3. EQUIVALENT 判定 / NOT_EQUIVALENT 判定の両方への作用

## 実効差分
現行 `SKILL.md` の Step 4 Rules には
- 実定義を読む
- VERIFIED を source 読了後にのみ付ける
- source 不在時の二次証拠探索順
- conditionals / mapping / configuration を追う
- loop/exception 内の反実仮想確認
がある（SKILL.md:106-112）。

提案が足すのは、そのうち最初の行に対する「full body 読解前に interface と top-level shape を先にメモする」という前処理である（proposal.md:35-38）。

つまり、これは新しい判定規則ではなく「関数読解のプリミティブな初手」を追加する変更である。

### NOT_EQUIVALENT への作用
正方向の効果は比較的わかりやすい。

期待できる点:
- 最初に見えた branch に固定されるのを防ぎ、後半分岐・default case・exception arm の存在を早く把握しやすい。
- compare モードで 2 変更が異なる腕を通るケースを見つけやすくなる。
- proposal.md 自身もここを主効果として述べている（proposal.md:64-70）。

監査所見:
- `NOT_EQUIVALENT` には確かに効きうる。
- ただし README.md では現状 `Not-equivalent pairs` はすでに 100% で、残存失敗は `Equivalent pairs` 側にある（README.md:83-94）。
- したがって、たとえこの提案が `NOT_EQUIVALENT` をさらに堅くするとしても、現状ボトルネックの解消には直結しない可能性が高い。

### EQUIVALENT への作用
ここは正負両面がある。

正方向:
- 先頭分岐だけ見て「差がある」と早合点するのを避け、関数全体の top-level shape を一度見渡してからトレースするので、局所差異への過剰反応は減りうる。
- 引数型・戻り型を先に把握することで、そもそも比較対象の契約が同じかを早く整理できる。

負方向 / 限界:
- branch shape を先に強調すると、逆に「構造が違う = 振る舞いが違う」と受け取りやすくなり、tested behavior が同じでも偽の `NOT_EQUIVALENT` を増やす危険がある。
- `EQUIVALENT` 判定で重要なのは、構文の似姿ではなく「既存テストに対する outcome の同一性」である（SKILL.md:171-180, 242-247）。
- そのため、top-level branch shape の事前確認は補助にはなるが、`EQUIVALENT` 側の主失敗要因を直接突く改善とは言いにくい。

### 片方向にしか作用しないか
結論: 片方向専用ではないが、期待効果は非対称。

- `NOT_EQUIVALENT` には比較的直接効く。
- `EQUIVALENT` にも一定の補助効果はありうるが、主作用ではない。
- 現状の benchmark pain point が `EQUIVALENT` であることを踏まえると、実効改善が片寄る懸念は大きい。

監査上はここが最も大きい懸念である。

## 4. failed-approaches.md の汎用原則との照合

### 原則 1: 次の探索で探すべき証拠の種類をテンプレートで事前固定しすぎない
failed-approaches.md:8-10

提案者は「同一情報源内の読み順であり、証拠種類の固定ではない」と主張している（proposal.md:80-83）。
これは半分は正しい。

良い点:
- 次に読むファイルや次の探索対象を固定しているわけではない。
- 同一関数定義の中での視線誘導に留まる。

ただし懸念:
- 実際には「return type / parameter types / top-level branch structure」を毎回先に拾わせるので、関数読解時の証拠抽出を固定ミニチェックリスト化している。
- これは failed-approaches の禁じる「特定シグナルの捜索」への寄り方を、探索全体ではなく“関数内部の読解”に縮小して持ち込む形になりうる。
- 特に state mutation、aliasing、data transformation、callee contract、dispatch table、implicit protocol など、branch shape 以外が本質のケースでは、先行 3 項目が注意資源を奪う可能性がある。

判定:
- 完全な再演ではない
- ただし本質的リスクは部分的に同じ

### 原則 2: 探索ドリフト対策時に探索自由度を削りすぎない
failed-approaches.md:11-13

良い点:
- 変更範囲は 1 文追加で小さい。
- 読む対象ファイルや関数を制約しない。

懸念:
- あらゆる関数で type/branch shape の先行確認を半必須にすると、単純 accessor や data-container 的コードでも儀式が増える。
- そのぶん attention budget を消費し、重要な downstream handling や data flow の追跡が薄くなる可能性はある。

判定:
- 軽度の緊張あり
- ただし原則 1 ほど強い抵触ではない

### 原則 3: 結論直前の自己監査に新しい必須のメタ判断を増やしすぎない
failed-approaches.md:14-16

判定:
- これは抵触しない
- 追加箇所は Step 4 であり、Step 5.5 の pre-conclusion self-check ではない

### 小結
`failed-approaches.md` との関係では、完全な禁止領域ではないが、原則 1 の縮小再演に近い匂いがある。

## 5. 汎化性チェック

### 明示的ルール違反の有無
提案文を確認した限り、以下は見当たらない。
- ベンチマーク対象リポジトリ名
- 特定のテスト名
- 特定のケース ID
- ベンチマーク実コード断片

含まれているのは
- `SKILL.md` 自身の既存文言引用
- Step 番号
- 行数やカテゴリ名
であり、これは Objective.md の R1 減点対象外の扱いに近い（Objective.md:202-213）。

したがって、明白な overfitting ルール違反はない。

### 暗黙のドメイン仮定
ここには懸念がある。

提案文は
- return type
- parameter types
- if/switch/try-catch shape
を前面に出している（proposal.md:35-38）。

この表現は以下を暗黙に強く想定する。
- 明示的型を持つ、または型注釈が安定して読める言語
- branch-centric な imperative / OO コード
- 関数本体の top-level shape が意味を持ちやすい実装スタイル

弱くなる対象:
- dynamic language で型がほぼ契約を表さないコード
- functional / expression-oriented / declarative / macro-heavy なコード
- dataflow, protocol, callback ordering, mutation, or configuration semantics が本質のコード
- top-level branch より下位 call chain や data transformation の方が重要なケース

判定:
- 露骨な benchmark overfit ではない
- ただし汎化性は満点ではなく、「多くの一般的コードには有効だが、かなり imperative 寄り」という留保が必要

## 6. 全体の推論品質がどう向上すると期待できるか

期待できる改善:
- line-by-line 読解開始時の path anchoring を弱める
- 関数の入口契約と大枠の制御構造を先に把握することで、Step 3 の仮説更新が多少しやすくなる
- Step 4 の VERIFIED behavior 記述が、局所トレースより少し俯瞰的になる

期待しにくい改善:
- `EQUIVALENT` の難所である「構造差はあるが test outcome は同じ」を見抜く力の大幅改善
- downstream handling の取りこぼし防止
- state / data flow / dispatch / indirect call を主因とする誤判定の削減

総合すると、改善幅は「局所的・中程度」に留まる可能性が高い。小さな hygiene improvement としては理解できるが、現状の主要失敗に対する打点は弱い。

## 最終判断

承認: NO（理由: 研究コアとの整合とカテゴリ B の妥当性は認められるが、現行文言は `NOT_EQUIVALENT` 側に偏って効く可能性が高く、README.md が示す主要弱点である `EQUIVALENT` 側の改善根拠が弱い。また `return type / parameter types / top-level branch structure` を固定的に先行確認させる点は、failed-approaches.md の「証拠種類の事前固定」原則と部分的に同質で、言語・実装スタイル一般性にも軽い難がある。）

## 参考: 承認に近づけるなら

もし再提案するなら、次の方向の方が安全。

- `return type / parameter types / if/switch/try-catch` の固定列挙を弱める
- 代わりに「Before reading the full body, sketch the function's interface/contract and the major control-flow or dispatch regions relevant to the current hypothesis.」のように、interface/contract と control-flow/dispatch を抽象的に表現する
- さらに compare モードとの接続を明示するなら、「do not treat structural differences as semantic differences until traced to tested behavior」といった EQUIVALENT 側保護の一文の方が、現状の課題にはより適合する
