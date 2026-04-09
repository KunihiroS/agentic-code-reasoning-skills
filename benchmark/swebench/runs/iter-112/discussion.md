# Iter-112 監査コメント

## 総評
提案の意図は理解できる。現行 Guardrail #5 の末尾文 "thorough-but-incomplete analysis" は抽象的で、何が不足しているのかを読み手が自力で補完しなければならない。一方で、今回の差分は「抽象語の明確化」であると同時に、実効的には「どこまで追うべきか」の要求を強める方向にも見える。そのため、表面上は中立でも、変更前との差分としては片方向寄りに作用する懸念が残る。

結論を先に書くと、この提案は
- カテゴリ E（表現改善）としては妥当
- 研究コアとも整合的
- ただし実効差分は主として premature NOT_EQUIVALENT を抑える方向に寄りやすい
- その結果、failed-approaches の「差分ベースで見た非対称性」および「実質的な立証責任の引き上げ」に接触する懸念がある

よって現時点では承認しない。

## 1. 既存研究との整合性

### 参照した Web 情報（DuckDuckGo MCP 経由）
1. https://arxiv.org/abs/2603.01896
   - Ugare & Chandra "Agentic Code Reasoning"
   - 要点: semi-formal reasoning は、明示的 premises、execution path tracing、formal conclusion を要求することで、unsupported claim や case skip を減らす設計である。
   - 整合性評価: 今回の提案はこの研究の「incomplete reasoning chain を減らす」という方向性には整合する。

2. https://arxiv.org/abs/2201.11903
   - Wei et al. "Chain-of-Thought Prompting Elicits Reasoning in Large Language Models"
   - 要点: 中間推論ステップの明示化は複雑推論の性能改善に寄与する。
   - 整合性評価: 曖昧なスローガンより、欠落している推論部分を具体化する方が一般に有利、という補助的根拠になる。

3. https://arxiv.org/abs/2305.10601
   - Yao et al. "Tree of Thoughts"
   - 要点: 推論性能は、単に thought を増やすだけでなく、lookahead・self-evaluation・branch の継続/打ち切り判断に依存する。
   - 整合性評価: 「正しい関数に到達しただけで止めない」という発想自体は妥当。

### 総合所見
研究との方向整合性はある。特に docs/design.md の「Incomplete reasoning chains」を guardrail に翻訳する設計思想とも一致する。ただし、既存研究が支持しているのは「構造化された検証・反証・トレース」の有効性であり、今回の 1 文書き換えだけで十分な改善が出るとは研究からは直接言えない。つまり、方向は合っているが、効果量の根拠は弱い。

## 2. Exploration Framework のカテゴリ選定は適切か

提案者のカテゴリ E（表現・フォーマット改善）という分類は妥当。
理由:
- 変更が 1 文の言い換えであり、手順追加や順序変更ではない
- 既存 guardrail の意味を大きく変えず、曖昧語を状態記述に置き換えている
- failed-approaches #22 が警戒する「具体物の例示」は避けている

ただし、実質的な狙いは単なる wording 改善ではなく「観測終点まで追え」という探索ナビゲーションの強化である。したがって、分類上は E でよいが、機能上は B/F にもまたがる。ここ自体は問題ではないが、「E なので安全」とは言い切れない。

## 3. EQUIVALENT / NOT_EQUIVALENT の両方にどう作用するか

### 変更前の意味
現行文:
"After building a reasoning chain, verify that downstream code does not already handle the edge case or condition you identified."

これはすでに、
- 差分やエッジケースを見つけても
- そのまま NOT_EQUIVALENT に飛ばず
- downstream handling を確認せよ
という趣旨を持っている。

### 変更後の追加効果
提案文:
"Confident-but-wrong answers often come from chains that trace the right functions but stop before the final observation point."

この差分が実質的に追加するのは、
- 正しい call path に入っていても不十分
- 中間ノードで止まるな
- 最終観測点まで追え
というメッセージである。

### EQUIVALENT 判定への作用
正方向には作用しうる。
- 差分が見つかっても downstream で吸収されるなら EQUIVALENT
- そのため、premature NOT_EQUIVALENT を減らす可能性がある

### NOT_EQUIVALENT 判定への作用
理論上は作用しうる。
- 逆に、見かけ上同じでも最終観測点では差が現れる可能性があるため、最終観測点まで追うことは premature EQUIVALENT も減らしうる

### しかし「変更前との差分」で見るとどうか
ここが重要。
現行文はすでに downstream handling の確認を要求している。今回の新規差分は、それをより印象的に「final observation point」まで追えと再記述したもの。したがって増分として最も強く働くのは、
- 中間差分を見て早めに NOT_EQUIVALENT と言ってしまう失敗
を抑える方向である。

一方で、false EQUIVALENT を減らす効果は相対的に弱い。なぜなら現行文の主語はすでに「identified edge case or condition」であり、今回の言い換えはその downstream absorption チェックをさらに鮮明にしたものだからである。

監査結論:
- 表面上は両方向に読める
- しかし実効差分としては NOT_EQUIVALENT 側のハードル上昇に寄りやすい
- failed-approaches #6 が言う「文言が対称でも差分は非対称」を完全には回避できていない

## 4. failed-approaches.md との照合

### 明確に非抵触と言える点
- #2 出力側の制約: 出力形式そのものは変えていない
- #3 探索量の削減: 探索を減らす変更ではない
- #22 具体物の例示: final observation point は具体物ではなく状態記述であり、ここは良い

### 懸念がある点
1. #1 / #6 / #12 判定の非対称操作・差分ベースの非対称性
   - 新規差分としては「中間差分を見ただけで結論を出すな」を強くするので、premature NOT_EQUIVALENT 抑制に寄りやすい
   - 提案者は非対称性なしと書いているが、差分ベースでは楽観できない

2. #19 エンドツーエンド完全立証義務の付与
   - "final observation point" は意味論的には良い表現だが、モデルによっては「最後まで全部追え」という重い義務として解釈する可能性がある
   - 複雑な call chain では探索予算圧迫のリスクがある

3. #20 厳格・排他的な書き換え
   - 提案者は「禁止ではなく記述」としているが、実際には現行より強い警告として作用しうる
   - 特に "stop before the final observation point" は failure mode をかなり鋭く指摘する表現で、モデルにとっては消極方向のブレーキになりうる

4. #23 抽象的問いだけでは改善しない
   - 今回は単なる問いではなく状態記述なので #23 そのものではない
   - ただし、具体的な検証手順は増えないため、改善効果が wording 依存に留まる可能性はある

総合すると、「完全な再演」ではないが、failed-approaches 群が警戒している失敗方向に部分接触している。

## 5. 汎化性チェック

### ルール違反の有無
明白なベンチマーク過剰適合の証拠は見当たらない。
- 特定の対象リポジトリ名: なし
- 特定のテスト名: なし
- 特定の関数/クラス/ファイルパス: なし
- ベンチマークケース ID: なし
- ベンチマーク対象コード断片: なし

proposal.md にある数値や識別子は、
- Iter 番号
- Guardrail 番号
- failed-approaches の項番
であり、いずれもこの改善プロセス内の自己参照であって、ベンチマーク対象そのものの識別子ではない。

また、変更後文言の "final observation point" は、
- 特定言語の assertion API
- 特定フレームワークの test runner
- 特定の call graph 形状
を明示していないため、文面上の汎化性は高い。

### 暗黙のドメイン仮定
軽微な懸念はある。
- "observation point" はテストオラクルや最終アサーションを暗に想起しやすく、compare モードには非常に自然
- しかし explain / localize では「何が final observation point か」が compare ほど自明でない場合がある

したがって、ドメイン固有ではないが、比較タスク寄りの発想が少し強い。

## 6. 全体の推論品質がどう向上すると期待できるか

期待できる改善:
- 「差分を見つけた時点で十分調べた」と錯覚する失敗を減らす
- 中間ノードの差分と最終観測結果を区別しやすくする
- Guardrail #5 の意味解像度を上げる

ただし限界も明確:
- 追加されるのは新しい検証手順ではなく、既存 guardrail の言い換えである
- Step 5, Step 5.5, Compare checklist にはすでに downstream / counterexample / claim outcome の確認がかなり入っている
- そのため、改善が起きるとしても主因は「注意喚起の再焦点化」であり、プロセスの能力向上は限定的

要するに、微小な改善はありうるが、回帰リスクゼロで確実に得られる改善とは言いにくい。

## 最終判定
承認: NO（理由: 研究方向との整合性と文面の汎化性は良いが、変更前との差分としては premature NOT_EQUIVALENT を抑える方向に寄りやすく、failed-approaches #6/#19/#20 系の懸念を十分に解消できていない。加えて、効果は主に wording 強化に依存しており、既存の Step 5・Compare checklist を超えるプロセス改善としては弱い。）
