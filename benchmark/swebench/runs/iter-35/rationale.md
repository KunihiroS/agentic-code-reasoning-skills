# Iteration 35 — 変更理由

## 前イテレーションの分析

- 前回スコア: 不明（この作業では参照対象外）
- 失敗ケース: 不明（この作業では参照対象外）
- 失敗原因の分析: compare における詳細 tracing の開始点が変更側に寄りやすく、relevant test の verdict を実際に決める assertion/check へ到達する前に、上流の差分を過大評価して判定がぶれる余地がある。

## 改善仮説

relevant test ごとの詳細 tracing を「変更側から前向きに広く追う」よりも、「具体的な assertion/check から最寄りの changed branch へ逆向きに入る」形へ寄せると、判定に効く証拠へ短く到達しやすくなる。これにより、判定に無関係な上流差分の影響を受けにくくしつつ、EQUIVALENT / NOT EQUIVALENT のどちらにも必要な観測境界ベースの比較をしやすくする。

## 変更内容

- Core Method の順序制約を、「各 section を順番どおりに書く」から「FORMAL CONCLUSION 前に required section を完了する。ただし compare の per-test tracing では、判定に効く証拠への最短経路として assertion/check 起点を許す」へ置換した。
- Compare の per-test テンプレートに、assertion/check から最寄りの changed branch へ逆向きに辿ってから必要分だけ外側へ広げる Trigger line を追加した。
- 各 Claim の説明文を、changed code 起点ではなく assertion/check 起点の tracing を要求する文言へ置換した。
- Compare checklist の該当項目を、各 test を concrete assertion/check に anchor してから A/B へ広げる指示へ置換した。
- 追加より置換を優先し、必須ゲート総量が増えないよう、既存の厳密な section 順序強制を緩める形で相殺した。

Trigger line (final): "Start from the concrete assertion/check for this test, trace backward to the nearest changed branch, then expand only as needed to determine A/B outcome."

この Trigger line は proposal の差分プレビューにある planned trigger line と一致しており、意図した一般化ではなく同一の分岐開始文言として反映されている。

## 期待効果

- relevant test の verdict を担う枝が未確定な場面で、どこから tracing を始めるかという意思決定点が変わり、判定に効かない差分の先読みを減らせる。
- NOT EQUIVALENT 側では、実際に diverging assertion を生む枝へ早く到達しやすくなる。
- EQUIVALENT 側では、上流の表現差や補助的差分を verdict 差と誤認するリスクを下げられる。
- 変更は compare の per-test tracing 開始点に限定され、STRUCTURAL TRIAGE や必須反証など研究コアは維持されるため、回帰リスクを抑えながら比較の実効差を出しやすい。
