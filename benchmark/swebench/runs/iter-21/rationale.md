# Iteration 21 — 変更理由

## 前イテレーションの分析

- 前回スコア: N/A（この作業で参照可能なファイルには未記載）
- 失敗ケース: N/A（この作業で参照可能なファイルには未記載）
- 失敗原因の分析: compare の終盤で、traced な差分を見つけた後に既存の結論ブロックへそのまま進みやすく、現在優勢な verdict を反転させる最小 witness の探索が後回しになりうる。

## 改善仮説

暫定 verdict を置いた直後に、その verdict を覆す最小の具体 witness を次の探索対象として明示すれば、見えている差分や一致を早く要約しすぎる癖を抑え、EQUIVALENT と NOT EQUIVALENT の両側で premature closure を減らせる。

## 変更内容

- compare の certificate template で、semantic difference の列挙直後に `VERDICT-FLIP PROBE` を追加した。
- `Tentative verdict` と `Required flip witness` を書かせ、結論ブロックへ入る前の次探索先を明示する形にした。
- 既存の `COUNTEREXAMPLE` / `NO COUNTEREXAMPLE EXISTS` は維持しつつ、探索順だけを変更した。
- `Complete every section. Do not skip to FORMAL CONCLUSION without completing ANALYSIS.` は `Complete every section.` に置換し、必須ゲートの総量が増えないようにした。
- Trigger line (final): "Before finalizing a compare verdict, name the smallest concrete witness that would make the opposite verdict true, and search for that witness next."
- この Trigger line は proposal の差分プレビューにあった planned trigger line と一致しており、一般化ではなくそのまま最終文言として反映した。

## 期待効果

暫定 EQUIVALENT のときはそれを壊す既存 assertion / path を先に探し、暫定 NOT EQUIVALENT のときは差分を吸収して同じ assertion に戻す witness を先に探すため、どちらの結論でも summary completion より discriminative search を優先しやすくなる。既存の反証構造は残しているため、研究のコアを保ったまま compare の意思決定点だけを小さく動かす改善を期待する。
