# Iteration 41 — 変更理由

## 前イテレーションの分析

- 前回スコア: 未参照（本タスクでは許可された参照範囲外）
- 失敗ケース: 未参照（本タスクでは許可された参照範囲外）
- 失敗原因の分析: compare で意味差を見つけた直後の次アクション指示が局所化されておらず、関連テストの追跡が終盤の checklist まで遅れやすい、という仮説を採用した。

## 改善仮説

意味差を観測した瞬間に relevant test trace へ入る局所トリガを ANALYSIS OF TEST BEHAVIOR 直下へ移すと、広いテンプレ実行を続けて探索が散る前に、結論に効く分岐を先に検証できる。あわせて重複した必須表現を削り、結論前の判定手順の総量を増やさずに compare の意思決定点だけを変える。

## 変更内容

- ANALYSIS OF TEST BEHAVIOR の直下に、意味差を見たが test-outcome difference はまだ示されていない時点で、relevant test を1本ただちにその分岐へ通す Trigger line を追加した。
- Compare checklist に残っていた同趣旨の文を削除し、分岐を発火させる場所を checklist 末尾ではなく compare 本文の分析位置へ移した。
- Step 5 の重複文「This step is **mandatory**, not optional.」を削除し、必須ゲートの総量増加を避けた。
- Trigger line (final): "When a semantic difference is observed before a test-outcome difference is shown, immediately trace one relevant test through that differing branch before any verdict."
- この Trigger line は proposal の差分プレビューにある planned trigger と一致しており、意図した一般化の範囲でも同等である。

## 期待効果

意味差の発見後に test trace を後回しにして早合点する流れを減らし、同じ挙動か異なる挙動かを具体的な関連テスト経由で早く確定しやすくする。特に、意味差はあるがテスト結果差は未確認という compare の迷い点で、偽の EQUIVALENT と偽の NOT EQUIVALENT の両方を抑えることを期待する。
