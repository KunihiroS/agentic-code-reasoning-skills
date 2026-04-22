# Iteration 28 — 変更理由

## 前イテレーションの分析

- 前回スコア: 未提供
- 失敗ケース: 未提供
- 失敗原因の分析: compare において structural gap を見つけた時点で即座に NOT EQUIVALENT へ短絡できる分岐があり、観測されるべき traced test divergence より先に結論へ進みうることが不安定要因だと分析した。

## 改善仮説

構造差は有力な手掛かりとして維持しつつ、その役割を verdict shortcut から first-trace selector に置き換える。これにより、構造差がある場合でも最初の relevant test trace を通して explicit な PASS/FAIL split を確認するまでは NOT EQUIVALENT を確定しない、という比較上の意思決定点を変えられる。

## 変更内容

- Compare セクションの structural triage 見出しを、S1/S2 を broad analysis 前の最初の discriminative trace 選択に使う文言へ置換した。
- S2 の説明から、構造差のみで即時に NOT EQUIVALENT とする分岐を外し、最初の relevant test trace を選ぶための条件へ統合した。
- 直接結論へ進める文を削除し、以下の trigger line と判定条件へ置換した。
- Trigger line (final): "When S1/S2 finds a structural gap, trace the most relevant test through that gap before any NOT EQUIVALENT conclusion."
- 上の Trigger line は proposal の差分プレビューにある planned trigger line と一致し、構造差を結論短絡ではなく分岐発火用の trace-first 指示として一般化なしに反映している。

## 期待効果

構造差だけで偽の NOT EQUIVALENT に倒れるリスクを減らしつつ、真に差がある場合は最初の traced test で diverging assertion を示せるため、compare の結論がより観測境界に接続された形で安定することを期待する。EQUIVALENT 側では shortcut による早計な否定を避け、NOT EQUIVALENT 側では assertion-level divergence を伴うより具体的な根拠を早く確立できる。