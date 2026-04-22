# Iteration 32 — 変更理由

## 前イテレーションの分析

- 前回スコア: N/A（この実装タスクでは参照情報が未提供）
- 失敗ケース: N/A（この実装タスクでは参照情報が未提供）
- 失敗原因の分析: compare では semantic difference を見つけた直後に、その差分自体を verdict-ready な証拠として扱いやすい曖昧さが残っていた。既存の文言は「no impact」側だけを弱く牽制しやすく、assertion-level trace や decisive UNVERIFIED link がないまま EQUIVALENT / NOT EQUIVALENT のどちらにも早く寄りうる点が改善対象だった。

## 改善仮説

semantic difference を provisional signal と明示し、traced assertion boundary か decisive UNVERIFIED link が出るまでは verdict に使えないと置き換えることで、差分それ自体からの premature verdict を減らし、結論を test-outcome witness に結びつけやすくなる。

## 変更内容

Compare checklist の既存 1 行を、semantic difference を provisional 扱いにする trigger line へ置換した。あわせて、差分を verdict に使ってよい条件を 1 行で明記した。これは必須ゲートの純増ではなく、既存 checklist 文の置換と近接する補足による統合であり、S1/S2 や新規モードは変更していない。

Trigger line (final): "If a semantic difference has no traced assertion boundary yet, keep it provisional: continue tracing or name the decisive link UNVERIFIED; do not conclude EQUIVALENT or NOT EQUIVALENT from the difference alone."

この Trigger line は proposal の差分プレビューにあった Trigger line と一致しており、compare 中に semantic difference を発見した直後の分岐を発火させる位置に配置した。

## 期待効果

assertion-level trace が未到達な段階で difference alone から EQUIVALENT / NOT EQUIVALENT へ流れる誤判定を減らし、追加 tracing か decisive UNVERIFIED link の明示へ分岐させやすくなる。その結果、反証可能性を維持したまま premature verdict を抑え、compare の意思決定点を小さな diff で変えられると期待する。
