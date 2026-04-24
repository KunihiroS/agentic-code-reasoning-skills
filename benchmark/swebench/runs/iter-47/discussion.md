# Iteration 47 — Discussion / 監査コメント

## 結論サマリ

提案の中核である「semantic difference を見つけたら、関連テスト全体を粗く通すのではなく、発散した state/value/control fact を次の consumer まで追ってから SAME/DIFFERENT に進む」という置換は、compare の実行時アウトカムを変える具体性があり、方向性としては有望です。

ただし、proposal 本文に具体的な数値 ID である `iter-46` が含まれているため、今回の汎化性チェックの明示ルールに抵触します。最大ブロッカーはこの 1 点です。

## 1. 既存研究との整合性

検索なし（理由: 一般原則の範囲で自己完結）。

根拠は、参照済みの README.md / docs/design.md 内で足りています。docs/design.md は、原論文由来の構造として Fault Localization の「Code Path Tracing → Divergence Analysis → Ranked Predictions」と、Code QA の「Function trace table with VERIFIED behavior, data flow tracking」を整理しており、proposal はこの既存説明を compare の semantic difference handling に移植するものです。

## 2. Exploration Framework のカテゴリ選定

カテゴリ F（原論文の未活用アイデアを導入する）の選定は概ね適切です。

理由:
- proposal は、localize/explain 側の Divergence Analysis / data-flow tracking を compare の semantic difference 分岐に圧縮して導入している。
- 既存の compare checklist の 1 bullet を置換する形で、研究コア（番号付き前提、仮説駆動探索、手続き間トレース、必須反証）を維持している。
- 「新しい結論ルール」ではなく「差分発見後に何を追跡するか」の推論手順変更なので、R3 の推論プロセス改善に合っている。

軽微な懸念:
- state/value/control fact という表現が、運用上は新しい抽象ラベルとして扱われるリスクがある。ただし proposal は「分類ゲートではなく、既に観測した差分を次の使用点へ運ぶための最小表現」と明記しており、意図としては failed-approaches 原則 3 の再演ではない。

## 3. EQUIVALENT / NOT_EQUIVALENT の両方向への作用

EQUIVALENT 側:
- 変更前は、semantic difference を見つけたあと「関連テストを通した」ことだけで、差分が実際には downstream で mask されるかを十分に見ず、偽 NOT_EQUIV に寄る可能性があった。
- 変更後は、次の consumer が default / guard / normalization などで差分を消費せず mask するなら、その経路では non-diverging と扱えるため、過大な NOT_EQUIV 判定を減らせる。

NOT_EQUIVALENT 側:
- 変更前は、テスト全体の pass/fail や粗い relevant path の一致に引っ張られ、途中の差分が assertion/output/error branch に入る事実を見落として偽 EQUIV に寄る可能性があった。
- 変更後は、発散 fact が assertion/output/error branch に消費される地点を counterexample candidate として扱うため、EQUIV に早く閉じる失敗を減らせる。

片方向最適化か:
- 片方向だけではありません。mask された差分は偽 NOT_EQUIV を抑え、消費された差分は偽 EQUIV を抑える、という両方向の分岐が proposal 内で説明されています。

## 4. failed-approaches.md との照合

原則 1「再収束を比較規則として前景化しすぎない」:
- NO。consumer が mask する場合を扱うため近接しますが、再収束を既定化して EQUIV へ倒す提案ではありません。mask されるか、assertion/output/error に消費されるかを確認してから判定する設計です。

原則 2「未確定 relevance や脆い仮定を常に保留側へ倒す」:
- NO。UNVERIFIED や保留を増やす提案ではなく、既に見つけた差分の次の消費点を確認して ANSWER / CONFIDENCE を変える提案です。

原則 3「差分の昇格条件を新しい抽象ラベルや必須の言い換え形式で強くゲート」:
- NO 寄り。ただし注意あり。state/value/control fact が分類ゲートとして運用されると YES に近づきます。現 proposal は「分類すること」ではなく「観測済みの発散事実を次の使用点へ運ぶこと」を要求しているため、本質的再演とは判断しません。

原則 4「証拠十分性チェックを confidence 調整へ吸収しすぎない」:
- NO。confidence に吸収せず、consumer 確認という追加の実証行動に変えています。

原則 5「最初に見えた差分から単一の追跡経路を即座に既定化しすぎない」:
- NO 寄り。ただし注意あり。「next consumer」が単一近傍アンカーとして硬直化すると危険ですが、既存 bullet の「at least one relevant test through the differing path」よりも、差分 fact の実使用点に追跡単位を変える置換なので、単一共有テストへの固定とは異なります。

## 5. 汎化性チェック

問題あり。

proposal には具体的な数値 ID として `iter-46` が含まれています。これは、今回の監査指示にある「提案文中に具体的な数値 ID が含まれていないか。含まれていれば実装者のルール違反」という条件に抵触します。

該当箇所:
- proposal line 27: `既存 iter-46 の有効変更と重複しやすい。`

一方で、以下は問題なしと見ます:
- リポジトリ名、具体的テスト名、ベンチマークケース ID、実装コード断片は見当たりません。
- Before/After の SKILL.md 自己引用は、Objective.md の R1 減点対象外に明示されている「SKILL.md 自身の文言引用」に該当するため問題ありません。
- `Change A and B` の discriminative probe は抽象ケースであり、特定ドメイン・言語・テストパターンへの依存ではありません。

暗黙のドメイン偏り:
- data/control consumer、assertion/output/error branch は多言語に適用できる一般概念であり、特定言語・特定フレームワーク前提ではありません。

## 6. compare 影響の実効性チェック

0) 実行時アウトカム差:
- semantic difference 発見後、追加探索の単位が「関連テスト全体」から「発散した fact の next consumer」に変わる。
- consumer が差分を mask する場合は NOT_EQUIV に進みにくくなり、assertion/output/error branch に入る場合は EQUIV に進みにくくなる。
- ANSWER、CONFIDENCE、counterexample candidate の出し方が観測可能に変わる。

1) Decision-point delta:
- IF/THEN 形式で 2 行（Before/After）になっているか？ YES。
- Before: IF a semantic difference is found THEN trace at least one relevant test through the differing path before concluding no impact.
- After: IF a semantic difference is found THEN name the divergent state/value/control fact and trace it to its next consumer before deciding SAME/DIFFERENT.
- 条件は同じだが、行動が「関連テストを通す」から「発散 fact の consumer を確認する」に変わっており、理由の言い換えだけではありません。
- Trigger line が差分プレビュー内に含まれているか？ YES。`Trigger line (planned): "When a semantic difference is found, name the divergent state/value/control fact and trace it to its next consumer before deciding SAME/DIFFERENT."` が含まれています。

2) Failure-mode target:
- 対象は両方。
- 偽 EQUIV: 発散 fact が実際には assertion/output/error branch に消費されるのに、粗い pass/fail や relevant path の一致で同等扱いする失敗を減らす。
- 偽 NOT_EQUIV: 中間差分が downstream で mask されるのに、局所差分だけで非同等扱いする失敗を減らす。

2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？
- NO。proposal は STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件そのものを変更していません。semantic difference 発見後の checklist bullet を置換する提案です。
- したがって impact witness 要件は直接の承認条件にはしません。
- ただし、After の 2 bullet 目にある `assertion/output/error branch` は、NOT_EQUIV の根拠を単なるファイル差ではなく実際の消費先に結びつける方向なので、構造差だけでの早期 NOT_EQUIV 退化は起きにくいです。

3) Non-goal:
- 探索経路を単一の共有テストへ半固定しない。
- state/value/control を分類ラベルのゲートにしない。
- assertion boundary / oracle visibility / test-dependency などの証拠種類を事前固定しない。
- 新規必須ゲートを純増せず、既存 checklist bullet の置換として扱う。

## 7. 停滞診断

監査 rubric に刺さる説明強化へ偏り、compare の意思決定を変えていない懸念:
- 低いです。Decision-point delta と Trigger line があり、実行時には「追加探索の対象」と「SAME/DIFFERENT へ進む条件」が変わります。単なる rationale 強化ではありません。

failed-approaches 該当 YES/NO:
- 探索経路の半固定: NO。ただし `next consumer` が常に単一近傍だけを見れば足りる、という運用になると YES に近づくため、実装時は「消費点が verdict に関係するか」を見る表現に留めるべきです。
- 必須ゲート増: NO。proposal は Payment として既存 MUST bullet の置換を明示しています。
- 証拠種類の事前固定: NO。assertion/output/error branch は例示的な counterexample candidate であり、証拠種類をこれだけに固定する書きぶりではありません。

## 8. Discriminative probe

抽象ケース:
- 2 つの変更が同じ relevant test に到達し、中間値だけが異なる。後段がその値を default で潰す場合と、出力・例外・assertion に渡す場合がある。
- 変更前は「関連テストを通した」という粗い記録で、前者を偽 NOT_EQUIV、後者を偽 EQUIV にしやすい。
- 変更後は、同じ必須 bullet の置換により next consumer を見るため、mask なら NOT_EQUIV を避け、消費されるなら EQUIV を避けられる。新規必須ゲートの純増ではありません。

## 9. 支払い（必須ゲート総量不変）の確認

A/B 対応付けは明示されています。

- A: 追加する MUST: `When a semantic difference is found, name the divergent state/value/control fact and trace it to its next consumer before deciding SAME/DIFFERENT`
- B: demote/remove する MUST: `When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact`

したがって、必須ゲート総量不変の説明は足りています。

## 10. 推論品質の期待改善

期待できる改善:
- semantic difference を見つけた後の追跡粒度が、テスト単位の粗い pass/fail から、実際に分岐・出力・例外・assertion へ入る発散 fact へ細かくなる。
- 局所差分を過大評価する失敗と、途中差分を過小評価する失敗の両方に効く。
- docs/design.md の data flow tracking / divergence analysis と整合し、SKILL.md の「subtle difference dismissal」「incomplete chains」対策を compare 内でより実行可能にする。

## 修正指示（最大ブロッカーに絞る）

1. proposal から `iter-46` という具体的な数値 ID を削除し、「既存の有効変更」または「直近の有効変更」のような非固有表現へ置換してください。

2. 同じ修正内で、`state/value/control fact` が分類ゲートではないことを維持するため、実装差分では `state/value/control` を増やしすぎず、Trigger line の 1 文を中心にしてください。追加説明を入れる場合は既存 bullet の置換範囲内に収めてください。

3. Payment は現状の A/B 対応で十分なので、新しい必須 self-check や別セクション追加にはしないでください。

## 承認

承認: NO（理由: 汎化性チェックの明示ルールに反し、proposal 本文に具体的な数値 ID `iter-46` が含まれているため）
