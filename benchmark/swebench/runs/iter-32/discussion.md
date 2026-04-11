# Iteration 32 — discussion

## 総評

**現案は承認できません。**
問題設定自体（「コード差分を見つけただけで NOT_EQ に飛ぶ」「downstream で差分が吸収される可能性を見落とす」）は妥当ですが、**提案された変更の実効差分は過去に既に危険だと判定したものとほぼ同型**です。

特に今回の提案は、
- 既存の Guardrail 5 がすでに含んでいる `downstream code does not already handle ...` の compare 向け言い換えであり、
- 実際の発火点は **「内部差分を見つけた後」** なので、
- 変更前との差分としては **NOT_EQ 候補局面にだけ追加慎重さを入れる** 方向に作用します。

これは **iter-30 時点で既に監査で却下した懸念と同じ** です。

---

## 1. Web 検索に基づく妥当性評価（DuckDuckGo MCP）

まず透明性のために記します。`ddg_search_search` では複数回検索を試しましたが、今回は DuckDuckGo 側の bot detection で結果を取得できませんでした。代わりに、**MCP の `ddg_search_fetch_content` を用いて既知の関連論文ページ本文を取得**し、その内容を根拠に評価します。

### 1-1. Agentic Code Reasoning
- URL: https://arxiv.org/abs/2603.01896
- MCP 取得要点:
  - semi-formal reasoning は **explicit premises / execution-path tracing / formal conclusions** を要求し、unsupported claim を防ぐ「certificate」として機能する。
  - patch equivalence を含む複数タスクで精度改善を報告している。
- 本提案への含意:
  - 「下流まで追うべき」という問題意識そのものは原論文と整合する。
  - ただし、その知見は **すでに SKILL.md の Guardrail 5 に反映済み** であり、今回の変更は新規導入というより既存ガードレールの compare-specific な再表現に留まる。

### 1-2. LLMDFA: Analyzing Dataflow in Code with Large Language Models
- URL: https://arxiv.org/abs/2402.10754
- MCP 取得要点:
  - reliable な code analysis のために、問題を複数のサブタスクへ分解し、program values の依存関係や path feasibility を扱う。
  - 幻覚を抑えるには、単なる説明追加ではなく、**分析手順そのものの分解と検証** が重要とされる。
- 本提案への含意:
  - 「差分が下流の観測点まで伝播するか」を見る発想自体は学術的に支持できる。
  - しかし今回の提案は **Guardrail に 1 文足すだけ** で、LLMDFA のようなサブタスク分解や検証行動の追加にはなっていない。したがって、研究的方向性は合うが、**この実装粒度で効果が出る根拠は弱い**。

### 1-3. SemCoder: Training Code Language Models with Comprehensive Semantics Reasoning
- URL: https://arxiv.org/abs/2406.01006
- MCP 取得要点:
  - Code LLM は static text pattern は得意でも、**execution effects / dynamic states / overall input-output behavior** の統合が弱い。
  - local execution effect と overall behavior をつなぐ reasoning が重要。
- 本提案への含意:
  - 「内部差分 ≠ テスト結果差分」という主張は妥当。
  - ただし SemCoder が示しているのは **局所差分から観測結果までをつなぐ実際の reasoning** の重要性であり、今回案のような注意書き追加がその reasoning を十分に増やすとは限らない。

### 1-4. Code Prompting Elicits Conditional Reasoning Abilities in Text+Code LLMs
- URL: https://aclanthology.org/2024.emnlp-main.629/
- MCP 取得要点:
  - 入力表現の構造化により、entity/state tracking が改善する。
  - 一方で prompt/template の細かな表現差が挙動に大きく影響しうる。
- 本提案への含意:
  - 文言変更が全く無意味とは言えない。
  - しかし逆に言えば、**小さな wording 差分でも片方向のアンカーとして働く** ため、安全性は高くない。今回の変更は「internal behavior difference」を前景化した後に追加確認を要求するので、NOT_EQ 側の自己証明負荷として作用するリスクがある。

### 1-5. Anchoring bias in large language models: an experimental study
- URL: https://link.springer.com/article/10.1007/s42001-025-00435-2
- MCP 取得要点:
  - LLM は initial framing に強く影響される。
  - 単純な CoT や reflection では anchoring bias は十分に緩和されない。
- 本提案への含意:
  - 「内部差分を見つけたら assertion まで届くか確認せよ」という wording は、意図としては慎重化だが、実際には **“difference” を先にアンカーとして強調** する。
  - その結果、EQUIV 偽陽性を減らすどころか、真の EQUIV ケースでも「差異があるのだから差は重要だろう」という方向へ注意を固定する危険がある。

### 小結
- **学術的妥当性（問題意識）**: ある
- **学術的妥当性（この具体的変更）**: 弱い
- **実務的評価**: downstream propagation の確認自体は良い習慣だが、今回の変更は既存 Guardrail 5 と重複し、しかも差異発見後にのみ実効性を持つため、回帰リスクが高い

---

## 2. Exploration Framework のカテゴリ選択は適切か？同一カテゴリが既に試されていないか？

### 判定
**適切ではありません。主張されているカテゴリ F の新規性は弱く、同種の方向は既に試され、しかも一度監査で退けられています。**

### 理由
提案書はカテゴリ F（原論文の未活用アイデア導入）としていますが、`docs/design.md` では既に
- error analysis を guardrails に翻訳した
- incomplete reasoning chains / downstream handling の見落としを Guardrail に反映した
と整理されています。

実際、現行 `SKILL.md` の Guardrail 5 はすでに次を含みます。

> verify that downstream code does not already handle the edge case or condition you identified

したがって今回の案は、**未活用アイデア導入ではなく、既存ガードレールの compare-specific 言い換え** です。実装の性質としては F より **E（表現改善）寄り** です。

### 過去イテレーションとの照合
この方向はすでに近い形で試されています。

- **iter-30 の監査で、ほぼ同じ方向が NO 判定**
  - `benchmark/swebench/runs/iter-30/discussion.md` では、Guardrail 5 への compare 向け追記案について
  - **「既存 Guardrail 5 の言い換えに留まり新規性が弱く、差異発見後の追加確認として実効的に NOT_EQ 側へ偏る」**
  - と明確に却下されています。

- 関連する失敗・却下方向
  - BL-6: 差異方向への追加 trace 義務
  - BL-14: DIFFERENT 主張時の backward verify
  - iter-30 discussion: propagation/downstream/assertion 到達確認の Guardrail 追記は危険と判断済み

よって、**カテゴリ F の未試行案とは評価できません**。

---

## 3. EQUIV / NOT_EQ の両方への影響と、変更前との差分分析

## 3.1 変更前との差分
現行 Guardrail 5:

> After building a reasoning chain, verify that downstream code does not already handle the edge case or condition you identified.

提案後の追加文:

> For `compare` mode specifically: when you find that two changes produce different internal behavior, verify that the behavior difference propagates all the way to what the test assertion actually evaluates ...

この追加文の発火条件は明確です。
**「two changes produce different internal behavior を見つけたとき」**です。

つまり、変更前との差分として新たに入るのは、
- SAME/EQUIV を検討している局面一般ではなく、
- **差異を見つけた後の局面**
への追加確認です。

## 3.2 EQUIV への影響
### 期待できる正の効果
- EQUIV 偽陽性の典型である「内部差分発見 → 即 NOT_EQ」を抑制する可能性はある。
- 提案者が狙っている failure mode には理屈上は合う。

### ただし限界が大きい
- この failure mode は **すでに Guardrail 5 の射程内**。
- よって今回の改善余地は、新しい推論操作の導入ではなく **salience の微調整** に近い。
- EQUIV 側に効くとしても、改善幅は限定的と見るべき。

## 3.3 NOT_EQ への影響
こちらの回帰リスクの方が大きいです。

- 真の NOT_EQ ケースでも、まずは内部差分を見つける。
- その直後にさらに「assertion まで届くか」を確認させるので、実効的には **NOT_EQ 候補時の追加慎重化** になる。
- wording 上は対称でも、変更前との差分は **NOT_EQ 側の立証負荷増** に近い。

この点は BL-6 / BL-14 と同型です。

## 3.4 一方向にしか作用しないか？
**はい。実効差分はかなり一方向です。**

提案書は「両方向に効く」と述べていますが、差分評価は wording ではなく **変更前から何が増えるか** で見るべきです。今回増えるのは、
- 差異発見後
- compare モードで
- assertion までの propagation 確認
を要求することです。

これは実質的に **NOT_EQ 候補時だけに追加行動を要求する** もので、EQUIV 側に同程度の新規義務は増えません。

---

## 4. failed-approaches.md のブラックリスト・共通原則との照合

### 結論
**この提案はブラックリスト・共通原則に抵触します。承認不可です。**

## 4.1 BL との類似

### BL-6（Guardrail 4 の「対称化」）との類似
BL-6 の失敗本質は、
- 表面上は対称
- だが既存制約との差分では NOT_EQ 側にだけ新規制約が乗った
ことでした。

今回も同じです。
- 表面上: compare モード全体への補足
- 実効差分: **差異を見つけた後だけ assertion 伝播確認を追加**

したがって、**BL-6 の再発** とみなすべきです。

### BL-14（Backward Trace 追加）との類似
BL-14 は DIFFERENT 主張時に追加検証を要求し、NOT_EQ の立証責任を上げて失敗しました。
今回の案も、backward という語は使っていないだけで、実質は
- 関数レベル差異から
- assertion まで
- 因果連鎖をもう一段つなげ直せ
という要求です。

作用方向は BL-14 と同じです。

### BL-15 / 共通原則 #2 に近い懸念
今回の変更は出力ブロックではなく guardrail なので BL-15 と完全同一ではありません。
ただし、**探索ステップそのものを構造的に変えず、文言レベルで慎重さを追加する** 点では近い懸念があります。研究が支持するのは tracing 行動の制度化であって、言い換えの追加ではありません。

## 4.2 共通原則との照合

- **原則 #1 判定の非対称操作**
  - 抵触します。
  - 発火条件が差異発見後なので、実効的には NOT_EQ 側の追加慎重化です。

- **原則 #4 同じ方向の変更は表現を変えても同じ結果**
  - 抵触します。
  - propagation / downstream handling / assertion 到達確認という表現違いでも、効果方向は BL-6 / BL-14 と同じです。

- **原則 #6 対称化は差分で評価せよ**
  - 強く抵触します。
  - wording 上は compare 全体向けでも、変更前との差分は差異発見後の追加確認だけです。

- **原則 #12 アドバイザリな非対称指示も立証責任引き上げになる**
  - 該当します。
  - Guardrail は「助言」に見えても、モデルにとっては自己証明義務として作用します。

よって、**承認: NO** です。

### 別カテゴリからの代替案（未試行寄り）
**カテゴリ B: 情報の取得方法を改善する** から、次の方向を提案します。

> `compare` の relevant test 特定（D2）で、変更シンボルを直接参照するテストだけでなく、**その caller / wrapper / helper を経由して到達するテストを repo search で拾う** ことを明示し、最初に「最も近い oracle-bearing caller」を優先して追う。

理由:
- これは **判定閾値の操作ではなく、証拠の集め方** の改善。
- 追加の慎重義務を NOT_EQ 側だけに課さない。
- BL-12 のような固定順序化ではなく、**探索優先順位の改善** に留まる。
- EQUIV/NOT_EQ の両方で relevant test の取りこぼしや過剰スコープを減らす可能性がある。

---

## 5. 全体の推論品質がどう向上すると期待できるか

限定的には、
- downstream handling を思い出しやすくする
- コード差異とテスト差異の混同を少し減らす
といった効果はありえます。

しかし期待できる改善は **構造的な推論能力向上ではなく、既存 Guardrail 5 の salience 微増** に留まります。しかもその salience 増加は差異発見後に集中するため、
- 真の NOT_EQ での過剰慎重化
- 結論遅延
- UNKNOWN / EQUIV への揺り戻し
を招くリスクの方が大きいです。

総じて、**全体品質の改善よりも回帰リスクが勝る** と判断します。

---

## 6. 承認するか、修正を求めるか

### 結論
**修正を求めます。現案のままでは承認できません。**

### 主理由
1. **カテゴリ F の新規性がない**
   - downstream handling は既に Guardrail 5 に実装済み。
2. **iter-30 で実質的に同型案が却下済み**
   - 同じ懸念を繰り返している。
3. **変更前との差分が一方向**
   - 差異発見後の assertion propagation 確認は、実効的に NOT_EQ 側の追加慎重化。
4. **failed-approaches の BL-6 / BL-14 / 原則 #6 / #12 に抵触**
   - wording を変えただけで、効果方向は同じ。

---

**承認: NO（理由: 既存 Guardrail 5 の言い換えに留まり、変更前との差分が「差異発見後の追加確認」として実効的に NOT_EQ 側へ偏るため。BL-6 / BL-14 / 共通原則 #1・#4・#6・#12 の再発）**
