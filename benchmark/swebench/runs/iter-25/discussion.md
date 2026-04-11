# Iter-25 discussion

## 総評
結論から言うと、この提案は**承認できません**。理由は、提案の表向きの説明は「`explain` の DATA FLOW ANALYSIS を `compare` に移植する」ですが、**実効的な差分**はそうなっておらず、実際には **「DIFFERENT / NOT_EQ を主張するときだけ、追加の立証責任を課す」** 変更だからです。これは `failed-approaches.md` の **BL-2** と **BL-6** に実質的に近く、さらに **iter-9 の propagation check 案** ともかなり近いです。

---

## 1. Web 検索による妥当性評価（DuckDuckGo MCP）

以下を検索し、関連研究・実務知見を確認しました。

### 1-1. Agentic Code Reasoning
- URL: https://arxiv.org/abs/2603.01896
- 要点:
  - 半形式的推論は「premises → trace → formal conclusion」の**証明書的構造**で精度を上げる。
  - patch equivalence / fault localization / code QA の各タスクで改善が出ている。
  - ただし論文の効き方の中心は、**構造化された探索と反証**であって、特定の結論方向だけに証拠要求を追加することではない。
- 本提案への示唆:
  - 「データフローを意識させる」方向性自体は論文と整合的。
  - しかし今回の差分は `compare` 全体に対する対称的な data-flow 強化ではなく、**DIFFERENT のときだけ propagation trace を要求する非対称変更**であり、論文のコアの移植としては弱い。

### 1-2. LLMDFA: Analyzing Dataflow in Code with Large Language Models
- URL: https://arxiv.org/abs/2402.10754
- 要点:
  - データフロー解析はコード解析の基礎技術。
  - 一方で、LLM にそのまま任せると hallucination が起きやすいため、**問題分解・外部ツール・経路妥当性検証**を組み合わせて精度を出している。
  - few-shot CoT だけでなく、**subtask decomposition** と **validation** が重要とされる。
- 本提案への示唆:
  - 「変数の生成→変更→使用を追う」こと自体は学術的に妥当。
  - ただし、その有効性は**対称的かつ系統的なデータフロー分析**として導入した場合の話であり、今回のように **NOT_EQ 主張時だけ出力欄を足す**形では、LLMDFA が強調する検証性・分解性に届かない。

### 1-3. An improving approach to analyzing change impact of C programs
- URL: https://www.sciencedirect.com/science/article/pii/S0140366421004199
- 要点:
  - change impact analysis では、program slicing / control-flow / call graph / data-flow graph を組み合わせ、**変更がどこへ波及するか**を細粒度で追うことが重要。
  - 研究上も、単純な関数粒度では粗すぎ、**definition/use と interprocedural impact** を丁寧に追う必要があるとされる。
- 本提案への示唆:
  - 「差分から assertion への伝播を見たい」という問題意識は実務・学術の両方で正しい。
  - ただし、この知見が支持しているのは**解析プロセス全体の改善**であって、**判定の片側だけの要求強化**ではない。

### 1-4. Symflower: Test impact analysis
- URL: https://symflower.com/en/company/blog/2024/test-impact-analysis/
- 要点:
  - test impact analysis では、dependency graph をたどって「どの変更がどのテストに影響するか」を結ぶ。
  - 実務上も granularity が重要で、package / file / function / control flow まで追うほど有効だが、**接続関係の構築コスト**も上がる。
- 本提案への示唆:
  - 実務的にも「変更→テスト結果」接続の明示は有意義。
  - しかしコスト増があるため、**全体プロセスの中でバランス良く入れる必要**がある。今回の案は DIFFERENT ケースにだけ重く効くため、コストが片側に偏る。

### 小結
- **肯定面**: data flow / propagation を重視する発想自体は、研究的にも実務的にも妥当。
- **否定面**: 今回の具体的な差分は、その知見を**対称的な解析改善**として実装しておらず、結果として **NOT_EQ 側だけの立証責任増加**になっている。よって、学術的な方向性は良いが、**提案された実装形式は不適切**です。

---

## 2. Exploration Framework のカテゴリ選択は適切か？

**結論: 適切ではありません。**

### 2-1. カテゴリ F 自体は既に試行済み
- iter-8: カテゴリ F（localize の divergence analysis を compare に移植）
- iter-9: カテゴリ F（divergence から assertion への propagation check を追加）

したがって、proposal.md の
> 「カテゴリ A〜D は複数回試行、E は未試行、今回は F」
という整理は**事実誤認**を含みます。E も iter-23 で試行済みですし、F も未試行ではありません。

### 2-2. 今回案は iter-9 とメカニズムが近い
iter-9 の提案はまさに:
- divergence を見つける
- それが assertion に届くかを propagation で確認する
- 届かなければ SAME

というものでした。今回案も:
- DIFFERENT を主張するなら
- divergence point から assertion affected まで
- propagation trace を出せ

であり、**表現は違うが実質はかなり近い**です。

### 2-3. 「論文の explain の DATA FLOW ANALYSIS を移植した」という説明も弱い
`SKILL.md` の `explain` にある DATA FLOW ANALYSIS は、
- key variable を選び
- Created / Modified / Used を追う
という**対称的で一般的な解析枠組み**です。

一方、今回の差分は
- `Comparison: DIFFERENT` のときだけ
- divergence→assertion を書かせる
という**条件付き出力欄追加**です。

つまり、**カテゴリ F と言っているが、実効差分は explain の data-flow 移植ではなく、NOT_EQ 主張時の追加証拠要求**です。カテゴリラベルと実際の差分が一致していません。

---

## 3. EQUIV / NOT_EQ への影響分析と、実効差分の方向性

## 3-1. 変更前との差分
現状の `compare` にはすでに以下があります。
- 各 relevant test を A/B それぞれ trace する
- DIFFERENT を主張するなら COUNTEREXAMPLE を出す
- EQUIV を主張するなら NO COUNTEREXAMPLE EXISTS を埋める
- checklist にも counterexample / no counterexample がある

今回の追加差分は:
- **DIFFERENT を主張したテストに限り** propagation trace を必須化
- checklist にも同内容を追加

したがって実効差分は、**EQUIV 側に新しい作業を課す変更ではなく、NOT_EQ / DIFFERENT 側だけに新しい作業を課す変更**です。

## 3-2. EQUIV への影響
- 期待される正の効果:
  - 根拠の薄い DIFFERENT 主張を抑えるので、**EQUIV の偽陽性（誤 NOT_EQ）** は減る可能性がある。
- ただし注意点:
  - これは EQUIV 側を直接改善しているというより、**NOT_EQ のハードルを上げることで相対的に EQUIV に倒れやすくする**効果に近い。

## 3-3. NOT_EQ への影響
- 負の効果が明確:
  - 真の NOT_EQ ケースでも、divergence→assertion の完全な propagation trace を書くコストが増える。
  - 複雑なケースでは、証拠不足・ターン不足・記述負荷増により、**UNKNOWN / EQUIV 側へ逃げる**リスクが上がる。
- これは failed-approaches の BL-2 が観測した挙動とほぼ一致します。

## 3-4. 一方向にしか作用していないか？
**はい。実効的には一方向です。**

提案文では「DIFFERENT 主張の誤りを減らすことで EQUIV が改善し、NOT_EQ は維持」と述べていますが、差分評価では:
- SAME / EQUIV 主張に新しい要求はない
- DIFFERENT / NOT_EQ 主張にのみ追加要求がある

ので、作用方向は**NOT_EQ の立証責任引き上げ一方向**です。これは `failed-approaches.md` の共通原則 #6（対称化は差分で評価せよ）に照らして問題があります。

---

## 4. failed-approaches.md との照合

## 4-1. ブラックリスト照合

### BL-2: NOT_EQ 判定の証拠閾値・厳格化
**実質的に抵触します。**

BL-2 の説明には
- counterexample にアサーションまでのトレースを要求
- call path の明示を要求

が含まれています。今回案の
- Propagation trace (required if DIFFERENT)
- divergence point → assertion affected を file:line 付きで要求

は、**言い換えただけで効果が非常に近い**です。

### BL-6: Guardrail 4 の対称化
**fail core に再度抵触します。**

BL-6 の本質は、「見た目は対称でも、既存状態からの差分を見ると NOT_EQ 側だけが厳しくなる」でした。今回案も同じで、現行 compare に対する追加差分は **DIFFERENT 側にしか新規制約がない** ため、同型です。

### iter-9（未 blacklist 番号とは別だが重要）
iter-9 の propagation check は、今回案の近縁です。過去に
- propagation 追加
- assertion 到達確認
- SAME へのオフランプ

を試しており、結果は芳しくありませんでした。今回はそれをさらに **DIFFERENT 条件付きの厳格な記述義務**に寄せた形で、むしろ BL-2 側へ近づいています。

## 4-2. 共通原則との照合

### 原則 #1: 判定の非対称操作
抵触します。DIFFERENT 側だけ義務化されています。

### 原則 #2: 出力側の制約
かなり近いです。提案者は「入力側・処理側」と主張していますが、実際の変更は compare テンプレートの**出力欄追加**であり、モデルの処理を変えるより「書くべきもの」を増やしています。

### 原則 #4: 同じ方向の変更は同じ結果になる
抵触します。propagation / assertion affected / divergence point という言葉に変わっても、**NOT_EQ の立証責任を引き上げる**という効果方向は BL-2 と同じです。

### 原則 #5: 入力テンプレートの過剰規定
軽度〜中程度の懸念があります。`Divergence point` / `Traced path` / `Assertion affected` の3点セットは、モデルの注意を「その形式を埋めること」へ引き寄せ、探索の柔軟性を下げる可能性があります。

### 原則 #6: 対称化の実効差分
明確に抵触します。表現上どう説明しても、**変更前との差分は DIFFERENT 側だけ**です。

### 原則 #8: 受動的記録フィールド
完全一致ではないものの近いです。提案者は「能動的トレース」と言いますが、実装上は `Propagation trace` という**追加欄**であり、BL-8 の教訓どおり「欄が増えること」と「実際に検証すること」は別です。しかも今回は DIFFERENT 側だけで欄が増えます。

---

## 5. 全体の推論品質はどう向上すると期待できるか？

限定的です。改善が出るとしても、
- 根拠の薄い NOT_EQ を抑える
- EQUIV 側の一部偽陽性を減らす

という**片側補正**としての改善に留まる可能性が高いです。

しかし Objective のゴールは **EQUIV と NOT_EQ の両方を安定して 100% に近づけること**であり、過去履歴からも「片側だけを締める」変更は繰り返し失敗しています。今回案は、発想自体はまともでも、**推論品質そのものを対称的に改善する案ではない**ため、全体最適にはつながりにくいです。

---

## 6. 結論と代替案

## 結論
**修正ではなく差し戻しを推奨します。**

### 理由の要約
1. カテゴリ F の選択理由が不正確で、既存試行（iter-8/9）と近い
2. `explain` の DATA FLOW ANALYSIS 移植と言いながら、実効差分はそうなっていない
3. 実効差分は **DIFFERENT / NOT_EQ 側のみの追加立証責任**であり、BL-2 / BL-6 と実質同型
4. EQUIV 改善は見込めても、NOT_EQ 回帰リスクが高い

## 代替案
Objective の「未試行カテゴリから」という条件に従いたいところですが、現時点では **A〜F すべて試行済み**です。したがって厳密な意味での「未試行カテゴリ」は残っていません。代わりに、**未試行メカニズム**として次を提案します。

### 代替案: `explain` の DATA FLOW ANALYSIS を本当に対称移植する
- 方向: カテゴリ F（ただし propagation 条件付きではなく、真に data-flow 枠組みを移植）
- 内容:
  - `ANALYSIS OF TEST BEHAVIOR` の前に、relevant test ごとに **key values / state variables** を 1〜2 個だけ選ばせる
  - A/B の両方について、その値が
    - created where
    - modified where
    - consumed where
    を**対称的に**記録させる
  - その後に `Claim C[N].1 / C[N].2` を書かせる
- 期待効果:
  - DIFFERENT 時だけの立証責任増加ではなく、**SAME / DIFFERENT の両側に効く共通の中間表現**になる
  - 「差が出た／出ない」のどちらにも同じ解析粒度で作用する
- 注意:
  - これは BL-8 の受動記録欄化に落ちないよう、**key values を 1〜2 個に限定**し、`Claim` に直接使う値だけに絞る必要がある

現案よりは、このような**対称的でプロセス中心の差分**の方が採用に値します。

---

## 最終判定
**承認: NO（理由: 実効差分が DIFFERENT/NOT_EQ 側の立証責任引き上げであり、BL-2・BL-6・iter-9 と実質的に近いため）**
