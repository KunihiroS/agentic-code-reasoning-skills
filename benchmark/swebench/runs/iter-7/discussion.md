# iter-7 discussion

## 総評
提案の狙い自体は理解できる。とくに「何か検索した」だけで EQUIV を確定する儀式化を避け、意思決定を変えうる探索へ寄せたい、という問題設定は妥当である。Decision-point delta も proposal 内で比較的具体化されており、「監査 rubic に刺さる説明強化」だけで終わらせない意図も見える。

ただし、今回の差分案は実効部分が Step 5.5 の required self-check の厳格化に強く依存しており、これは failed-approaches.md が明示的に警戒している「結論直前の自己監査に特定の検証経路を半必須化する」方向にかなり近い。結果として、compare の意思決定を改善するというより、「EQUIV を出す前の必須通過条件」を狭める片方向バイアスとして働く懸念が強い。

## 1. 既存研究との整合性
DuckDuckGo MCP で確認した範囲では、提案の核である「一般的な探索」より「結論を覆しうる反例・診断的証拠」に探索を寄せる発想自体は、広い研究潮流とは整合する。

- URL: https://eikmeier.sites.grinnell.edu/csc-151-s221/readings/hypothesis-driven-debugging.html
  - 要点: hypothesis-driven debugging は、ad-hoc な探索ではなく、予測を立て、それを verify/refute する証拠収集へ進めるべきだとする。提案の「結論反転しうる探索へ寄せる」はこの方向性と整合。
  - 含意: どのファイルを読むかを固定するのではなく、「どの観測が仮説を覆すか」を先に意識すること自体は汎用原則として自然。

- URL: https://www.emergentmind.com/topics/counterexample-guided-abstraction-refinement-cegar
  - 要点: CEGAR は counterexample analysis を使って refinement を局所化し、generic search ではなく diagnostic precision の高い refinement を進める枠組み。
  - 含意: 「反例像が探索を導く」という抽象原理は一般的で、探索の情報量より decision-relevance を重視する考え方には先行例がある。

- URL: https://arxiv.org/html/2603.14823v1
  - 要点: verification failure から得られる spurious counterexample を用いて、blind refinement を targeted refinement に置き換えると search tree size と verification time を削減できる、と論じている。
  - 含意: blind search よりも「失敗を生む/結論を覆す証拠」を狙う探索が有効、という一般論は支持される。

結論として、研究との整合性はある。ただし、これらの先行例が支持しているのは「反例が探索を導く」原理であって、「結論直前 self-check に特定の探索型を required として埋め込む」設計まで直接支持しているわけではない。

## 2. Exploration Framework のカテゴリ選定
判定: 部分的に適切だが、主作用点の説明としては不十分。

- proposal はカテゴリ B（情報の取得方法を改善する）としている。
- Step 3 optional 欄の INFO GAIN → DECISION-FLIP TARGET 置換だけを見るなら B でよい。
- しかし compare の実効差分は主に Step 5.5 の required self-check の意味変更で生まれており、これは B だけでなく D（メタ認知・自己チェック）にもまたがる。
- しかも問題はこの D 側の変更であり、ここが回帰リスクの主因。

したがって、「主作用は B」と言い切るより、「B を狙ったが実効差分は D に乗っている」と認識したほうがよい。カテゴリ整理が甘いままだと、failed-approaches.md にある self-check 系の失敗原則を見落としやすい。

## 3. EQUIVALENT / NOT_EQUIVALENT の両方向への作用
### 変更前との実効的差分
- 変更前: 「実際に検索/inspection した」という最低条件を満たせば self-check を通過できる。
- 変更後: 「counterexample-shaped な検索/inspection」を実施しないと self-check を通過しにくくなる。

### EQUIVALENT 側への作用
- 明確に強く作用する。
- EQUIV を出す前に、より decision-relevant な探索を要求するため、偽 EQUIV の抑制には効きうる。

### NOT_EQUIVALENT 側への作用
- 作用は弱く、対称ではない。
- proposal は「根拠薄い NOT_EQUIV への飛躍も抑える」と書くが、提示差分そのものは NOT_EQUIV の要件を直接改善していない。
- 実際には、「反例形を明快に言語化できない」ケースで EQUIV を出しにくくなる一方、agent が保留を嫌う場合は NOT_EQUIV へ逃げる圧力すら生じうる。

### 片方向最適化か
判定: かなり片方向寄り。

この提案は主として「EQUIV を出すハードルを上げる」変更であり、NOT_EQUIV 判定の誤りを減らす機構は proposal 本文上の説明ほど実装差分に埋め込まれていない。したがって、両方向改善というより「偽 EQUIV 抑制に寄った調整」とみるべき。

## 4. failed-approaches.md との照合
最重要懸念はここ。

- 「証拠の種類をテンプレートで事前固定しすぎる変更は避ける」
  - proposal は証拠内容ではなく探索の型だと説明するが、required 項目として「counterexample-shaped search/inspection」を求める時点で、実質的には証拠収集の型を事前固定している。

- 「結論直前の自己監査に、新しい必須のメタ判断を増やしすぎない」
  - proposal は“追加”ではなく“置換”と主張するが、failed-approaches.md は「既存チェック項目への補足に見える形でも、結論前に特定の検証経路を半必須化すると、実質的に新しい判定ゲートとして働きやすい」と明示している。
  - 今回はまさにこれに近い。

- 「暫定的な反例像や結論形式を冒頭で先に置かせる変更も同類」
  - Step 3 の decision-flip target は optional なので直接の違反度は低いが、Step 5.5 required と組み合わさると、探索の終盤で「まず反例像を置けること」が通過条件化し、探索全体をその型へ寄せる圧力になる。

結論: wording は新しく見えるが、本質的には failed-approaches.md が警戒する「証拠種類/検証経路の半固定」と「結論前ゲートの実質増設」の再演リスクが高い。

## 5. 汎化性チェック
### 明示的なルール違反の有無
- 具体的な数値 ID: なし
- 特定リポジトリ名: なし
- 特定テスト名: なし
- ベンチマーク実コード断片: なし

この点は良い。SKILL.md 自身の引用のみで、Objective.md の許容範囲に収まっている。

### 暗黙のドメイン前提
- 提案は「テスト × 観測差分」「オラクル可視差分」という compare 文脈に強く寄っている。
- ただし SKILL.md の compare モード自体が test outcome ベースなので、compare 改善案としては許容範囲。
- 一方で、「counterexample-shaped」を強く押しすぎると、テストオラクルが明示的でない言語/環境や、同値性の判断材料が分散しているケースでは言語化コストが上がる。

よって、明白な overfitting 違反ではないが、運用設計としては compare の一部スタイルに寄りやすい。

## 6. 全体の推論品質への期待効果
期待できる改善はある。

- 「検索した事実」ではなく「決定境界を動かしうる探索」を意識させる点は、儀式的な探索の抑制に効く。
- とくに偽 EQUIV の主要因が「既知経路だけ追って安心する」タイプなら、追加探索を促す力はある。

ただし、今回の書き込み位置が悪い。

- optional な探索誘導として置くなら、探索の質を上げる可能性がある。
- required self-check に埋め込むと、推論品質の改善というより、終盤での形式的な通過条件化が起きやすい。
- その結果、比較判断の質を上げるより「counterexample-shaped と書けるか」の報告能力を測るリスクがある。

## 停滞診断
- 懸念 1 点: proposal は「EQUIV を出す前提が変わる」と説明しており compare 影響を語れてはいるが、実際の変更位置が Step 5.5 self-check なので、意思決定そのものの改善より“監査 rubric に見えやすい形式的な厳格化”へ寄っている懸念がある。

### failed-approaches 該当性
- 探索経路の半固定: YES
  - 原因文言: 「OPTIONAL — DECISION-FLIP TARGET」「counterexample-shaped search/inspection」を required 側でも要求しており、探索を特定の反例像中心へ寄せる圧力がある。
- 必須ゲート増: YES
  - 原因文言: Step 5.5 の required 項目を「何か検索した」から「counterexample-shaped search/inspection」に置換しており、項目数は同じでも実質的な通過条件は強化されている。
- 証拠種類の事前固定: YES
  - 原因文言: 「a concrete 'would flip the conclusion' pattern」を必須化しており、証拠の収集型を事前指定している。

## compare 影響の実効性チェック
- 1) Decision-point delta:
  - Before: IF 「最低1回の検索/inspection をした」かつ「手元の追跡で同じに見える」 THEN EQUIV に進みやすい
  - After: IF 「結論を反転させ得る反例形を狙った検索/inspection が未実施」 THEN 保留して追加探索へ進む
  - IF/THEN 形式で 2 行（Before/After）になっているか: YES
  - ただし評価: 条件と行動は一応変わっているので proposal 要件は満たすが、変化の主座が self-check gate であり、探索戦略そのものの分岐変更より「EQUIV の通過基準厳格化」に寄っている。

- 2) Failure-mode target:
  - 主対象: 偽 EQUIV
  - メカニズム: 既知経路の整合 + 形式的検索 1 回で終えるのを防ぎ、結論を覆す観測差分を狙った探索が済むまで EQUIV を出しにくくする。
  - 副作用候補: 偽 NOT_EQUIV というより、保留増加または EQUIV 回避バイアス。

- 3) Non-goal:
  - 変えないべきことは、探索順序の固定、証拠種類の固定、結論前ゲートの増設。
  - しかし現提案はこの境界条件を文章上では宣言しつつ、Step 5.5 required 変更で実質的に踏み越えている。

- Discriminative probe:
  - 抽象ケース: 2 変更が主要経路では同じだが、別の既存テストだけが副作用差分を観測しうるケース。
  - 変更前は「一度検索したし同じに見える」で偽 EQUIV が起きうる。変更後は副作用差分を反例形として置ければ追加探索に進めるので、この誤りは減りうる。
  - ただし、その改善は optional な探索誘導だけでもある程度得られ、Step 5.5 required 化まで要るとはまだ示せていない。

## 修正指示
1. Step 5.5 の required 置換は戻すこと。代わりに、Step 3 の optional 欄だけを強化するか、compare テンプレートの「NO COUNTEREXAMPLE EXISTS」節の文言を少し具体化する形へ移すこと。
2. 「counterexample-shaped」を必須語にするのではなく、「current leading conclusion を最も動かしうる観測差分」程度に弱め、反例像の事前固定を避けること。
3. NOT_EQUIV 側にも対称な効き方を持つよう、EQUIV だけを止める gate ではなく、「追加探索する/結論する」の分岐条件を compare 本文側で置換すること。その場合は別の required 文言を増やさず、既存文の統合で支払うこと。

## 結論
提案の問題意識と最小差分志向は良いが、現形では failed-approaches.md の本質的な再演リスクが高い。とくに Step 5.5 の required self-check に特定の探索型を埋め込む点が最大のブロッカー。

承認: NO（理由: failed-approaches.md が禁じる「結論直前 self-check で特定の検証経路を半必須化する」変更の再演に近く、compare 改善より EQUIV 側の通過基準厳格化へ偏っているため）
