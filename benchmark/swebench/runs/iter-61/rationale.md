# Iteration 61 — 変更理由

## 前イテレーションの分析

- 前回スコア: 未記載
- 失敗ケース: 固有識別子を記載しない
- 失敗原因の分析: 両側の trace が別々に説明できるだけで、テスト assertion が読む共有 value/API contract と各側の値へ比較点をそろえる前に SAME/DIFFERENT を置くリスクがあった。

## 改善仮説

Compare で per-test SAME/DIFFERENT を出す直前に、比較点を assertion-facing value/API contract へそろえることで、内部実装差の印象による偽差分判定と、高レベル説明だけによる偽同一判定の両方を減らす。

## 変更内容

Compare checklist の既存行を、次の文に置換した: `Trace each test through both changes separately; before comparing, name the assertion-facing value/API contract and each side's value at that point.`
Trigger line (final): "before comparing, name the assertion-facing value/API contract and each side's value at that point."
This matches the proposal preview's Trigger line exactly and places it at the per-test comparison decision point rather than as an end note.

## 期待効果

Before: IF each side has a separate trace to the test THEN assign SAME/DIFFERENT because both outcomes are narratively explained.
After: IF each side's trace reaches the same assertion-facing value/API contract with side-specific values THEN assign SAME/DIFFERENT; otherwise perform one more targeted trace to that observed value because comparison must occur at the value the test reads.
既存の必須 checklist 行を置換しただけなので、結論前の判定手順の総量は増やさず、compare に効く条件と行動だけを変える。
