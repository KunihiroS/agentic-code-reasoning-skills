# iter-19 discussion

## 総評
提案は、compare の「semantic difference 発見後」の内部判定だけを、抽象 obligation ラベル中心の処理から「premise / assertion に結びついた divergence claim」中心へ置換するものです。探索経路・relevant tests 発見規則・STRUCTURAL TRIAGE を固定化せず、既存の研究コア（番号付き前提、仮説駆動探索、手続き間トレース、反証）とも整合しています。監査 PASS の下限を満たしつつ、compare 実行時の分岐を実際に変える提案になっています。

## 1. 既存研究との整合性
最小限の検索あり。

- URL: https://arxiv.org/abs/2603.01896
  - 要点: 論文の中核は explicit premises, execution-path tracing, formal conclusions であり、structured template を「certificate」として使う点にある。提案の premise-linked claim 化は、この certificate 性を compare の差分処理へ延長する方向で、論文の主張と整合的。
- URL: https://arxiv.org/html/2603.01896v2
  - 要点: fault localization / code QA 側でも claims を明示的証拠へ結びつける説明があり、提案の「premise→claim→prediction の compare への移植」は、全く別原理の導入ではなく未活用要素の横展開として読める。

補足: この検索は、提案が原論文の localize/explain 系の発想に明示依拠しているため実施した。検索範囲は最小限に留めた。

## 2. Exploration Framework のカテゴリ選定
カテゴリ F（原論文の未活用アイデアを導入する）は適切です。

理由:
- 変更対象は compare 内の既存分岐であり、新しい大域方針や別系統の heuristic を足す提案ではない。
- localize / explain 的な「claim を証拠に結びつける」発想を compare に移している。
- A/B/C/D/E/G のどれかに見えなくもないが、中心は順序変更でも自己チェック追加でも簡素化でもなく、「原論文で既に使われている証拠化の型」の転用なので F が最も自然。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用
片方向最適化ではなく、両方向に作用します。

- EQUIVALENT 側:
  - 変更前は、semantic difference を obligation レベルで早く吸収しやすく、無害と有害の境界が粗いまま「PRESERVED BY BOTH」へ寄る余地がある。
  - 変更後は、absorbing の前に「どの premise/assertion に対する差か」を明示させるため、偽 EQUIVALENT を減らしやすい。
- NOT_EQUIVALENT 側:
  - 変更前は、semantic difference を見つけた時点で obligation ラベルを介して差分を過大評価し、実際の assertion 境界まで届いていない差でも NOT_EQ 寄りに扱う余地がある。
  - 変更後は、assertion へ届く trace target が必要になるため、偽 NOT_EQUIVALENT も減らしやすい。

実効的差分は「semantic difference を verdict に使う直前の昇格条件」が変わる点です。理由説明の言い換えではなく、差分の吸収・保留・断定の基準が変わっています。

## 4. failed-approaches.md との照合
本質的再演ではありません。

- 原則1「再収束を比較規則として前景化しすぎない」: 非該当。提案は再収束の説明を既定化せず、むしろ差分を先に premise/assertion へ接続する。
- 原則2「未確定を常に保留側へ倒す既定動作」: 非該当。UNVERIFIED や保留への新規 fallback gate を増やしていない。
- 原則3「抽象ラベルで差分昇格を強くゲート」: むしろ逆方向。obligation という抽象ラベルの前景化を弱め、より具体的な premise-linked claim に置換している。

注意点として、実装時に CLAIM D[N] を新しい抽象分類ラベルとして運用すると原則3に接近しうるが、proposal 文面では「分類ラベル追加」ではなく「premise/assertion に接続する記述義務」に留まっており、現時点では問題ないです。

## 5. 汎化性チェック
汎化性は概ね良好です。

- 具体的な数値 ID, ベンチマークケース ID, リポジトリ名, テスト名, 実コード断片: 含まれていません。
- D[N], P[N] などの記法は skill 内の抽象テンプレート表現であり、固有識別子ではありません。
- 例外型/戻り値条件の例は一般的で、特定言語・フレームワーク専用の条件にはなっていません。
- 暗黙のドメイン前提も薄いです。提案の中心は「semantic difference を test premise / assertion へ接続してから verdict に使う」という一般原則で、言語非依存です。

## 6. 全体の推論品質への期待効果
期待できる改善は次の通りです。

- semantic difference の扱いが「抽象 obligation ラベル」から「観測境界に接続された主張」へ具体化される。
- 差分検出後の reasoning chain が短絡しにくくなり、absorb / escalate の誤りが減る。
- compare で最も誤りやすい「差分は見えたが test outcome への接続が曖昧」という中間地帯を整理できる。
- 既存コア構造を壊さず、局所置換で効くため回帰リスクも相対的に低い。

## 停滞診断
- 懸念 1 点: 「premise-linked claim」という説明の導入が監査 rubric には刺さりやすい一方、compare 実行時に claim 作成だけして verdict 分岐が従来通りなら停滞する。しかし proposal は「before/after の decision-point delta」「Trigger line」「Payment」を明示しており、単なる説明強化だけには留まっていない。

failed-approaches 該当性:
- 探索経路の半固定: NO
- 必須ゲート増: NO
- 証拠種類の事前固定: NO

## compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  - semantic difference 発見後、obligation ラベルだけで absorb / verdict せず、specific premise/assertion への trace を 1 段要求するようになる。
  - その結果、PRESERVED BY BOTH に入る差分数、UNRESOLVED に残る条件、NOT_EQUIVALENT を出せる条件が観測可能に変わる。

- 1) Decision-point delta:
  - IF/THEN 形式で 2 行（Before/After）になっているか？ YES
  - Before/After が条件も行動も同じで理由だけ言い換えか？ NO
  - Trigger line（発火する文言の自己引用）が差分プレビューに含まれているか？ YES
  - 実際に変わる意思決定ポイント: 「semantic difference を見つけたあと、即 obligation-level classify するか、premise/assertion に再記述してから classify するか」という分岐。

- 2) Failure-mode target:
  - 対象: 偽 EQUIV / 偽 NOT_EQ の両方
  - メカニズム: assertion 境界に届いていない差分の過剰昇格を抑えつつ、逆に assertion に効く差分の早すぎる吸収も抑える。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？ NO

- 3) Non-goal:
  - relevant tests 発見規則は変えない。
  - STRUCTURAL TRIAGE や早期 NOT_EQUIV の条件を広げたり狭めたりしない。
  - semantic difference の処理を置換するだけで、探索経路の固定や新たな mandatory fallback は増やさない。

追加チェック:
- Discriminative probe:
  - 抽象ケースは十分に弁別的です。内部差分はあるが、ある assertion には効き、別の assertion には効かないケースを想定しており、変更前は obligation レベル吸収で偽 EQUIV、または差分過大評価で偽 NOT_EQ が起きうる。
  - 変更後は、同じ必須総量の中で「semantic difference の扱い」を置換しており、新しい大域ゲートを増やさずに誤判定回避の説明ができている。

- 支払い（必須ゲート総量不変）の A/B 対応付け:
  - 明示あり。旧 MUST を demote/remove し、新 MUST に置換する Payment が書かれている。ここは停滞対策として十分です。

## 最終判断
提案は、監査に刺さる説明追加だけでなく、compare の実行時分岐を具体的に変える設計になっています。failed-approaches.md の本質的再演でもなく、汎化性違反も見当たりません。加えて、EQUIVALENT 側と NOT_EQUIVALENT 側の両方で観測可能な差が見込めます。

修正指示（最小限）:
1. 実装時は CLAIM D[N] を新しい抽象ラベル体系として肥大化させず、「specific premise/assertion への接続義務」であることを一文で固定すること。
2. compare 本文と checklist の両方で、旧 obligation-level 文言を残さず完全置換にすること。二重に残すと旧分岐が温存されて停滞しやすい。

承認: YES
