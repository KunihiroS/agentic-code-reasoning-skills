# iter-9 discussion

## 総評
方向性は概ね妥当です。既存の Step 5.5 にある曖昧な「does not alter the conclusion」を、UNVERIFIED が結論を左右しうるかどうかで分岐する判定文に置き換える、という中身自体は compare の偽 EQUIV を減らす実効差があります。しかも新規チェック項目の追加ではなく 1 行置換として設計されており、failed-approaches.md が禁じる「必須ゲート増設」に踏み込みにくい点もよいです。

一方で、提案文のままでは「relevant test outcome」という compare 専用の言い方を Core Method の共通 Step 5.5 に入れようとしており、compare 以外の mode への適用境界が少し粗いです。最大の懸念はここで、改善の核はよいので、reject ではなくこの 1 点を中心に表現調整して通すのがよいと考えます。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

判断根拠:
- README.md と docs/design.md のコアは「明示的前提」「仮説駆動探索」「手続き間トレース」「必須反証」による semi-formal reasoning の証明書化です。
- 今回の提案はそのコアを崩さず、既存の自己監査文言を「弱い環が結論を支配するなら追加探索または結論縮小へ分岐」と精密化するものです。
- これは新しい理論の導入というより、既存 certificate の判定境界を明確化する小修正なので、追加の外部調査は不要です。

## 2. Exploration Framework のカテゴリ選定
判定: 適切

理由:
- Objective.md の D は「思い込み検査」「弱い環の特定」「確信度と根拠の対応」です。
- 提案の本体はまさに「UNVERIFIED 仮定が outcome を左右しうるなら、そのまま確定結論に行かない」という自己チェック強化であり、探索順序や証拠種類の固定ではありません。
- E や B にも少し跨りますが、主要メカニズムは D と見るのが自然です。

## 3. compare 影響の実効性チェック
- Decision-point delta:
  - Before: IF UNVERIFIED が残っていても「結論に影響しない」と自己申告できる THEN EQUIV に進みやすい
  - After: IF UNVERIFIED が関連結果を変えうる THEN 追加で探す / それでも残るなら条件付き結論 + LOW に縮める
  - IF/THEN 形式で 2 行になっているか: YES
  - 評価: 条件も行動も変わっており、理由の言い換えではないので compare 影響は実効的です。

- Failure-mode target:
  - 主対象は偽 EQUIV の削減です。
  - メカニズムは「反証未発見」を「同一挙動の証拠」と誤読する経路を止め、UNVERIFIED を outcome 支配の弱い環として扱う点にあります。
  - 副次的には、些細な未検証に対しては「影響しない根拠」を書けば先へ進めるため、偽 NOT_EQ や過剰保留への寄りもある程度抑えます。

- Non-goal:
  - 読解順序の半固定はしない。
  - 新しい必須ゲートは増やさない。
  - 検証手段や証拠種類は事前固定しない。

- Discriminative probe:
  - 抽象ケース: 両案の差は間接呼び出し先にあり、直接のテスト assertion には現れていないが、その未検証関数しだいで分岐条件が変わりうる。
  - 変更前は「反証なし」で EQUIV に寄りやすい。変更後は UNVERIFIED が outcome を変えうるため、追加探索か条件付き結論に分岐し、偽 EQUIV を避けやすい。
  - これは新しい必須ゲートの増設ではなく、既存 Step 5.5 の 1 行を分岐文に置換することで説明できています。

- 支払い（必須ゲート総量不変）:
  - proposal 内で A/B 対応付けは明示されています。既存 1 行の置換で、項目追加なしという説明は十分です。

## 4. EQUIVALENT 判定と NOT_EQUIVALENT 判定への作用
- EQUIVALENT 側:
  - 明確に効きます。特に「NO COUNTEREXAMPLE FOUND」から早すぎる EQUIV に飛ぶ経路を鈍らせます。
  - 以前は UNVERIFIED を自己申告で無害化しやすかったのに対し、変更後は outcome 影響可能性が残る限り、追加探索または条件付き・低確信度へ押し戻されます。

- NOT_EQUIVALENT 側:
  - 直接「NOT_EQ を出しやすくする」変更ではありません。
  - ただし、些細な未検証を理由に過剰に NOT_EQ へ倒れるのではなく、「影響しない根拠があれば通常どおり進める」「残るなら conditional + LOW」という逃がし方なので、片方向最適化にはなっていません。
  - したがって、主効果は偽 EQUIV の削減、逆方向への悪化は限定的という評価です。

## 5. failed-approaches.md との照合
- 探索経路の半固定: NO
  - 次に何を読むか、どこから読むか、どの境界を先に確定するかは固定していません。

- 必須ゲート増: NO
  - 新しいチェック項目を増やさず、既存 Step 5.5 の 1 行を置換する提案です。
  - 実質ゲート化の懸念は少しありますが、項目追加ではなく既存項目の意味の精密化に留まっています。

- 証拠種類の事前固定: NO
  - 「検証 or 影響しない根拠を作る」としており、特定の証拠様式に固定していません。

補足懸念:
- failed-approaches.md には「既存の判定基準を特定の観測境界だけに還元しすぎない」とあります。
- proposal の文言がそのまま Core Method に入ると、「relevant test outcome」という compare の観測境界へ寄りすぎ、explain / audit-improve では不自然です。これは失敗原則の再演そのものではないですが、放置すると近づきます。

## 6. 汎化性チェック
判定: 概ね問題なし

- 具体的な数値 ID, リポジトリ名, テスト名, 実コード断片: なし
- SKILL.md 自身の引用 diff は許容範囲
- 特定言語・特定フレームワーク前提: なし
- 暗黙のドメイン偏り: 小
  - ただし「relevant test outcome」は compare には自然でも、全 mode 共通文としてはやや compare 偏重です。
  - 汎化性を保つには、「relevant claimed outcome」や「relevant downstream conclusion」など mode 非依存の言い方へ丸めるのが安全です。

## 7. 推論品質の改善見込み
期待値はあります。

改善が見込める点:
- 「未検証リンクが残っているのに結論だけ強い」という典型的な過信を減らせる
- Step 5 の refutation と Step 6 の conclusion の間に、証拠強度に応じた分岐を明確化できる
- 1 行置換なので複雑性増加やテンプレート肥大化が小さい

改善が限定される点:
- 実効差の中心は偽 EQUIV の抑制で、偽 NOT_EQ 改善は副次的です
- 自己チェック文なので、表現だけが強まり compare の行動差が弱い、という停滞リスクは少し残ります

## 停滞診断（必須）
- 懸念 1 点:
  - 「監査 rubic に刺さる説明強化」に寄り、実際の compare 行動差が agent の自己申告に吸収される恐れはあります。つまり、実装後も agent が安易に「cannot change outcome」と書いて通すなら、見た目ほど decision は変わりません。

- failed-approaches 該当性:
  - 探索経路の半固定: NO
  - 必須ゲート増: NO
  - 証拠種類の事前固定: NO

## 修正指示（2〜3 点）
1. Core Method の共通文に入れるなら「relevant test outcome」を mode 非依存表現へ置換してください。
   - 例: 「cannot change any relevant claimed outcome」または「cannot change the conclusion about the relevant observed behavior」
   - compare 専用にしたいなら Compare 節へ移し、Core Method には置かないでください。

2. 「追加で探す」の支払いは不要ですが、条件分岐の出口をもう一段だけ明確にしてください。
   - 具体的には「verify / justify invariance / narrow conclusion + LOW」の 3 択で十分です。
   - それ以上の報告様式追加はしないでください。

3. NOT_EQ 側への副作用回避を 1 文だけ短く補ってください。
   - 例: 「mere presence of UNVERIFIED is not itself grounds for NOT_EQUIVALENT when outcome-invariance is evidenced」
   - これも追加項目ではなく、同一行の言い換えか compare 節の短い補足に留めるのがよいです。

## 最終判断
承認: YES

理由:
- Decision-point delta が具体で、compare の偽 EQUIV を減らす方向に実効差がある
- failed-approaches.md の本質的再演ではない
- 変更量が小さく、必須ゲート総量不変という条件も満たしている
- 最大懸念は共通 Step 5.5 に compare 専用語を入れる表現境界であり、これは修正可能な粒度です