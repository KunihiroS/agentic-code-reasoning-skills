# Iteration 34 — 監査コメント

## 総評
今回の提案は、**iter-33 で削った文言を iter-31 相当に戻す回帰修正**としては理解できます。しかし、監査観点では主変更のかなりの部分が **COUNTEREXAMPLE / NO COUNTEREXAMPLE EXISTS の出力テンプレート文言** と **NOT_EQ 主張時の証拠記述の厳格化** に寄っており、`failed-approaches.md` の BL-2 / BL-15 / 共通原則 #2 #6 に実質的に近いです。したがって、現状のままの承認は難しいです。

---

## 1. 既存研究・コード推論知見との照合（MCP Web検索ベース）

### 検索結果と要点
1. **Ugare & Chandra, "Agentic Code Reasoning" (arXiv 2026)**  
   URL: https://arxiv.org/abs/2603.01896  
   要点:
   - semi-formal reasoning は **explicit premises / execution-path tracing / formal conclusions** を要求する structured prompting。
   - patch equivalence で 78%→88%、実運用パッチで 93% まで改善。
   - 研究の主眼は **証拠収集とトレースの構造化** であり、単なる最終出力文言の整形ではない。

2. **DETAIL Matters: Measuring the Impact of Prompt Specificity on Reasoning in LLMs**  
   URL: https://arxiv.org/html/2512.02246v1  
   要点:
   - prompt specificity は reasoning 精度に影響し、特に procedural task では具体化が有効。
   - ただし論文自身が、**詳細化は reasoning pathways を制約しうる** と明記している。
   - つまり「具体化すれば常に良い」ではなく、**どの部分を具体化するか** が重要。

3. **Puerto et al., "Code Prompting Elicits Conditional Reasoning Abilities in Text+Code LLMs" (EMNLP 2024)**  
   URL: https://aclanthology.org/2024.emnlp-main.629/  
   要点:
   - 入力表現の構造化により reasoning が改善し、state tracking がしやすくなる。
   - 効いているのは **input representation が内部状態追跡を助けること** であり、出力直前の証明書文言追加ではない。

4. **InfoWorld: "Meta shows structured prompts can make LLMs more reliable for code review"**  
   URL: https://www.infoworld.com/article/4153054/meta-shows-structured-prompts-can-make-llms-more-reliable-for-code-review.html  
   要点:
   - 実務面でも structured prompting の有効性は支持される。
   - 一方で、記事は **confident but wrong な structured answer** のリスクも指摘している。
   - したがって、テンプレートを厳格化しても、**探索行動が変わらなければ誤った確信を整然と出すだけ** になりうる。

5. **OpenAI GPT-5.2 Prompting Guide**  
   URL: https://developers.openai.com/cookbook/examples/gpt-5/gpt-5-2_prompting_guide  
   要点:
   - production agent では explicit prompting が重要で、small changes to prompt structure can matter。
   - ただし同時に、verbosity / extra structure は latency・tool use に影響しうるため、**構造追加は目的に直接効く部分に限定すべき**。

### 学術的・実務的評価
- **支持できる点**: iter-33 で曖昧化した指示を戻すこと自体は、DETAIL 論文や Agentic Code Reasoning の主張と整合的です。特に「trace の完成条件を明確にする」方向は妥当です。
- **支持しにくい点**: 今回の具体案の中心は、`COUNTEREXAMPLE` と `NO COUNTEREXAMPLE EXISTS` の **出力テンプレート** と、Guardrail 2 の **assertion まで到達せよ** という厳格化です。研究が支持しているのは **探索・追跡プロセスの構造化** であって、出力証明書の wording 強化そのものではありません。
- 結論として、**「曖昧さを減らす」方向性は妥当だが、提案された差分の置き場所が悪い**、という評価です。

---

## 2. Exploration Framework のカテゴリ選択は適切か？同一カテゴリ既試行か？

### 判定
- **カテゴリ E（表現・フォーマット）自体の選択は形式上は成立**します。
- ただし、**同一カテゴリ E は既に複数回試行済み**です。少なくとも proposal 群から確認できる範囲で:
  - iter-23: E
  - iter-30: E
  - iter-31: E
  - 今回 iter-34: E

### コメント
- よって proposal の「新規カテゴリ」扱いは不正確です。
- さらに今回の変更は、カテゴリ E の中でも **テンプレート文言の具体化** と **Guardrail wording の厳格化** であり、過去の E 系失敗と十分に離れているとは言い切れません。
- もし採るなら「未試行カテゴリ」ではなく、**既知の成功状態への限定的ロールバック仮説** として扱うべきです。

---

## 3. EQUIV / NOT_EQ への影響と、実効的差分の分析

### 提案者の想定
- NOT_EQ: 7/10 → 10/10 回復
- EQUIV: 7/10 維持

### 監査上の見立て
この予測自体が、**変更の作用がほぼ一方向（NOT_EQ 側）である**ことを示しています。共通原則 #6 に照らすと危険信号です。

### 実効差分
変更前（iter-33）との差分を機能単位で見ると:

1. **COUNTEREXAMPLE に `By P[N]` を戻す**  
   - 作用点: NOT_EQ の最終反例記述
   - 実効: NOT_EQ を主張する時だけ、P3/P4 参照と assertion/behavior 接続を追加要求
   - 問題: これは **出力側の証明書要件** に近く、探索そのものを増やす保証が薄い

2. **NO COUNTEREXAMPLE EXISTS に `what assertion in P[N]` を戻す**  
   - 表面上は EQUIV 側にも対称
   - しかし既に EQUIV 側には「反例不在を説明する」構造が元からあり、追加差分は比較的小さい
   - 一方、NOT_EQ 側では `By P[N]` により新たな明示義務が増える
   - よって **差分の強さは対称でない**

3. **Guardrail 2 を assertion/condition まで到達必須に戻す**  
   - 表面上は PASS/FAIL どちらにも適用
   - しかし実運用上は、NOT_EQ を主張するには「Aではこう、Bではこう」と outcome divergence を積極的に示す必要があるため、追加 burden は NOT_EQ 側で強く効く
   - これは BL-2 / BL-6 / BL-14 で繰り返し問題になったパターンに近い

### EQUIV / NOT_EQ への予想影響
- **NOT_EQ**: UNKNOWN を減らす可能性はあります。ただし、改善メカニズムは「探索の収束」ではなく「最終記述の完成条件の強化」に依存しており、逆に証拠不足判定を増やすリスクもあります。
- **EQUIV**: 提案者自身が「変化なし」と見ている通り、現行の持続的 EQUIV 偽陽性にはほぼ効かない可能性が高いです。
- したがって本提案は、**全体推論品質の底上げというより、NOT_EQ 側の completion pressure を上げるだけ** になりやすいです。

---

## 4. failed-approaches.md のブラックリスト・共通原則との照合

### BL-15 との関係
- BL-15 は `COUNTEREXAMPLE` の `By P[N]` を削除した試行の失敗記録です。
- 重要なのは BL-15 の Fail Core で、**COUNTEREXAMPLE wording は結論直前の整形であり、証拠収集そのものを強化しない**と整理されています。
- 今回はその逆操作ですが、**同じ出力側テンプレートに依存する**点で本質的に近いです。

### BL-2 との関係
- Guardrail 2 の「assertion/condition まで到達せよ」は、proposal が否定するほど BL-2 から遠くありません。
- BL-2 の中核は「NOT_EQ と結論するための立証責任を引き上げること」であり、今回の差分も実効的にはそれに近いです。

### 共通原則との照合
- **原則 #1 判定の非対称操作**: 実効差分は NOT_EQ 側に強く作用するため抵触懸念あり。
- **原則 #2 出力側の制約**: `COUNTEREXAMPLE` / `NO COUNTEREXAMPLE EXISTS` の修正はまさに出力証明書側。
- **原則 #5 入力テンプレートの過剰規定**: 「what assertion in P[N]」は限定的ではあるが、assertion framing への再アンカーを起こしうる。
- **原則 #6 対称化の実効差分**: 文面上は両方向でも、変更前との差分は NOT_EQ 側で強い。

### 監査結論
**ブラックリストと実質的に近い**です。表現は違っても、効果としては
- 出力側テンプレート強化
- NOT_EQ 側の立証責任上昇
に寄っています。

したがって、この観点では **承認不可** です。

### 代替提案（別アプローチ）
却下する場合の代替としては、**カテゴリ C: 比較の枠組みを変える** の未試行メカニズムを推します。具体的には:
- **テスト単位の比較の前に、変更された関数/公開APIごとに「外部可観測契約」を1行で比較するステップ**を入れる
- 例: 「この差分は return value / raised exception / mutated persistent state / emitted call のどれを変えうるか」を関数単位で先に整理し、その後 relevant test と接続する

これは
- 出力側制約ではなく、比較フレームそのものを変える
- EQUIV では「コード差分はあるが観測可能契約は不変」を捉えやすく、NOT_EQ では「観測可能契約が変わる」を明示しやすい
- 片方向だけの burden 増ではなく、両方向に同じ比較軸を与える
という点で、今回案より健全です。

---

## 5. 全体の推論品質はどう向上すると期待できるか？

現案のままだと、期待できる向上は限定的です。

- 良くて、NOT_EQ ケースで「何を書けば COUNTEREXAMPLE 完成か」が明瞭になり、**一部 UNKNOWN を減らす**程度。
- しかし EQUIV 偽陽性の主因である「コード差分発見→テスト結果差分と短絡」の改善には薄い。
- さらに、assertion レベルへの到達要求が **探索負荷や立証負荷を増やし、再び NOT_EQ を UNKNOWN/EQUIV に押し戻す**危険があります。

つまり、**局所的な completion aid にはなりうるが、全体の reasoning quality を底上げする変更としては弱い**です。

---

## 6. 結論

### 判定
- **修正を求めます。**
- 特に以下の2点を再設計してください:
  1. `COUNTEREXAMPLE` / `NO COUNTEREXAMPLE EXISTS` の wording 依存を減らし、**探索・比較プロセス側**に効く差分へ寄せること
  2. 変更前との差分が **NOT_EQ 側だけに強く作用していないか** を再点検すること

### 最終結論
**承認: NO（理由: BL-2 / BL-15 / 共通原則 #2 #6 に実質的に近く、実効差分が NOT_EQ 側へ偏るため）**
