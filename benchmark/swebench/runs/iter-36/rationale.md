# Iteration 36 — 変更理由

## 前イテレーションの分析

- 前回スコア: N/A（この作業で参照可能な資料には未記載）
- 失敗ケース: N/A（この作業で参照可能な資料には未記載）
- 失敗原因の分析: semantic difference を見つけた直後に、その差分が relevant test に接続するか未確定でも下流の内部実装を深掘りしやすく、irrelevant difference の過読みによる偽 NOT_EQUIV と、relevant path の見落としによる偽 EQUIV の両方を招きうる。

## 改善仮説

relevance 未確定時の既定探索を「より深い内部 trace」ではなく「到達性を決める最寄りの caller/test/dispatch 証拠の確認」に置き換えると、結論前の分岐でより判別力の高い情報を先に取得でき、EQUIV/NOT_EQUIV の両側で誤判定を減らせる。

## 変更内容

- Step 3 に、relevance 未確定時は最寄りの caller/test/dispatch site を先に読む Trigger line を 1 行追加した。
- Step 4 の対象を「relevant code path」から「relevant or relevance-deciding path」へ置換し、読取対象を relevance 判定に必要な経路へ絞った。
- Compare checklist の 3 項目を置換し、無条件の下流追跡をやめて、relevant test 優先・relevance 解決優先の読順に統一した。
- 追加より置換を優先し、判定手順の総量が増えない形に留めた。

Trigger line (final): "When test relevance is unresolved, first read the nearest caller/test/dispatch site that decides whether the changed path is exercised before tracing deeper internals."

この Trigger line は差分プレビューの planned trigger line と一致しており、意味差発見後に relevance 分岐を発火させる位置へ実際に配置されている。

## 期待効果

semantic difference を見つけても relevant test への接続が未確定な段階では、先に到達性を決める証拠を読むため、未到達な差分を irrelevant と判断して EQUIV 側へ戻しやすくなる。一方で到達する差分は relevant test trace を早く始められるため、真に影響する差分の見落としも減る。