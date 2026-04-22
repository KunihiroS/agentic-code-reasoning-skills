# 監査コメント

## 総評
この提案は、compare の結論直前にある重複 mandatory gate を削り、Step 5 の refutation を唯一の結論前ゲートに戻す案として一貫している。SKILL.md 上の実行時分岐を実際に変える提案になっており、単なる説明強化ではない。failed-approaches.md が禁じる「保留側への既定倒し」を弱める方向でもあり、監査 PASS の下限は満たしている。

検索なし（理由: 一般原則の範囲で自己完結）

## 1. 既存研究との整合性
外部研究への強い依拠は見当たらない。提案の中心は、SKILL.md 内の重複ゲート整理と compare の停止点変更であり、一般的な推論設計・監査原則の範囲で自己完結している。

## 2. Exploration Framework のカテゴリ選定
カテゴリ G としての選定は概ね妥当。理由は以下。
- 提案の本体は「探索経路の追加」でも「新しい証拠形式の追加」でもなく、結論直前の停止条件の調整である。
- Step 3 や structural triage の探索順そのものは変えず、Step 5.5 という重複 self-check を削るため、探索フレーム全体ではなく結論移行の分岐に効く。
- 候補2・候補3より、compare 実行時の観測可能な差が最も明確に書かれている。

したがって、「監査説明の整形」ではなく「結論に進める/戻す分岐の変更」を狙うカテゴリとして筋が通っている。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用
片方向最適化には見えない。主作用はどちらの verdict を増やすことでもなく、「追加探索/保留」を減らして明示付き結論へ進める条件を変えることにある。

- EQUIVALENT 側への作用:
  - 変更前は、bounded な未検証事項が残るだけで Step 5.5 の NO に引っかかり、追加探索や保留に流れやすい。
  - 変更後は、Step 5 の refutation が済み、残余不確実性が結論非依存なら、UNVERIFIED を明示して EQUIVALENT に進める。

- NOT_EQUIVALENT 側への作用:
  - 変更前は、差分と diverging assertion が十分に見えていても、trace table や inspection 充足の重複チェックで止まりうる。
  - 変更後は、Step 5 で counterexample が立っていれば、結論非依存の未検証事項は Step 6 に持ち込めるため、NOT_EQUIVALENT も早く出せる。

- バランス評価:
  - この案は verdict の向きを変えるより、保留しがちなケースを結論へ押し出す。
  - ただし「bounded non-decisive uncertainty」の定義が緩いと、EQUIVALENT 側で未検証依存を過小評価する危険はある。ここは minor 修正で締めれば足りる。

## 4. failed-approaches.md との照合
本質的再演には当たらない。

- 原則1「再収束を比較規則として前景化しすぎない」:
  - 該当しない。提案は再収束規範を新設せず、結論前の重複 gate を削るだけ。
- 原則2「未確定を常に保留側へ倒す既定動作にしすぎない」:
  - むしろこれを是正する方向。Step 5.5 の NO で Step 6 禁止という fallback を外すため、failed-approaches と整合的。
- 原則3「新しい抽象ラベルや必須の言い換え形式で強くゲートしすぎない」:
  - 大筋では該当しない。新しい必須フォーマットは増やしていない。
  - ただし「bounded non-decisive uncertainty」という語は新ラベル寄りなので、これ自体を再度 gate 化しない文言にしておくのが安全。

## 5. 汎化性チェック
汎化性違反は見当たらない。

- 具体的な数値 ID: なし
- 特定リポジトリ名: なし
- 特定テスト名: なし
- コード断片への依存: なし
- 特定言語・特定ドメイン前提: 明示的にはなし

提案は SKILL.md の一般的分岐変更として書かれており、特定ケース焼き込みにはなっていない。

## 6. 推論品質の改善見込み
期待できる改善は明確。
- compare の停止点が減り、証拠収集の価値が低い追加探索を抑えられる。
- 「未解決だから保留」ではなく、「未解決だが結論非依存なら明示して結論」という運用になり、出力が痩せにくい。
- Step 5 の refutation を唯一の mandatory gate に戻すため、実質的な安全装置は維持しつつ重複だけを減らせる。
- 特に bounded uncertainty が残る静的比較で、過度な non-answer を減らす効果が見込める。

## 停滞診断
- 懸念 1 点: 「Step 5 is complete」の解釈が曖昧だと、実装者が別の checklist を温存して説明だけ言い換える余地がある。ここが曖昧だと監査 rubric には刺さっても compare の停止点が実際には変わらない。

failed-approaches 該当性:
- 探索経路の半固定: NO
- 必須ゲート増: NO
- 証拠種類の事前固定: NO

## compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  - 変更前は Step 5.5 の NO により Step 6 へ進めず、追加探索/保留が発生する。
  - 変更後は Step 5 完了かつ残余不確実性が結論非依存なら、UNVERIFIED 明示つきで Step 6 に進める。これは compare 実行結果として「保留→結論」の観測可能差になる。

- 1) Decision-point delta:
  - Before: IF pre-conclusion checklist に 1 つでも NO がある THEN Step 6 に進まず追加探索/修正へ戻る。
  - After: IF Step 5 が完了し、残余不確実性が結論非依存かつ局所化されている THEN UNVERIFIED を明示して Step 6 に進む。
  - IF/THEN 形式で 2 行（Before/After）になっているか: YES
  - 条件も行動も変わっているか: YES
  - Trigger line（発火する文言の自己引用）が差分プレビュー内にあるか: YES

- 2) Failure-mode target:
  - 主対象は「過度な追加探索/保留」による両方向の取りこぼし。
  - 偽 EQUIV / 偽 NOT_EQUIV を直接減らすというより、証拠は足りているのに重複 gate で verdict 不能になる failure mode を減らす。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か:
  - NO

- 3) Non-goal:
  - structural gap から NOT_EQUIV を出す条件は変えない。
  - 新しい探索順、必須ゲート、証拠種類は追加しない。
  - Step 5 の refutation requirement 自体は弱めない。

追加チェック:
- Discriminative probe:
  - 抽象ケースとして、両変更とも同じ assertion boundary まで追えており、差分の有無は Step 5 で十分比較できるが、途中に source 不在 helper が 1 つだけ残る場合を考える。
  - 変更前は Step 5.5 の包括チェックに引っかかって保留しやすい。変更後は、その helper が結論非依存である限り UNVERIFIED として開示しつつ verdict に進めるため、不要な保留を避けられる。
  - これは新しい必須ゲート追加ではなく、既存の重複 gate を削って Step 5 に統合する説明になっている。

- 支払い（必須ゲート総量不変）:
  - A/B 対応付けは proposal に明示されている。remove MUST("If any answer is NO, fix it before Step 6.") に対し、Step 5 完了時の UNVERIFIED carry-forward を add MUST として置いており、総量増のない置換として読める。

## 修正指示（最小限）
1. 「bounded non-decisive uncertainty」を、結論を左右する claim に未検証依存が残らない場合に限る、と 1 行で明確化すること。曖昧なままだと EQUIVALENT 側で広がりすぎる。
2. 「Step 5 is complete」を checklist 的再実装にしないため、Step 5.5 では yes/no 項目を復活させず、単文 note に限定すると明記すること。
3. Step 6 側の文言に「remaining limits are reported, not reopened, unless they would change the verdict」を入れると、carry-forward の境界がより実装しやすい。

## 結論
承認: YES

最大の評価点は、提案が compare の実行時分岐を実際に変える点にある。Step 5.5 の "NO なら Step 6 禁止" を外すのは、監査向け説明補強ではなく停止点の変更であり、failed-approaches.md の本質的再演でもない。軽微な文言修正は必要だが、差し戻すほどのブロッカーではない。