1) 過去提案との差異: 早期 NOT_EQUIV 条件や観測境界の狭窄ではなく、既存の必須「反証/自己チェック」の“狙う対象”を意思決定感度ベースに置き換える。
2) Target: 両方（偽 EQUIV と偽 NOT_EQUIV を同時に減らす）
3) Mechanism (抽象): 反証を「重要そうな点」ではなく「結論がひっくり返る最小の仮定/主張」に優先的に当てるよう、Step 5/5.5 の指示を微修正する。
4) Non-goal: STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を制限/追加したり、比較の観測境界（テスト可視性等）へ判定基準を還元する変更はしない。

---

ステップ1（禁止方向の列挙: failed-approaches.md + 却下履歴）
- 判定基準を特定の観測境界（テスト依存/VERIFIED 接続/可視オラクル等）に写像できた時だけ有効、のように狭く再定義する（構造差→NOT_EQUIV の条件狭窄を含む）。
- 反証や探索で「探す証拠の種類」をテンプレで事前固定し、探索を捜索タスク化する。
- 読み始めや境界確定を半固定して探索の自由度を削る。
- 反証が見つからない場合の記録様式や、未検証要素専用トリガ（例: UNVERIFIED だけで結論を縮める）を実質ゲートとして増やす。
- 姿勢語（丁寧に/注意深く）を IF 条件にして行動が変わらない提案。

カテゴリD（メタ認知・自己チェック）内での具体メカニズム選択理由
- SKILL.md には Step 5（必須反証）と Step 5.5（必須自己チェック）が既に存在するが、「何を反証対象として優先するか」は例示中心で、結論を左右する“最短の弱点”に反証を集中させる指示が弱い。
- ここを「観測境界でゲートを作る」のではなく、「同じ反証コストで、より判定に効く対象へ配分する」方向に変えると、EQUIV/NOT_EQUIV の片側だけが強くなる回帰を起こしにくい（両側とも“決定的根拠の取り違え”が主因になりやすいため）。

改善仮説（1つ）
- 反証の優先順位を“決定感度（その主張/仮定が誤ると最終結論が反転する度合い）”で選ぶようにすると、(a) 偽 EQUIV（見落とした差が実は結論を変える）と (b) 偽 NOT_EQUIV（重要でない差を決定打と誤認）の両方が減る。

SKILL.md の該当箇所（短い引用）と変更案
- 現状（Step 5）引用:
  "Scope: Apply counterfactual reasoning not only at the final conclusion, but at every key intermediate claim — especially: ..."
- 現状（Step 5.5）引用:
  "... explicitly UNVERIFIED with a stated assumption that does not alter the conclusion."
- 変更の要点:
  Step 5 の Scope に「複数の key claim がある場合、結論反転に最も近い claim/assumption を優先して反証対象に選ぶ」を1行足し、Step 5.5 の UNVERIFIED 項目を「反転条件を明示できないなら“結論へ影響しない”と断定せず、結論/確信度へ反映する」に置換する。

Decision-point delta（IF/THEN 2行）
Before: IF key intermediate claims are many THEN apply counterfactual checks broadly because coverage reduces blind spots.
After:  IF key intermediate claims are many THEN pick the most decision-sensitive claim/assumption first and counterfactually test it because it most directly controls EQUIV↔NOT_EQUIV reversal.

変更差分プレビュー（Before/After; 3–10行）
Before:
- Scope: Apply counterfactual reasoning not only at the final conclusion, but at every key intermediate claim — especially:
- ...
- [ ] Every function in the trace table is marked VERIFIED, or explicitly UNVERIFIED with a stated assumption that does not alter the conclusion.
After:
- Scope: Apply counterfactual reasoning not only at the final conclusion, but at every key intermediate claim.
- Prioritize the claim/assumption whose negation would flip the final answer (EQUIV↔NOT_EQUIV / PASS↔FAIL) when choosing what to refute first.
- [ ] Every function in the trace table is marked VERIFIED, or explicitly UNVERIFIED with a stated assumption; if you cannot state what would change if the assumption were false, reflect that uncertainty in the conclusion/confidence.

failed-approaches.md との照合（整合点）
- 「判定基準を特定の観測境界へ過度に還元」: 境界（テスト可視/VERIFIED 接続）を新しいゲートにせず、既存の必須 Step 5/5.5 の“対象選択”だけを一般原則で改善するため整合。
- 「結論直前の自己監査に必須メタ判断を増やしすぎない」: 新しい必須チェック項目を純増せず、既存の文言を置換して“どれを優先的に疑うか”へ重心を移すため整合。

変更規模の宣言
- SKILL.md 変更は最大 3–4 行（Step 5 の Scope に 1 行追加、Step 5.5 のチェック項目 1 行置換、必要なら周辺1行の改行調整のみ）。