# Iter-3 Proposal 監査コメント

## 総評
提案は Exploration Framework の D. メタ認知・自己チェック強化 に適切に属する。変更対象は compare の結論直前 self-check であり、STRUCTURAL TRIAGE の閾値や定義をいじらずに、「未検証の弱い環が outcome に効くときにそのまま断定しない」という意思決定分岐を追加している。研究コア（番号付き前提、仮説駆動探索、手続き間トレース、必須反証）を維持したまま、incomplete reasoning chain への対策を outcome-sensitive に具体化している点は妥当。

Web 検索: 検索なし（理由: 一般原則の範囲で自己完結。README.md / docs/design.md / SKILL.md の既存設計と整合確認で足りる）

## 1. 既存研究との整合性
README.md と docs/design.md では、semi-formal reasoning の価値は「証拠収集前に結論へ飛ばないこと」「certificate により unsupported claim を防ぐこと」と整理されている。今回の提案は新しい判定理論の導入ではなく、既存の Step 5.5 self-check を、Guardrail #5「Do not trust incomplete chains」により近い形へ具体化するもの。よって研究コアからの逸脱ではなく、既存の失敗分析を compare の結論分岐へ接続し直す提案として整合的。

## 2. Exploration Framework のカテゴリ選定
判定: 適切（D）

理由:
- 変更対象が Step 5.5 の pre-conclusion self-check であり、探索順序や比較単位の変更ではない。
- 「weakest link を特定する」「outcome-critical なら targeted check か confidence downgrade に分岐」は、まさに自己点検の粒度を上げる提案。
- Step 4 の UNVERIFIED 規則は維持され、そこから compare の結論条件へ橋をかける構図なので、B や C より D が本筋。

## 3. EQUIVALENT / NOT_EQUIVALENT の両方向への作用
片方向最適化ではない。

- EQUIVALENT 側:
  - 変更前は、推論鎖のどこかに outcome-critical な未検証仮定が残っていても、「全体として traced evidence がある」ことで EQUIVALENT に進みやすい。
  - 変更後は、最弱リンクが未検証なら targeted check か confidence downgrade が必要になるため、偽 EQUIV を減らしやすい。

- NOT_EQUIVALENT 側:
  - 変更前は、差分らしきものを見つけた時点で、その差分が本当に assertion boundary まで届くか未検証でも NOT_EQUIV に寄りやすい場面がある。
  - 変更後は、NOT_EQUIV を支える最弱リンクが未検証なら同様に targeted check か confidence downgrade が必要になるため、偽 NOT_EQUIV も減らしやすい。

実効差分としては、「証拠総量がそれなりにある」だけでは断定できず、「結論を実際に支えている最弱リンクの検証状態」が分岐条件になる点が重要。これは両方向に作用する。

## 4. failed-approaches.md との照合
本質的再演ではない。

failed-approaches.md の失敗原則は「再収束を比較規則として前景化しすぎない」。今回の提案は再収束優先規範を増やしていない。むしろ、未検証の弱い環を露出させ、追加探索または confidence 低下に倒す方向であり、下流一致を理由に差分シグナルを弱める提案ではない。

## 5. 汎化性チェック
判定: 問題なし

- proposal 内に具体的な数値 ID、ベンチマークケース ID、リポジトリ名、テスト名、実コード断片は含まれていない。
- "helper" や "source unavailable" の記述は抽象例の範囲で、特定言語・ドメインへの依存は薄い。
- "search/trace" はどの言語でも成立する一般行為であり、特定のテストフレームワークや AST 形状を前提にしていない。

軽微な留意点として、「one targeted search/trace」は比較的具体的な運用文言なので、実装時に特定の検索様式へ狭めすぎないことだけ注意すれば十分。

## 6. 全体の推論品質への期待効果
期待効果はある。

- compare の失敗は「証拠がゼロ」より「かなり読んだが、結論を支える一点が未検証」の形で起きやすい。
- そのため、一般的な self-check を outcome-critical weakest link に差し替えるのは、認知資源を最も危ない一点へ集中させる効果がある。
- しかも payment が明示され、mandatory 総量を純増させないので、複雑化による逆効果を比較的抑えられている。

## 停滞診断
- 懸念点 1 つ: 提案は監査 rubric には刺さりやすいが、もし実装文言が「最弱リンクを名前だけ書く」で終わると compare の実行時挙動が変わらず、説明強化だけで停滞する危険がある。今回は Trigger line と targeted check / lower confidence の行動分岐まで書けているため、この懸念は現状かなり抑えられている。

failed-approaches 該当性:
- 探索経路の半固定: NO
- 必須ゲート増: NO
- 証拠種類の事前固定: NO

補足:
- 「one targeted search/trace」は行動要求だが、検索対象や証拠媒体を固定していないため、事前固定には当たらない。
- Payment が add MUST ↔ demote/remove MUST の対応で明示されているため、必須ゲート純増にも当たらない。

## compare 影響の実効性チェック
0) 実行時アウトカム差
- 観測可能に変わる点は少なくとも 3 つある: 追加探索を 1 回要求する条件、UNVERIFIED を明示したまま結論する条件、CONFIDENCE を下げる条件。
- つまり compare 実行時に、ANSWER は維持でも CONFIDENCE が下がる、または即断せず targeted search/trace が 1 回増える、という差が観測できる。

1) Decision-point delta
- IF/THEN 形式で 2 行（Before/After）になっているか: YES
- Before/After が理由だけの言い換えではなく分岐として変わっているか: YES
  - Before は「テンプレートが埋まり直接矛盾がなければ結論へ進む」
  - After は「weakest outcome-critical link が UNVERIFIED なら targeted check か confidence downgrade へ進む」
- Trigger line（発火する文言の自己引用）が差分プレビュー内にあるか: YES

2) Failure-mode target
- 対象: 両方
- メカニズム:
  - 偽 EQUIV: hidden assumption を抱えたまま「十分 traced した」と誤認して同値判定する失敗を減らす。
  - 偽 NOT_EQUIV: 見つけた差分が outcome へ届くか未検証のまま非同値判定する失敗を減らす。

2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？
- NO
- したがって impact witness 要求の欠如による「ファイル差があるだけで NOT_EQUIV へ退化」のリスクは、この提案自体には直接ない。

3) Non-goal
- 変えないことが明示されている: STRUCTURAL TRIAGE の NOT_EQUIV 条件を狭めない、構造差の定義を観測境界ベースで再定義しない。
- これは探索経路の半固定、必須ゲート増、証拠種類の事前固定を避ける境界条件として妥当。

追加チェック: Discriminative probe
- ある差分がテスト結果を変えるかどうかが、未読の補助関数 1 つの挙動仮定に実質依存しているケースを考える。変更前は、他の大半が追えているので EQUIV または NOT_EQUIV を早めに断定しがち。
- 変更後は、その補助関数が weakest outcome-critical link として露出し、そこへの targeted search/trace か confidence downgrade が必要になるため、誤断定を避けやすい。
- これは新規ゲート追加ではなく、既存 self-check の置換で説明されており、要件を満たす。

追加チェック: 支払い（必須ゲート総量不変）
- A/B の対応付けは明示されているか: YES
- add MUST と demote/remove MUST の対応が proposal に明記されているため、compare 実効差が曖昧なまま mandatory だけ増える懸念は小さい。

## 最大の論点
この提案の成否は、「weakest link を named するだけ」で終わらず、実際に compare の分岐を変える文言として実装できるかに尽きる。proposal はこの点を Trigger line と Before/After でかなり具体化できているため、現時点では監査 PASS の下限を満たしている。

## 修正指示（最小限）
1. 実装時は「weakest link を named したら終わり」にしないこと。必ず「outcome-critical かつ UNVERIFIED/assumption-bearingなら targeted check or explicit confidence downgrade」の行動分岐まで 1 セットで置換すること。
2. "one targeted search/trace" の文言は残してよいが、特定の証拠型に読めないよう、search / trace のどちらでもよいことを保つこと。新しい証拠種類の固定ルールにしないこと。
3. 置換対象は proposal の payment 通り、既存の一般 self-check 1 項目に限定すること。周辺の MUST を追加して mandatory 総量を増やさないこと。

承認: YES
