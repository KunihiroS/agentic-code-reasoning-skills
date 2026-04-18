# Iteration 23 Discussion

## 総評
提案の狙い自体は理解できる。差分を見つけたときに「テストを1本ざっくり追う」より、「assert に届く値への寄与」を見るほうが compare の判定密度を上げたい、という発想は研究コア（明示的トレース、反証、証拠に基づく結論）と整合的で、偽 EQUIV / 偽 NOT_EQUIV の両側を意識している点もよい。

ただし今回は、failed-approaches.md が明示的に避けるべきだとしている「既存の汎用ガードレールを、特定の追跡方向で具体化しすぎる置換」にかなり近い。しかも補助ヒューリスティックの追加ではなく、Guardrail #4 の中核文言を置換しようとしているため、compare 改善より探索経路の半固定化が先に立つ懸念がある。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

README.md と docs/design.md の範囲で十分に根拠づけられている。特に docs/design.md の「Code Question Answering では data flow tracking を使う」は事実であり、explain 由来の観点を compare に移植したい、というカテゴリ F の発想自体は妥当。

ただし、論文由来であることと、compare の guardrail として置換してよいことは別問題。研究整合性はあるが、導入位置と強さには再検討が必要。

## 2. Exploration Framework のカテゴリ選定
カテゴリ F の選定は概ね適切。理由は、proposal が「原論文の未活用アイデアを compare に移植する」と明示しており、Objective.md の F に合っているため。

一方で、実際に変えているものは compare 時の「どう探すか」という探索方法でもあるので、副次的には B にもまたがる。とはいえ主分類を F としたこと自体は不自然ではない。

## 3. compare 影響の実効性チェック
- Decision-point delta:
  - Before: IF semantic difference is found THEN trace at least one relevant test through the differing code path before concluding no impact.
  - After: IF semantic difference is found THEN trace the assert-dependent data-flow slice on both sides before judging impact.
  - IF/THEN 形式で 2 行になっているか: YES
  - 条件も行動も同じで理由だけ言い換えか: NO
  - Trigger line（発火する文言の自己引用）が差分プレビューにあるか: YES
    - 該当: "identify the assert-dependent value(s) and trace the minimal data flow slice (difference → asserted value) on both sides"

- Failure-mode target:
  - 狙いは両方。 
  - 偽 NOT_EQUIV 側: 差分を見ただけで重要とみなしすぎる誤判定を、assert への未到達確認で減らしたい。
  - 偽 EQUIV 側: 「1本のテストを追ったが、どの値が assert を左右するかが曖昧なまま見落とす」誤判定を、assert 依存値の明示で減らしたい。

- Non-goal:
  - 早期 NOT_EQUIV 条件や STRUCTURAL TRIAGE には触れない、という境界は明確。
  - ただし「証拠種類の事前固定を避ける」「探索経路の半固定を避ける」という失敗原則への境界は、現状の文面では十分に守れていない。

- Discriminative probe:
  - 抽象ケース: 2 つの変更が同じテスト経路を通るが、一方は assert に使われない中間状態だけを変え、もう一方は assert の入力値そのものを変える。
  - 変更前は「関連テストを1本追った」だけで両者を同程度に扱い、偽 NOT_EQUIV と偽 EQUIV の両方が起こりうる。
  - 変更後は assert 依存値まで局所化できれば区別しやすくなる。ただし、これを guardrail の既定方向として固定すると、assert 値に還元しづらい差分（例: 例外条件、状態変化、順序依存）を逆に取りこぼすおそれがある。

- 支払い（必須ゲート総量不変）:
  - YES。proposal は 1 行置換で純増なしと明示しており、A/B の対応付けもある。

## 4. EQUIVALENT / NOT_EQUIVALENT の両方向への作用
片方向最適化ではなく、理屈上は両方向に作用する提案になっている点は評価できる。

- EQUIVALENT 判定への作用:
  - 差分があっても assert へ届かないなら「見かけの差」を落としやすくなるので、偽 NOT_EQUIV を減らす方向に働く。

- NOT_EQUIVALENT 判定への作用:
  - 差分が assert 入力に届くかを両側で明示するため、「なんとなく同じ経路を通る」だけで EQUIV としてしまう偽 EQUIV を減らす方向に働く。

- ただし実効的差分としては、どちらにも効く一方で、探索を assert-data-flow に寄せすぎると「assert 値以外の観測差」を拾う柔軟性を失う。よって、両方向に効きうるが、導入の仕方を誤ると両方向に副作用もありうる。

## 5. failed-approaches.md との照合
ここが最大の懸念点。

- 「探索経路の半固定」: YES
  - 原因文言: "identify the assert-dependent value(s) and trace the minimal data flow slice (difference → asserted value) on both sides"
  - 理由: 差分発見後の次の探索を、実質的に「assert 依存の最小データフロー」に寄せており、failed-approaches.md 22-25 行の「特定の追跡方向や観点で具体化しすぎない」に近い。

- 「必須ゲート増」: NO
  - 1 行置換で純増なし。

- 「証拠種類の事前固定」: YES
  - 原因文言: 同上。
  - 理由: proposal は「同じテスト/assert 根拠のまま」と説明しているが、実際には compare における優先証拠を data-flow-to-assert にかなり固定している。failed-approaches.md 8-12 行, 22-25 行の警告に抵触気味。

結論として、これは failed-approaches.md の本質的な再演にかなり近い。特に問題なのは「弱い補助」ではなく、既存の汎用 guardrail の置換として提案している点。

## 6. 汎化性チェック
- 具体的な数値 ID, リポジトリ名, テスト名, コード断片: 目立つ違反なし。
- 提案文はベンチマーク固有のリポジトリやテストを直接持ち込んでいない。
- ドメイン依存性: 明示的な特定言語・特定フレームワーク前提は薄い。

ただし暗黙の前提として、「比較したい差分の重要性は assert に流れ込む値として整理しやすい」というモデルを置いている。この前提は多くのテストで有効だが、例外発生、破壊的更新、順序、外部副作用、非値的な観測差まで一般化できるとは限らない。したがって R1 的には 2〜3 の中間、少なくとも無条件に 3 とまでは言いにくい。

## 7. 推論品質の改善期待
改善期待はある。特に、差分を見つけた後の「どこまで追えば impact/no-impact を言えるか」を具体化するので、compare の局所的な証拠密度は上がりうる。

しかし現案のままでは、改善の本体が「説明の精密化」だけで終わらず、本当に compare の意思決定を変える点はある一方、その変え方が狭い方向への探索誘導になっている。つまり、推論品質を上げる可能性はあるが、同時に探索の自由度を削って回帰を招くリスクが無視できない。

## 停滞診断
懸念は1点だけ。今回の proposal は、監査 rubic 上は「研究由来」「1行置換」「両方向を意識」と説明しやすいが、compare の実運用では差分発見後の探索を assert-data-flow に寄せるだけで、他の有力な観測差の探索余地を狭めるおそれがある。つまり「監査に刺さる説明強化」に寄りすぎ、compare の改善が探索の幅を犠牲にする形で実装される懸念がある。

## 修正指示
1. 置換をやめて、Guardrail #4 の汎用性は残すこと。
   - 「trace at least one relevant test...」を消さず、data-flow-to-assert は補助ヒューリスティックに下げるべき。
   - failed-approaches.md の 22-25 行に照らすと、既存ガードレールの方向固定な置換が問題。

2. assert-data-flow を必須方向にしない境界を 1 行で明示すること。
   - 例: 「when the test outcome is determined by asserted values」など、適用条件を限定し、例外・副作用・状態変化・順序差には他の観測経路も許す。
   - 追加するなら、別の既存文言を optional 化/統合して“支払い”を明示すること。

3. Decision-point delta は維持しつつ、「assert へ局所化できない場合の fallback」を同じ差分プレビュー内で自己引用すること。
   - 現状は発火条件はあるが、非適合ケースの逃げ道がないため compare の弾力を失いやすい。

## 最終判断
承認: NO（理由: failed-approaches.md が禁じる「既存の汎用ガードレールを、特定の追跡方向・証拠型へ置換して探索経路を半固定化する」再演に近い）
