# Iteration 23 — 変更理由

## 前イテレーションの分析

- 前回スコア: 未記載
- 失敗ケース: 非記載（固有識別子制約のため）
- 失敗原因の分析: pass-to-pass relevance を direct call-path membership に寄せすぎると、編集が最終 callee 本体の外でテスト入力・fixture・config・lookup data を決める場合に relevant test から除外され、compare が偽 EQUIVALENT になりうる。

## 改善仮説

pass-to-pass relevance の判定単位を「直接 call path にあるか」から「テストに露出する入力依存を編集が決めるか」へ置き換えると、実行本体の外にある差分でも assertion outcome に届く候補を tracing 対象へ残せる。

## 変更内容

- compare の D2(b) を、pass-to-pass test が relevant になる条件として traced execution path に加えて inputs / fixtures / configuration / lookup data を決める編集も含む文言へ置換した。
- pass-to-pass test を off-path として早期除外しないための Trigger line を D2(b) 直下に追加した。
- 同じ依存差分が per-test tracing で既に扱われる場合は、edge-case 節を optional と明記して必須ゲート総量を増やさない形にした。

Trigger line (final): "When a change only affects test-exposed setup/config/data selection, do not exclude the pass-to-pass test as \"off-path\"; trace it as a relevance candidate."

This matches the proposed trigger line verbatim, so the intended branching point remains the same after the final edit.

Observed runtime delta: a pass-to-pass test is no longer excluded solely because the edited line is outside the final callee body; if the edit determines consumed setup/config/data, the decision now shifts from early exclusion toward additional tracing before the final equivalence conclusion.

## 期待効果

pass-to-pass test の relevant set が広がることで、入力依存の差がある比較では追加探索または NOT EQUIVALENT に分岐しやすくなり、除外起因の見落としを減らせる。一方で、同じ依存を per-test tracing で既に扱える場合は edge-case 節を optional 化したため、結論前の判定手順の総量は増えにくい。