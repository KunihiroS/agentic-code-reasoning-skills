# Iteration 58 — 監査ディスカッション

## 対象提案の要約

提案は、SKILL.md Step 5.5 の最後の自己チェック項目を次のように拡張するものです。

- 現行: semantic difference が見つかった場合のみ、差分経路を relevant test まで追ったかを確認する
- 提案: semantic difference が見つからなかった場合にも、「探索を早く止めただけではなく、明示的な search で不在を確認したか」を確認する

提案者の主張は「差異あり側だけを明示している非対称性を解消し、EQUIVALENT / NOT_EQUIVALENT の両方向で結論直前の自己監査を強化する」というものです。

---

## 1. 既存研究との整合性

### 参照した外部資料

1. Agentic Code Reasoning (arXiv)
   - URL: https://arxiv.org/abs/2603.01896
   - 要点: semi-formal reasoning は、explicit premises・execution path tracing・formal conclusion を要求することで、unsupported claims や case skipping を減らす「certificate」として働く。構造化された反証可能な推論は研究コアと整合する。

2. Confirmation bias (Wikipedia)
   - URL: https://en.wikipedia.org/wiki/Confirmation_bias
   - 要点: 人は自分の仮説を支持する情報だけを集めやすく、反対情報の探索が弱くなりやすい。したがって、「差異が見つからなかった」という結論に対し、探索打ち切りではなく反証的探索を要求したい、という発想自体は一般原則として妥当。

3. Falsifiability (Wikipedia)
   - URL: https://en.wikipedia.org/wiki/Falsifiability
   - 要点: 不在や同値の主張は、単なる未発見ではなく、何が見つかれば反証になるかを意識した検証と相性がよい。absence claim に refutation-oriented check を求める方向性は理にかなう。

### 整合性評価

高水準では整合しています。特に、
- unsupported な「差異なし」結論を減らしたい
- 反証可能性を no-difference 側にも意識させたい
という狙いは、README.md と docs/design.md が要約する研究コアと矛盾しません。

ただし、研究が支持しているのはあくまで
- explicit premises
- traced evidence
- mandatory refutation
- formal conclusion
の強化であって、Step 5.5 に新しい mode-specific な自己監査ゲートを足すこと自体ではありません。

つまり、この提案は
- 研究コアの精神とは部分整合
- 実装位置と表現方法は研究からは直接は導かれない
という評価です。

---

## 2. Exploration Framework のカテゴリ選定は適切か

提案者はカテゴリ E「表現・フォーマットを改善する」、メカニズムは「曖昧文言の具体化」としていますが、これはやや無理があります。

理由:
1. 変更は単なる wording clarification ではない
   - 既存文の解釈を明確にするだけでなく、
   - 「no semantic difference のときは explicit search を要求する」という
   - 新しい確認義務を追加している

2. 作用点が Step 5.5 の self-check である
   - これは「表現改善」よりも、Objective.md の分類でいえば D「メタ認知・自己チェックを強化する」に近い
   - あるいは「どう探すか」の指定なので B「情報の取得方法を改善する」にも接している

3. 実効上は template behavior を変える
   - 読み手が従うべき手続きが増えるため、単なる文言の対称化以上の意味を持つ

結論として、この提案の実体は E より D 寄りです。カテゴリ選定は監査上は不適切、少なくとも「E だけ」とみなすのは甘いです。

---

## 3. この変更は EQUIVALENT / NOT_EQUIVALENT の双方にどう作用するか

### 変更前の実効

現行 Step 5.5 は、
- semantic difference を見つけた後に
- その差分が test outcome に影響する/しないを言う前に
- 少なくとも 1 つ relevant test を差分経路まで追ったか
を確認させています。

これは主に「差分を見つけたが重要性評価を雑に済ませる」失敗を抑えるための guardrail です。

### 変更後の実効

提案文の追加は、
- semantic difference が見つからなかった場合に
- それが単なる exploration stop ではなく explicit search に基づくか
を確認させます。

### EQUIVALENT への作用

ここには直接効きます。

期待される改善:
- 「差異が見つからなかった」ことを「差異が存在しない」と早合点する premature EQUIVALENT を減らす
- NO COUNTEREXAMPLE EXISTS ブロックと自己監査の整合を上げる

ただし副作用もあります。
- explicit search の有無が自己監査の新しい通過条件になり、テンプレート充足が目的化しやすい
- 「何をもって explicit search とするか」が曖昧で、形式的な search 記載を誘発しうる

### NOT_EQUIVALENT への作用

ここへの直接効果はかなり弱いです。

理由:
- NOT_EQUIVALENT は通常、semantic difference を見つけた側の既存チェックで既にカバーされる
- 提案追加文は no semantic difference の場合にしか発火しない
- したがって、NOT_EQUIVALENT 判定の改善はせいぜい間接的

### 総評

提案者は「対称化により両方向を同一チェックポイントでカバーする」と述べていますが、実効的差分は対称ではありません。

実際には、
- 強く効くのは EQUIVALENT 側
- NOT_EQUIVALENT 側にはほぼ新情報がない
という片方向の変更です。

この点は監査上、明確に認識すべきです。

---

## 4. failed-approaches.md の汎用原則との照合

提案文自身は「既知の失敗原則には抵触しない」と結論していますが、私は逆です。かなり近い再演リスクがあります。

### 抵触が疑われる原則 1

- 「既存の汎用ガードレールを、特定の追跡方向や観点で具体化しすぎない」

今回の追加は、既存 Guardrail #4 を no-difference 方向へ具体化したものです。提案者はこれを「対称化」と呼んでいますが、実際には
- difference found 時の test-trace 義務
に加えて
- no difference found 時の explicit-search 義務
を足しています。

これは方向非依存な原則の維持というより、別方向の半必須手順を追加した形です。

### 抵触が疑われる原則 2

- 「結論直前の自己監査に、新しい必須のメタ判断を増やしすぎない」

今回の追加はまさに Step 5.5 に
- explicit search をしたか
- early stop ではないか
という新しいメタ判断を載せています。

新規欄追加ではないものの、failed-approaches.md が警戒している「既存チェックへの補足に見えても実質的に新しい判定ゲートとして働く」型にかなり近いです。

### 抵触が疑われる原則 3

- 「反証が見つからなかった場合の記録様式を細かく規定しすぎると、探索の質の改善よりテンプレート充足が目的化しやすい」

提案は記録欄を増やしてはいませんが、no-difference 側に「explicit search を示せ」という圧を追加しています。これは NO COUNTEREXAMPLE EXISTS の運用をさらに形式化する方向であり、failed-approaches が避けるべきとする挙動に近いです。

### この観点での結論

表現は変えてありますが、本質的には
- pre-conclusion self-audit に新たな通過条件を足す
- no-counterexample 側の手続き義務を強める
- compare の一方向に寄った具体化を加える
という過去失敗方向の再演リスクが高いです。

---

## 5. 汎化性チェック

### 明示的なルール違反の有無

提案文には、禁止対象である
- 具体的な数値 ID
- ベンチマーク対象リポジトリ名
- 具体的テスト名
- ベンチマーク実コード断片
は含まれていません。

含まれているのは主に
- SKILL.md 自身の引用
- Step 5.5 / Guardrail #4 といった内部参照
- EQUIVALENT / NOT_EQUIVALENT の一般概念
であり、Objective.md の R1 基準上、これ自体は即違反ではありません。

### ただし、暗黙の compare-mode 仮定が強い

ここが本質的な懸念です。

追加文は
- semantic difference
- explicit search
- early stop
という compare モードでの patch equivalence 判定をかなり強く想定した表現です。

しかし Step 5.5 は compare 専用ではなく、Core Method の共通 self-check です。そこに compare 寄りの no-difference 義務を持ち込むと、
- explain
- diagnose
- audit-improve
では意味が薄い、または不自然な文言になります。

つまり、
- ベンチマーク固有 ID には依存していない
- しかし mode-general な場所に compare-specific な手続きを埋め込んでいる
という形で、汎化性の質は高くありません。

### この項目の結論

明示的な overfitting ルール違反ではないが、汎化性は「強い」とは言えません。特定リポジトリ依存ではなく、特定タスク形への偏りという意味で弱点があります。

---

## 6. 全体の推論品質がどう向上すると期待できるか

### 期待できる改善

限定的には次を期待できます。

1. premature EQUIVALENT の抑制
   - 差異が見つからなかったときに、探索打ち切りをそのまま absence claim に変換する雑な結論を減らせる可能性がある

2. Step 5 の refutation obligation との接続強化
   - no-counterexample 側にも、単なる reasoning でなく search/inspection を伴うべきだという意識づけはできる

### 想定される悪化リスク

1. self-audit の複雑化
   - Step 5.5 は最終ゲートなので、ここで新しい判断軸を足すと萎縮や形式主義を招きやすい

2. template-filling 化
   - 実質的に「explicit search を書いておけばよい」挙動を助長し、探索の質より報告様式が優先される恐れがある

3. mode leakage
   - compare 用の concern が共通 self-check に混入し、他モードの自然さと汎用性を下げる

4. 片方向改善に留まる
   - 改善余地が主に EQUIVALENT 側に限られ、NOT_EQUIVALENT 側の精度向上にはほぼ寄与しない

### 総合評価

改善の狙い自体は理解できますが、入れどころが悪いです。

同じアイデアを採るなら、Core Method の Step 5.5 ではなく、compare mode の
- NO COUNTEREXAMPLE EXISTS
- Compare checklist
の wording を軽く明確化する方が、研究コアを保ちつつ副作用が小さいはずです。

現提案のままでは、全体推論品質の安定向上よりも、
- compare の EQUIVALENT 側だけを締める
- しかも self-audit を重くする
方向に働く公算が大きいです。

---

## 総合所見

この提案は「差異なし主張にも反証的探索を要求したい」という問題意識自体は妥当です。しかし、
- カテゴリ E という整理は実体に合っていない
- 効果は実効上 EQUIVALENT 側に偏る
- failed-approaches.md が警戒する「結論直前の自己監査への新しいメタ判断追加」「no-counterexample 側の形式化」に近い
- Core Method の共通 self-check に compare-specific な義務を持ち込んでおり、汎化性が弱い
という理由から、採用には慎重であるべきです。

## 承認: NO（理由）

理由:
1. 変更の実体が「表現の明確化」ではなく、新しい self-check 義務の追加であり、カテゴリ整理が不適切
2. 効果が EQUIVALENT 側に偏っており、提案者のいう両方向の対称化は実効的には成立していない
3. failed-approaches.md の禁止原則、特に「結論直前の自己監査への新しいメタ判断追加」と実質的に近い
4. compare-specific な no-difference 手続きを Core Method の共通 self-check に埋め込むため、汎化性に懸念がある
5. 期待利益は限定的だが、形式主義化と回帰リスクは無視できない
