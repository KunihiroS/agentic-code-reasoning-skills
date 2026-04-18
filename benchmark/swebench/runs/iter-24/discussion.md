# Iteration 24 — discussion

## 総評
提案の芯は明確です。compare テンプレート冒頭の「minimal counterexample shape を先に置く」指示が、実質的に探索入口のアンカーとして働きうるため、既に compare 本文内で required とされている DEFINITIONS + STRUCTURAL TRIAGE を先に出し、その後に triage-scoped な反例候補生成へ移す、というものです。

これは「何の証拠を探すか」を固定する変更ではなく、「同じ要素をいつやるか」の置換なので、Objective.md の Exploration Framework では A. 推論の順序・構造を変える に入れるのが妥当です。しかも SKILL.md 内の既存要件（STRUCTURAL TRIAGE required before detailed tracing）と certificate 冒頭文の軽い不整合を解消する方向なので、単なる説明強化ではなく compare の入口分岐を実際に触っています。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

README.md / docs/design.md の研究コアは「番号付き前提、仮説駆動探索、手続き間トレース、必須反証」であり、本提案はそのコアを削らず、compare の入口順序だけを調整するものです。特に docs/design.md が強調する「structured templates are certificates」「per-item iteration as anti-skip mechanism」と矛盾せず、反例義務自体も維持されています。

## 2. Exploration Framework のカテゴリ選定
判定: 適切。

理由:
- 提案の本体は compare 冒頭の順序置換であり、A. 推論の順序・構造変更に素直に対応している。
- B（取得方法）や D（自己チェック追加）ではない。新しい探索対象や新しい監査ゲートを増やしていないため。
- F（原論文未活用）を副次的に主張する余地はあるが、主成分はあくまで順序変更。

## 3. EQUIVALENT / NOT_EQUIVALENT 両方向への作用
この提案は片方向最適化ではなく、両方向に作用しうる。

- EQUIVALENT 側:
  先に反例像を雑に決めると、たまたま思いついた差分像に探索が寄り、triage で見るべき比較スコープより先に「差がありそう」という局所像に引っ張られる。提案後は scope 先行になるので、偽 NOT_EQUIV を減らしやすい。
- NOT_EQUIVALENT 側:
  逆に、先に置いた反例像が不適切すぎると「見つからなかったので差がない」に寄り、構造ギャップや relevant path 上の欠落を過小評価して偽 EQUIV へ倒れる。提案後は triage-scoped な反例候補になるので、偽 EQUIV も減らしやすい。

実効差分として重要なのは、反例生成の削除ではなく「後置」です。反例チェック義務は残るため、NOT_EQUIVALENT 判定だけを弱める変更ではありません。

## 4. failed-approaches.md との照合
### 本質的な再演か
結論: 直撃の再演ではないが、近接領域なので実装文言は慎重に絞るべき。

整合する点:
- failed-approaches.md は「暫定的な反例像を冒頭で先に置かせる変更」を探索入口の狭窄として警戒しており、本提案はそこを後置するので方向としては整合的。
- 証拠種類の事前固定、観測境界への過度還元、新しい必須メタ判断の純増はしていない。

注意点:
- 同ファイルは「どこから読み始めるか」「どの境界を先に確定するか」の半固定も警戒している。したがって実装時に triage-first を“新しい強い探索哲学”として膨らませると、別形の半固定に見えうる。
- ただし今回の proposal は、既に SKILL.md に存在する required triage を certificate 冒頭文へ整合させるレベルであり、新たな経路固定を追加しているわけではない。この範囲なら許容可能。

## 5. 汎化性チェック
判定: 概ね良好。

- proposal 内にベンチマークケース ID、特定リポジトリ名、テスト名、コード断片の持ち込みはない。
- 引用されているのは SKILL.md 自身の文言であり、Objective.md の R1 減点対象外に収まる。
- 特定言語・ドメイン・テストパターンへの暗黙の依存も薄い。structural scope → relevant tests → counterexample sketch という流れは言語非依存。

軽微な留意:
- “reverse from D1” は test-outcome 基準中心の compare モードに依存するので、compare 以外へ横展開する話に広げないほうがよい。

## 6. 期待される推論品質の向上
- compare 冒頭の自己アンカリングを弱め、先に relevant scope を定めることで探索の初手が安定する。
- SKILL.md 内の「counterexample first」と「STRUCTURAL TRIAGE required before detailed tracing」のねじれが減り、テンプレート指示の一貫性が上がる。
- 変更量が小さいため、研究コアや既存の反証可能性を崩さずに compare の判断入口だけ改善できる。

## 停滞診断（必須）
- 懸念 1 点: この提案は「冒頭文の言い換え」に留まると audit rubric には刺さるが compare の意思決定は変わらない。したがって、certificate 冒頭の実指示順序が本当に Before/After で置換されることが必要。

### failed-approaches 該当性チェック
- 探索経路の半固定: NO
  - 理由: 新しい固定化ではなく、既存の required triage と冒頭文の不整合解消が主眼。反例生成自体は削らず後置するだけ。
- 必須ゲート増: NO
  - 理由: proposal 自身が「MUST/required の追加なし」「1–2行の置換」と明記している。
- 証拠種類の事前固定: NO
  - 理由: 何を探すかのテンプレ固定ではなく、反例生成のタイミング変更。

## compare 影響の実効性チェック（必須）
- 1) Decision-point delta:
  - Before: IF compare certificate に入ったら THEN minimal counterexample shape を先に置いてから分析に入る。
  - After: IF compare certificate に入ったら THEN DEFINITIONS + STRUCTURAL TRIAGE で比較スコープを確定し、その後に triage-scoped な counterexample shape を置く。
  - IF/THEN 形式で 2 行になっているか: YES
  - Trigger line（発火する文言の自己引用）が差分プレビューにあるか: YES
  - 評価: 条件も行動も変わっており、理由の言い換えだけではない。

- 2) Failure-mode target:
  - 対象: 両方（偽 EQUIV / 偽 NOT_EQUIV）
  - メカニズム: 反例像の早期アンカリングを弱め、先に relevant scope を確定することで、狭すぎる反例像による見落としと、雑な差分像への過剰適応を同時に減らす。

- 3) Non-goal:
  - STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件（S2→直行）自体はいじらない。
  - 新しい必須欄や新しい証拠タイプは増やさない。
  - 探索経路を別の局所観点に差し替える提案にはしない。

- Discriminative probe:
  - 抽象ケース: 2 変更は一見異なる実装だが、relevant tests が触るのは一部の共有スコープだけで、差分は非relevant path にある。
  - 変更前は、先に描いた反例像がその非relevant 差分に寄ると偽 NOT_EQUIV に倒れやすい。変更後は triage で relevant scope を先に押さえるため、その差分を counterexample 候補から外しやすい。
  - これは新ゲート追加ではなく、既存の triage と counterexample の順序置換だけで説明できる。

- 支払い（必須ゲート総量不変）の明示:
  - 本件は新しい必須ゲートの追加提案ではなく、既存必須要素の再配置なので、A/B 対応付けの支払いは追加では不要。

## 修正指示（2〜3点）
1. 実装は certificate 冒頭 1 行の置換に厳密に留め、triage-first の説明文を別の必須文として増やさないこと。
2. After 文言では「scope what must be compared」を残しつつ、triage が探索経路そのものを固定するかのような強い表現は避けること。既存 required triage への整合、というトーンに抑えること。
3. 可能なら “using what triage reveals” を “using the scoped relevant tests/paths identified above” のように少し具体化し、counterexample 後置が compare 判断のどこに効くかを明確にすること。

## 結論
承認: YES

理由: Trigger line と Before/After の decision-point delta が具体で、compare の入口分岐を実際に変えている。failed-approaches.md の禁止方向にも原則抵触せず、しかも新ゲート追加なしの小差分なので、PASS の下限を満たしたまま compare 改善に結びつく提案として妥当。