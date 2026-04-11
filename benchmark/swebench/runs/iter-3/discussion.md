# Iter-3 監査ディスカッション

## 総評

現提案は、Step 3 の `CONFIDENCE` 行に「medium/low の場合は最も弱い前提と、それを解消する次の探索対象ファイルを 1 文で書く」という条件を足すだけの小変更であり、研究コアを大きく崩すものではありません。これは `SKILL.md` の共有コアにある仮説駆動探索の一部を微修正する提案です [SKILL.md:70-93]。

ただし、監査観点では懸念が強いです。主な理由は次の 4 点です。

1. 変更の発火条件が `CONFIDENCE: medium / low` という自己評価に依存しており、failed-approaches の原則 #9 と正面衝突しやすいこと [failed-approaches.md:26-26]。
2. 実装位置が Step 3 の記録フィールド内部であり、実効としては「受動的な記録欄の拡張」に近く、原則 #8 の再演リスクが高いこと [failed-approaches.md:24-24]。
3. 文面上は対称でも、変更前との差分としては EQUIVALENT 側の探索停止条件により強く作用しやすく、原則 #1 と #6 の非対称化リスクがあること [failed-approaches.md:10-10][failed-approaches.md:20-20]。
4. proposal 自体にコード断片・行番号参照が含まれており、監査観点 5 の厳格運用ではルール違反を含むこと [benchmark/swebench/runs/iter-3/proposal.md:42-52]。

以上より、現案は「意図は理解できるが、採用には弱い」という評価です。

## 1. 既存研究との整合性

### DuckDuckGo MCP 調査

DuckDuckGo MCP で以下の検索を試行しましたが、いずれも結果 0 件でした。
- "LLM self evaluation reasoning paper"
- "language models self correction paper"
- "uncertainty calibration language models paper"
- さらに簡略化した関連クエリ群

そのため、Web から直接安定して回収できた研究根拠は、README でも参照されている原論文 URL の直接取得に限られました。

### 取得できた研究 URL と要点

1. https://arxiv.org/abs/2603.01896
   - 要点: semi-formal reasoning は、明示的前提・実行経路トレース・形式的結論を要求することで、unsupported claim と case skip を減らす「certificate」として機能する。
   - 本提案との整合: Step 3 の探索ジャーナルをわずかに強化する、という意味では原論文の「構造化された探索」の方向には沿っています。
   - ただし注意点: 原論文・README・design が強く押している主因は「premises / tracing / refutation / per-item iteration」であり、自己確信の言語化自体が主要メカニズムとして示されているわけではありません [README.md:47-57][docs/design.md:33-55]。

### 整合性の結論

- 高レベルでは整合的: 既存の semi-formal reasoning の枠内での微修正であり、研究コアを壊してはいません [Objective.md:214-220]。
- 直接的研究根拠は弱い: 原論文が有効と示しているのは、自己評価の洗練そのものよりも、証拠収集と反証を強制する構造です [docs/design.md:42-55]。
- したがって、本提案は「研究と矛盾はしないが、研究で強く支持された改善軸そのものでもない」です。

## 2. Exploration Framework のカテゴリ選定は適切か

### カテゴリ適合性

proposal は Category D を選んでおり、その理由として D2/D3 の交差点、すなわち「弱い環の特定」と「確信度と根拠の対応付け」を挙げています [benchmark/swebench/runs/iter-3/proposal.md:3-24]。分類としては確かに D です。`CONFIDENCE` 欄を拡張し、弱い前提を 1 文で述べさせるので、表面上のカテゴリ選定は妥当です。

### ただし汎用原則としての妥当性は弱い

問題は、カテゴリ D 自体が failed-approaches の中で最も危険な領域の 1 つだという点です。原則 #9 は、自己チェックや自己評価はそのままでは機能せず、特に消極的結論と積極的結論に非対称に作用しやすいと述べています [failed-approaches.md:26-26]。今回の案も発火条件が `medium/low` である以上、入口は依然として自己評価です。

さらに、proposal は「外部的に検証可能な行動の直接要求」だと主張しますが [benchmark/swebench/runs/iter-3/proposal.md:18-25]、実際の変更文言は「どの file would resolve it と書く」までであり、「そのファイルを実際に読む」ことは要求していません [benchmark/swebench/runs/iter-3/proposal.md:50-52]。つまり、外部行動の誘発を期待してはいるが、文言レベルではまだ記録欄の強化に留まっています。

結論として:
- カテゴリ D への分類自体は正しい。
- しかし「D だから良い」ではなく、D の中でも failed-approaches に最も接近した危険なメカニズムです。
- 汎用原則としては、「弱点を言語化させること」より「次の探索を実行させること」の方が本筋であり、現案はそこまで届いていません。

## 3. EQUIVALENT 判定と NOT_EQUIVALENT 判定の両方への作用

### 変更前との差分

変更前:
- `CONFIDENCE: high / medium / low` [SKILL.md:73-77]

変更後:
- `medium/low` のときに、最も弱い前提と、それを解消する次のファイルを 1 文で書かせる [benchmark/swebench/runs/iter-3/proposal.md:48-52]

差分として重要なのは、「high には何も追加されず、medium/low のときだけ追加負荷がかかる」点です。

### NOT_EQUIVALENT への作用

NOT_EQUIVALENT は、比較モードでは具体的 counterexample を 1 つ見つけられると一気に高確信になりやすいです。`COUNTEREXAMPLE` 節もその構造です [SKILL.md:226-230]。そのため、明確な差異を見つけたケースでは追加条件が発火しない、または短時間しか発火しない可能性があります。

効く場面はあります。
- 弱い差異しか見えていない段階で、「何が最弱仮定か」を書かせることで、雑な NOT_EQ 推定を止める。
- 名前推測や中間ノード推論だけで差異ありと誤認するケースを、追加探索に押し戻す。

ただし、これは「NOT_EQ を良くする」より「雑な NOT_EQ を抑える」作用に近いです。

### EQUIVALENT への作用

EQUIVALENT は本質的に「反例がない」ことを扱うため、medium/low に留まりやすいです。比較テンプレートでも EQUIVALENT を主張する場合は `NO COUNTEREXAMPLE EXISTS` を要求しており、こちらは元々、差異の不在をより広く探す必要があります [SKILL.md:232-238]。

そのため今回の差分は、実効的には EQUIVALENT 側でより頻繁に発火する可能性が高いです。つまり:
- 良い方向: 早すぎる EQUIVALENT を減らし、取りこぼしていた NOT_EQ を拾う可能性がある。
- 悪い方向: 真に EQUIVALENT なケースでも追加探索負荷が増え、収束遅延・ターン消費・安全側への別判定を招く可能性がある。

### 非対称性の評価

proposal は「EQUIV/NOT_EQ 双方に同じ条件で適用されるので非対称ではない」と述べます [benchmark/swebench/runs/iter-3/proposal.md:84-90]。しかし failed-approaches の原則 #6 は、対称な文言かどうかではなく「変更前との差分がどちらに実効するか」を見よと警告しています [failed-approaches.md:20-20]。

今回の差分は、high-confidence 経路には何も足さず、medium/low 経路にだけ負荷を足します。そして medium/low は一般に EQUIVALENT 主張側で長く残りやすい。したがって、文面上対称でも、実効上は EQUIVALENT 側により強く作用する可能性が高いです。

結論:
- 片方向にしか作用しない、とまでは断言しません。
- しかし「両方向に同程度に作用する」とも言えません。
- 実効差分は EQUIVALENT 側に偏りやすく、非対称化リスクがあります。

## 4. failed-approaches.md の汎用原則との照合

### 原則 #8 受動的な記録フィールドの追加

もっとも近い失敗原則です [failed-approaches.md:24-24]。

proposal は「単なる記録欄拡張ではなく、次のファイル明示により検証行動を誘発する」と主張します [benchmark/swebench/runs/iter-3/proposal.md:18-25]。しかし実際の diff は Step 3 の `CONFIDENCE` 行への文言追加だけで、新しい探索ステップも、実際にそのファイルを読む義務も追加していません [benchmark/swebench/runs/iter-3/proposal.md:54-57]。

よって本質的には:
- 記録欄に「弱点」と「次のファイル」を書かせる
- しかし、その次のファイルを読むかは依然として任意

となり、原則 #8 の「書くことは増えるが、調べることは保証されない」にかなり近いです。

### 原則 #9 メタ認知的自己チェックの限界

proposal は原則 #9 を回避できていると主張します [benchmark/swebench/runs/iter-3/proposal.md:82-90]。ただし、トリガーは依然として `CONFIDENCE: medium/low` です。つまり「自分はいま不確かか」を自己判定できることが前提です。ここが原則 #9 の危険点そのものです [failed-approaches.md:26-26]。

また、「最も弱い仮定」を言語化させること自体が、自己評価能力への依存を完全には外していません。

### 原則 #1 / #6 判定の非対称操作・差分評価

前節の通り、文言上は対称でも、差分としては EQUIVALENT 側に強く効きやすいです [failed-approaches.md:10-10][failed-approaches.md:20-20]。したがって proposal の自己評価ほど安全ではありません。

### 原則 #27 次仮説の即時確定

proposal は反証後ではなく仮説段階で「どのファイルが解決するか」を 1 文で定めます [benchmark/swebench/runs/iter-3/proposal.md:29-33][benchmark/swebench/runs/iter-3/proposal.md:50-52]。これは原則 #27 の完全一致ではありませんが、「まだ十分な追加証拠がないのに、次の探索軸を先に固定する」という意味で近縁です [failed-approaches.md:62-62]。

### 小結

proposal は failed-approaches を引用して自ら安全性を論じていますが、監査上はむしろ以下の再演リスクがあります。
- 強: #8, #9
- 中: #1, #6
- 弱〜中: #27

「表現を変えた同型失敗」の可能性は無視できません。

## 5. 汎化性チェック

### 明示的ルール違反の有無

あります。proposal には少なくとも以下が含まれます。
- `SKILL.md 76行目` という具体的行番号 [benchmark/swebench/runs/iter-3/proposal.md:42-42]
- 変更前/後のコード断片 [benchmark/swebench/runs/iter-3/proposal.md:44-52]

ユーザー指定の監査観点 5 を厳格に読むなら、これは実装者ルール違反です。

補足すると、Objective の R1 は「SKILL.md 自身の文言引用」は減点対象外としています [Objective.md:202-213]。しかし今回の監査指示はそれより厳格で、「proposal 文中に具体的な数値 ID, リポジトリ名, テスト名, コード断片が含まれていないか。含まれていればルール違反として指摘」と明示しています。したがって本監査では指摘対象にすべきです。

### 暗黙のドメイン依存

proposal 自体は、特定リポジトリ名・特定テスト名・特定言語構文への依存はありません。そこは良い点です。

ただし、暗黙には「次に読むべきものが file として明確に離散化されている」状況を想定しています。これは多くのコードベースで妥当ですが、実際には以下のケースではやや不自然です。
- 主要論点が設定・生成コード・外部 API 契約・型定義に跨る場合
- 1 ファイルより「call path 上の観測点」や「test oracle」が重要な場合
- notebook / REPL / multi-snippet / config-driven な環境

つまり、露骨な overfitting ではないものの、探索対象を「次の file」に定型化しすぎており、汎化性は満点ではありません。

## 6. 全体の推論品質がどう向上すると期待できるか

期待できる改善は限定的です。

### 改善しうる点

- 低確信のまま結論へショートカットする癖を少し抑える。
- Step 3 の探索ログに「どこが弱いか」が残るため、人間監査や自己継続の足場にはなる。
- 名前推測や浅い差分観測からの premature conclusion を、追加読解へ押し戻す可能性がある。

### 期待しにくい点

- 実際に探索行動が増える保証はない。書くだけで終わる可能性がある。
- どのファイルが解決するかを早めに固定すると、探索順序のアンカリングを生む可能性がある。
- medium/low にのみ追加負荷をかけるため、収束が難しい EQUIVALENT 側へ偏ってコスト増となる恐れがある。

### 総合評価

推論品質への期待改善は「小〜中」です。しかも純改善ではなく、
- 一部の premature conclusion は減るかもしれない
- その代わり探索負荷・収束遅延・EQUIVALENT 側の回帰リスクがある

というトレードオフ型です。Objective が求める「全体精度を安定して 100% に近づける汎用改善」としては、根拠がまだ弱いです [Objective.md:5-25]。

## 最終判定

承認: NO（理由: 原則 #8 と #9 の再演リスクが高く、文面上の対称性に対して実効差分は EQUIVALENT 側へ偏りやすい。さらに proposal 文中に行番号・コード断片が含まれており、今回の監査指示では汎化性ルール違反を含むため。）
