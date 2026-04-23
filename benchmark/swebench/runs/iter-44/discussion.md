# Iteration 44 — discussion

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

この提案は、README.md と docs/design.md が強調する「結論ではなく推論プロセスを改善する」「per-item iteration で premature conclusion を防ぐ」という設計に整合している。特に、compare の relevant test 集合の作り方を direct call path 依存から、実際にテストが消費する contract ベースへ置き換える点は、証拠収集の粒度改善であって、研究コア（番号付き前提・仮説駆動探索・手続き間トレース・反証）を壊していない。

## 2. Exploration Framework のカテゴリ選定
カテゴリ C「比較の枠組みを変える」で適切。

理由:
- 変更対象は tracing の順序や self-check ではなく、「何を relevant test とみなすか」という compare の比較母集団そのもの。
- proposal の Mechanism も「差分比較の単位を direct call path から changed contract consumption へ広げる」と明示しており、Objective.md の C の説明と一致している。
- B（情報取得）や D（メタ認知）に見せかけた変更ではなく、compare 判定の入力集合を変えるので C が最も自然。

## 3. compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  - pass-to-pass test の一部が「irrelevant なので比較から除外」ではなく「relevant として比較対象に入る」ようになる。
  - その結果、従来は早めに EQUIVALENT へ寄っていたケースで、追加探索要求・EQUIV 保留・NOT_EQUIV への遷移が観測可能に増える。
- 1) Decision-point delta:
  - Before: IF a pass-to-pass test does not traverse the edited code directly THEN omit it from comparison.
  - After: IF a pass-to-pass test consumes a changed return/state/exception contract, even indirectly, THEN include it in comparison.
  - IF/THEN 形式で 2 行になっているか: YES
  - Trigger line の自己引用が差分プレビューに含まれているか: YES
  - 評価: 条件も行動も変わっており、理由の言い換えだけではない。
- 2) Failure-mode target:
  - 主対象は偽 EQUIV の削減。メカニズムは、wrapper / indirection 越しに contract を消費する pass-to-pass test を relevant set に戻し、見落としていた回帰差を比較に乗せること。
  - 副次的には、direct path 非一致だけで irrelevant 扱いしていたものを再評価するので、「構造差があるから違うはず」という雑な偽 NOT_EQUIV も抑えやすい。
- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？
  - NO
- 3) Non-goal:
  - structural triage の早期 NOT_EQUIV 条件は変えない。
  - 新しい必須ゲートや新ラベル分類は増やさず、既存 D2(b) と checklist 文言の置換に留める。
  - 「relevance 未解決なら常に保留」の既定分岐は追加しない。

追加チェック:
- Discriminative probe:
  - 抽象ケースとして、helper の contract 変更を caller A/B が異なる形で吸収するが、fail-to-pass だけ見ると両方通る状況を置いている。変更前は indirect consumer な pass-to-pass test を外して偽 EQUIV になりやすい。
  - 変更後は、その consumer test を比較対象へ戻すことで差分が test outcome へ波及するかを確認でき、誤判定を避けやすい。
  - しかも説明は「既存 relevance 文言の置換」であり、新しい必須ゲート増設ではない。
- 「支払い（必須ゲート総量不変）」の A/B 対応付け:
  - YES。proposal の Payment 行で、追加する MUST と demote/remove する MUST の対応が明示されている。

## 4. EQUIVALENT 判定 / NOT_EQUIVALENT 判定の両方向への作用
EQUIVALENT への作用:
- 変更前は、direct call path にない pass-to-pass test を relevance から外しやすく、観測差が未確認のまま EQUIVALENT に寄る余地があった。
- 変更後は、changed contract consumer を relevant に含めるため、EQUIVALENT を出す前に「その contract を消費する既存テストで差が出ない」ことを確認しやすくなる。
- したがって、EQUIVALENT は出しにくくなる方向だが、それは理由説明の強化ではなく、比較対象の実質拡張によるもの。

NOT_EQUIVALENT への作用:
- 変更前は、relevant set が狭すぎて、差があっても比較に乗らず false EQUIV に埋もれる余地があった。
- 変更後は、indirect consumer test が relevant になれば、差分が assertion outcome に及ぶ場合に NOT_EQUIVALENT へ到達しやすくなる。
- 一方で structural triage や early NOT_EQUIV 条件は変えていないため、「ファイル差があるだけ」で NOT_EQUIVALENT に倒す片方向最適化にはなっていない。

結論として、片方向最適化ではない。主効果は偽 EQUIV の削減だが、NOT_EQUIVALENT だけを増やす規則ではなく、EQUIVALENT を出す前の relevant-set 構成を改善する提案なので、両方向に実効差がある。

## 5. failed-approaches.md との照合
本質的再演には見えない。

- 「探索経路の半固定」: NO
  - 単一アンカーや単一テストへの固定ではなく、relevant set の定義変更。次にどの 1 経路を必ず追えとは言っていない。
- 「必須ゲート増」: NO
  - D2(b) と checklist の置換が中心で、Payment も明示されている。新たな独立ゲート増設ではない。
- 「証拠種類の事前固定」: NO
  - 追加で求めるのは特定証拠フォーマットではなく、どのテストを relevant とみなすかの基準変更。assertion boundary 固定や新ラベル分類の強制でもない。

補足:
- failed-approaches.md の原則2にある「間接経路を探索し尽くすまで relevance を閉じない既定動作」は要注意だが、今回の提案は「changed contract consumption が見える pass-to-pass tests を含める」であり、間接経路を無限に暫定採用する規則ではない。
- 原則5の「最初に見えた差分から単一追跡経路を固定」にも当たらない。

## 6. 汎化性チェック
- 具体的な数値 ID, リポジトリ名, テスト名, コード断片: 見当たらない。
- SKILL.md 自身の文言引用はあるが、Objective.md の R1 減点対象外に該当する自己引用の範囲。
- 「return/state/exception contract」という表現は API 的・言語非依存で、特定言語や特定テストフレームワーク前提にはなっていない。
- 暗黙のドメイン偏りも強くはない。wrapper / indirection の例は一般的なプログラム構造であり、特定リポジトリ想定ではない。

## 7. 停滞診断
- 懸念点を 1 点だけ挙げると、「contract consumption」という説明語が監査には刺さりやすい一方、実装時に relevance 判定の発火条件が曖昧だと compare の挙動差が弱くなる。今回は Trigger line と Before/After があるので最低限は満たしているが、discussion としては「消費」の判定を checked behavior ベースで書き切ることが重要。

failed-approaches 該当性:
- 探索経路の半固定: NO
- 必須ゲート増: NO
- 証拠種類の事前固定: NO

## 8. 全体の推論品質への期待効果
期待できる改善は妥当。

- compare が direct call path の表面的近さに寄りすぎるのを防ぎ、実際の test oracle が観測する contract 単位で差を拾いやすくなる。
- 研究コアの「per-test iteration」と整合的に、relevant test の取りこぼしを減らす方向の改善であり、template-driven reasoning の証拠密度を上げる。
- 変更規模も小さく、既存構造の局所置換なので回帰リスクは相対的に低い。

## 9. 総合所見
この proposal は、監査 rubric に合わせた説明強化だけでなく、compare の実行時の分岐点そのものを変えている。特に、Before/After の IF/THEN、Trigger line、Payment、Discriminative probe が揃っており、「監査には通りやすいが compare に効かない」類型は一応回避できている。

最大の残留リスクは、changed contract consumption の判定が実装時に広すぎると relevance 集合が膨らみ、原則2の「間接経路の救済優先」に寄る点だが、proposal 文面では checked behavior consumes a changed contract と限定しており、現時点では過剰拡張までは読めない。

修正指示（最小限）:
1. 「consumes a changed contract」を、可能なら proposal 実装時に「the test assertion or checked behavior depends on that return/state/exception contract」と少しだけ具体化すること。追加行ではなく既存 After 文の置換で足りる。
2. checklist の変更では、単に pass-to-pass tests を増やすのではなく、「irrelevant と除外する前に changed-contract consumers を確認する」と exclusion 条件の側に寄せて書くこと。新ゲート化を避けやすい。

承認: YES