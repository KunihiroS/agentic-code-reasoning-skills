# Iteration 38 Discussion

## 総評
提案の狙い自体は理解できる。Step 5.5 の最後の抽象 bullet を、結論直前に「どの未検証点が verdict を実際に反転させうるか」を露出させる operational な文言へ置換し、confidence / 追加探索 / UNVERIFIED 明示の切替を促す、という筋は compare 実行時の観測可能な振る舞いに接続している。加えて Payment, Trigger line, Before/After, Discriminative probe も揃っており、「監査に刺さる説明だけで compare の分岐は変わらない」という提案にはなっていない。

ただし、最大の問題は failed-approaches.md 原則 2 の本質的再演にかなり近い点である。提案の中心文言である「verdict を反転させうる最弱リンクが未反証のまま残る THEN HIGH を禁止し、追加探索または UNVERIFIED 明示つきの低確信結論へ切り替える」は、failed-approaches.md が避けるべきと明示している「結論直前に弱い環を特定させ、その未検証性を次の必須行動に結びつける」型とほぼ同型である。ここが監査上の最大ブロッカー。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

README.md / docs/design.md の研究コアは、番号付き前提・仮説駆動探索・手続き間トレース・必須反証を通じて premature closure を防ぐことにある。本提案は core structure を壊さず Step 5.5 の self-check を operational にする案なので、研究コアから大きく逸脱はしていない。

## 2. Exploration Framework のカテゴリ選定
カテゴリ D（メタ認知・自己チェック強化）は適切。
理由:
- 変更対象が Step 5.5 の pre-conclusion self-check そのもの
- 探索順序や証拠種別の再編ではなく、結論直前の自己点検の仕方を変える提案
- Category C や G の要素も少し含むが、主作用点はあくまで self-check

ただし、D として自然であることと、failed-approaches 原則 2 に抵触しないことは別問題。本件はカテゴリ選定は妥当だが、選んだメカニズムが危うい。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用
両方向に作用する設計にはなっている。

- EQUIVALENT 側:
  未読の downstream handling や条件分岐が「等価性を崩しうる最弱リンク」として残っている場合、HIGH のまま EQUIVALENT で閉じるのを抑える方向に働く。
- NOT_EQUIVALENT 側:
  見つけた差分が実際の test outcome divergence に届くか未検証なら、HIGH の NOT_EQUIVALENT を抑え、追加探索や UNVERIFIED 明示へ寄せる方向に働く。

したがって片方向最適化ではない。実効的差分もある。ただし、その差分の出し方が「未検証なら保留へ寄せる既定動作」になりやすく、結果として両方向で判別力より非確定化が学習される懸念がある。

## 4. failed-approaches.md との照合
最大ブロッカーはここ。

failed-approaches.md 原則 2 には、以下が明示的に書かれている。
- 「結論直前に『未検証の最弱リンクが verdict を左右しうるなら確定しない』のような不安定性チェックを Guardrail 化しても...過剰適応を招く」
- 「比較ごとの証拠の弱い側を必ず特定させ、その側の未検証性を次の必須行動に結びつけると...局所的な証拠非対称を過大評価しやすい」
- 「verdict を左右する claim ごとに『未検証依存なら結論前に非確定化する』といった判定を必須化しても...比較判断の出力が痩せやすい」

今回の proposal の中核はまさに:
- weakest verdict-critical link を 1 つ特定する
- それが UNVERIFIED で verdict を flip しうるなら HIGH 禁止
- 追加探索または UNVERIFIED-dependent verdict に切り替える

であり、表現を少し洗練した同型再演に見える。原則 2 への反論として proposal 側は「critical な 1 点だけを見るので広く保留化しない」と述べているが、failed-approaches.md はまさに「弱い側を 1 点特定して次の行動へ結びつける」こと自体を危険視しているため、反論として十分ではない。

## 5. 汎化性チェック
汎化性違反は見当たらない。

- 具体的な数値 ID: なし
- ベンチマーク対象リポジトリ名: なし
- テスト名: なし
- 実コード断片: なし（SKILL.md 自身の引用のみで許容範囲）

また、特定言語・特定ドメイン・特定テストパターンへの依存も薄い。「downstream handler」「未読 handler」は例示としてやや実装系に寄るが、全体としては汎用的。

## 6. 全体の推論品質への期待効果
期待効果はある。
- Step 5.5 の最後の bullet は現状かなり抽象的で、support boundary を守っていても verdict-critical な穴を見落とす余地がある。
- したがって「弱い環を露出させる」という問題設定自体は、premature HIGH confidence を減らすうえで合理的。

ただし本提案のままだと、改善の中心が「弱い環を見つけたら confidence を下げる/保留へ寄せる」に寄りすぎる。そのため、推論品質の改善というより「出力の慎重化」に吸収される可能性が高い。Objective.md の停滞警戒とも相性が悪い。

## 停滞診断
- 懸念点 1つ: 提案は compare の最終出力を変える具体性を持つ一方、その変化が主に「HIGH を禁止して保留や追加探索へ送る」方向であり、監査 rubric に刺さる安全化としては強いが、compare の判別力そのものを上げるより非確定化の学習に寄る恐れがある。

failed-approaches 該当性:
- 探索経路の半固定: NO
- 必須ゲート増: NO（置換を明示しており総量はほぼ不変）
- 証拠種類の事前固定: NO

補足: 上記 3 類型には直接は当たらないが、failed-approaches 原則 2 の「未検証の弱いリンクを結論前の既定保留トリガーにする」変種には YES。

## compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  HIGH confidence の EQUIVALENT / NOT_EQUIVALENT が、UNVERIFIED-dependent verdict か追加探索要求に変わりうる。これは compare 実行結果として観測可能。

- 1) Decision-point delta:
  Before: IF 未検証点が残っていても「今書く結論は traced evidence を超えていない」と言える THEN そのまま高確信で結論しやすい
  After: IF 最弱の verdict-critical link が未検証で、それを反転すると答えも反転しうる THEN HIGH を禁止し、追加探索または UNVERIFIED 明示へ切り替える
  - IF/THEN 形式で 2 行（Before/After）になっているか: YES
  - Trigger line（発火する文言の自己引用）が差分プレビューに含まれているか: YES

- 2) Failure-mode target:
  両方。偽 EQUIV と偽 NOT_EQUIV の双方を、結論直前に残る verdict-critical 未検証点の放置を減らすことで抑えたい、というメカニズム。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か:
  NO

- 3) Non-goal:
  構造差からの早期 NOT_EQUIV 条件や探索開始点は固定しない。証拠種類の新規固定もしていない。変更点は Step 5.5 の末尾 bullet の置換に限定される。

追加チェック:
- Discriminative probe:
  ある差分が中盤では別分岐に見えるが、下流で再収束するか divergence に至るかは未読 handler 次第、という抽象ケースは妥当。変更前は traced evidence の範囲内という理由で早く閉じやすく、変更後はその未読 handler を verdict-critical link として露出できる、という説明は compare への作用が具体。

追加チェック（停滞対策の検証）:
- Payment の A/B 対応付けは明示されているか: YES
  add MUST(weakest verdict-critical link...) ↔ demote/remove MUST(existing final bullet) が書かれている。

## 監査結論
承認しにくい主因は 1 つに絞ると、failed-approaches.md 原則 2 の本質的再演である。

proposal は compare 実行時の分岐差を持ち、汎化性違反もなく、説明責任も比較的高い。そこは評価できる。しかし「結論前に weakest verdict-critical link を特定し、その未検証性を confidence 低下/追加探索/UNVERIFIED 判定へ結びつける」という中心メカニズムが、失敗原則で禁止されている型と近すぎる。このまま通すと、判別力改善ではなく保留トリガーの学習へ寄り、停滞を再発させるリスクが高い。

## 最小修正指示
1. 「weakest verdict-critical link を特定し、未検証なら HIGH 禁止」という必須分岐を削ること。
   置換先は、未検証そのものを保留トリガーにする文ではなく、「結論を支える最終 claim に対して、反転証拠があるならそれを 1 つ探したか」を問う refutation 寄りの operational 化に寄せること。

2. 追加探索/UNVERIFIED-dependent verdict への直結を削り、Step 5 の既存 refutation check に統合すること。
   新しい必須ゲートを作るのではなく、既存 Step 5.5 の抽象 bullet を「support boundary の確認 + 反転しうる証拠の見落とし確認」の一文へ統合する方向がよい。

3. compare 影響は維持しつつ、保留化ではなく「どの条件で claim を再検証するか」に言い換えること。
   つまり output を弱める条件ではなく、追加で見るべき局所証拠を指定する条件に変える。これなら failed-approaches 原則 2 から距離を取れる。

承認: NO（理由: failed-approaches.md 原則 2 の本質的再演）
