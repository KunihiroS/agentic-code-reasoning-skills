# Iteration 50 — 変更理由

## 前イテレーションの分析

- 前回スコア: proposal.md に未記載
- 失敗ケース: 固有識別子を含めない制約により、個別ケース名は記載しない
- 失敗原因の分析: semantic difference を観測した後、その差分がどの入力・状態・設定で選択されるかを読む前に、広い test/caller 探索または影響判断へ進むと、到達不能な差分を過大評価したり、到達可能な差分を見落としたりする。

## 改善仮説

Semantic difference の有無だけでなく、その差分を選択する直近の branch predicate または data source を先に読むよう探索優先順位を変えると、到達条件つきの根拠で EQUIVALENT / NOT EQUIVALENT を判断できる。

## 変更内容

Compare checklist では、独立した test tracing の必須 bullet と従来の semantic difference bullet を統合し、semantic difference 発見後はまず差分を選ぶ直近条件またはデータ源を特定してから、関連 test/input をその選択条件に通す形へ置換した。Step 3 の NEXT ACTION RATIONALE 直後には、分岐を発火させる Trigger line を配置した。

Trigger line (final): "After observing a semantic difference, the next read should identify the nearest branch predicate or data source that selects the differing behavior before widening to callers/tests."

この Trigger line は proposal.md の差分プレビューにあった Trigger line と一致しており、末尾の注意ではなく semantic difference 観測後の次探索を決める位置に置かれている。

## 期待効果

EQUIVALENT 側では、実際には選択されない差分を根拠に誤って差ありと判断するリスクを下げる。NOT EQUIVALENT 側では、実際に選択される差分を confidence-only や保留に流さず、到達条件つきの反例として扱いやすくする。新しい必須ゲートを増やす代わりに既存 bullet を統合しているため、結論前の判定手順の総量は増やしていない。
