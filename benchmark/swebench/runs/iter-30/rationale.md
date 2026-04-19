# Iteration 30 — 変更理由

## 前イテレーションの分析

- 前回スコア: (未提供)
- 失敗ケース: (未提供)
- 失敗原因の分析: セマンティック差分が見つかった後の探索が片方向に寄ると、EQUIV/NOT_EQ のどちらの結論にも必要な決定的証拠（反例の露出 or オラクル吸収）が不足し、誤判定が起きやすい。

## 改善仮説

セマンティック差分を検出した瞬間に、同一トリガから (A) 反例（観測可能な分岐・assertion への到達）と (B) 無害化（テストオラクルが差分を吸収/正規化）の両方向を短く試すことで、確認バイアスを抑えつつ EQUIV/NOT_EQ の分岐をより証拠駆動にできる。

Trigger line (final): "When a semantic difference is found, run a split probe: (i) counterexample-to-assertion, (ii) oracle-absorbs-diff; then choose NOT_EQ vs EQUIV"

この Trigger line は proposal の差分プレビューにあったトリガ（差分発見時に split probe を走らせ、NOT_EQ vs EQUIV を選ぶ）と同等の意図を保った一般化になっている。

## 変更内容

Compare checklist の 1 行を置換し、「差分発見後に影響なし側へ寄る」単方向の次アクションを、「反例探索」と「オラクル吸収の確認」を同一トリガで二股化してから結論方向を選ぶ、という意思決定点へ変更した。

## 期待効果

EQUIV/NOT_EQ のどちらにも偏らず、差分が (i) テストの assertion へ露出するのか、(ii) テストオラクルにより吸収されるのか、の判別に必要な最短証拠を取りに行けるため、偽 EQUIV と偽 NOT_EQ の双方を減らすことが期待できる。
