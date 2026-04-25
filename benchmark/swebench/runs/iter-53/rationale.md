# Iteration 53 — 変更理由

## 前イテレーションの分析

- 前回スコア: proposal.md に記載なし（この実装手順では追加参照なし）
- 失敗ケース: 個別ケース ID は記載しない
- 失敗原因の分析: per-test comparison 欄で assert/check result が未検証の場合でも SAME/DIFFERENT の比較証拠として消費されやすく、未知の結果が EQUIV/NOT_EQUIV の根拠に混ざる可能性があった。

## 改善仮説

Per-test comparison 欄で、両側の traced assert/check result が PASS/FAIL として確定している場合だけ SAME/DIFFERENT を使い、未検証が混じる場合は impact UNVERIFIED として残せば、未知の結果を verdict-bearing evidence として誤消費する premature verdict が減る。

## 変更内容

Compare template の relevant test analysis にある Comparison 行を 1 行置換し、UNVERIFIED を SAME/DIFFERENT の根拠にしない条件を明示した。

Trigger line (final): "Comparison: SAME / DIFFERENT only when both traced assert/check results are PASS/FAIL; if either side is UNVERIFIED, write Impact: UNVERIFIED instead of using it as equivalence evidence."

この Trigger line は proposal の差分プレビューにあった planned line と一致しており、per-test comparison の分岐を発火させる位置に入っている。

## 期待効果

未検証の assert/check result を equivalence/non-equivalence の証拠として扱う分岐が減り、SAME/DIFFERENT と Impact: UNVERIFIED の使い分けが明確になる。新しい必須ゲートは追加せず既存行の置換に留めたため、結論前の判定手順の総量は増えていない。
