# Iteration 35 — 変更理由

## 前イテレーションの分析

- 前回スコア: 不明（このタスクではスコア情報を参照していない）
- 失敗ケース: 不明（このタスクではケース情報を参照していない）
- 失敗原因の分析: 「STRUCTURAL TRIAGE で構造差が見える」だけで NOT EQUIVALENT に早期直行し、D1（テスト結果同一性）への接続根拠が薄いまま結論が確定しうる、という意思決定点の偏りを抑制する必要がある。

## 改善仮説

STRUCTURAL TRIAGE からの早期 NOT EQUIVALENT 直行を“禁止”するのではなく、直行する場合に限って COUNTEREXAMPLE の最小限の具体証拠（テスト影響の目撃）を要求し、提示できない場合は ANALYSIS に戻す分岐へ置換すると、偽 NOT_EQUIVALENT（早計な結論）を減らしつつ、偽 EQUIVALENT も増やしにくい。

## 変更内容

Compare セクションの「S1/S2 で構造差が見えたら NOT EQUIVALENT に直行できる」説明を置換し、(a) 直行するなら COUNTEREXAMPLE として concrete test-impact witness（例: import/use/assert）を file:line 付きで引用する、(b) まだ引用できないなら ANALYSIS に進む、という条件分岐に変更した。

Trigger line (final): "If you cannot yet cite such a witness, continue into ANALYSIS."

上の Trigger line は proposal の planned trigger line（"concrete test-impact witness" を明示）と同等であり、直前行で定義した witness を "such a witness" が指す形に一般化しただけで分岐（提示できない場合は ANALYSIS へ戻る）は一致している。

## 期待効果

- 構造差が見えても、テスト結果（D1）に効く具体的な影響の根拠が出せない限り早期結論に直行できなくなるため、根拠の薄い NOT EQUIVALENT を抑制できる。
- 「必須ゲート」の純増を避けつつ（既存の COUNTEREXAMPLE を早期直行の枝にも適用するだけ）、影響が不明な場合は ANALYSIS に戻って根拠を分離できるため、EQUIV/NOT_EQ の両誤判定を同時に減らす方向に働く。