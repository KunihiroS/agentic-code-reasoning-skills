# Iteration 10 — 変更理由

## 前イテレーションの分析

- 前回スコア: 不明（この実装タスクでは参照用入力として与えられていない）
- 失敗ケース: 不明（この実装タスクでは参照用入力として与えられていない）
- 失敗原因の分析: 結論直前の自己チェックが aggregate support check に寄っており、主要トレース上の UNVERIFIED 仮定が verdict を左右する場合でも、「結論を変えない」という抽象判断に吸収されやすい。そのため、弱い未検証リンクが残ったまま EQUIVALENT / NOT_EQUIVALENT を確定しやすい。

## 改善仮説

「UNVERIFIED があるか」ではなく、「最弱の UNVERIFIED 仮定を反転させたとき verdict が崩れるか」を結論直前で確認する形に置き換えると、偽 EQUIVALENT と偽 NOT_EQUIVALENT の両方を、新しい判定モードを増やさずに減らせる。

## 変更内容

- Step 5.5 の "Every function in the trace table is marked VERIFIED, or explicitly UNVERIFIED with a stated assumption that does not alter the conclusion." を、UNVERIFIED を単なる注記ではなく後続の stability check に接続できる形へ簡素化した。
- Step 5.5 の "The conclusion I am about to write asserts nothing beyond what the traced evidence supports." を削除し、その代わりに decisive path 上の最弱リンクを特定する weakest-link check と、反転で verdict が変わるなら確定しないという分岐を追加した。
- Trigger line (final): "If reversing that assumption could change the verdict, do not finalize the verdict as settled; continue tracing or mark the conclusion UNVERIFIED / lower CONFIDENCE."
- この Trigger line は proposal の差分プレビューにある planned trigger line と一致し、反転条件と非確定アクションを同じ一般化で表現している。

## 期待効果

主要な compare の意思決定点が、「全体として支えられているか」という抽象評価から、「最弱の未検証リンクが verdict を支えているか」という具体的な stability 判定へ変わるため、未読の helper/library call や未検証仮定が decisive path に残るケースで誤確定を避けやすくなる。特に、最弱リンクの反転で少なくとも 1 つの test outcome 予測が変わる場合に、追加探索・UNVERIFIED 明示・CONFIDENCE 低下へ分岐できるようになる。