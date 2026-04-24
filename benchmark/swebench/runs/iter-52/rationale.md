# Iteration 52 — 変更理由

## 前イテレーションの分析

- 前回スコア: 未参照（今回の実装指示で参照許可された資料に含まれない）
- 失敗ケース: 未参照（今回の実装指示で参照許可された資料に含まれない）
- 失敗原因の分析: 提案では、結論直前に証拠十分性を広く確認するだけだと、推論チェーン内の弱い前提が ANSWER、CONFIDENCE、UNVERIFIED のどれに影響するかが暗黙になりやすい、と整理されている。

## 改善仮説

結論直前に、最弱の verdict-bearing link と出力上の扱いを明示させることで、証拠全体は揃っているが一部の支えが脆い場合に、偽の高信頼判定と不要な全面保留の両方を減らせる。

## 変更内容

- Step 5.5 の結論前チェック 1 行を、最弱リンクを名指しし、それが verdict を支えるのか、confidence を下げるのか、impact を UNVERIFIED に残すのかを選ばせる文に置換した。
- Step 6 の confidence 指定 1 行を、最弱の verdict-bearing link に紐づく confidence として表現する文に置換した。
- 新しい必須ゲートを純増させず、既存の結論前チェックと confidence 行の置換に留めた。

Trigger line (final): "Before ANSWER/CONFIDENCE, name the weakest verdict-bearing link and state whether the evidence supports the verdict, lowers confidence, or leaves impact UNVERIFIED."

この Trigger line は、提案の差分プレビューにあった Trigger line と一致しており、分岐を発火させる場所である Step 5.5 の結論前チェックに配置されている。

## 期待効果

同じ ANSWER に到達できる場合でも、最弱リンクが残るときは CONFIDENCE を下げる、impact を UNVERIFIED と明示する、または追加確認へ戻る判断がしやすくなる。これにより、EQUIVALENT/NOT EQUIVALENT の片側へ寄せるのではなく、結論形式と根拠の強さの対応が改善される。