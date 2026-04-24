# Iteration 49 — 変更理由

## 前イテレーションの分析

- 前回スコア: 参照範囲外（本タスクで指定された入力には含まれない）
- 失敗ケース: 参照範囲外
- 失敗原因の分析: 探索順が固定順・網羅順に寄り、次の読解が EQUIV/NOT_EQUIV のどの未解決 claim を反転しうるかを明示しないまま追加探索へ進むと、結論に効かない調査で保留が増える、または結論に必要な trace の優先度が下がる。

## 改善仮説

次の行動を「不確実性を減らすか」ではなく「どの verdict-bearing claim を反転しうるか」で選ばせると、ANSWER を変えない探索は confidence-only として扱いやすくなり、必要な trace と refutation を保ったまま過剰な追加探索を抑えられる。

## 変更内容

- Step 3 の探索優先度を、未解決 uncertainty 一般ではなく、未解決 EQUIV/NOT_EQUIV claim を変えうるかに置換した。
- Step 3 の optional info-gain 行を、verdict-flip target を名指す行と confidence-only の場合の分岐に置換した。
- Compare template 冒頭の全セクション完遂命令を、certificate sections を必要証拠のガイドとして使い、verdict-bearing claims が解決済みなら無関係な browsing を増やさない表現へ弱めた。

Trigger line (final): "Trigger line (planned): \"MUST name VERDICT-FLIP TARGET: the unresolved EQUIV/NOT_EQUIV claim this action could change, or 'confidence only'.\""

この Trigger line は proposal の差分プレビューにあった Trigger line と一致しており、分岐を発火させる Step 3 の読解後ジャーナル内に配置されている。

Decision-point delta:
- Before: IF an uncertainty remains after reading THEN choose a next file/step justified by rationale and optional info gain because it may resolve a hypothesis or claim.
- After: IF an uncertainty remains after reading THEN choose the next file/step only if it names an unresolved EQUIV/NOT_EQUIV claim it could change; otherwise conclude with stated uncertainty or lower CONFIDENCE because the action is confidence-only.

## 期待効果

EQUIV 側では、観測された差分が結論を反転しない場合に追加探索を続けすぎず、明示的不確実性または CONFIDENCE 調整へ進みやすくなる。NOT_EQUIV 側では、結論を反転しうる claim を優先して trace するため、実際に異なる outcome へ到達する反証候補を早く扱いやすくなる。必須ゲートは純増させず、optional info-gain の置換と冒頭命令の弱化で判定前手順の総量を増やさない。
