# Iteration 45 — 監査コメント

## 総評
提案の問題意識（「コード差異を見つけただけで NOT_EQ に飛ぶ短絡を防ぎたい」）自体は妥当です。しかし、**今回の実効差分は Compare の最終 `COUNTEREXAMPLE` 文言を assertion-centric に厳格化するだけ**であり、既存の失敗履歴と照合すると **BL-2 / BL-15 / BL-16 / iter-42却下理由の再発**にかなり近いです。特に、**変更前との差分で見ると NOT_EQ 側にしか直接作用しない**ため、提案が主張する EQUIV 改善メカニズムは弱いです。

---

## 1. Web 検索に基づく学術的・実務的評価

DuckDuckGo MCP で確認した関連知見:

1. **Agentic Code Reasoning (arXiv)**  
   URL: https://arxiv.org/abs/2603.01896  
   要点:
   - semi-formal reasoning は、**explicit premises / execution-path tracing / formal conclusion** を要求する「certificate」として働く。
   - 精度向上の主因は、**分析ループ内でケースを飛ばさず追跡させること**にある。
   評価:
   - 提案の「premise 参照型」発想そのものは、この論文の方向性と整合する。
   - ただし今回の適用先は **分析本体ではなく final COUNTEREXAMPLE**。論文の効き方は主に exploration/trace 過程の構造化であって、**最後の出力証明書の wording 強化だけでは弱い**。

2. **A Literature Survey of Assertions in Software Testing (Springer, ECBS 2023)**  
   URL: https://link.springer.com/chapter/10.1007/978-3-031-49252-5_8  
   要点:
   - assertions は program behavior をチェックする有用な自動化技法であり、研究上も重要な test oracle。
   - 一方で assertion 研究は test oracle 全体の一部であり、テストの観測・検証は assertion 文だけに尽きない。
   評価:
   - 「テストが何を観測しているかへ接続せよ」という方向は支持できる。
   - しかし **観測点を assertion 行へ固定するのは過剰**。実務上のテスト失敗は例外、setup/teardown、副作用、状態変化など assertion 文外でも生じるため、assertion-only 化にはリスクがある。

3. **On the Rationale and Use of Assertion Messages in Test Code (arXiv 2408.01751)**  
   URL: https://arxiv.org/abs/2408.01751  
   要点:
   - assertion messages は failure troubleshooting、test understandability、documentation に有益。
   - assertion は失敗理解の重要な手掛かりだが、実務ではそれだけで failure diagnosis が完結するとは言っていない。
   評価:
   - assertion を参照させること自体には実務的価値がある。
   - ただしこの知見は **「assertion を見ると理解しやすい」** を支持するものであって、**「NOT_EQ の証明は assertion 行参照を必須にすべき」** までは支持しない。

### 学術的・実務的な結論
- **支持できる点**: テストの観測対象まで追わせたい、という狙いは研究・実務の両面で妥当。
- **支持しにくい点**: その実装を **COUNTEREXAMPLE の assertion-centered な最終出力制約**として入れるのは、研究が示す改善メカニズム（探索過程の構造化）より弱く、しかも観測点を assertion に寄せすぎている。

---

## 2. Exploration Framework のカテゴリ選択は適切か

**結論: カテゴリ F としての新規性は弱いです。**

理由:
- iter-8 ですでに **localize の divergence 観点を compare に移植**する F 案が試されている。
- iter-38 でも **localize の premise-reference 型 claim を compare に移植**する F 案が提案されている。
- iter-39/40/43 周辺でも、論文の anti-skip 機構や downstream verification を compare に移植する F 系が繰り返されている。

したがって今回の提案は、表現上は F だが、**「localize の premise-reference パターンを compare に持ち込む」系統としては既出**です。しかも適用先が `COUNTEREXAMPLE` なので、F の中でも既存の「出力証明強化」寄りであり、新規カテゴリを選べているとは言い難いです。

---

## 3. EQUIV / NOT_EQ の両方への影響と、実効的差分の分析

### 実効的差分
変更前:
```text
COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
  Test [name] will [PASS/FAIL] with Change A because [reason]
  Test [name] will [FAIL/PASS] with Change B because [reason]
  Therefore changes produce DIFFERENT test outcomes.
```

変更後:
```text
COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
  Test [name]: assertion checks [specific condition — cite file:line]
  With Change A, this assertion [PASSES/FAILS] because [trace ...]
  With Change B, this assertion [FAILS/PASSES] because [trace ...]
  Therefore the assertion produces DIFFERENT outcomes under Change A vs Change B.
```

### 重要な点
この差分は **`required if claiming NOT EQUIVALENT` のブロックにしか存在しません**。  
つまり、**エージェントが EQUIV と判断した経路では一切発火しない**変更です。

### EQUIV への影響
- 提案文では EQUIV 偽陰性の改善を主張しているが、直接の構造変化は EQUIV 経路にない。
- 期待できるのは「NOT_EQ を書こうとしたときに書きにくくなるので、結果として NOT_EQ を出しにくくなる」程度。
- これは本質的に **EQUIV 推論の質向上ではなく、NOT_EQ 側の閾値上昇**です。

### NOT_EQ への影響
- 真の NOT_EQ ケースでは、これまでより **assertion 行・file:line・asserted condition までの説明**が必要になる。
- 複雑な失敗（例外、setup/teardown、副作用、複数観測点）では、証明コストが上がり、UNKNOWN/EQUIV への流出リスクが増える。

### 一方向にしか作用しないか
**はい。実効差分はほぼ一方向です。**
- 変更対象は NOT_EQ の最終証明書のみ。
- EQUIV 側の `NO COUNTEREXAMPLE EXISTS` も、ANALYSIS ループも、checklist も不変。
- よってこの変更は、表現上は A/B 対称でも、**変更前との差分で見ると NOT_EQ にだけ追加制約がかかる**。

これは failed-approaches の共通原則 #6
> 「対称化」は既存制約との差分で評価せよ
にそのまま抵触します。

---

## 4. failed-approaches ブラックリスト / 共通原則との照合

### 4.1 ブラックリストとの実質同型性

#### BL-2: NOT_EQ 判定の証拠閾値・厳格化
- BL-2 には **counterexample にアサーションまでのトレースを要求**した失敗が明記されている。
- 今回の提案はまさに `COUNTEREXAMPLE` に対し、assertion condition と file:line を追加要求している。
- 「Claims ではなく COUNTEREXAMPLE だから違う」という主張は弱い。**実効としては NOT_EQ の立証責任引き上げ**で同じ。

#### BL-15: COUNTEREXAMPLE 文言変更
- BL-15 は `COUNTEREXAMPLE` の wording をいじっても upstream の探索は改善しない、という失敗。
- 今回も変更箇所は `COUNTEREXAMPLE` のみで、**探索行動ではなく最終証明書の文言変更**。
- したがって BL-15 の再発色が濃い。

#### BL-16 / iter-44 / iter-42 却下理由との近さ
- BL-16 は「内部コード差分ではなく観測点で比較せよ」という framing を output 側へ入れて失敗。
- iter-44 は「テストのアサーションが検査する観測対象」への比較単位移行を提案しており、今回と問題設定がかなり近い。
- iter-42 再提案の冒頭でも **assertion-centric なテンプレート変更は BL-5 / BL-8 / BL-11 / BL-14 / BL-16 の再発**として退けられている。

### 4.2 共通原則との照合

#### 原則 #1: 判定の非対称操作
抵触します。  
文言上は A/B 対称でも、**NOT_EQ を主張するときだけ追加証明を要求**しているため、判定の実効差分は非対称です。

#### 原則 #2: 出力側の制約は効果がない
抵触します。  
今回の変更は分析ループではなく、最終 `COUNTEREXAMPLE` のテンプレート変更です。これは典型的な **出力側の制約**です。

#### 原則 #3: 探索量の削減
直接は抵触しませんが、逆方向に **証明コストを増やすだけで探索改善がない**ため、総合的には不利です。

#### 原則 #4: 同じ方向の変形は表現を変えても同じ結果
抵触します。  
「assertion checks を1行追加」「premise-reference を移植」という表現の違いがあっても、効果の本質は **NOT_EQ を書きにくくすること**です。

#### 原則 #5: 入力テンプレートの過剰規定
assertion 固定という意味で近いです。特に BL-11 で指摘されたように、テスト結果のメカニズムを assertion に寄せるのは視野狭窄を招きます。

#### 原則 #6: 対称化の実効差分
明確に抵触します。  
新規制約は `NOT EQUIVALENT` ブロックのみに追加され、EQUIV 側には差分がありません。

### 判定
**承認: NO**

---

## 代替案（未試行カテゴリから）

### 提案カテゴリ: A — 推論の順序・構造を変える

**代替アプローチ案**:  
`ANALYSIS OF TEST BEHAVIOR` の各 relevant test で、先に **A/B それぞれの「テストが実際に観測する outcome」** を書かせ、その後で PASS/FAIL 比較を書くように順序を明示する。

例の方向性:
- 先に `Observed under Change A: [returned value / raised exception / visible state change]`
- 次に `Observed under Change B: [...]`
- 最後に `Therefore this test outcome is SAME/DIFFERENT`

理由:
- 変更が **main analysis loop** に作用し、final counterexample wording だけをいじらない。
- assertion 固定にせず、例外・状態変化・副作用も扱える。
- EQUIV / NOT_EQ の両方に同じ順序変更がかかるため、実効差分が片側に寄りにくい。

※これは「新しい記録欄を大量追加する」方向ではなく、**既存 Claim → Comparison の順序関係を outcome-first に整理する**軽量な構造変更として検討するのがよいです。

---

## 5. 全体の推論品質への期待効果

今回案のままでは、全体品質の向上は限定的か、むしろ悪化リスクが高いです。

- 良い点: NOT_EQ を安易に主張する雑な反例を多少は抑える可能性がある。
- 悪い点:
  - 反例構成のコストだけ上がり、分析そのものは改善しない。
  - assertion に観測点を寄せすぎて、例外・setup/teardown・副作用ベースの差異を取りこぼしうる。
  - EQUIV 改善の根拠が「NOT_EQ を出しにくくする」ことに依存しており、汎用的な推論力向上ではない。

したがって、**全体の推論品質を底上げする変更としては弱い**と判断します。

---

## 6. 結論

- 問題設定は理解できるが、実装位置が悪いです。  
- `COUNTEREXAMPLE` の assertion-centric 強化は、既存研究の「探索過程の構造化」という効き方より弱く、かつ failed-approaches の BL-2 / BL-15 / BL-16 と実質的に重なります。  
- 変更前との差分で見ると **NOT_EQ 側にしか直接作用しない**ため、提案が主張する EQUIV 改善は構造的に裏付けられていません。

**承認: NO（理由: BL-2/BL-15/BL-16 系の再発であり、実効差分が NOT_EQ 側の立証責任引き上げに偏るため）**
