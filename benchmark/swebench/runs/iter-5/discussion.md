# Iter-5 監査ディスカッション

## 総評
提案は、`compare` モードの Step 4 に `Relevance to test` 列を追加し、各トレース対象の関数が「どの relevant test の判定経路に、なぜ関係するか」を明示させるものです。

結論から言うと、この提案は概ね妥当です。変更規模が非常に小さく、研究コアを壊さず、既存の `localize/diagnose` 系テンプレートに存在する「各メソッドがどの前提・判定に効くかを明示する」という仕組みを `compare` に移植する形になっています。とくに `compare` モードでは、関数を読んだ事実と「その関数差分が本当に relevant test の結果差につながるか」の間にギャップが残りやすく、この列追加はそのギャップを埋める方向です。

一方で、効果は主として「差分発見後の接続確認」の強化であり、テスト列挙漏れや pass-to-pass 範囲判定ミスを単独で解消するものではありません。したがって万能薬ではありませんが、既存構造との整合性が高い改善です。

## 1. 既存研究との整合性

注: DuckDuckGo MCP の search エンドポイントは今回 no results だったため、同じ DuckDuckGo MCP 名前空間の `fetch_content` を用いて既知の公開 URL を取得し、整合性確認を行いました。

### 参照 1
- URL: https://arxiv.org/abs/2603.01896
- 要点:
  - 論文の中心主張は、semi-formal reasoning により「explicit premises, trace execution paths, derive formal conclusions」を強制することです。
  - つまり、単に関数を読むだけでなく、推論対象と結論をつなぐ証拠の鎖を明示することが精度改善の本体です。
  - 今回の `Relevance to test` 列は、Step 4 の関数トレースを最終判定対象である test outcome に結びつける補助なので、論文の「certificate 的に飛躍を防ぐ」方向と整合します。

### 参照 2
- URL: https://en.wikipedia.org/wiki/Program_slicing
- 要点:
  - program slicing は「ある観測点の値に影響しうる文の集合」を特定する考え方です。
  - 今回の列追加は、厳密な slicing そのものではないものの、「この関数が test assertion / outcome に影響する経路上にあるか」を明示させるため、発想として slicing 的です。
  - したがって、無関係な差分を重要視する誤りを減らす一般原則と整合的です。

### 参照 3
- URL: https://en.wikipedia.org/wiki/Call_graph
- 要点:
  - call graph は手続き間の呼び出し関係を表しますが、単に呼び出し関係があるだけでは十分ではなく、どの経路が実際の関心対象に関係するかの精度が重要です。
  - 今回の提案は、既存の interprocedural tracing を call relationship の記録で終わらせず、test relevance まで押し込むものです。
  - これは「呼び出し関係の列挙」と「判定に効く経路の特定」を区別する、より精密な静的推論の方向です。

### 研究整合性の監査結論
提案は既存研究に反していません。むしろ、
- 論文の certificate 的構造
- program slicing 的な関連性絞り込み
- call graph を test outcome に接続する精度向上
を、軽量なテンプレート変更で取り込む案と評価できます。

## 2. Exploration Framework のカテゴリ選定は適切か

### 判定
カテゴリ F の選定は妥当です。

### 根拠
提案の本質は、`diagnose` の Phase 2 テーブルにある `RELEVANT` という発想を `compare` の Step 4 に持ち込むことです。これは Objective.md の F カテゴリにある
- 「論文の他のタスクモード（localize, explain）の手法を compare に応用する」
にかなり直接的に一致しています。

### 他カテゴリとの境界
副次的には D（メタ認知・自己チェック強化）や E（表現・フォーマット改善）の面もあります。しかし今回の変更の中核は、単なる wording 改善ではなく、論文由来の別モードの証拠記述形式を compare に移植する点です。したがって最も本質的なカテゴリは F です。

## 3. EQUIVALENT 判定と NOT_EQUIVALENT 判定の両方への作用

### 変更前との差分の本質
変更前の Step 4 は、各関数の verified behavior は記録しますが、その関数が「relevant test の outcome に接続する経路上にあるのか」を明示しません。

そのため、以下の2種類の誤りが残ります。
1. 関数差分を見つけた時に、それが test outcome に効くか未確認のまま重く扱う。
2. 関数を読んだことで十分追跡した気になり、実際には test assertion への接続確認が不十分なまま結論する。

今回の変更は、この接続確認を Step 4 の各行で要求するものです。

### EQUIVALENT 側への作用
EQUIVALENT ペアでは、主に「見つけた差分が relevant test に効かない」ことを適切に示せるかが重要です。

この列追加により、モデルは各関数差分について
- どの test に関係するか
- なぜその関係があると言えるか
を都度書かされるため、無関係な差分を根拠に NOT_EQUIVALENT と言う誤りを減らす方向に作用します。

さらに、README.md にある persistent failure が EQUIVALENT 側に偏っていることとも整合します。EQUIVALENT 判定では「差分が存在する」こと自体ではなく、「差分が test outcome を変えるか」が本丸なので、relevance 明示はとくに有効です。

### NOT_EQUIVALENT 側への作用
NOT_EQUIVALENT ペアでも効果はあります。ここでは逆に、見つけた差分が本当に relevant test の outcome divergence を生むことを早い段階で接続できます。

つまりこの変更は、
- 単なる semantic difference
から
- test-relevant semantic difference
への昇格条件を明示するため、NOT_EQUIVALENT の主張の証拠密度を上げます。

もし本当に relevant path 上の差分なら、`Relevance to test` 列はその差分を弱めるのではなく、むしろ counterexample 記述の前段を補強します。

### 片方向にしか作用しないか
片方向だけには作用しません。両方向に作用します。

- EQUIVALENT には: irrelevant difference を過大評価しない方向で効く
- NOT_EQUIVALENT には: relevant difference を test outcome divergence へ接続する方向で効く

ただし、実効差分の強さは非対称です。README.md の現状分析から見て、期待される改善幅は EQUIVALENT 側のほうが大きい可能性があります。これは提案が片方向専用だからではなく、現状の主要ボトルネックが EQUIVALENT 側に偏っているためです。

### 残る限界
この変更だけでは、
- relevant tests の抽出自体が漏れる場合
- pass-to-pass tests の call path 判断が早い段階で誤る場合
- Step 4 を埋めても Step 5/結論でその情報を使わない場合
までは自動では防げません。

したがって、「差分の relevance 明示」という中間層の強化であり、compare 全工程の完全な保険ではありません。

## 4. failed-approaches.md の汎用原則との照合

### 判定
明示的な抵触はありません。

### 根拠
`failed-approaches.md` には現時点で具体的な共通失敗原則が未登録です。したがって、文書上のブラックリスト違反はありません。

ただし監査上は「未登録だから何でも良い」ではなく、本質的な過去失敗の再演でないかを見る必要があります。その観点では、今回の提案は
- 特定ケース向けルール追加
- 直接的な判定ショートカット
- ベンチマーク依存の if-then
ではなく、証拠表の粒度を一段上げるだけです。

よって、過去失敗の表現替えをしているようには見えません。

## 5. 汎化性チェック

### 明示的な固有識別子・具体例の混入チェック
提案文には以下のような違反は見当たりません。
- ベンチマークの具体的ケース ID
- 対象リポジトリ名
- 特定テスト名
- 特定コードベース固有の関数名やクラス名
- 実コード断片の引用

含まれている具体物は `SKILL.md` 自身の既存表ヘッダ引用と、一般概念としての `test(s)`・`Function/Method`・`file:N` などだけです。これは Objective.md の R1 の減点対象外に該当し、監査上は問題ありません。

### 数値 ID の扱い
`T[N]` のような記法は、論文テンプレートの抽象的な premise/test 番号表記であり、ベンチマーク固有 ID ではありません。よって違反ではありません。

### 暗黙のドメイン依存性
提案は test outcome と call path の関係を問う一般原則であり、特定言語・フレームワーク依存ではありません。関数名ベースでなく「relevant path かどうか」を問うので、
- Python
- Java
- JavaScript/TypeScript
- C/C++
のような異なる言語でも適用可能です。

ただし、前提として「test という観測単位がある compare タスク」に強く最適化されています。これは `compare` モードの定義そのものに沿った制約であって、過剰適合とは言えません。

### 監査結論
汎化性は十分高いです。ベンチマーク狙い撃ちの匂いは弱いです。

## 6. 全体の推論品質がどう向上すると期待できるか

### 改善が期待できる点
1. 関数理解と test 結論の間の飛躍を減らす
   - 既存 Step 4 は「関数を読んだ」ことの証明にはなるが、「その関数が test outcome に効く」ことの証明にはなりきれていません。
   - 提案はここを埋めます。

2. compare モードでの scope judgment を改善する
   - `compare` では差分の存在ではなく relevance が本質です。
   - relevance 列により、差分の重要度評価が test-grounded になります。

3. Step 5 の反証をやりやすくする
   - relevance が各行にあると、「本当にこの差分は relevant path 上か？」という反証対象が明瞭になります。
   - 結果として counterexample / no-counterexample の記述が具体化しやすくなります。

4. diagnose と compare の様式を寄せ、skill 全体の一貫性を上げる
   - mode 間で「各 traced unit が何に効くかを説明する」という共通規律が強くなります。
   - これは skill 学習・再利用の観点でも自然です。

### 限界と注意点
1. テーブル記入の負荷は少し増える
   - ただし1列追加のみで、複雑性増加は小さいです。

2. 形だけ埋めるリスクはある
   - モデルが `relevant because used by test` のような空疎な文で済ませると効果が薄いです。
   - ただし今回の提案は最小変更を守っており、まずはこのレベルの導入として妥当です。

3. Step 4 と compare certificate 本文の接続はまだ弱い
   - もし将来さらに改善するなら、`ANALYSIS OF TEST BEHAVIOR` または `NO COUNTEREXAMPLE EXISTS` に Step 4 の relevance 行を参照させる強化余地があります。
   - ただし今回は 1 イテレーション 1 仮説の原則上、そこまで同時に入れない方がよいです。

## 最終判断
提案は、
- 研究コアを維持し
- compare モードの弱点に対して直接効き
- EQUIVALENT / NOT_EQUIVALENT の両方に理屈上作用し
- 汎化性も高く
- 変更規模も最小
であり、監査上は前向きに評価できます。

懸念があるとすれば、「効果の中心は relevance 明示であり、relevant test の発見漏れそのものは解決しない」点ですが、これはこの提案の欠陥というより射程の明確さです。

承認: YES
