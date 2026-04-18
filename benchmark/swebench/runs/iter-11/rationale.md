# Iteration 11 — 変更理由

## 前イテレーションの分析

- 前回スコア: （未記載）
- 失敗ケース: （この文書では固有識別子を扱わないため省略）
- 失敗原因の分析: 「反証が見つからない」ことを根拠に結論へ急ぎ、結論を左右する最小の決定点（hinge）が UNVERIFIED のままでも EQUIV/NOT_EQUIV を断定しうる。

## 改善仮説

compare で結論（EQUIV/NOT_EQUIV）を出す直前に、判定を反転させうる hinge が UNVERIFIED なら結論を保留して追加探索へ分岐させることで、推測混入による偽 EQUIV と、assertion へ未接続の差分に対する過剰反応（偽 NOT_EQUIV）の両方を減らせる。

## 変更内容

- Compare checklist から冗長な 1 行（changed files の同定）を削除し、結論直前の意思決定点を 1 行で置換した。
- これにより「必須ゲートの総量」は増やさず、既存の結論項目を“UNVERIFIED hinge 検知時は保留→追加探索”へ置き換える形で意思決定だけを変えた。

Trigger line (final): "- Trigger: if the verdict hinges on any UNVERIFIED step (or a semantic diff not linked to a diverging assertion), HOLD conclusion and continue exploring until the hinge is VERIFIED."

上の Trigger line は proposal の差分プレビューにあった Trigger line と一致しており、意図した一般化として同等である。

## 期待効果

- 偽 EQUIV の抑制: 「反証が見つからない」型の根拠で断定する前に、結論 hinge が UNVERIFIED なら探索を継続するため、潜在反例の見落としを減らす。
- 偽 NOT_EQUIV の抑制: 差分が見つかっても diverging assertion に接続できない（= hinge が未成立）場合は断定を保留し、重要度の過大評価を減らす。