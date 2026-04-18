# Iteration 29 Discussion

## 総評
提案の主眼は、compare における「意味差分を見つけた後の no-impact / impact 断定」を、test assertion に結びついた説明まで引き上げることにあります。これは新しい証拠種類を追加する提案というより、既存 compare bullet「差分を見つけたら少なくとも1本の relevant test を追う」を、より判別的な分岐条件へ置換する提案です。SKILL.md の compare 定義がもともと「relevant test outcomes の同一性」を基準にしていること、NOT_EQUIVALENT 側では既に diverging assertion を要求していることから、方向性自体は研究コアと整合しています（SKILL.md:169-178, 226-230, 258）。

## 1. 既存研究との整合性
- 検索なし（理由: 一般原則の範囲で自己完結）。
- README.md と docs/design.md の要旨では、論文のコアは semi-formal reasoning による「premises → tracing → refutation → formal conclusion」の証拠駆動化であり、特に compare は per-test iteration と counterexample obligation が中核です（README.md:49-57, docs/design.md:11-18, 33-50）。
- proposal は localize の DIVERGENCE ANALYSIS を compare に移植すると述べていますが、これは docs/design.md が明示する「原論文の他タスクの手法を翻訳して guardrail 化する」方針と矛盾しません（docs/design.md:66-68, Objective.md:168-171）。

## 2. Exploration Framework のカテゴリ選定
- 判定: 適切（F 寄り、ただし C にもまたがる）。
- 理由:
  - proposal は compare の最終判定基準そのものを変えるのではなく、原論文由来の localize/explain 的な「divergence を具体位置に結ぶ書式」を compare に再利用しようとしているため、Objective.md の F「原論文の未活用アイデアを導入する」に合っています（Objective.md:168-171）。
  - 同時に compare 内の decision point を差し替えるため C の側面もありますが、メカニズムの源泉は原論文の他モードなので、主カテゴリ F で妥当です。

## 3. EQUIVALENT / NOT_EQUIVALENT の両方向への作用
- EQUIVALENT への作用:
  - 変更前は、意味差分を見つけても「relevant test を1本追った」だけで no-impact を言いやすく、たまたま観た経路で差分が吸収された場合に偽 EQUIV が残りえます。
  - 変更後は、assertion まで接続した downstream neutralization を説明できない限り no-impact を断定しづらくなるので、偽 EQUIV を減らす方向に働きます。
- NOT_EQUIVALENT への作用:
  - 変更前は、意味差分そのものを outcome 差と短絡し、assertion で本当に観測されるかの詰めが甘いまま偽 NOT_EQUIV に倒れる余地があります。
  - 変更後は、impact 側も assertion-anchored divergence を要求するため、差分の過大評価を抑えられます。
- 実効差分:
  - これは片方向最適化ではなく、「差分を見つけた瞬間の断定条件」を両方向で厳密化する変更です。
  - ただし wording が assertion 側に寄りすぎると、構造差や import 差を structural triage で先に切る既存ルートとの役割分担が曖昧になるため、compare bullet の置換対象が「semantic difference 後の no-impact 判定」に限定されることを実装時に明記したほうが安全です。

## 4. failed-approaches.md との照合
- 「証拠種類の事前固定」再演か: 部分的な懸念はあるが、現状の proposal 文なら本質的再演ではない。
  - 良い点: proposal 自身が data-flow / 型 / 例外 / 順序などの具体証拠種類を固定しないと明記しており、この点は failed-approaches.md の禁止方向を意識できています（proposal.md:49-51, failed-approaches.md:8-12）。
  - 懸念点: 「earliest divergence を specific test assertion に localize」という言い回しは、探索の着地点を assertion に強く寄せるため、文面次第では「特定の観測境界への還元」と読まれえます（failed-approaches.md:11-17）。
- 「探索経路の半固定」再演か: 弱い懸念あり。
  - 特に “earliest divergence” は、どこから読解を始めるか・どの分岐を優先するかを半固定化する表現に見えやすいです（failed-approaches.md:14-18, 22-25）。
  - ただし提案の本丸は tracing order の固定ではなく、結論の根拠粒度の指定なので、ここは wording を少し弱めれば回避可能です。
- 「新しい必須ゲート増」再演か: 主要には NO。
  - proposal は compare checklist の 1 bullet を差し替えるだけで、必須欄や新セクションの追加ではないと宣言しています（proposal.md:53-54）。
  - そのため failed-approaches.md の「結論直前の自己監査に新しい必須ゲートを増やしすぎない」に正面から抵触しているとは言いにくいです（failed-approaches.md:27-31）。

## 5. 汎化性チェック
- 固有識別子違反: なし。
  - proposal 内に具体的な repository 名、テスト名、ケース ID、コード断片は含まれていません。SKILL.md の自己引用は Objective.md の減点対象外ルールにも整合します（Objective.md:202-213）。
- ドメイン依存の暗黙前提: 強くは見られない。
  - 例外型、戻り値形、順序差などの例示は言語非依存で、特定フレームワークに閉じていません。
  - ただし「specific test assertion」への anchoring は xUnit 型テスト観をやや強く想起させるため、実装文では assertion を「observable test check / failure condition」を含む広い表現にしたほうが、言語・テスト基盤横断でより自然です。

## 6. compare 影響の実効性チェック
- 1) Decision-point delta:
  - IF/THEN 形式で 2 行（Before/After）になっているか？: YES
  - Trigger line（発火する文言の自己引用）が差分プレビューにあるか？: YES
  - 実効性評価:
    - Before は「semantic difference を見たら representative test path を1本追えば no-impact を言える」。
    - After は「semantic difference を見たら assertion-anchored divergence explanation または downstream neutralization を書けるまで no-impact を言わない」。
    - 条件と行動が両方変わっており、単なる理由の言い換えではありません。
- 2) Failure-mode target:
  - 対象: 両方（偽 EQUIV / 偽 NOT_EQUIV）
  - メカニズム: 差分発見後の断定条件を path-level から observable-assertion-level へ上げることで、差分の過小評価と過大評価を同時に抑える。
- 3) Non-goal:
  - structural triage の早期 NOT_EQUIV 条件は変えない。
  - 探索で探す証拠種類を data-flow などに固定しない。
  - compare 全体に新欄を増やさず、既存 bullet の置換に留める。
- Discriminative probe:
  - 抽象ケースとして、「中間状態は異なるが test の最終観測点では吸収される」または「中間状態差が例外捕捉条件の差を通じて assertion で観測される」というケースを置いており、変更前は path-level の雰囲気で EQUIV / NOT_EQUIV を誤りやすい、変更後は assertion-level まで接続できない限り断定しない、という差が説明できています。
  - これは新ゲート追加ではなく、既存 bullet の置換として説明されているため、要件を満たしています。
- 支払い（必須ゲート総量不変）の明示:
  - YES。proposal は compare checklist の 1 bullet 差し替えであり、追加ではなく置換だと明示しています（proposal.md:53-54）。

## 停滞診断
- 懸念を 1 点だけ挙げると、proposal は「assertion まで書け」という説明強化に見えやすく、実装文が弱いと compare の探索行動自体が変わらず、単に監査で説明を厚くするだけで終わる恐れがあります。したがって実装では、「書けなければ no-impact を conclude せず、追加探索または保留へ進む」という分岐動作まで明文化すべきです。
- failed-approaches 該当性:
  - 探索経路の半固定: YES（弱く）。原因候補の文言: “localize the earliest A↔B divergence ...”
  - 必須ゲート増: NO
  - 証拠種類の事前固定: NO

## 推論品質への期待効果
- compare の最も危ない誤りは、差分発見後の premature closure です。今回の提案はその局所 decision point に絞っており、影響範囲が限定的です。
- 既存の research core（per-test tracing, refutation, formal conclusion）を壊さず、compare の観測粒度を「差分あり/なし」から「その差分が test result にどう接続するか」へ上げるため、推論の判別性は改善しやすいです。
- 特に SKILL.md Guardrail #4「subtle difference dismissal」を compare template 側へ具体化する形になるので、guardrail と certificate template の間のズレを減らす効果が見込めます（SKILL.md:452-458）。

## 修正指示（2点）
1. “earliest divergence” は探索順序の半固定に読めるので、実装時は「a concrete divergence that is causally connected to an observable test check」程度に弱めてください。置換で済ませ、読解順序の固定に見える語は削るのがよいです。
2. “specific test assertion” はやや狭いので、「assertion or other observable test check / failure condition」に広げてください。追加説明を増やすのではなく、観測境界の言い換えで汎化性を上げるのがよいです。

## 結論
承認: YES