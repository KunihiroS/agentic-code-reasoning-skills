# Iteration 27 — 変更理由

## 前イテレーションの分析

- 前回スコア: 未提供
- 失敗ケース: 未提供
- 失敗原因の分析: 結論直前の重複 mandatory gate が、反証完了後でも checklist 未充足を理由に追加探索や結論保留へ戻しやすく、bounded な未検証事項を明示付き結論へ持ち込む分岐を弱めていた。

## 改善仮説

結論前の第二 mandatory gate を削り、反証完了を唯一の結論前ゲートに戻せば、偽 EQUIV や偽 NOT_EQUIV を増やさずに、結論非依存で局所化された未確実性を UNVERIFIED として明示したまま結論へ進める。これにより、追加探索の既定化を減らし、compare の停止点をより直接に変えられる。

## 変更内容

Step 5.5 を required self-check から note に置換し、checklist 全体を削除した。最終文言では、Step 5 完了後は bounded non-decisive uncertainty を explicit UNVERIFIED scope として Step 6 に持ち込み、duplicate checklist を満たすためだけの再探索を禁止するようにした。

Trigger line (final): "If Step 5 is complete, carry bounded non-decisive uncertainty into Step 6 as explicit UNVERIFIED scope instead of reopening exploration solely to satisfy a duplicate checklist."

この Trigger line は提案の差分プレビューにあった Trigger line と一致しており、意図した一般化ではなく同一の分岐条件と行動を維持している。

Observed runtime delta: 結論条件は「Step 5 完了かつ残余不確実性が結論非依存で局所化できるなら Step 6 へ進む」に変わり、保留条件は「checklist に NO があるだけで差し戻す」から外れ、追加探索条件は「重複 checklist 充足のため」ではなく「結論依存の未解決性が残る場合」に限定された。

## 期待効果

重複 gate による過度な保留や再探索が減り、反証済みの主要分岐を維持したまま、局所的で非決定的な未検証事項を明示して compare の結論まで到達しやすくなる。特に、結論を変えない未検証要素が一部残る状況で、追加探索より明示付き結論を選べるようになることを期待する。
