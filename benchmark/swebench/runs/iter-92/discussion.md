# Iter-92 Discussion

## 総評

提案の問題意識自体は妥当です。`SKILL.md` の Step 4 既存ルールは `exception handling inside loops or multi-branch control flows` にのみ対実例トレースを要求しており、見た目が単純でも実際には履歴依存・状態依存な関数を過信して `VERIFIED` 扱いしてしまう穴は確かにあります。これは README / design が重視する「定義を読んで実際の振る舞いを確かめる」「不完全な reasoning chain を防ぐ」という研究コアには整合しています。

ただし、今回の書き方には 2 つの大きな懸念があります。

1. `shared mutable state` を `instance variables, module-level state, mutable arguments` という具体物で例示しており、`failed-approaches.md` の原則 #22（抽象原則での具体物の例示）にかなり近いです。
2. 変更前との差分として実際に増えるのは「Step 4 の局所トレース義務の発火条件」であり、compare の中心ループ（relevant test 選定、差分から assertion までの因果追跡）を直接強化する変更ではありません。したがって改善方向は理解できる一方、探索負荷増の副作用を慎重に見る必要があります。

以下、監査観点ごとに評価します。

---

## 1. 既存研究との整合性

注: DuckDuckGo MCP の search エンドポイントは今回の実行では結果を返せなかったため、同じ DuckDuckGo MCP の `fetch_content` で既知の基礎的参照先を取得して確認しました。

### 参照 1
- URL: https://en.wikipedia.org/wiki/Side_effect_(computer_science)
- 要点:
  - side effect とは「戻り値以外の観測可能な効果」であり、非局所変数・静的変数・mutable argument の更新が代表例。
  - side effect があると「program's behaviour may depend on history; order of evaluation matters」とされる。
  - つまり、共有可変状態や履歴依存性は、関数を入力→出力の純粋写像として読んだときの誤読を招きやすい。
- 提案との関係:
  - 「共有可変状態に依存する関数は追加の concrete trace を要求すべき」という発想自体は、状態依存コードの難しさと整合する。

### 参照 2
- URL: https://en.wikipedia.org/wiki/Static_program_analysis
- 要点:
  - static analysis / program understanding は、実行せずにコード理解を進める営み。
  - 解析の精度は、個々の文だけを見る浅い解析から、プログラム全体を含む深い解析まで幅がある。
  - 安全性や正しさの確認では、局所文脈だけでなく広い文脈を含む分析が重要。
- 提案との関係:
  - 共有状態依存を明示的に警戒するのは、局所読みによる取り違えを減らす方向で、静的理解の一般論とは整合する。
  - ただし研究一般から直接出るのは「状態依存性を無視しないこと」までであり、今回のような具体的なトリガー文言が最適かは別問題。

### 参照 3
- URL: https://en.wikipedia.org/wiki/Program_slicing
- 要点:
  - program slicing は、ある観測点の値に影響する文を dependency を遡って特定する考え方。
  - static slice は「あらゆる入力」で当該値へ影響しうる文を含める。
- 提案との関係:
  - 共有可変状態はまさに dependency source の一種なので、観測点の値やテスト結果に至る依存を追うべき、という発想は妥当。
  - 一方で slicing 的観点からは、重要なのは具体物名ではなく「どの状態・依存が最終観測へ伝播するか」です。ここは提案文がやや具体物寄りです。

### 参照 4
- URL: https://en.wikipedia.org/wiki/Symbolic_execution
- 要点:
  - symbolic execution は、どの入力がどの分岐・振る舞いを引き起こすかを条件付きで追う。
  - 反面、path explosion や aliasing / memory alias の難しさがある。
- 提案との関係:
  - 提案中の `if this trace were wrong, what concrete input would produce different behavior?` は、反証入力を置いて path を具体化するという意味で symbolic execution 的な健全な発想。
  - ただし aliasing / mutable state は難しいため、具体物列挙で安易に検索対象化すると探索コストが急増しうる。

小結:
- 研究的には「状態依存・履歴依存を雑に扱わない」「反証入力で trace を確かめる」は整合的です。
- しかしその実装表現として「具体物の列挙をトリガーにする」点は、研究一般が支持しているというより、このリポジトリの failed principles と緊張します。

---

## 2. Exploration Framework のカテゴリ選定は適切か

提案は Category B「情報の取得方法を改善する」に分類されています。

これは概ね妥当です。理由:
- 結論を直接誘導していない。
- 新しい出力フィールドも導入していない。
- 「何を判定せよ」ではなく、「どういう関数に遭遇したときに、どのような追加トレースをするか」を変えている。

ただし純粋な B と言い切るには留保があります。
- 変更対象は Step 4 のルールであり、単なる探索優先順位ではなく、`VERIFIED` を付けるための立証負荷の変更でもあります。
- そのため B（取得方法）であると同時に、実効的には D（自己チェック強化）や E（文言追加）の性質も少し帯びます。

それでも主要カテゴリとしては B でよいです。問題はカテゴリ名ではなく、B の中でも「具体物を探させる方向」になっていないかです。

---

## 3. EQUIVALENT / NOT_EQUIVALENT への作用分析

### 変更前との差分
既存ルール:
- ループ内例外処理
- 多分岐制御フロー
に対してのみ、反証入力を置いた concrete trace を要求。

提案後の追加差分:
- `functions whose behavior depends on shared mutable state`
にも同じ要求を適用。

つまり、差分の本体は「対実例チェックの対象クラスを state-dependent function まで広げる」ことです。

### NOT_EQUIVALENT 側への期待効果
ここが最も改善しやすい方向です。
- 一見単純な getter / updater / helper でも、共有状態や mutable argument の前状態に依存して結果が変わる場合、見かけ上は同じでも実テストで差が出る可能性があります。
- 現行ルールは構文的複雑さ（loop / branch / exception）には敏感ですが、状態依存のような「構文上は単純、意味上は複雑」なケースに弱い。
- そのため false EQUIV を減らし、正しく NOT_EQUIVALENT を拾う方向の効果は期待できます。

### EQUIVALENT 側への期待効果
ゼロではありません。
- 共有状態を読む関数に見えても、実際には relevant tests が通る初期状態・呼び出し順の下では A/B の観測結果が同じ、ということがあります。
- 反証入力ベースで stateful behavior を具体化すると、「差がありそう」という早計な印象を打ち消し、EQUIVALENT を維持できる可能性があります。

### ただし、実効差分は完全対称ではない
`failed-approaches.md` 原則 #6 の観点で見ると、文面が対称でも差分の効き方は対称とは限りません。

今回の追加は、既に強く求められている compare 主体の end-to-end tracing を置き換えるものではなく、Step 4 の局所ノードで追加検証を発火させます。これにより:
- false EQUIV を減らす方向の利益は比較的わかりやすい。
- 一方で false NOT_EQ を減らす利益はあるものの、そこまで直接的ではない。
- さらに探索コスト増により、複雑なケースでは UNKNOWN 寄り・安全側寄りの挙動を誘発するリスクがある。

したがって、「片方向にしか作用しない」とまでは言いませんが、実効的には
- 主効果: false EQUIV の抑制
- 副効果: 一部の false NOT_EQ の抑制
- 副作用: 探索負荷増による未完了 / 保守的判定
という非対称性があります。

この点を proposal は「特定の判定方向への優遇はない」と書いていますが、そこまでは断言できません。

---

## 4. failed-approaches.md の汎用原則との照合

### 抵触しにくい点
- 原則 #2 出力側の制約: 該当しない。出力形式ではなく、探索中の行動規則を変えている。
- 原則 #8 受動的記録フィールド追加: 該当しない。新列追加ではなく、既存 verification 行動の適用条件拡張。
- 原則 #9 メタ認知的自己チェック: 比較的回避できている。単なる「本当に見たか？」ではなく、反証入力を trace させる点は外部的行動に近い。

### 強い懸念: 原則 #22 抽象原則での具体物の例示
ここが最大の懸念です。

提案文は `shared mutable state` を
- instance variables
- module-level state
- mutable arguments
と明示しています。

この 3 例はベンチマーク固有識別子ではないため R1 即失格級ではありません。しかし failed principle #22 が問題視しているのは、固有名詞かどうかではなく、「抽象原則の中で具体的コード要素を示すと、それが physical search target 化する」ことです。

実際、この文言を読むエージェントは
- instance variable を探す
- module-level state を探す
- mutable argument を探す
という検索行動に引っ張られやすいです。

本来必要なのは「観測結果が hidden state / prior history / aliased mutation に依存するか」を見抜くことであり、具体物の列挙ではありません。

### 中程度の懸念: 原則 #14, #17, #18, #19
- #14 条件付き特例探索: 今回の追加は中心比較ループではなく、特定条件でのみ発火する局所追加チェックです。完全一致ではないが、主ループを直接強化していない点は近い。
- #17 中間ノードの局所分析義務化: Step 4 の局所関数行で追加 trace を要求するため、最終観測点より中間ノードに注意が固定されるリスクがある。
- #18 / #19 探索予算枯渇: 1 行追加なので軽微ではあるが、stateful code は探索の枝刈りが難しく、追加義務のコストが読みにくい。

### 原則 #1 非対称操作との関係
proposal は「双方向に効く」と述べています。完全な違反ではありません。
ただし前節の通り、差分効果は false EQUIV 抑制寄りで、完全対称とは言い難いです。よって #1 に明確抵触とは言わないが、#6 の警告対象ではあります。

---

## 5. 汎化性チェック

### 明示的ルール違反の有無
提案文中には以下は含まれていません。
- 具体的な数値 ID
- 特定リポジトリ名
- 特定テスト名
- ベンチマーク実コード断片

したがって、監査観点 5 の「含まれていれば即指摘」の意味での明白なルール違反はありません。

### ただし、暗黙の言語・ドメイン偏りはある
- `instance variables`
- `module-level state`
- `mutable arguments`
という例示は、主に OO 言語や Python 系のコードの読み方を強く想起させます。
- `module-level state` は特に言語依存の匂いが強く、任意言語への抽象度としては少し低いです。
- 共有可変状態の実体は、グローバルキャッシュ、シングルトン、クロージャに閉じたセル、外部ハンドル、context object、DB transaction state など多様なので、列挙の切り方がやや狭いです。

### 望ましい抽象化
もし採用するなら、具体物列挙より次のような性質ベースに寄せた方がよいです。
- hidden state
- prior-history dependence
- alias-mediated mutation
- behavior depends on state not explicit in the call signature

この方が汎化性は高く、failed principle #22 のリスクも下がります。

---

## 6. 全体の推論品質がどう向上すると期待できるか

期待できる改善はあります。
- 構文の見た目に反して意味が状態依存な関数での誤 `VERIFIED` を減らす
- 「ここまでは読んだが、その結果がどの状態を前提に成り立つか」を曖昧にしたまま先へ進む失敗を減らす
- compare で hidden state を介した差分伝播を見落とすケースを一部減らす

ただし、その改善幅は文言次第です。

現状提案のままだと、改善される可能性と同程度に以下の副作用も見えます。
- 具体物探索に寄って本来の観測境界追跡が弱まる
- Step 4 の局所ノードでの追加作業が増え、compare の本丸である test-outcome tracing に使う予算を圧迫する
- stateful code 全般を「とにかく追加トレース対象」として扱い、広く浅い探索になる

ゆえに、狙いは良いが、そのままの wording では「推論品質を安定改善する」とまでは言い切れません。

---

## 結論

この提案の核となる問題設定、すなわち
- 共有可変状態 / 履歴依存は構文上の複雑さでは検出しにくい
- そのため concrete counterexample trace を追加したい
という方向性は妥当です。

しかし、今回の具体的文言は
- failed-approaches.md 原則 #22 に近い具体物列挙を含み、physical search target 化しやすい
- 変更前との差分としては Step 4 の局所トレース負荷を増やす側面が強く、中心ループ強化としてはやや弱い
- 実効効果は双方向ゼロサムではないが、false EQUIV 抑制寄りに偏る可能性がある
ため、そのままでは承認しにくいです。

もし修正するなら、承認に近づく方向は以下です。
- 具体物列挙をやめ、`behavior depends on hidden state or prior history not explicit in the call signature` のような性質ベース表現にする
- 「stateful function を探せ」ではなく、「その関数の結論が呼び出し時状態に依存しうるなら、別状態の反証入力を 1 つ置いて trace せよ」という行動記述に寄せる
- compare の最終観測点との接続を明確化し、局所ノード分析で終わらないようにする

承認: NO（理由: 問題設定は妥当だが、提案文の具体物列挙が failed-approaches.md の原則 #22 に近く、汎化性と探索効率の両面でリスクが残るため。このままの wording では、安定した全体改善よりも局所的な探索負荷増の副作用が懸念される。）
