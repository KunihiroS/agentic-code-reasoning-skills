# Iteration 50 — proposal discussion

## 1. 既存研究との整合性

検索なし（理由: 提案は「semantic difference を観測した後、実行経路上でそれを選ぶ条件・データ源を先に読む」という一般的な静的コード推論・仮説駆動探索の範囲で自己完結している。特定の外部概念や新規用語へ強く依拠していない）。

README.md / docs/design.md が述べるコアは、番号付き前提、仮説駆動探索、手続き間トレース、必須反証である。提案はこのコアを削らず、Step 3 の探索優先順位と Compare checklist の既存 bullet を置換する形なので、研究コアとの整合性は概ね高い。

## 2. Exploration Framework のカテゴリ選定

カテゴリ B「情報の取得方法を改善する」として妥当。

理由:
- 変更は verdict ルールそのものではなく、semantic difference 観測後に次に読む対象を「広い caller/test」から「差分を選択する直近の branch predicate / data source」へ優先付けるもの。
- 「何を探すか」を新しい証拠種類として固定するより、「既に見えた差分の到達条件をどう確認するか」を調整している。
- 新モード追加や大きな手順追加ではなく、既存 checklist 内の置換として扱っている点もカテゴリ B と合う。

軽微な注意点として、"nearest branch predicate or data source" が常に唯一の次探索に見えすぎると failed-approaches.md 原則 5 の「単一の追跡経路の既定化」に近づく。ただし proposal は「結論ゲート」ではなく「探索優先順位」として説明しており、before widening to callers/tests として後続探索を否定していないため、現状では許容範囲。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用

EQUIVALENT 側:
- 内部 semantic difference を見つけた時点で即 NOT_EQUIV に寄るのではなく、その差分が実際に選ばれる入力条件・状態・データ源を確認するため、到達不能または既存テストで選ばれない差分による偽 NOT_EQUIV を減らす効果が期待できる。
- NO COUNTEREXAMPLE EXISTS の議論も、単に「同じ assertion outcome」ではなく「観測済み差分が選択される条件を通っても同じ outcome か」に近づく。

NOT_EQUIVALENT 側:
- semantic difference を confidence-only や UNVERIFIED に流す前に、その差分を選ぶ条件を読むため、到達可能な差分を見落として偽 EQUIV にするリスクを減らす。
- 差分が実行経路上で選ばれることを確認してから relevant test/input へ接続するので、NOT_EQUIV の根拠が単なる内部差分ではなく outcome divergence へ近づく。

片方向性:
- 片方向のみの最適化ではない。差分の「存在」ではなく「選択条件」を読むため、差分の過大評価（偽 NOT_EQUIV）と過小評価（偽 EQUIV）の両方に作用する。
- ただし、実装時に "first identify" が硬い必須ゲートとして強調されすぎると、広い構造差や別経路の高情報量シグナルを拾う前に局所条件へ固定される危険がある。提案どおり checklist の置換範囲に留めることが重要。

## 4. failed-approaches.md との照合

- 原則 1（再収束の前景化）: NO。再収束を既定動作にしていない。差分を吸収する後段処理の説明を優先する提案ではない。
- 原則 2（未確定 relevance を常に保留へ）: NO。未検証なら保留、ではなく、差分を選ぶ条件・データ源を読みに行く探索優先順位の変更である。
- 原則 3（差分昇格条件の抽象ラベル化・必須言い換え）: NO。新しい分類ラベルや CLAIM 形式を追加していない。
- 原則 4（証拠十分性を confidence 調整へ吸収）: NO。むしろ semantic difference を CONFIDENCE だけに逃がさず、到達条件つき証拠へ寄せる。
- 原則 5（最初の差分から単一追跡経路を即座に既定化）: NO。ただし境界に近い。"nearest branch predicate or data source" という近傍観測を優先するが、proposal は「before widening to callers/tests」として広い探索を排除せず、特定 assertion boundary へ固定もしないため、本質的再演とは判断しない。
- 原則 6（探索理由と情報利得の圧縮）: NO。NEXT ACTION RATIONALE の近辺に 1 文を足す/置換するだけで、INFO GAIN 欄や反証可能性を潰していない。

## 5. 汎化性チェック

固有識別子:
- 具体的な数値 ID、リポジトリ名、ベンチマーク対象のファイルパス、関数名、クラス名、テスト名、実装コード断片は含まれていない。
- proposal 内の行番号的な Step 番号、カテゴリ B、SKILL.md 自己引用、"Trigger line" は手続き・文書構造の引用であり、汎化性違反ではない。

ドメイン偏り:
- "branch predicate / data source" は多くの言語・フレームワークで成立する一般概念。
- Discriminative probe の "configuration / input shape / feature flag / normalizer" は具体例だが、特定リポジトリや特定言語の実装断片ではなく抽象例なので許容できる。
- 暗黙に Web、Django、特定テストフレームワーク、特定言語を前提にしていない。

## 6. compare 影響の実効性チェック

0) 実行時アウトカム差:
- semantic difference を見つけた直後の追加探索対象が変わる。変更前は relevant test/caller へ広く飛ぶ、または観測済み差分から impact を早く判断しがちだった。変更後は、ANSWER / CONFIDENCE の前に「その差分を選ぶ branch predicate / data source を読んだか」が観測可能に残る。
- UNVERIFIED の扱いも、verdict claim を支える差分なら追加探索へ寄り、支えないなら明示したうえで結論可能になる。

1) Decision-point delta:
- IF/THEN 形式で 2 行（Before/After）になっているか？ YES。
  - Before: IF a semantic difference is observed but its selecting condition is unread THEN trace a relevant test or decide impact from the observed behavior...
  - After: IF a semantic difference is observed but its selecting condition is unread THEN first read the nearest branch predicate/data source...
- 条件も行動も同じで理由だけ言い換えか？ NO。行動が「test/caller tracing または observed behavior から判断」から「まず selection condition / data source を読む」へ変わっている。
- Trigger line が差分プレビュー内に含まれているか？ YES。proposal line 63 に予定文言が自己引用されている。

2) Failure-mode target:
- 対象は両方。
- 偽 EQUIV: 到達可能な semantic difference を、選択条件未読のまま SAME outcome / no counterexample に流す誤りを減らす。
- 偽 NOT_EQUIV: 到達不能・非選択の内部差分を、実行時 outcome 差として過大評価する誤りを減らす。
- メカニズムは「差分そのもの」ではなく「差分を選ぶ条件・データ源」を先に検証し、test/input trace を reachability-conditioned semantic difference にすること。

2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？ NO。
- 構造差から早期 NOT_EQUIV を追加する提案ではない。
- impact witness 要求の追加は対象外。ただし既存 SKILL.md には COUNTEREXAMPLE の diverging assertion と Step 5.5 の assert/check 接続が残っているため、NOT_EQUIV 根拠が単なるファイル差へ退化する変更ではない。

3) Non-goal:
- 探索経路の半固定を避ける: branch predicate / data source は「semantic difference 観測後」の優先候補であり、唯一の探索経路や結論条件ではない。
- 必須ゲート増を避ける: proposal は Payment として既存 Compare checklist の test tracing 必須 bullet を弱める/置換すると明記しており、必須総量不変を意識している。
- 証拠種類の事前固定を避ける: 特定 assertion boundary、テスト ID、リポジトリ構造、構造差の早期 NOT_EQUIV 条件を追加しないと明記している。

## 7. 停滞診断

監査 rubric に刺さる説明強化へ偏り、compare の意思決定を変えていない懸念:
- 懸念は小さい。proposal は説明だけでなく、Decision-point delta と Trigger line により「semantic difference 観測後、選択条件未読なら最初に読む対象を変える」という実行時分岐を明示している。

failed-approaches.md 該当性:
- 探索経路の半固定: NO。ただし "first identify the nearest branch predicate or data source" が強くなりすぎると YES に近づくため、実装では「before widening」で後続探索を残す表現を維持すること。
- 必須ゲート増: NO。Payment により既存必須 bullet の置換が示されている。
- 証拠種類の事前固定: NO。branch predicate / data source は semantic difference の到達条件を読む汎用対象であり、特定の assertion boundary や test oracle だけへ固定していない。

支払い（必須ゲート総量不変）:
- A/B 対応付けは明示されている。add MUST("After observing...") と demote/remove MUST("Trace each test through both changes separately before comparing") の対応が proposal line 49-50 にある。
- ただし実装では、per-test tracing の研究コアまで弱めないよう、Compare checklist の独立 bullet を置換するだけに留め、ANALYSIS OF TEST BEHAVIOR と Step 5 の per-test obligation は維持すること。

## 8. Discriminative probe

抽象ケース:
- 2 つの変更に内部の semantic difference があるが、その差分は特定の入力状態または設定由来の分岐でのみ選ばれる。
- 変更前は、差分の存在だけで偽 NOT_EQUIV に寄るか、広い relevant test 探索で分岐条件を読まず偽 EQUIV / 過度な保留に寄りやすい。
- 変更後は、既存 checklist の置換範囲で selection condition / data source を先に読むため、差分が実際に選ばれるかを確認してから test outcome を比較できる。これは新しい必須ゲートの増設ではなく、既存の test tracing 優先 bullet との置換で説明されている。

## 9. 全体の推論品質への期待効果

期待される改善:
- semantic difference を見つけた後の premature verdict を減らせる。
- 「差分がある」から「その差分が relevant input/test で選ばれる」への橋渡しが明確になる。
- EQUIV の no-counterexample 論証と NOT_EQUIV の counterexample 論証の両方で、到達条件つきの根拠が増える。
- 読む量やテンプレート総量を増やさず、既存の探索優先順位を入れ替えるため、複雑性増加は限定的。

回帰リスク:
- 主なリスクは、branch predicate / data source の確認が過度に義務化され、最初の差分近傍へ探索が固定されること。
- このリスクは、提案の Non-goal と Payment を実装時に守り、「唯一の経路」ではなく「semantic difference 観測後、選択条件が未読の場合の次読みに関する優先順位」として書けば抑えられる。

## 10. 修正指示（最小限）

1. 実装時は Compare checklist の置換に限定し、ANALYSIS OF TEST BEHAVIOR / Step 5 / Step 5.5 の per-test trace と assertion/check 接続は弱めないこと。
2. 追加文は proposal の Trigger line をほぼそのまま使い、"before widening to callers/tests" を残して、単一近傍探索への固定に見えないようにすること。
3. "Trace each test through both changes separately before comparing" を完全削除する場合は、同等の per-test obligation が template 本体に残っていることを rationale で明記すること。削除が不安なら checklist 上では optional 化ではなく、semantic-difference bullet に統合して総量不変を保つこと。

## 11. 結論

承認: YES

理由: 提案は汎化性違反を含まず、failed-approaches.md の本質的再演でもなく、EQUIVALENT / NOT_EQUIVALENT の両方向に対して実行時アウトカム差が具体的である。Decision-point delta は IF/THEN の Before/After として成立し、Trigger line と Payment も proposal 内に明示されている。実装時は per-test tracing の研究コアを削らず、semantic difference 観測後の探索優先順位の置換として最小 diff に留めること。
