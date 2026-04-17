# Iter-3 Discussion — 監査コメント

## 総評
提案の狙い自体は理解できる。`UNVERIFIED` や unknown を結論の確信度へ接続し、過信を減らしたいという問題意識は、README / design が置く「証拠に基づく半形式的推論」「不確実性を隠さない」という方向と整合的である。

ただし今回の具体案は、`failed-approaches.md` が明示的に避けるべきだと述べている類型にかなり近い。特に「結論直前の自己監査に、新しい必須のメタ判断を増やしすぎない」「推論中の最弱点を特定して確信度へ結びつける」の再演に見えるため、このままでは監査 PASS の下限を満たしにくい。

## 1. 既存研究との整合性
README と docs/design.md が示す研究コアは、番号付き前提・仮説駆動探索・手続き間トレース・反証可能性の維持である。今回の提案はこのコアを壊してはいないが、直接の研究コア強化というより「不確実性表明の補強」に属する。

DuckDuckGo MCP で確認した関連文献:

1. https://arxiv.org/abs/2306.13063
   - Xiong et al., "Can LLMs Express Their Uncertainty?"
   - 要点: LLM の verbalized confidence は意思決定上重要だが、過信しがちであり、confidence elicitation や consistency 集約で改善余地がある。
   - 整合性: 「confidence を雑に置かない」「不確実性表明を改善したい」という問題設定には整合する。
   - 限界: この論文が支持しているのは uncertainty expression の改善一般であり、「結論ごとに decision-flip uncertainty を exactly one で必須記載させる」ことまでは直接支持しない。

2. https://aclanthology.org/2024.emnlp-main.1205/
   - Liu et al., "Can LLMs Learn Uncertainty on Their Own?"
   - 要点: LLM の uncertainty 表現は人間の意思決定支援に有益で、改善可能。
   - 整合性: 結論時に uncertainty を明示する方向は一般論として妥当。
   - 限界: こちらも「不確実性を 1 個に圧縮して必須化する設計」の根拠には弱い。

3. https://www.sciencedirect.com/science/article/pii/S0957417424000198
   - Lofstrom et al., "Calibrated explanations: With uncertainty information and counterfactuals"
   - 要点: explanation に uncertainty 情報と counterfactual 観点を組み込むと、説明の信頼性と意思決定支援が上がる。
   - 整合性: uncertainty と counterfactual を結びつける発想自体は妥当。
   - 限界: ただし本件のような「最も plausible な decision-flip uncertainty を必ず 1 つ書く」という運用ルールまでは導かれない。

結論として、研究との整合は「中程度」。confidence / uncertainty を改善する方向性には先行研究の一般支持があるが、今回の必須化の形は研究から強く要請されていない。

## 2. Exploration Framework のカテゴリ選定は適切か
カテゴリ D（メタ認知・自己チェック）は表面的には適切。実際、提案は探索方法や比較枠組みよりも、結論直前の自己監査と confidence 表現を変える案だからである。

ただし、カテゴリ適合と採用妥当性は別問題。Objective.md の D には「推論チェーンの弱い環を特定」「確信度と根拠の対応を明示」が例示されている一方、failed-approaches.md はその具体化が過剰になると失敗しやすいと補正している。したがって「D だから安全」ではなく、今回の案は D の中でも blacklist に近い側の実装になっている。

## 3. EQUIVALENT 判定 / NOT_EQUIVALENT 判定への作用
### 変更前との実効的差分
SKILL.md Step 6 は現在:
- 何が確立されたか
- 何が未検証か
- confidence をどう置くか
を求めるが、confidence の付け方は自由度が高い。

今回の変更は、その自由度を削って
- confidence を付ける
- かつ exactly one の decision-flip uncertainty を命名する
へ変えるもの。

つまり、探索経路や per-test trace そのものは変えず、最終結論の書き方に mandatory なメタ判断を 1 個追加するのが実効差分である。

### EQUIVALENT 側への作用
プラス面:
- 未検証要素を軽視して EQUIVALENT を断定する偽 EQUIV は減る可能性がある。
- 特に「反証が見つからない」ことを「差異がない」に短絡する癖にはブレーキがかかる。

マイナス面:
- EQUIVALENT を出すたびに「もし反転するならどの unknown か」を 1 つ必ず作る運用になり、証拠十分なケースでも人工的な不安要素を最後に挿入しやすい。
- その結果、判定自体より confidence だけが下がる、あるいは結論が必要以上に腰砕けになる懸念がある。

### NOT_EQUIVALENT 側への作用
プラス面:
- counterexample が弱いのに NOT_EQUIVALENT を急ぐケースでは、未検証点を可視化して過信を抑える効果はありうる。

マイナス面:
- しかし NOT_EQUIVALENT は compare テンプレート上、既に具体 counterexample と diverging assertion を要求している。そこにさらに「判断を反転させる unknown」を必須化しても、強い反例があるケースでは意思決定にほぼ寄与せず、むしろ確証的な結論へ余計なノイズを足す可能性がある。

### 片方向最適化か
完全な片方向最適化ではないが、実質的には EQUIVALENT 側の過信抑制に主に効く案で、NOT_EQUIVALENT 側への純増効果は弱い。しかも compare の意思決定境界そのものより、最終説明の tone / confidence 記述に作用する比率が高い。

したがって「両方向に効く」とまでは言いにくい。少なくとも、提案本文が述べるほど対称的な改善ではない。

## 4. failed-approaches.md との照合
ここが最大の懸念。

failed-approaches.md 21-24 行は、結論直前の自己監査に新しい必須メタ判断を増やしすぎないこと、特に「推論中の最弱点を特定して確信度へ結びつける」類型を明確に警戒している。

今回の置換案:
- "Assigns a confidence level ... and names exactly one decision-flip uncertainty ..."

これは表現こそ少し違うが、本質的には
- 最弱点 / 反転点を 1 つ特定し
- それを confidence と接続し
- 結論時に必須で出させる
という設計であり、failed-approaches.md の警告とかなり直接に重なる。

「Step 6 の既存 1 行を置換するだけだから新ゲートではない」という弁明も弱い。ファイルが禁じているのは行数増ではなく、実質的に新しい必須メタ判断が増えることだからである。今回の案はまさにそこに触れている。

## 5. 汎化性チェック
### 明示的ルール違反の有無
提案文中に、禁止される具体的な数値 ID、ベンチマーク対象リポジトリ名、テスト名、実コード断片は見当たらない。
- SKILL.md の自己引用は Objective.md 上も許容範囲
- 例示も「外部要素の挙動」「未読の分岐」「入力制約」など抽象的

したがって、明示的な汎化性違反は現時点ではなし。

### 暗黙のドメイン依存
大きな言語依存・ドメイン依存は薄い。ただし「decision-flip uncertainty を exactly one 挙げる」という作法は、コード推論そのものより explanation style の規律であり、compare 以外のモードや強い証拠が既に揃っているケースでは有効性が不均一になりやすい。これは overfitting というより、タスク非対称性の懸念。

## 6. 全体の推論品質への期待効果
期待できる改善:
- 過信した結論の抑制
- 未検証点の可視化
- 監査時に「何が弱点か」を追いやすくすること

ただし改善の主戦場は「結論の監査しやすさ」であり、compare の本体である
- relevant tests の同定
- per-test tracing
- structural triage
- concrete counterexample
を変えていない。

そのため、推論品質改善の中心が decision quality そのものより、監査 rubric に刺さる説明強化へ寄ってしまう危険がある。

## 停滞診断（必須）
- 懸念 1 点:
  - ある。今回の変更は compare のテスト単位の比較や counterexample 探索の質そのものではなく、最後の `CONFIDENCE` 記述を監査しやすくする方向が中心で、意思決定境界より説明の見え方を改善している比率が高い。

- failed-approaches 該当性:
  - 探索経路の半固定: NO
  - 必須ゲート増: YES
    - 原因文言: `names exactly one decision-flip uncertainty`。行追加はなくても、結論時の必須メタ判断を実質追加している。
  - 証拠種類の事前固定: NO

## 修正指示（2〜3点）
1. `exactly one decision-flip uncertainty` の mandatory 化は削ること。
   - 置換先候補: 既存の `States what remains uncertain or unverified` を少し精緻化するだけに留める。
   - つまり「新しい必須要素を足す」のではなく、既存の uncertainty 記述の質を上げる方向へ戻す。

2. compare に効かせたいなら、Step 6 ではなく compare セクション内の既存 `NO COUNTEREXAMPLE EXISTS` 記述へ統合すること。
   - 追加ではなく統合で支払うこと。
   - 例: `no counterexample exists because ...` の部分に、未検証点が残る場合はそれが counterexample 候補たりうるかだけ簡潔に触れる。
   - これなら EQUIV 判定の飛躍へより直接に効き、NOT_EQUIV 側への無用なノイズも減る。

3. confidence 改善を残すなら、必須ルールではなく LOW/MEDIUM の場合だけの optional guidance に弱めること。
   - `HIGH/MEDIUM/LOW` 自体は維持しつつ、全結論に一律適用しない。
   - その代わり、Step 6 の他の bullet を増やさず、既存 bullet の説明内に吸収して複雑性を増やさないこと。

## 結論
最大のブロッカーは 1 つ:
- `failed-approaches.md` の「結論直前の自己監査に新しい必須のメタ判断を増やしすぎない」「最弱点を特定して確信度へ結びつける」の本質的再演になっている点。

承認: NO（理由: failed-approaches.md の本質的な再演）
