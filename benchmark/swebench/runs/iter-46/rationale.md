# Iteration 46 — 変更理由

## 前イテレーションの分析

- 前回スコア: 未確認
- 失敗ケース: semantic difference を観測した後も generic な no-counterexample で EQUIVALENT に閉じやすい compare ケース群
- 失敗原因の分析: EQUIV 側の `NO COUNTEREXAMPLE EXISTS` が自由形式の不在証明を許しており、観測済み差分と最終的な assertion outcome の対応づけが弱いまま結論できてしまう。

## 改善仮説

EQUIV 主張時の no-counterexample 記述を、観測済みの semantic difference に anchored な 1 つの具体テスト/入力と同一 assertion outcome の確認へ置き換えると、差分を汎用的な不在証明だけで吸収する偽 EQUIV を減らしつつ、必要なときだけ UNVERIFIED を明示できる。

## 変更内容

`NO COUNTEREXAMPLE EXISTS` 節だけを置換し、generic な counterexample search の書き方を、観測済み差分の明示 → その差分に対する concrete relevant test/input の確認 → 同一 assertion outcome の確認、という順に寄せた。新しいモードや追加ゲートは増やさず、既存の EQUIV 側テンプレート文言を差し替える範囲に留めた。

Trigger line (final): "When claiming EQUIVALENT after observing a semantic difference, anchor the no-counterexample argument to that exact difference with one concrete relevant test/input and the same traced assertion outcome on both sides; otherwise mark the impact UNVERIFIED."

この Trigger line は proposal の差分プレビューにあった planned trigger line と一致しており、Decision-point delta の分岐を `NO COUNTEREXAMPLE EXISTS` 節の先頭で実際に発火させる配置になっている。

## 期待効果

semantic difference 発見後の EQUIV 判定で、条件が「一般に反例が見つからない」から「その差分に対する具体的な equality witness を示せる」へ変わるため、偽 EQUIV が減り、必要な追加探索または impact の UNVERIFIED 明示が増えると期待する。特に compare における差分発見後の吸収ミスを抑えつつ、既存の NOT EQUIVALENT 側や structural triage 側の判断量は増やさない。