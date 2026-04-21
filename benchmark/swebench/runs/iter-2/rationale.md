# Iteration 2 — 変更理由

## 前イテレーションの分析

- 前回スコア: 不明（この作業では参照対象外）
- 失敗ケース: 個別識別子は未参照
- 失敗原因の分析: 内部の経路差を見つけた直後に、その差を強い判別材料として扱いやすく、比較粒度が path-level のまま固定されることで、下流で再収束する差を過大評価しうる。

## 改善仮説

意味差を見つけた直後に結論へ寄せるのではなく、次の共有された test-relevant predicate / returned value / asserted state まで差が残るかで分類すれば、途中の実装差を provisional に扱え、早すぎる差分結論と見落としの両方を減らせる。

## 変更内容

- compare チェックリストの該当 bullet を、"差がある経路を 1 本なぞる" 指示から、次の共有された test-relevant predicate / returned value / asserted state まで divergence が残るかを比較する指示へ置換した。
- 同じ判断規則を Guardrail 4 にも反映し、比較の意思決定点を reconvergence の有無へ揃えた。
- Trigger line (final): "If two traces diverge internally but re-enter the same test-relevant predicate/value state, treat the earlier difference as non-discriminative and compare from that reconvergence point."
- この Trigger line は proposal の差分プレビューにある planned trigger line と一致しており、分岐を発火させる比較手順の位置にも実際に入っている。

## 期待効果

途中経路の差をそのまま NOT EQUIVALENT 側の証拠として固定せず、共有された判定点での再収束を確認してから差分性を判断できるため、比較粒度が test-relevant な観測点に寄り、EQUIVALENT/NOT EQUIVALENT の両側で過早な結論を減らすことが期待される。
