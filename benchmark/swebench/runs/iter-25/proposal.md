1) 過去提案との差異: 反証優先順位や構造差→早期NOT_EQUIV条件の“狭め”ではなく、Step 3 の「次に何を読むか」を“識別力”で選ぶ書き方にだけ手を入れる。
2) Target: 両方（偽 EQUIV / 偽 NOT_EQUIV を同時に下げる）
3) Mechanism (抽象): 探索ログ内の NEXT ACTION RATIONALE を「関連そう」から「どの未解決を、どの観測で分岐させるか」へ置換し、情報取得の優先順位づけを識別的にする。
4) Non-goal: STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件の限定・厳格化や、反証（Step 5）の優先順位ルール強化は行わない。

ステップ1（禁止方向の列挙）
- 証拠種類をテンプレで事前固定しすぎる（failed-approaches.md:「証拠種類の事前固定を避ける」）。
- 判定基準や構造差の意味を特定の観測境界に還元して狭める／早期 NOT_EQUIV の条件を特定の境界に寄せる（failed-approaches.md:「観測境界への過度な還元を避ける」＋ユーザ提示の却下履歴）。
- 「どこから読み始めるか」「どの境界を先に確定するか」を半固定化する（failed-approaches.md:「読解順序の半固定は探索経路を細らせる」）。
- Step 5 の pivot claims / highest-tier-first を強い表現で優先化し、反証経路を細らせる（iter-19/20 系の却下理由）。
- compare の根拠を特定の観測（例: asserted key value の data-flow）へ実質固定し、探索経路を半固定化する（iter-23 系の却下理由）。
- 必須ゲート（MUST/required）の純増（failed-approaches.md:「結論直前の必須メタ判断を増やしすぎない」）。

ステップ2（SKILL.md から未着手の改善余地を特定）
観察: Core Method の Step 3 には「NEXT ACTION RATIONALE」はあるが、優先順位づけの基準が抽象的で、
- “関連そうなファイルを読む”に流れやすい（探索ドリフト）
- 片方向（反証 or 正当化）に寄りやすい
- compare / diagnose / explain / audit-improve を跨いで、次アクションが「どの分岐を閉じるのか」が明文化されにくい
という情報取得上の弱点が残る。

該当箇所（SKILL.md 抜粋）
- Step 3 の探索ログ雛形より:
  "NEXT ACTION RATIONALE: [why the next file or step is justified]"
- Step 3 の仮説雛形より:
  "CONFIDENCE: high / medium / low"

ステップ3（強制カテゴリBでの具体メカニズム選択理由）
カテゴリBは「何を探すか」ではなく「どう探すか／優先順位付け」を改善する枠。
ここでは“証拠タイプや観測境界を固定せずに”、各時点の未解決と仮説集合に対して「次の1手がどの分岐を識別するか」を書かせることで、探索の取り方（読む順・探す順）だけを変える。

改善仮説（1つ）
探索中に「次アクションがどの仮説分岐（EQUIV/NOT_EQUIV を含む）を識別するか」を明示させると、
- 偽 EQUIV: 反例になりうる分岐（ただし特定境界に限定しない）を取り落としにくくなる
- 偽 NOT_EQUIV: “差がある”を“差が結論に効く”と取り違える前に、差が効く/効かないを識別する読みを優先しやすくなる
結果として両方向の判定精度が同時に上がる。

Decision-point delta（IF/THEN 2行）
Before: IF UNRESOLVED が複数ある THEN 「次に読む対象」を“関連そう”で選ぶ because 直感的関連（weak rationale）。
After:  IF UNRESOLVED が複数ある THEN 「次の1手で分岐させたい選択肢（仮説/結論候補）と、それを分ける観測」を先に書き、その観測が得られる対象を選ぶ because 識別力（discriminative evidence）。

変更差分プレビュー（3-10行）
Before:
  CONFIDENCE: high / medium / low
  ...
  UNRESOLVED:
    - [remaining questions]
  NEXT ACTION RATIONALE: [why the next file or step is justified]

After:
  CONFIDENCE: high / medium / low (would change if: [what observation])
  ...
  UNRESOLVED:
    - [remaining questions]
  NEXT ACTION RATIONALE: [which unresolved question this targets] ; [what observation would decide between at least two options]

failed-approaches.md との照合（整合ポイント）
- 「証拠種類の事前固定」を避ける: “観測”は仮説に依存して動的に選ばれ、テスト/型/ドキュメント等の特定カテゴリを必須化しない（固定テンプレ化しない）。
- 「探索経路の半固定」を避ける: 読む順序を事前に規定せず、各時点の UNRESOLVED と競合する選択肢に基づく局所的な優先順位づけのみを求める（固定の入口を作らない）。

変更規模の宣言
- SKILL.md の変更は 2 行の置換のみ（5行以内）。新しい必須ゲートの純増なし。