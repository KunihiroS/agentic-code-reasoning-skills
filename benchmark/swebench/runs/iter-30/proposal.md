過去提案との差異: 数値IDの混入や「構造差→早期 NOT_EQ」を特定の観測境界へ狭める変更ではなく、差分発見時の探索を EQUIV/NOT_EQ の両方向へ同一トリガで二股化する。
Target: 両方
Mechanism (抽象): セマンティック差分が出た瞬間に「反例成立(可観測な分岐)」と「無害化(テストオラクルが吸収)」を並行に短く試し、どちらが証拠で支持されるかで結論方向を決める。
Non-goal: STRUCTURAL TRIAGE の早期 NOT_EQ 条件を観測境界へ還元して狭めない／新しい必須ゲートを純増しない。

---

Step 1) 禁止された方向（failed-approaches.md + 却下履歴の要約）
- 提案文中に特定の数値IDや過去回の番号を埋め込む（汎化性ルール違反を誘発）。
- compare の意思決定を片方向だけ具体化し、逆方向(特に NOT_EQ 側)の判断変更が曖昧なまま探索経路を半固定化する。
- 既存の判定基準を「特定の観測境界に写像できたときだけ有効」のように還元し、構造差や反例の拾い直し自由度を削る。
- 探索で探すべき証拠“種類”をテンプレで事前固定しすぎる（確認バイアス・経路固定）。
- 結論直前のメタ判断や必須チェックを純増し、萎縮・複雑化を招く。

Step 2) SKILL.md から overall に直結する意思決定ポイント候補（IF/THEN で書ける分岐）
1) compare: 「セマンティック差分を見つけた後、NOT_EQ の反例探しへ進むか／EQUIV の“影響なし”へ進むか（追加探索の方向が変わる）」
2) compare: 「pass-to-pass tests を“呼び出し経路にある”として扱うか否か（探索対象テストが変わる）」
3) Core Step 4/5.5: 「主要な挙動が UNVERIFIED のまま残るとき、結論を出す/保留する/確信度を下げる のどれに倒すか（アウトカム表示が変わる）」

Step 3) 選ぶ分岐（1つ）
採用: (1) セマンティック差分検出後の分岐
選定理由（2点以内）:
- compare の誤りは「差分＝即 NOT_EQ」または「差分を“影響なし”と即 EQUIV」で起きやすく、ここで次アクションが変われば結論が反転しうる。
- 現行文面は“影響なし”側の検証(=EQUIV の保護)に寄りがちで、NOT_EQ のための“可観測な反例”構築へ分岐させるトリガが弱い。

Step 4) 改善仮説（1つ、抽象・汎用）
セマンティック差分が見えた時点で探索を「反例(観測可能な分岐)」と「無害化(オラクル吸収)」の二股に短く分割すると、確認バイアスを抑えつつ EQUIV/NOT_EQ のどちらにも必要な決定的証拠へ最短で到達しやすくなる。

Step 5) 抽象ケースでの Before/After 挙動差（分岐として効くことの説明）
抽象ケース: 2つの変更が“内部表現/中間値”だけ異なり得るが、テストは正規化(丸め・ソート・例外型のみ確認等)された観測値しか見ない／逆に、テストが内部表現に由来するエラーメッセージや順序を直接 assert していて差分が露出する。
- Before: 差分発見後、「影響なし」の片方向トレースに寄りやすく、(a) 露出する assert を見落として偽 EQUIV、または (b) オラクル吸収を確認しないまま偽 NOT_EQ を起こしやすい。
- After: 同じ差分トリガから (i) 露出する assert へ繋がる反例トレース と (ii) オラクル吸収の証拠(正規化・比較方法) の両方を短く試し、結果に応じて NOT_EQ / EQUIV へ分岐できる。

---

カテゴリA（推論の順序・構造変更）としてのメカニズム選択理由
- 差分を見た“直後”に探索を二股化するのは、同一の観測から「結論へ直進」ではなく「両結論候補を並列に縮約」してから選ぶ、順序・構造の変更である。
- 証拠“種類”の事前固定ではなく、差分という汎用トリガに対して“どちらの結論も反証可能にする最短の次手”を対称に用意するだけなので、探索経路の半固定化を起こしにくい。

SKILL.md 該当箇所（短い引用）と変更
引用（Compare checklist）:
- "When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact"
これを、差分発見時の次アクションを EQUIV/NOT_EQ の両方向へ同じトリガで分岐させる文言に置換する（チェック項目の総量は増やさず、1行置換で実現）。

Decision-point delta（IF/THEN 2行）
Before: IF a semantic difference is found THEN trace a relevant test mainly to justify "no impact" and proceed toward EQUIV because impact-is-absent evidence.
After:  IF a semantic difference is found THEN run a split probe: (A) attempt a counterexample trace to a diverging assertion, (B) attempt to show the test oracle absorbs/normalizes the difference, then choose NOT_EQ vs EQUIV because discriminative test-oracle evidence.

変更差分プレビュー（Before/After, 3–10行）
Before:
- Trace each test through both changes separately before comparing
- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact
- Provide a counterexample (if different) or justify no counterexample exists (if equivalent)
After:
- Trace each test through both changes separately before comparing
- ...When a semantic difference is found, run a split probe: (i) counterexample-to-assertion, (ii) oracle-absorbs-diff; then choose NOT_EQ vs EQUIV...
- Provide a counterexample (if different) or justify no counterexample exists (if equivalent)

Discriminative probe（抽象ケース, 2–3行）
差分(内部表現/順序/メッセージ等)を見つけたら、(i) その差分が直接現れる assert/比較箇所を最短で探す、(ii) テスト側や下流で正規化・比較の“吸収”がある証拠を最短で探す。
変更前は (ii) だけに寄って偽 EQUIV、または (i) だけに寄って偽 NOT_EQ になりがちだが、変更後は同一トリガで両探索を走らせ誤判定を避けやすい。

failed-approaches.md との照合（整合 1–2点）
- 「証拠種類の事前固定を避ける」: 差分トリガに対し“反例/吸収”の二股を用意するだけで、特定の証拠型へ探索を固定しない。
- 「観測境界への過度な還元を避ける」: 構造差の早期 NOT_EQ 条件を狭めず、差分発見後の探索構造を対称化するだけ。

変更規模の宣言
- SKILL.md の Compare checklist の 1行置換（差分は 5 行以内、必須ゲート純増なし）。
