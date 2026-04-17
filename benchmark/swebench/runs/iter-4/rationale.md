# Iteration 4 — 変更理由

## 前イテレーションの分析

- 前回スコア: N/A（この作業コンテキストでは提供されていない）
- 失敗ケース: N/A（固有識別子を含めない制約のため記載しない）
- 失敗原因の分析: compare において、構造差を見つけた時点で「それが relevant tests に必然的に影響する差か」を明確に区別しないまま、早期に NOT EQUIVALENT を宣言しうる曖昧条件が残っていた。

## 改善仮説

「早期に NOT EQUIVALENT を確定してよい条件」を、D1（テスト結果同一性）と D2（relevant tests のスコープ）に明示的に結びつけて具体化すると、スコープ外の構造差を過大評価した premature な NOT EQUIVALENT が減り、EQUIV/NOT_EQUIV の両方向の誤判定が減る。

## 変更内容

Compare の certificate template にある STRUCTURAL TRIAGE 直後の早期結論許可文（「clear structural gap」）を、D1/D2 の relevant-test scope に対して必然的に影響する structural gap に限定する表現へ置換した（手順の追加ではなく条件文の言い換えのみ）。

## 期待効果

- 変更前: 「差がある」事実だけで NOT EQUIVALENT へ短絡しやすい。
- 変更後: その差が D2 の relevant tests に触れ、D1 の結果へ必然的に影響する場合にのみショートカット結論が正当化される。

結果として、探索手順や必須ゲートの総量を増やさずに、結論へ進んでよい条件の曖昧さ由来の誤判定（特に偽 NOT_EQUIV）を抑制することを狙う。