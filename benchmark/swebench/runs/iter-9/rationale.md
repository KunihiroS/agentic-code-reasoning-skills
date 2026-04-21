# Iteration 9 — 変更理由

## 前イテレーションの分析

- 前回スコア: N/A
- 失敗ケース: N/A
- 失敗原因の分析: 比較対象の relevant path 上で差異を見つけた時点で、その差異をそのまま test-level comparison evidence に昇格しやすく、caller-visible な結果を変えない内部差まで重く扱ってしまう停滞点があった。

## 改善仮説

relevant path 上の差異を即座に比較証拠にするのではなく、まず caller-visible な branch predicate、return payload、raised exception、persisted side effect を変えるかで分類すれば、internal-only な差異の過大評価を減らしつつ、outcome-shaping な差異だけを確実に per-test comparison へ昇格できる。

## 変更内容

- compare テンプレートの「EDGE CASES RELEVANT TO EXISTING TESTS:」ブロックを、差異を outcome-shaping / internal-only に分類する「DIFFERENCE CLASSIFICATION:」ブロックへ置換した。
- compare checklist の tracing 条件を、任意の semantic difference ではなく outcome-shaping differences に限定する形へ置換した。
- Guardrail #4 も同じ条件に合わせ、semantic difference を見つけたら先に caller-visible commitment の変化有無を分類する文に置換した。
- Trigger line (final): "For each observed difference, first classify whether it changes a caller-visible branch predicate, return payload, raised exception, or persisted side effect before treating it as comparison evidence."
- この Trigger line は proposal の差分プレビューにあった planned trigger line と一致しており、差異の昇格分岐を ANALYSIS OF TEST BEHAVIOR 内で直接発火させる配置になっている。

## 期待効果

internal-only な実装差だけで偽の NOT EQUIVALENT や過度な保留へ寄るリスクを下げつつ、return・exception・side effect・branch predicate の差のような caller-visible な違いは従来どおり test-level tracing に持ち上げられるため、EQUIV と NOT_EQUIVALENT の両方で比較粒度が安定すると期待する。
