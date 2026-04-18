# Iteration 19 — Proposal Discussion

## 検索
- 検索なし（理由: 提案の依拠概念は「情報利得」「競合仮説を最も判別する取得」「ピボット主張の優先反証」であり、既存研究の固有用語や強い外部主張に依存せず、README.md / docs/design.md / SKILL.md の一般原則だけで自己完結して評価できる）

## 総評
提案の主眼は、compare を含む共通基盤で「次に何を読むか」の優先順位を、後付けの正当化から、競合仮説を最も分ける取得へ寄せることにある。これは結論を直接指示する変更ではなく、探索の順序づけを改善する提案なので、Objective.md の Exploration Framework では B「情報の取得方法を改善する」に最も整合的です。D（自己チェック強化）寄りに見える要素もあるが、主作用点は結論直前ではなく探索中の次アクション選択なので、主カテゴリは B で妥当です。

## 既存研究・設計との整合性
- README.md / docs/design.md のコアは「premises → 仮説駆動探索 → interprocedural tracing → refutation → formal conclusion」という証拠先行の半形式的推論です。
- 本提案はその構造を壊さず、Step 3 の探索優先順位と Step 5 の反証対象の選好だけを微調整するものです。
- したがって研究コアの踏襲という点では概ね整合的です。新しいモード、言語依存規則、実行依存手順は導入していません。

## Exploration Framework のカテゴリ選定
- 判定: 適切
- 理由:
  - 「何を探すか」を固定せず、「どう次を選ぶか」を変える提案であり、B の定義に一致する。
  - 読み始めの固定順序を導入していないため、A（順序・構造の固定化）ではない。
  - 新しい必須自己監査欄や確信度軸を増やす提案ではないため、D が主カテゴリでもない。

## compare 影響の実効性チェック
1. Decision-point delta
- IF/THEN 形式で 2 行（Before/After）になっているか: YES
- Trigger line（発火する文言の自己引用）が差分プレビューに含まれているか: YES
  - Step 3 の自己引用: `NEXT ACTION RATIONALE: [why this next action is the most discriminative check among current competing hypotheses]`
  - Step 5 の自己引用: `Prioritize refuting 1–2 pivot claims...`
- 実効差分の評価:
  - Step 3 は「justified ならよい」から「競合仮説を最も判別するものを優先」へ分岐条件が変わっており、理由の言い換えだけではなく、次に読む対象の選択規則を変えている。
  - ただし Step 5 の `pivot claims` は、実装時に「高インパクト主張を優先して疑う」以上の意味に膨らむと、反証経路を狭める危険がある。ここは弱い補助ヒューリスティックとして留める必要がある。

2. Failure-mode target
- 目標: 両方（偽 EQUIV / 偽 NOT_EQUIV）
- メカニズム:
  - 偽 EQUIV 低減: 似て見える2案に対して、結論を反転させうる差分に最短で当たりにいくことで、見逃し型の差分未発見を減らす。
  - 偽 NOT_EQUIV 低減: 表面的な差分や説明しやすい差分ではなく、実際にテスト結果を分けるかどうかを最も判別できる取得を優先することで、無害差分の過大評価を減らす。

3. Non-goal
- 変えないこと:
  - 探索経路の半固定はしない（常に特定ファイル/特定起点から読む、を導入しない）
  - 必須ゲートは増やさない（Step 3/5 の既存欄の置換・軽微補足に留める）
  - 証拠種類の事前固定はしない（テスト、設定、呼出し、データ等のどれを読むかは都度の競合仮説次第）
- 支払い（必須ゲート総量不変）: 必須。だが本提案は原則として既存文言の置換・既存 mandatory 節内の軽い優先づけで成立するので、新規 mandatory 欄の純増は不要。実装時は「追加」ではなく「置換」を明示すべき。

## Discriminative probe
- 抽象ケース: 2 つの変更が同じ関数を直しているが、一方だけ例外ハンドリング経由で既存テストのアサーション結果を変えうる。もう一方の見た目の差分は大きいが、実際のテスト経路には乗らない。
- 変更前は、説明しやすい差分や先に見つけた差分を追って NOT_EQUIVALENT に寄りやすい。変更後は、「どの取得が競合仮説を最も分けるか」を基準に、アサーションを反転させうる経路の確認を優先できるため、無害差分への過反応を避けやすい。
- これは新しいゲート追加ではなく、既存の NEXT ACTION RATIONALE の置換で説明できる。

## EQUIVALENT / NOT_EQUIVALENT の両方向への作用
- EQUIVALENT 側:
  - 改善余地あり。反例になりうる高インパクトの分岐やピボット主張を先に潰すことで、「差分はあるがテスト上は同じ」をより強く裏づけやすい。
  - ただし `pivot claims` の解釈が強すぎると、少数の主張だけ見て「主要分岐は同じだから EQUIV」と早収束する危険がある。したがって「before lower-impact checks」は優先順位であって打ち切り条件ではない、と明記した方が安全。
- NOT_EQUIVALENT 側:
  - 改善余地あり。結論反転に効く箇所を優先して見に行くため、実際にテスト結果を変える差分へ早く到達しやすい。
  - 特に structural triage で即断できないケースで、意味の薄い差分ではなく実効差分へ近づく補助になる。
- 片方向最適化か:
  - 主作用は片方向ではない。Step 3 の「判別的な次アクション」は両方向に効く。
  - ただし Step 5 の `1–2 pivot claims` だけは、運用次第で反証対象を細らせる方向に寄るので、compare での逆方向回帰を避けるため弱く書くべき。

## failed-approaches.md との照合
- 探索経路の半固定: NO
  - 理由: 提案文は固定開始点を導入していない。
- 必須ゲート増: NO
  - 理由: 既存 Step 3 / Step 5 の文言置換と既存 mandatory 節内の補足であり、新しい独立ゲートを追加する提案ではない。
- 証拠種類の事前固定: NO（ただし注意あり）
  - 理由: テスト/設定/型/例外など特定の証拠タイプを列挙して固定していない。
  - 注意: `Prioritize refuting 1–2 pivot claims` が強い運用になると、証拠タイプではなく「反証対象の種類」を事実上狭める恐れはある。

本質的な再演か:
- 部分的懸念はあるが、本質的な再演までは言えません。
- 特に failed-approaches.md が警戒するのは「どこから読み始めるかの半固定」「証拠種類のテンプレ固定」「新しい必須メタ判断の純増」であり、本提案の中心である Step 3 の置換はそこを回避しています。
- 一方で Step 5 の pivot-claim 優先は、failed-approaches.md の「反証や監査の優先順位を特定局所観点へ寄せすぎない」にやや近いので、ここだけは表現を弱めるのが望ましいです。

## 汎化性チェック
- 固有識別子違反: 見当たりません。
  - 具体的な数値 ID、ベンチマークケース ID、リポジトリ名、テスト名、実コード断片は含まれていません。
  - SKILL.md 自身の文言引用は Objective.md の減点対象外に該当します。
- 暗黙のドメイン前提:
  - 強い言語依存・フレームワーク依存はありません。
  - 「競合仮説」「判別的取得」は compare / diagnose / explain / audit-improve のいずれにも適用可能な一般原則です。

## 停滞診断
- 懸念点（1 点だけ）:
  - Step 3 の変更は良いが、Step 5 の `pivot claims` 追記は、compare の意思決定点を増やすというより「監査で説明しやすい反証記録」を濃くする方向に見えやすい。ここが強すぎると、監査 rubric には刺さるが compare の実際の分岐改善は薄くなる懸念がある。
- failed-approaches 該当性:
  - 探索経路の半固定: NO
  - 必須ゲート増: NO
  - 証拠種類の事前固定: NO

## 期待される全体的な推論品質の向上
- 探索の「説明可能性」ではなく「判別可能性」を優先するため、局所的にもっともらしいが結論に効かない取得を減らしやすい。
- compare だけでなく diagnose / explain / audit-improve でも、次に読む対象の選択が改善される余地がある。
- 変更量が小さく、研究コアを崩さず、既存テンプレの使い方を少し鋭くするタイプの改善としては筋が良いです。

## 修正指示（2–3 点）
1. Step 5 の `Prioritize refuting 1–2 pivot claims` は、そのままだと反証経路の細りを招きうるため、追加ではなく弱い補助文へ統合してください。
   - 例: `When several candidate claims exist, start with claims whose failure would most change the conclusion; do not treat this as permission to skip other plausible refutations.`
   - これなら「優先」は残しつつ、探索の自由度を削りにくいです。
2. 「支払い」を明確にしてください。
   - Step 3 は既存の `NEXT ACTION RATIONALE` の置換であること、Step 5 も既存 Scope 行への統合であり、新規 mandatory requirement の純増ではないことを proposal 上で明記してください。
3. compare への実効差をさらに明確にするため、Step 3 の Trigger line には `most likely to change the final conclusion among current uncertainties` の趣旨を残し、単なる「説明の質向上」に見えないようにしてください。

## 結論
- この proposal の中核（Step 3 の discriminative-next-action 化）は compare の意思決定を実際に変えうる良い改善です。
- ただし Step 5 の pivot-claim 優先が強いままだと、failed-approaches.md の「反証優先順位の局所固定」に接近し、両方向改善より監査向け説明強化に寄るおそれがあります。

承認: NO（理由: 最大のブロッカーは、Step 5 の `pivot claims` 優先が強い表現のままだと、failed-approaches.md の禁止原則に近づき、compare での両方向改善より反証経路の細りを招くリスクがあるため）
