# Iteration 16 — 変更理由

## 前イテレーションの分析

- 前回スコア: N/A（この作業で参照可能な入力には含まれていない）
- 失敗ケース: N/A（個別ケース情報は未参照）
- 失敗原因の分析: 意味差を見つけた後の compare の畳み方が、共有された test-facing obligation ではなく単発の traced path に寄りやすい、という仮説に基づいて改善した。1 本の witness で downstream outcome が一致すると差分を早く no-impact 吸収しやすく、逆に内部差分を obligation へ写す前に重く見てしまう揺れがある。

## 改善仮説

意味差の比較単位を「1 本の traced path」から「その差分が変えうる test-facing obligation」へ置換すると、差分を preserved / broken / unresolved に分類するまで verdict へ吸収しなくなる。その結果、偽 EQUIVALENT と偽 NOT EQUIVALENT の両方を減らせる。

## 変更内容

- Compare checklist の既存 1 行を置換し、意味差を見つけた直後に obligation 分類へ進む trigger を入れた。
- EDGE CASES RELEVANT TO EXISTING TESTS に obligation check の 3 行を追加し、survives tracing な差分を PRESERVED BY BOTH / BROKEN IN ONE CHANGE / UNRESOLVED で扱うようにした。
- これは新しい必須ゲートの単純追加ではなく、従来の「at least one relevant test を trace して no-impact 判定する」分岐を置き換える変更であり、結論前の判定手順の総量を増やさないようにした。
- Trigger line (final): "After any semantic difference is found, classify the difference by the test-facing obligation it could change: preserved by both / broken in one change / unresolved."
- この Trigger line は proposal の差分プレビューにあった planned trigger と一致しており、分岐を発火させる場所も checklist と EDGE CASES 冒頭に実際に反映されている。
- Before/After の差は理由の言い換えではなく、条件と行動の両方を変えている。以前は 1 本の traced path で no-impact 吸収できたが、変更後は obligation が分類されるまで explicit comparison item のまま残る。

## 期待効果

- 代表経路では同じ outcome を示すが、別入力や upstream obligation では差が残るケースで、差分を早く吸収しすぎる誤判定を減らせる。
- 内部実装差があっても共有 obligation が両側で preserved と示せる場合は、安全に吸収できるため、差分の過大評価も減らせる。
- 変更は compare の意思決定点に限定され、既存の per-test tracing・edge case・counterexample の骨格を維持したまま比較粒度だけを変えるため、汎用性と回帰リスクのバランスがよい。