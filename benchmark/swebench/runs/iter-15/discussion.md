# Iteration 15 — Discussion

## Web search
- 検索なし（理由: 提案の核は「反証対象を結論感度で優先する」「未検証仮定の影響を結論/確信度へ反映する」という一般的な推論運用原則であり、特定研究や固有概念への強い依拠は見当たらないため）

## 総評
提案は、既存の必須 Step 5 / Step 5.5 を維持したまま「どの主張を先に疑うか」の配分を変える小規模修正であり、研究コア（前提・探索・トレース・反証）を壊さず compare の意思決定に実効差を出しうる方向です。特定の観測境界や証拠種別を新ゲート化しておらず、failed-approaches.md の主要な禁則にも概ね抵触していません。

## 1. 既存研究との整合性
- README.md / docs/design.md が強調する研究コアは「明示的前提」「反復的証拠収集」「反証」「形式的結論」です。
- 本提案は新しい判定基準そのものを導入するのではなく、既存の mandatory refutation を「結論反転に最も効く主張へ先に当てる」よう微調整するものなので、コア構造の維持・補強として解釈できます。
- とくに docs/design.md の「per-item iteration as the anti-skip mechanism」とは両立します。全件走査の代替ではなく、複数の key claim があるときの反証優先順位を明示するだけだからです。

## 2. Exploration Framework のカテゴリ選定
- 判定: 概ね適切（D: メタ認知・自己チェック）
- 理由:
  - 変更対象が Step 5（Refutation check）と Step 5.5（Pre-conclusion self-check）であり、探索本体の読解順序を固定する提案ではなく、「何を弱点候補として優先的に疑うか」という自己監査の質を上げる案だからです。
  - ただし副次的には B（探索の優先順位付け）にも接しています。実装時は「探索順序の固定」ではなく「反証対象の優先順位付け」であることを明確に保つべきです。

## 3. compare 影響の実効性チェック
- 1) Decision-point delta:
  - IF/THEN 形式で 2 行（Before/After）になっているか: YES
  - Trigger line（発火する文言の自己引用）が差分プレビュー内にあるか: YES
  - 実効差分の評価:
    - Before は「key intermediate claims が多いとき、広く counterfactual checks を当てる」です。
    - After は「結論反転に最も近い claim/assumption を first target に選ぶ」です。
    - これは理由の言い換えだけではなく、最初に反証する対象と、未検証を結論へどう反映するかを変えるので、compare の分岐を実際に変えます。
    - 具体的には「結論を出す/保留する/追加で探す」のうち、追加で探す先が“広く”から“最も decision-sensitive な claim”へ変わります。

- 2) Failure-mode target:
  - 対象: 両方（偽 EQUIV / 偽 NOT_EQUIV）
  - メカニズム:
    - 偽 EQUIV: 些末な差や広い網羅感に気を取られ、実は結論を反転させる未検証仮定を見逃すケースを減らす。
    - 偽 NOT_EQUIV: 差分は見つけたが、それが test outcome を本当に反転させるか未検証のまま決定打扱いするケースを減らす。

- 3) Non-goal:
  - 変えないことは明記できています。STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件をいじらず、観測境界への還元も行わず、証拠種別の固定もしないという境界条件は妥当です。

- Discriminative probe:
  - 抽象ケース: 2 つの変更に局所的な意味差はあるが、既存テスト結果を反転させるかは「ある未検証の補助関数の振る舞い」に依存する場面。
  - 変更前は、複数 claim に広く浅く反証を当てて補助関数の仮定を後回しにし、差を軽視して偽 EQUIV、または差を過大視して偽 NOT_EQUIV が起きうる。
  - 変更後は、「その仮定が false なら結論が反転するか」を先に問うため、その補助関数の未検証性を結論/確信度へ直結させやすくなる。

- 支払い（必須ゲート総量不変）:
  - あり。proposal は Step 5 に 1 行追加しつつ、Step 5.5 の既存 1 行を置換すると明示しており、A/B の対応付けは十分あります。

## 4. EQUIVALENT / NOT_EQUIVALENT の両方向への作用
- EQUIVALENT 側:
  - 改善余地があります。EQUIVALENT は「反例がない」ことを言うため、結論反転に最も近い仮定を先に潰すのは、偽の安心感を減らします。
  - とくに Step 5.5 の置換案は、「影響しない」と言い切れない未検証要素を confidence や conclusion に反映させるため、弱い根拠での EQUIVALENT 断定を抑制します。

- NOT_EQUIVALENT 側:
  - こちらにも効きます。見つけた差分が decision-sensitive でないなら、先にそこを反証対象にすることで「差はあるが test outcome は同じ」を確認しやすくなります。
  - その結果、重要でない差を決定打扱いする偽 NOT_EQUIVALENT を減らせます。

- 片方向最適化の懸念:
  - 現時点では限定的です。提案は「より疑わしい差を探せ」ではなく「結論を反転させる主張を優先せよ」なので、EQUIV にも NOT_EQUIV にも対称に作用します。
  - ただし実装文言が「flip the final answer」を NOT_EQUIV の counterexample 探索だけに寄せると、逆方向に崩れる危険があります。Step 5 / 5.5 の文言は EQUIV↔NOT_EQUIV 双方向で読めるよう保つべきです。

## 5. failed-approaches.md との照合
- 探索経路の半固定: NO
  - 理由: 「どこから読み始めるか」「どの境界を先に確定するか」を固定していません。複数の key claim があるときの refutation target の優先順位を与えるだけです。
- 必須ゲート増: NO
  - 理由: proposal 自身が 1 行追加 + 1 行置換としており、総量不変の支払いがあります。新しい独立ゲートを純増していません。
- 証拠種類の事前固定: NO
  - 理由: 「何を探すか」の証拠カテゴリをテンプレで固定しておらず、decision-sensitive な claim を起点に反証するよう求めるだけです。

補足懸念:
- failed-approaches.md には「結論直前の自己監査に、新しい必須のメタ判断を増やしすぎない」があります。
- 今回は Step 5.5 を置換する形なので原則セーフですが、実装で「反転条件を毎回必ず列挙せよ」のように独立した報告義務へ膨らませると、この失敗原則の再演になります。

## 6. 汎化性チェック
- 明示的な違反は見当たりません。
  - 具体的な数値 ID: なし
  - ベンチマーク対象リポジトリ名: なし
  - テスト名: なし
  - 対象リポジトリのコード断片: なし
- ドメイン依存の懸念も小さいです。
  - 「claim/assumption」「final answer flip」「confidence reflection」は言語非依存・ドメイン非依存の推論運用原則です。
  - compare 専用の最適化に見える部分はありますが、Step 5 / 5.5 の修正として書かれているため、audit-improve や explain でも「結論反転に最も効く未検証箇所を先に疑う」という一般原則として流用可能です。

## 7. 推論品質の向上見込み
- 既存の mandatory refutation を残したまま、反証の焦点を「重要そう」から「結論感度が高い」へずらすため、同じトークン/注意資源でより判定に効く検証ができる可能性があります。
- compare では特に、「semantic difference は見つけたが test outcome への影響が浅い」ケースと、「未検証前提を軽く流して equivalence を断定する」ケースの両方に効きやすいです。
- 変更規模が小さいため回帰リスクも比較的低く、監査 PASS の下限を満たしつつ compare 改善へつなげやすい案です。

## 停滞診断（必須）
- 懸念点を 1 点だけ:
  - 「decision-sensitive」という説明が、単に既存の refutation をもっと丁寧に言い換えただけだと、監査 rubric には刺さっても compare の意思決定分岐は実際には変わらない恐れがあります。
  - 今回は Before/After と Trigger line が入っているので最低限回避できていますが、実装時も“最初に何を反証するかが変わる”文として残すべきです。

## 修正指示
1. Step 5 の追加文は「choose what to refute first」のように順序変化を明示し、単なる姿勢語にしないでください。
2. Step 5.5 の置換文は「reflect that uncertainty in the conclusion/confidence」を保ちつつ、独立した新チェック欄や新テンプレ欄を増やさないでください。
3. compare 側だけに読める文言を避け、EQUIV↔NOT_EQUIV 双方向の反転条件として読める表現を維持してください。

## 結論
- 監査観点では、提案は failed-approaches の本質的再演ではなく、compare の decision point に実効差を与える最小変更として成立しています。
- 最大の残留リスクは、実装時に「決定感度」が説明語に留まり、実際の分岐文にならないことです。ただし proposal には Before/After と Trigger line があり、この点は現時点で十分に具体化されています。

承認: YES
