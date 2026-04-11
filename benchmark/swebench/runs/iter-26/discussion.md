# Iter-26 改善案レビュー

## 総評
結論から言うと、この提案は**承認しません**。理由は、提案の狙い自体（「コード差異を見つけただけで NOT_EQ に飛ばず、最終的なテスト結果まで因果を追う」）は妥当ですが、**今回の変更の実効的差分が過去の失敗方向 BL-2 / BL-6 とほぼ同型**だからです。表現は checklist 追加ですが、作用としては **NOT_EQ を主張する側にだけ追加立証責任を載せる**変更であり、failed-approaches.md の共通原則 #1, #4, #6 に抵触します。

---

## 1. Web 検索に基づく妥当性評価（mcp / DuckDuckGo）

### 検索結果と要点

| URL | 要点 | 本提案への含意 |
|---|---|---|
| https://arxiv.org/abs/2603.01896 | *Agentic Code Reasoning* は、explicit premises・execution path tracing・formal conclusion を要求する semi-formal reasoning が有効だと述べる。さらにエラー分析として **incomplete reasoning chains**（途中までは追うが downstream handling を見落とす）を失敗要因として挙げる。 | 「差異を見つけたら downstream まで追うべき」という問題設定は妥当。ただし論文が支持しているのは**推論鎖の完全化**であり、**NOT_EQ の主張閾値の片側引き上げ**ではない。 |
| https://arxiv.org/html/2506.10322v1 | *LLM4PFA* は、false positive の主因を **source→sink の path feasibility を十分に検証できないこと**とし、interprocedural に execution path を追うことで誤警報を削減している。 | 「中間差異が最終 outcome/sink まで届くかを見る」という実務・研究上の発想は正しい。ただし本研究も有効化しているのは**探索手順の改善**であり、結論側の追加ハードルではない。 |
| https://owasp.org/www-community/controls/Static_Code_Analysis | OWASP は static analysis の false positive が生じる理由として、**input から output までのデータフローを十分に保証できないこと**を挙げる。 | 「最終観測点まで届いたか」を見る発想は実務的に筋が良い。だが、OWASP 的にも必要なのは**フロー検証の質向上**であり、単純な判定制約の追加ではない。 |
| https://qwiet.ai/appsec-resources/reachability-in-appsec/ | reachability analysis は、理論上の差異と実際に exploitable / reachable な差異を区別し、false positives を減らすと説明している。 | 提案の狙いと整合的。ただしこの知見も「本当に届くか調べる」方法論の支持であって、「different と言う前にもう一文要求する」ことの支持ではない。 |
| https://arxiv.org/abs/2305.20050 | *Let’s Verify Step by Step* は、outcome supervision より **process supervision** が推論品質を上げると報告する。 | この観点でも有効なのは**途中工程の検証改善**であり、最終判定時の片側義務追加だけでは弱い。 |

### 学術的・実務的評価

- **学術的には部分的に妥当**です。研究・実務の両方で、「中間差異」と「最終観測結果」は区別すべきであり、downstream handling / sink / assertion まで追う重要性は支持されます。
- ただし、**今回の具体的実装形式は弱い**です。研究が支持しているのは「途中の reasoning chain を完全にすること」であって、今回のような **DIFFERENT 主張時だけの checklist 義務**ではありません。
- よって、**問題認識は正しいが、処方箋が過去失敗と同型**という評価です。

---

## 2. Exploration Framework のカテゴリ選択は適切か？

### 判定
**適切ではありません。**

### 理由
提案はカテゴリ C（比較の枠組みを変える）とされていますが、実際にやっていることは

- Compare checklist に 1 行追加する
- DIFFERENT を主張する前の検証義務を追加する

であり、実態としては

- **E: 表現・フォーマットの改善**
- または **F: 原論文のエラー分析（incomplete reasoning chains）の再適用**
- あるいは **D: 自己/検証チェック強化に近い操作**

です。少なくとも、**比較の枠組みそのもの（比較単位・比較粒度・比較対象の再編）を変えてはいません**。

### 同一カテゴリ/同一メカニズムの既試行性
過去にほぼ同型の方向が既に試されています。

- **BL-2: NOT_EQ 判定の証拠閾値・厳格化**
  - failed-approaches.md に明記されている通り、**「counterexample にアサーションまでのトレースを要求」**はすでに失敗済みです。
  - 今回の文言「When claiming different test outcomes, verify the behavioral divergence reaches the test assertion condition」は、表現を変えただけで本質的に同じです。

- **BL-6: Guardrail 4 の対称化（差異あり結論の前にも trace 義務）**
  - 今回の提案は「対称化」と言っていますが、failed-approaches.md の原則 #6 が指摘するとおり、**既存状態との差分で見ると DIFFERENT 側にしか新しい義務が増えていません**。
  - したがって、実効的には BL-6 の再発です。

つまり、提案者の「未試行メカニズム」という主張には賛成できません。

---

## 3. EQUIV と NOT_EQ への影響分析（実効的差分ベース）

### 変更前にすでにあるもの
現行 SKILL.md の Compare checklist には、すでに以下があります。

- `Trace each test through both changes separately before comparing`
- `When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact`
- `Provide a counterexample (if different) or justify no counterexample exists (if equivalent)`

つまり現状でも、
- テストを両側 separately に trace すること
- semantic difference を見つけたら relevant test を追うこと
- different なら counterexample を出すこと

は既に要求されています。

### 今回の実効的差分
今回追加されるのは次の 1 行です。

- `When claiming different test outcomes, verify the behavioral divergence reaches the test assertion condition ...`

したがって、**変更前との差分は DIFFERENT 主張時にだけ追加要件が乗ること**です。

### EQUIV への影響
- 理論上は、EQUIV の誤判定（EQUIV なのに NOT_EQ と言う）を少し減らす可能性があります。
- しかし、そのメカニズムは「NOT_EQ を言いにくくする」ことであり、**EQUIV 側の推論そのものを改善しているわけではありません**。
- しかも既存 prompt でも「trace」「counterexample」は既に求めており、それでも失敗している以上、**checklist 1 行の再表現で大きな改善が出る期待は低い**です。

### NOT_EQ への影響
- 真の NOT_EQ では、追加要件を満たせるはず、という提案者の見立ては理解できます。
- しかし failed-approaches.md が示す通り、実際の運用ではこの種の追加義務は
  - 余分なターン消費
  - 証拠不十分扱いによる UNKNOWN/EQUIV への逃避
  - NOT_EQ 主張への慎重化

  を引き起こしやすいです。
- よって、**NOT_EQ recall を落とすリスクが高い**です。

### 一方向にしか作用しないか？
**はい。一方向にしか作用します。**

- EQUIV 結論時には新規義務は増えない
- NOT_EQ 結論時にだけ「assertion condition まで reach を確認せよ」が追加される

これは failed-approaches.md の共通原則 #6 が警告する

> 既存制約との差分が一方向にしか作用しない変更は、表現上「対称」であっても実効的には非対称

にそのまま当てはまります。

---

## 4. failed-approaches.md との照合

### ブラックリストとの実質同一性

#### BL-2 との関係
> NOT_EQ 判定の証拠閾値・厳格化
> 内容: counterexample にアサーションまでのトレースを要求

今回の提案は、ほぼこれです。用語は
- `counterexample にアサーションまでのトレースを要求`
- `different test outcomes を主張する前に assertion condition まで reaches を verify`

と違いますが、**実質的効果は同じ**です。

#### BL-6 との関係
> Guardrail 4 の「対称化」
> 既存方向には実効差分がなく、新規方向にのみ制約が作用した

今回もまさに同じです。提案者は「SAME/DIFFERENT の対称性を補う」と説明していますが、**既存 prompt は already SAME 側の保護を持っている**ため、差分として追加されるのは DIFFERENT 側だけです。

### 共通原則への抵触

- **原則 #1 判定の非対称操作**: 抵触
  - DIFFERENT 側だけに追加義務を載せるため、NOT_EQ 側に不利。

- **原則 #2 出力側の制約**: 部分的に抵触
  - 提案者は「出力制約ではなく検証義務」と言うが、SKILL 上の具体化は **claiming different test outcomes の前提条件**の追加であり、結論側の制約として働く。

- **原則 #4 同じ方向の変更は表現が違っても同じ結果**: 抵触
  - BL-2 / BL-6 と同方向。

- **原則 #5 入力テンプレートの過剰規定**: 直接ではないが注意
  - 今回はフィールド追加ではないので BL-13 ほどではない。ただし「assertion condition まで reach」という新しい表現が、再び特定の観測点へのアンカーになる懸念はある。

- **原則 #6 対称化の実効差分**: 強く抵触
  - 表現上の対称性に対して、実効差分は NOT_EQ 側のみ。

### 結論
この照合結果から、**承認: NO** です。

---

## 5. 全体の推論品質がどう向上すると期待できるか？

### 良い点
- 「コード差異 ≠ テスト結果差異」を明示したい意図は正しいです。
- downstream handling / assertion 到達まで追うべき、という認識は研究・実務の双方に整合します。

### しかし期待改善は限定的
今回の実装では、推論品質の向上よりも

- NOT_EQ 結論時の追加確認
- 追加説明負荷
- 結論の慎重化

として作用する公算が高いです。

つまり、
- **EQUIV 偽陽性の削減**は少し期待できても、
- **NOT_EQ の取りこぼし**や **UNKNOWN 増加**で相殺される可能性が高い

と見ます。

研究に沿った形で本当に推論品質を上げるなら、必要なのは

- 「DIFFERENT と言う前に assertion まで確認せよ」という**片側の閾値追加**ではなく、
- 「差異を見つけた後、次に何を読むか」を改善する**探索手順そのものの改善**

です。

---

## 6. 修正提案（未試行カテゴリからの代替案）

### 推奨: カテゴリ B または F に振り直す
今回の問題設定を活かすなら、次のような**探索手順の改善**として設計し直すべきです。

### 代替案（カテゴリ B: 情報の取得方法を改善する）
**差異を見つけた直後の読む先を指定する**。

例:
- semantic difference を見つけたら、まず「その差異を**消費する直後の caller / consumer / handler**」を 1 段以上読む
- 結論を出す前に、差異が
  1. downstream で吸収・正規化されるのか
  2. 例外・返り値・副作用として外に出るのか
  を確認する

これは
- NOT_EQ の閾値を上げる変更ではなく、
- **差異発見後の探索先を改善する変更**

なので、BL-2 / BL-6 より安全です。

### 代替案（カテゴリ F: 論文の未活用アイデア）
論文の error analysis にある **incomplete reasoning chains** をそのまま Compare の探索規則に落とし込む。

例:
- 「差異を生む地点を見つけたら、そこで止まらず、**その値や分岐を受け取る downstream handling まで追う**」

この形なら、assertion という特定観測点へのアンカーより広く、
- return value
- raised exception
- side effect
- normalized / swallowed behavior

も含めて扱えるため、BL-5 / BL-11 的な視野狭窄も起こしにくいです。

---

## 最終判断

- 提案の問題意識: **妥当**
- 提案の具体的変更: **過去失敗と実質同型**
- 期待効果: **EQUIV にわずかな改善余地はあるが、NOT_EQ 回帰リスクが高い**
- 結論: **修正を求める**

**承認: NO（理由: BL-2 / BL-6 と実効的に同型であり、変更前との差分が NOT_EQ 側にしか作用しないため）**
