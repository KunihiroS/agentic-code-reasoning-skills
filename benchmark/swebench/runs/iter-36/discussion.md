# Iteration 36 — 監査コメント

## 1. 関連研究・実務知見の Web 検索に基づく評価

DuckDuckGo MCP で関連文献・実務資料を確認した。結論から言うと、**「変更に影響される relevant test を call path / impact で絞る」という大枠は研究的に妥当**だが、今回提案のように**“削除・skip されたテストを等価性判定から明示的に外す carve-out” は、既存研究の主張からは直接は支持されない**。むしろ「比較対象から証拠を除外するルール追加」であり、過去失敗 BL-1 と同型の危険が強い。

### 検索結果と要点

1. **Agentic Code Reasoning**  
   URL: https://arxiv.org/abs/2603.01896  
   要点:
   - semi-formal reasoning は、premise 明示・execution path tracing・formal conclusion により、**unsupported claim や incomplete reasoning chain** を防ぐための「証明書」的構造である。
   - したがって今回の失敗原因に対する自然な処方は、本来 **trace の完全性や downstream handling の確認を強めること** であって、**比較対象から一部のテストを除外する定義変更**ではない。
   - 提案は論文の「incomplete reasoning chain」知見を引用しているが、実効差分は tracing 強化ではなく **relevance 除外規則の追加** になっている。

2. **More Precise Regression Test Selection via Reasoning about Semantics**  
   URL: https://dl.acm.org/doi/10.1145/3597926.3598086  
   要点:
   - RTS は「code changes に **affected** される test を選ぶ」問題として定式化されており、**precision と safety のトレードオフ**がある。
   - この文脈では、影響されないテストを外すこと自体は正しい方向だが、**外しすぎると差異検出力が落ちる**。
   - 今回案は precision を上げる名目だが、実際には「patch が test を消した」という差異を **比較対象から外す明示規則**なので、safety を下げる側に倒れやすい。

3. **An Extensive Study of Static Regression Test Selection in Modern Software Evolution**  
   URL: https://dl.acm.org/doi/10.1145/2950290.2950361  
   要点:
   - RTS 研究は一貫して「**変更の影響を受けるテストを漏らさない safety**」を重視する。
   - call graph / dependency に基づく選別は有効だが、**relevant set の under-approximation は危険**。
   - 今回提案の carve-out は、まさに「ある種の差異を relevant set から外す under-approximation」であり、学術的には慎重であるべき。

4. **A safe, efficient regression test selection technique**  
   URL: https://dl.acm.org/doi/abs/10.1145/248233.248262  
   要点:
   - 古典的 RTS でも主眼は **安全に affected tests を選ぶこと**。
   - 「安全」とは、差異を示しうるテストを落とさないこと。  
   - 今回の変更は「test removal / skip」を条件に **差異の証拠候補を除外**するため、安全側ではなく、検出力低下側の変更として読むのが自然。

### 研究・実務の総合評価

- **支持される部分**: D2 の call path 基準そのもの。
- **支持が弱い部分**: 「削除・skip されたテストは、事前に D2 relevant でない限り counterexample にならない」という追加規則。
- これは tracing の質向上ではなく、**比較集合の境界を後から狭める規則**であり、学術的にも実務的にも回帰リスクがある。

---

## 2. Exploration Framework のカテゴリ選択は適切か？過去の同一カテゴリ試行との関係

### 判定
**カテゴリ F の選択は弱い。**

### 理由

提案は「論文の error analysis を反映」と説明しているが、実際に SKILL へ入れる差分は

- incomplete chain を追跡させる新しい tracing 手順
- downstream handling の確認義務
- premise/claim 接続強化

ではなく、**D2 に compare-specific な relevance 例外を追加すること**である。これは論文の未活用アイデア導入というより、**定義の補足・ carve-out** に近い。

### 同一カテゴリの既試行
カテゴリ F は既に複数回試されている。

- iter-8
- iter-9
- iter-25
- iter-28
- iter-31（補助的要素）
- iter-32（前回 F 案却下の文脈あり）

したがって、**カテゴリ F 自体は未試行ではない**。さらに重要なのは、過去の F 系却下理由が「論文知見を口実に、実効差分が compare-specific の追加制約になっている」という点だったこと。今回案もかなり近い。

### 実質カテゴリの見立て
今回の変更は実質的には
- **C: 比較の枠組み変更**（何を relevant とみなすかの境界変更）
- または **E: 表現/定義の補足**

に近く、F としての正当化は弱い。

---

## 3. EQUIV / NOT_EQ 両方への影響と、実効差分の分析

### 変更前後の実効差分
変更前の D2:
- pass-to-pass tests は「changed code lies in their call path」のとき relevant

変更後の追加差分:
- **patch が test を remove / skip した場合でも**、その test は「patch 前から D2 relevant であったとき」にのみ counterexample として有効
- **call path 外の削除 test は equivalence determination に影響しない**

### この差分がどちら向きに効くか
この差分は、実効的には **NOT_EQ の証拠候補を減らす方向にのみ働く**。

- EQUIV 側には有利:
  - 「削除・skip された test を反例として使う」経路を塞ぐため、EQUIV 偽陰性は減りうる。
- NOT_EQ 側には不利:
  - これまで反例として使えたかもしれない test 変更を、定義上「比較対象外」として捨てるため、NOT_EQ 証拠が減る。

### 対称性の検証
提案文では「既存 D2 の明確化であり対称」と主張しているが、**変更前との差分**で見ると対称ではない。

- 新たにできること: EQUIV を支えるために、ある種の test 差異を無効化できる
- 新たに難しくなること: NOT_EQ を支えるために、ある種の test 差異を使えなくなる

したがって、**実効差分は一方向**である。これは failed-approaches の共通原則 #6「対称化は既存制約との差分で評価せよ」に照らして不合格。

### 個別ラベルへの予想
- **EQUIV**: 15368 型には局所的に効く可能性あり
- **NOT_EQ**: 100% を維持している現在、証拠除外規則の追加は回帰リスクがある
- **13821**: 本提案の文面は test removal / skip の話であり、環境仮定による誤反例には直接効かない。proposal の「間接効果」評価は弱い

---

## 4. failed-approaches.md のブラックリスト・共通原則との照合

### 結論
**BL-1 に実質的に抵触**し、加えて共通原則 #1, #4, #6 に抵触する可能性が高い。

### BL-1 との関係
BL-1:
- 「テスト削除を ABSENT として定義追加」
- Fail Core: **比較対象から特定のテストを除外するルールの追加**は NOT_EQ の証拠を減らす

今回案:
- ABSENT というラベルは使っていない
- しかし本質は **“削除・skip された test のうち、一定条件を満たさないものは equivalence 判定に使わない”** という除外規則

つまり、**表現は違うが効果は同じ**。BL-1 の Fail Core にそのまま当てはまる。

### 共通原則との照合

1. **共通原則 #1（判定の非対称操作）**  
   実効的には EQUIV 側の誤反例だけを潰し、NOT_EQ 側の証拠を減らす方向。非対称。

2. **共通原則 #4（同じ方向の変更は表現を変えても同じ結果）**  
   ABSENT 定義追加ではなくても、結果として「比較しなくてよい test を増やす」なら同型。

3. **共通原則 #6（対称化の実効差分）**  
   文面上は D2 の定義補足だが、差分としては「ある種の反例候補を無効化する」だけで、一方向。

### ブラックリスト非該当という提案者の主張への反論
提案者は「既存基準の補完であって閾値引き上げではない」と述べるが、監査上は**実効差分**で判断すべき。今回の差分は、モデルが採用できる NOT_EQ 証拠の集合を狭める以上、**機能的には BL-1 / BL-2 系の再発**とみなすべき。

### 未試行カテゴリからの代替案
却下するなら、次は **カテゴリ B（情報の取得方法）** から、**除外規則の追加ではなく「patch 前の test relevance を確認する探索行動」を増やす**アプローチがよい。

例:
- D2 の定義は変えず、`To identify them` に近い場所で
  - **test deletion / skip を見つけたら、その test が patch 前に changed code を実際に exercise していたか repo search で確認する**
  - 確認できない場合は counterexample に使わず、P[N] の制約として明記する

これは「比較対象から除外する定義追加」ではなく、**証拠採用前の情報取得改善**なので、B カテゴリとしてまだ筋がよい。

---

## 5. 全体の推論品質にどう効くか

### 期待できる改善
- 15368 型の「call path 外の削除 test を安易に反例採用する」誤りには局所的改善がありうる。

### 期待しにくい点
- 推論の核である
  - relevant test の同定
  - code path tracing
  - downstream handling の確認
  - premise と claim の接続

  を直接改善していない。
- つまり、**推論プロセス改善ではなく、証拠空間の一部除外**に留まる。
- そのため、誤った test relevance 判定、仮想環境依存の反例、浅い因果連鎖など、他の失敗モードには効きにくい。

### 総評
局所症状には効いても、全体品質を押し上げるタイプの変更ではない。Objective の「汎用的なコード推論能力向上」に対しては弱い。

---

## 6. 結論: 承認するか、修正を求めるか

**修正を求める。**

理由:
1. 論文・RTS 研究が支持するのは「affected tests を精度よく見つけること」であって、**removed/skipped test を定義で除外する carve-out** ではない。  
2. 実効差分は **EQUIV 側に有利・NOT_EQ 側に不利** の一方向である。  
3. **BL-1 の Fail Core と実質同型**であり、表現違いの再発とみなすべき。  
4. 13821 への効果主張も文面上は直接支えられていない。  
5. 推論プロセスそのものより、比較対象の除外でスコアを調整する方向になっている。

---

## 最終判定

**承認: NO（BL-1「比較対象から特定のテストを除外するルール追加」の実質的再発であり、実効差分が EQUIV 方向にのみ作用するため）**
