# Iteration 15 — 変更理由

## 前イテレーションの分析

- 前回スコア: N/A（このファイル作成時点では参照しない）
- 失敗ケース: N/A（このファイル作成時点では参照しない）
- 失敗原因の分析: 反証/自己チェックは存在するが、複数の中間主張がある状況で「どれを最優先で反証すべきか」が曖昧だと、結論反転に直結する弱点を外して偽 EQUIV / 偽 NOT_EQUIV の両方を起こしうる。

## 改善仮説

反証対象の優先順位を「結論の反転（EQUIV↔NOT_EQUIV / PASS↔FAIL）に最も直結する主張/仮定」へ寄せることで、同じ必須反証コストの範囲で判定感度を上げ、偽 EQUIV と偽 NOT_EQUIV を同時に減らす。

## 変更内容

- Step 5 の Scope を「広く当てる」から、複数候補があるときにまず“最も決定感度が高い主張/仮定”を優先して反証する指示へ置換/補強した。
- Step 5.5 の UNVERIFIED 項目を、影響説明ができない仮定は「結論へ影響しない」と断定せず、不確実性として結論/確信度へ反映する指示に置換した。

Trigger line (final): "- Prioritize the claim/assumption whose negation would flip the final answer (EQUIV↔NOT_EQUIV / PASS↔FAIL) when choosing what to refute first."
上の Trigger line は、proposal の差分プレビューにある Trigger line と文言・意図の両面で一致する。

## 期待効果

- 偽 EQUIV: 重要な差が結論を反転させるタイプの見落としに対し、最優先で反証を当てやすくなる。
- 偽 NOT_EQUIV: 重要でない差を決定打と誤認するリスクを下げ、結論反転に関係する根拠へ反証を集中できる。
