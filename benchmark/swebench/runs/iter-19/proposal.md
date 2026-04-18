1) 過去提案との差異: 構造差→早期 NOT_EQUIV の「観測境界への還元/制限」には触れず、探索中の“次に何を読むか”という情報取得の優先順位付けだけを可変・判別的にする。
2) Target: 両方（偽 EQUIV と 偽 NOT_EQUIV の同時低減）
3) Mechanism (抽象): 次アクション選択を「正当化」から「競合仮説を最も判別できる取得」へ寄せ、反証の対象も“結論を反転させるピボット主張”から優先する。
4) Non-goal: 早期 NOT_EQUIV の新条件追加、証拠種類のテンプレ事前固定、探索経路の半固定（開始点固定など）は行わない。

Step 1（禁止方向の列挙: failed-approaches + 却下履歴より）
- 構造差/早期 NOT_EQUIV の条件を「特定の観測境界（テスト依存/オラクル可視/VERIFIED接続など）に狭める」方向は反復却下済みで禁止。
- 探すべき証拠の“種類”をテンプレで事前固定しすぎる変更は禁止（確認バイアス・探索固定化）。
- 「どこから読み始めるか」を半固定する変更は禁止（探索経路が細り、別粒度の手掛かりを拾いにくい）。
- ガードレールを特定方向に具体化しすぎる置換は禁止（方向非依存を維持）。
- 結論前の必須メタ判断ゲートの純増は禁止。

Step 2（SKILL.md から未着手の改善余地: 今回は共通基盤の decision point を狙う）
- Step 3 の探索ジャーナルは「NEXT ACTION RATIONALE」が抽象で、次に読む対象の選び方が“説明責任”に寄りやすい（= 取得の判別力でなく、後付け正当化に流れやすい）。
- Step 5 は必須だが、反証の“対象の選び方”（どの中間主張をまず疑うか）の選好が明文化されていない。
  -> どちらも compare 以外（diagnose/explain/audit-improve）にも波及する共通基盤の改善余地。

Step 3（採用する改善仮説: 1つだけ）
- 仮説: 次アクションを「最も情報利得（= 競合仮説の判別/結論反転の可能性）を上げる取得」に寄せると、(a) 片方だけに都合のよい探索ドリフトを減らし、(b) 重要な分岐を早期に確定でき、偽 EQUIV / 偽 NOT_EQUIV の双方を同時に下げる。

カテゴリB内での具体メカニズム選択理由
- Objective.md のカテゴリBは「何を探すかではなく、どう探すか／探索の優先順位付け」を改善すること（Exploration Framework: B）。
- 本提案は“証拠の種類”や“読む開始点”を固定せず、毎回の UNRESOLVED と競合仮説に対して「どの取得が最も判別的か」を基準に優先順位を決めるため、探索自由度を削らずに取得品質だけを上げる。

SKILL.md 該当箇所（短い引用）と変更方針
- Step 3 テンプレ末尾: 「NEXT ACTION RATIONALE: [why the next file or step is justified]」
  -> ここを“判別的な次アクション”の指針に差し替え（次に読む対象の選び方を具体化）。
- Step 5 Scope（反証の対象選び）
  -> 反証を当てる優先対象を「結論を反転させうるピボット主張」から選ぶ、と1行だけ添える（やり方ではなく対象選好）。

Decision-point delta（IF/THEN 2行）
Before: IF UNRESOLVED が残る THEN 次の file/step を選ぶ because “justified”（説明可能であること）
After:  IF UNRESOLVED が残る THEN 競合仮説を最も判別できる file/step を選ぶ because “discriminative evidence”（結論反転の可能性を最大化する）

変更差分プレビュー（Before/After）
Before (Step 3):
  NEXT ACTION RATIONALE: [why the next file or step is justified]
After (Step 3):
  NEXT ACTION RATIONALE: [why this next action is the most discriminative check among current competing hypotheses]
  (Prefer actions that could flip a pivot claim or materially change the final conclusion.)

Before (Step 5 Scope):
  Scope: Apply counterfactual reasoning not only at the final conclusion, but at every key intermediate claim — especially:
After (Step 5 Scope):
  Scope: Apply counterfactual reasoning ... especially:
  - Prioritize refuting 1–2 pivot claims (claims that would flip the conclusion if wrong) before lower-impact checks.

failed-approaches.md との照合（整合点 1-2）
- 「証拠種類の事前固定を避ける」: 本提案は“証拠タイプの固定”ではなく、都度の競合仮説に対して最も判別的な取得を選ぶ基準を与えるだけで、探索の自由度を維持する。
- 「読解順序の半固定を避ける」: “常にテストから/常にXから”の固定開始点は導入せず、UNRESOLVED と仮説競合に依存して次の取得が変わる（経路の固定化ではない）。

変更規模の宣言
- SKILL.md の変更は合計 5 行以内（置換 + 追記の最小差分）。
