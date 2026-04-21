# Iteration 12 — 変更理由

## 前イテレーションの分析

- 前回スコア: 未提供
- 失敗ケース: 未提供
- 失敗原因の分析: compare で差分を見つけた後の説明が「差分あり/なし」や単一路径の追跡で止まると、最初の分岐点と最終 assertion までの伝播・吸収の区別を誤り、偽の EQUIVALENT / NOT EQUIVALENT の両方を生みうる。

## 改善仮説

compare における差分発見後の既定動作を、単なる differing path の追跡から、最初の behavioral fork を局在化し、その差が concrete assertion まで残るか途中で neutralize されるかを示す形へ置換すると、症状と根本原因の取り違えを減らしつつ、結論前の意思決定をより識別的にできる。

## 変更内容

- Guardrail #3 の文言を、compare では first visible mismatch ではなく first behavioral fork を説明対象にするよう更新した。
- Compare checklist の既存項目を置換し、semantic difference 発見時は relevant path を1本なぞる代わりに、first behavioral fork が concrete assertion へ propagates するか neutralized されるかを示すようにした。
- 追加ではなく置換で実施し、結論前の必須判定手順の総量を増やさないようにした。
- Trigger line (final): "When a semantic difference is found, localize the first behavioral fork and show whether it propagates to the concrete assertion or is neutralized before it"
- この Trigger line は proposal の差分プレビューにある planned trigger line と実質的に同一であり、意図した一般化の範囲内で一致している。

## 期待効果

差分が下流で吸収されるケースでは偽の NOT EQUIVALENT を減らし、途中差分が最終 assertion まで生き残るケースでは偽の EQUIVALENT を減らすことが期待される。あわせて、compare の説明対象を「最初の見える差」から「assertion outcome を分ける最初の分岐点」へ移すことで、より汎用的で反証可能な推論プロセスになる。