# Iter-106 Discussion

## 総評

結論から言うと、この提案は表面的には「D1 に整合する曖昧さの除去」に見えるが、実効的には `EQUIVALENT` 側の反証記述だけに新しい証拠形式を課す変更であり、`failed-approaches.md` の失敗原則 #1, #6, #20, #26 にかなり近い。改善仮説自体（内部差分ではなく観測可能なテスト結果差分を見るべき）は妥当だが、その実装位置が `NO COUNTEREXAMPLE EXISTS` ブロックに限定されているため、作用は片方向になりやすい。

## 1. 既存研究との整合性

注記: DuckDuckGo MCP の search は今回すべて no results だったため、同じ DDG MCP の `fetch_content` で既知の一般参照 URL を取得して確認した。

### 参照 1
- URL: https://en.wikipedia.org/wiki/Test_oracle
- 要点:
  - テストオラクルは「入力に対する正しい出力/結果」を与えるものであり、テストとは実際の結果と期待結果の比較である。
  - design by contract では assertion が test oracle として機能する。
  - つまり、等価性をテスト観点で定義するなら、最終的な観測対象を pass/fail や assertion outcome に寄せるという発想自体は一般論として妥当。

### 参照 2
- URL: https://en.wikipedia.org/wiki/Observational_equivalence
- 要点:
  - observational equivalence は、内部実装が異なっても「観測可能な含意」が同じなら区別できないという考え方。
  - プログラミング言語意味論でも、全ての文脈で同じ値/観測を返すなら区別不能とみなす。
  - この観点からは、単なるコード上の差異ではなく観測可能結果に基づいて等価性を考えるべき、という提案の方向性は研究的に自然。

### 参照 3
- URL: https://en.wikipedia.org/wiki/Regression_testing
- 要点:
  - regression testing は変更後も既存機能が期待どおり動くかを再実行して確認する活動であり、変更の良し悪しは最終的に既存テストの結果で判断される。
  - 「変更差分そのもの」ではなく「既存テストの outcome」を中心に比較するのは、回帰検証の一般原則と整合的。

### 参照 4
- URL: https://arxiv.org/abs/2603.01896
- 要点:
  - 本リポジトリの元研究は semi-formal reasoning を「explicit premises, trace execution paths, formal conclusions」を強制する certificate として位置づける。
  - 重要なのは、結論誘導ではなく、分析過程でケースを飛ばさず supported claims を作ること。
  - したがって研究コアとの整合性を評価する際は、「観測可能な outcome に注目させること」自体よりも、「それが片方向の立証責任変更になっていないか」が重要。

研究整合性の小結:
- 「内部挙動差分ではなく観測可能なテスト結果差分を見るべき」という思想は妥当。
- ただし、その思想を `EQUIVALENT` 側の反証テンプレートだけに埋め込むと、研究整合的な“定義の明確化”ではなく、分岐依存の証拠要求に変質する。

## 2. Exploration Framework のカテゴリ選定は適切か

表面上の分類としては E「表現・フォーマットを改善する」でよい。実際、変更差分は 1 行の文言修正であり、UI 上は wording change である。

ただし、監査上はカテゴリ名より実効メカニズムを見るべきで、この提案の本質は単なる wording cleanup ではない。

- 変更前: 反例を広く「diverging behavior」として記述できる
- 変更後: 反例を「どの assertion の PASS/FAIL が変わるか」に限定する

これは単なる表現改善ではなく、
- 有効な反例の表現形式の再定義
- `EQUIVALENT` 主張時の反証様式の絞り込み
- モデルが反例として想起する対象の変更
を伴う。

したがってカテゴリ E は「形式上は正しい」が、「汎用原則として harmless な文言整形」とみなすのは危険。実質的には compare モードの証拠基準に触れている変更である。

## 3. EQUIVALENT / NOT_EQUIVALENT の両判定への作用

### EQUIVALENT への作用

ここには明確に作用する。

提案の狙いどおり、モデルが
- コード差分を見つける
- それをそのまま “diverging behavior” と呼ぶ
- 反例があると見なす
- `NOT EQUIVALENT` に流れる
という短絡を抑える可能性はある。

特に D1 が「テストの pass/fail outcome 一致」である以上、「反例があるならどのテストのどの assertion outcome が変わるか」を問うのは、観測境界を internal behavior から test oracle に戻す効果がある。

### NOT_EQUIVALENT への作用

実装者は「`COUNTEREXAMPLE` ブロックは変更しないので直接影響しない」と述べているが、監査上はこれをそのまま受け入れにくい。

理由は 2 つある。

1. 差分としては `NO COUNTEREXAMPLE EXISTS` 側だけが変わる
   - これは `EQUIVALENT` を主張する時の要件だけを変更している。
   - `failed-approaches.md` 原則 #6 が述べるとおり、文面が対称に見えても差分が片側にしか入っていないなら、効果も片側になりやすい。

2. 変更された wording が compare 全体の「有効な証拠像」を暗黙に再定義する
   - モデルはしばしば局所文言をテンプレート全体の規範として一般化する。
   - その結果、真の `NOT_EQUIVALENT` ケースでも、assertion-level の差分を即座に特定できない場合に、差異の採用をためらう可能性がある。
   - つまり「直接は EQUIV 側のみ変更」だが、間接的には `NOT_EQUIVALENT` 証明の採用閾値も上げうる。

### 実効的差分の評価

変更前との差分でみると、この案はほぼ確実に片方向的である。

- 変更前には許されていた広い反例記述を、EQUIV 側だけでより狭い形式に絞る
- NOT_EQ 側の positive proof path には同等の対称変更を入れていない

よって、「片方向にしか作用しないか確認する」という観点では、答えは Yes: 実効的には主として EQUIVALENT 側に作用する。

これは `failed-approaches.md` 原則 #1「判定の非対称操作は必ず失敗する」と緊張関係にある。

## 4. failed-approaches.md の汎用原則との照合

実装者の自己評価は楽観的すぎる。主に以下の原則に近い。

### 原則 #1 判定の非対称操作
最も近い懸念。

- 提案は EQUIV 主張時の `NO COUNTEREXAMPLE EXISTS` にのみ追加の具体性を要求する。
- これは「EQUIV をよりちゃんと考えさせる」つもりでも、実効的には EQUIV 側の思考様式だけを変える変更。
- 片側の誤りを減らしたい意図の変更は、しばしば全体最適でなくクラス間トレードオフになる。

### 原則 #6 「対称化」は既存制約との差分で評価せよ
提案文は D1 整合性を根拠に“定義の明確化”とみなしているが、差分は対称ではない。

- D1 自体は compare 全体の定義
- しかし変更は `NO COUNTEREXAMPLE EXISTS` のみ
- したがって「定義の整合化」ではなく「片分岐の運用変更」とみるべき

この点で原則 #6 に強く抵触する。

### 原則 #20 目標証拠の厳密な言い換え
今回の変更はまさにこれに近い。

- `diverging behavior` を、より狭く・より厳格な `which assertion would produce a different PASS/FAIL outcome` に言い換えている。
- 意図は明確化でも、モデルには「そこまで言えないなら反例扱いするな」という強いシグナルとして作用しうる。
- これは正当な差異の採用まで躊躇させる危険がある。

### 原則 #26 中間ステップでの過剰な物理的検証要求
完全一致ではないが、かなり近い。

- 今回は `file:line` や assertion 名の引用義務までは課していない。
- しかし「どの assertion が変わるか」を要求すると、モデルは assertion レベルの特定作業を追加で行う必要を感じやすい。
- その結果、反例を見つけた後にさらに assertion 特定へ寄り道し、探索コストを増やす可能性がある。
- 特に真の `NOT_EQUIVALENT` ケースで、差異は把握しているが assertion 単位への落とし込みが遅れると、安全側フォールバックが起こりうる。

### 原則 #2 出力側の制約は効果がない
完全一致ではない。
この変更は単なる最終回答フォーマットではなく、反例探索の対象そのものを変えようとしている点で、単純な「こう答えろ」制約よりは一段深い。
ただし、実装位置が certificate の記述欄である以上、「何を調べるか」より「どう書くか」に流れる危険はある。

小結:
- 最も重要なのは #1, #6, #20。
- 補助的懸念として #26。
- 「不抵触」とまでは言えない。むしろ過去失敗の再演リスクが高い。

## 5. 汎化性チェック

### 明示的な固有識別子の有無
- ベンチマーク対象リポジトリ名: なし
- テスト名: なし
- コード断片（ベンチマーク対象 repo の実コード）: なし
- 特定ドメインの API / フレームワーク名: なし

この点では overfitting 的な露骨な違反は見当たらない。

ただし注意点がある。
- 提案文のタイトルには `Iter-106` というプロセス上の数値 ID がある。
- これはベンチマーク対象固有識別子ではなくイテレーション管理上のメタ情報なので、過剰適合の本質的証拠とは言いにくい。
- 監査観点 5 の趣旨は「特定ケース/リポジトリ/テストへの誘導の有無」なので、ここで本質的に問題なのはむしろ文面の作用方向である。

### 暗黙のドメイン仮定
軽微な懸念はある。

- 「which assertion would produce a different PASS/FAIL outcome」という wording は unit test / xUnit 的な assertion 文化をやや強く想起させる。
- 実際には全てのテストが明示的 assertion 文を持つとは限らない。例: golden file 比較、snapshot、exit status、exception expectation、property-based predicate、framework-level matcher、implicit oracle。
- D1 は pass/fail outcome の一致であり、必ずしも“assertion 文の同定”までは必要ない。

したがって、この文言は
- リポジトリ固有ではない
- しかしテスト様式としては assertion-centered にやや寄っている
という評価になる。

より汎用的にするなら、`which observable test check or pass/fail outcome would differ` のように assertion を唯一の形式にしない方がよい。

## 6. 全体の推論品質への期待効果

改善余地はあるが、提案どおりの位置に入れるのは危険。

### 良い点
- 内部実装差分と観測可能差分を混同しない、という方向性は正しい。
- D1 の「modulo tests」という定義に再注目させる点は有益。
- EQUIV ケースでの安易な偽陰性を減らす可能性はある。

### 悪い点
- 差分の入り方が片側だけなので、全体精度改善ではなくクラス間しきい値移動になりやすい。
- assertion-level 指定は、テスト oracle の一般概念より狭い。
- 「定義の明確化」のつもりが、モデルには「その粒度まで言えない差異は採用するな」という禁止的シグナルに見える可能性がある。

### 監査としての総合判断
改善したい失敗モードの理解は妥当だが、今回の具体案はその修正の入れ方が悪い。

もし同じ問題意識を活かすなら、
- `NO COUNTEREXAMPLE EXISTS` のみを締めるのではなく、compare 全体で「relevant behavior = test-observable outcome」であることをより中立的に示す
- `assertion` に限定せず `observable test outcome / test check / oracle` といった広い語にする
- EQUIV 側だけでなく COUNTEREXAMPLE 側も含めて、観測境界の説明を整合的に扱う
といった再設計の方が安全。

## 最終判断

承認: NO（理由: 変更の思想自体は理解できるが、実効差分は `EQUIVALENT` 側の反証様式だけを狭める片方向変更であり、failed-approaches.md の原則 #1, #6, #20, #26 に近い。さらに `assertion` への言い換えは D1 の「pass/fail outcome」より狭く、汎用性もやや落とすため。）
