# Iteration 4 — 変更理由

## 前イテレーションの分析

- 前回スコア: 未参照
- 失敗ケース: 未参照
- 失敗原因の分析: pass-to-pass test の call-path relevance が未検証でも分析対象から黙って外れやすく、その結果として早計な EQUIVALENT / NOT EQUIVALENT に寄りうる。また、compare テンプレート内の「全セクション完遂」と structural triage による早期結論許可が併存し、保留ではなく省略範囲の解釈でぶれを生みうる。

## 改善仮説

pass-to-pass test の relevance 未確定時の既定分岐を明示し、「除外して結論」ではなく「trace して除外 / できなければ UNVERIFIED」に寄せると、未確認のまま silent exclusion する誤りを減らせる。同時に、全セクション完遂の強い文言を structural triage と両立する形へ圧縮すれば、必須ゲート総量を増やさずに判断の安定性を上げられる。

## 変更内容

- compare テンプレートの pass-to-pass tests 定義に、call-path relevance 未解決時は provisional relevant として保持し、trace で除外できない場合は scope を UNVERIFIED にする trigger line を 1 行追加した。
- compare テンプレート冒頭の「全セクション完遂」指示を、「適用可能なセクションを完了し、STRUCTURAL TRIAGE が結論を確立した場合のみ不要な節を省略できる」という文言へ置換した。

Trigger line (final): "If call-path relevance of a pass-to-pass test is unresolved, keep it provisionally relevant until tracing excludes it, or mark the scope UNVERIFIED instead of omitting it."

この Trigger line は提案時の差分プレビューにある planned trigger line と一致しており、未確定時の条件と行動の両方を実際の分岐点に反映している。

## 期待効果

pass-to-pass coverage が曖昧な比較で、未検証の relevance を理由なく落としてしまう誤判定を減らし、必要な追加 tracing か UNVERIFIED への保留へ分岐しやすくなる。あわせて、structural triage が十分な場面では不要な ANALYSIS 強制を避けられるため、比較判断の総量を増やさずに認知負荷と分岐のぶれを抑えられる。
