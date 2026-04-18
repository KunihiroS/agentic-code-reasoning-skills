# iter-28 discussion

## 監査所見

### 1. 既存研究との整合性
- 検索なし（理由: 一般原則の範囲で自己完結）。
- README.md / docs/design.md のコアは「番号付き前提・仮説駆動探索・手続き間トレース・必須反証」であり、本提案は Step 5 の反証対象を明示化するだけで、このコア構造を壊していない。
- むしろ docs/design.md の「template が certificate として skip を防ぐ」という考え方に沿う。反証欄の対象主張を明示すると、反証が空文化しにくくなる。

### 2. Exploration Framework のカテゴリ選定
- 判定: 妥当。
- 本提案の主作用は「新しい探索順序・比較単位・判定基準の追加」ではなく、既存 Step 5 の表現を、対象主張が曖昧にならない書式へ寄せることにある。
- したがってカテゴリ E（表現・フォーマット）が最も近い。カテゴリ D に寄せるほどの新しい自己監査ゲート追加でもなく、カテゴリ B のような探索経路の優先順位変更でもない。

### 3. compare 影響の実効性チェック
- Decision-point delta:
  - Before: IF Step 5 を書く THEN 結論全体をぼんやり反証する文を書きがちで、対象主張の選定は暗黙のまま。
  - After: IF Step 5 を書く THEN 先に「誤りなら最終回答が反転する主張」を TARGET CLAIM として宣言し、その主張を反証する探索に入る。
- IF/THEN 形式で 2 行（Before/After）になっているか: YES
- Trigger line（発火する文言の自己引用）が差分プレビューに含まれているか: YES
  - 「TARGET CLAIM: [the decision-critical claim you are trying to falsify]」がある。
- 評価:
  - これは理由の言い換えだけではなく、Step 5 開始時の分岐を変えている。「結論全体」から入るのではなく、「決定的主張」から入るので、compare の意思決定ポイントに実効差がある。

- Failure-mode target:
  - 対象: 両方。
  - 偽 EQUIV 側: 反証対象がぼやけると「差はあるが relevant test では効かないはず」という雑な無反例結論を出しやすい。decision-critical claim を固定すると、どの主張を崩せば NOT_EQUIV になるかが明確になり、見逃しを減らせる。
  - 偽 NOT_EQUIV 側: 局所差分に過集中すると「差がある」こと自体を反証対象にしてしまい、test outcome 反転に本当に効く主張かを見失う。decision-critical claim を「それが誤りなら最終回答が反転する主張」に限定することで、些末差の過大評価を抑えやすい。

- Non-goal:
  - 探索経路の半固定はしない。どの証拠種類を探すか、どのファイルから読むか、どの観測境界を優先するかは固定していない。
  - 必須ゲートは増やさない。既存 Step 5 の内部で対象主張の明示を要求するだけで、新しい pre-check / post-check は足していない。
  - 証拠種類の事前固定はしない。固定するのは evidence type ではなく、あくまで「どの主張を崩しに行くか」。

- Discriminative probe:
  - 抽象ケース: 2 つの変更に局所的な実装差はあるが、relevant tests の assertion には影響しない。一方で別の分岐では assertion に効く可能性もある。
  - 変更前は Step 5 が「結論が偽なら何があるか」の一般論に流れ、局所差だけ見て偽 NOT_EQUIV、または反証不在を雑に述べて偽 EQUIV の両方が起こりうる。
  - 変更後は「どの主張が崩れたら最終回答が反転するか」を先に置くため、局所差そのものではなく test outcome 反転に直結する claim に探索を合わせやすい。これは新ゲート追加ではなく、既存 Step 5 文言の置換・明確化として説明できる。

- 支払い（必須ゲート総量不変）の明示要否:
  - 本件は新しい必須ゲート増設ではなく、既存 mandatory Step 5 の内部明確化なので、A/B の支払い対応を必須とする類型ではない。

### 4. EQUIVALENT / NOT_EQUIVALENT への作用
- EQUIVALENT 判定への作用:
  - 「NO COUNTEREXAMPLE EXISTS」を書くとき、何の claim を崩せば反例になるかを先に言語化させるので、無内容な「見つからなかった」報告を減らす。
  - その結果、偽 EQUIV の主因である“反証対象の曖昧化”は減りやすい。
- NOT_EQUIVALENT 判定への作用:
  - 「差がある」という事実だけでなく、「その差が final answer を flip させる decision-critical claim を壊すか」を意識させるため、局所差の過大評価を抑えやすい。
  - その結果、偽 NOT_EQUIV の主因である“些末差からの飛躍”も減らしうる。
- 片方向最適化か:
  - 片方向ではない。反証対象の粒度を結論全体より少し細かくしつつ、decision-critical に限定しているため、EQUIV 側では反例探索を具体化し、NOT_EQUIV 側では差分の relevance 判定を厳密化する。
  - ただし TARGET CLAIM が単なる結論の言い換えに終わると効果が弱まる。この点は実装時に「final answer が flip する主張」であることを明示し続ける必要がある。

### 5. failed-approaches.md との照合
- 「探索経路の半固定」該当: NO
- 「必須ゲート増」該当: NO
- 「証拠種類の事前固定」該当: NO
- 根拠:
  - 追加されるのは target claim の欄であり、ファイル種別・証拠種別・観測境界の固定ではない。
  - 既存 Step 5 の mandatory 性はそのままで、新しい Step 5.7 のような独立ゲート追加ではない。
  - failed-approaches.md が特に警戒するのは「次の探索で探す証拠種別の固定」「観測境界への過度還元」「反例像の冒頭固定による探索入口の狭窄」だが、本案は反例像そのものではなく decision-critical claim を明示するだけで、まだ探索自由度をかなり残している。
- ただし軽微な注意点:
  - failed-approaches.md 17 行目の「暫定的な反例像や結論形式を冒頭で先に置かせる変更」に近づくリスクはゼロではない。もし TARGET CLAIM の例示が具体化されすぎると、探索入口の狭窄に寄る。
  - そのため実装時は TARGET CLAIM を「example-rich に増やす」のではなく、最短定義だけに留めるのが安全。

### 6. 汎化性チェック
- 具体的な数値 ID, リポジトリ名, テスト名, コード断片の混入: なし。
- SKILL.md 自身の文言引用はあるが、Objective.md の R1 減点対象外に明示されている範囲。
- 暗黙のドメイン依存:
  - 「decision-critical claim」は compare / diagnose / explain / audit いずれにも通用する一般概念で、特定言語や特定テストパターンへの依存は薄い。
  - relevant tests を前提にする compare の枠組みとも整合しており、特定フレームワーク前提は見えない。

### 7. 全体の推論品質への期待効果
- Step 5 の失敗モードの一つは「反証欄を埋めたが、実際には何も崩しに行っていない」こと。本提案はそこを最小差分で突いている。
- 既存の certificate 構造を維持したまま、反証の焦点を decision-critical claim に合わせるため、推論の密度は上がるが複雑性増は小さい。
- compare に対して特に有効なのは、「差分の有無」ではなく「test outcome 反転に効く差分か」を考えさせやすくなる点。

## 停滞診断（必須）
- 懸念 1 点:
  - 「TARGET CLAIM」を書くだけで、実際の compare 分岐が変わらず説明だけ綺麗になる停滞リスクはある。特に target claim が「私の結論は正しい」のような抽象文に退化すると、監査 rubic には刺さるが compare の判断は変わらない。
- failed-approaches 該当性:
  - 探索経路の半固定: NO
  - 必須ゲート増: NO
  - 証拠種類の事前固定: NO

## 総合評価
- 良い点:
  - 最小差分で Step 5 の実効性を上げようとしており、研究コア・反証可能性・複雑性のバランスがよい。
  - compare の両方向誤判定に効く機序が明示されている。
  - Trigger line と IF/THEN の decision-point delta が proposal 内で具体化されている。
- 残る注意:
  - 実装では TARGET CLAIM を「最終回答が反転する主張」に固定し、単なる結論の言い換えや局所差の言い換えに落とさないこと。ここが曖昧だと監査向けの説明強化に留まり、compare 停滞を招く。

## 修正指示
1. 「TARGET CLAIM」を追加するなら、同じ行か直後で「not the whole conclusion; the claim whose falsity would flip the final answer」と短く定義し、結論全体の言い換えを避けること。
2. 変更差分プレビューでは、COUNTEREXAMPLE / ALTERNATIVE HYPOTHESIS の両方に同じ 2 行を足すのではなく、Step 5 scope の定義 1 行を主にして、テンプレート側は最小限に留めること。過剰な欄追加に見せないため。
3. 「全モード共通の Step 5」と言うなら、実装範囲を compare+audit と explain+diagnose の両側でどう反映するかを 1 行で明示すること。現状でも概ね読めるが、実装ズレ防止のため。

承認: YES