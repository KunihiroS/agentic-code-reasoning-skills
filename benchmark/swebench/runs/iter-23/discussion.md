# iter-23 proposal 監査コメント

## 総評
提案の狙い自体は理解できます。compare の Claim C[N].1/.2 が実運用で call-chain の列挙に流れやすく、アサーション到達性の検証が甘くなる、という問題設定は妥当です。また、explore ではなく compare の既存テンプレ 2 行を置換する小変更として設計している点、Decision-point delta と Trigger line を proposal 内に明示している点もよいです。

ただし、今回の文言は compare の根拠を「asserted key value の data-flow (Created/Modified/Used)」へ実質的に固定しており、failed-approaches.md が禁じている「証拠種類の事前固定」と「特定方向の追跡の具体化」の再演にかなり近いです。したがって、このままの承認はできません。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

README.md / docs/design.md / SKILL.md の範囲だけで、原論文由来の explain 側 data-flow を compare に移植するという位置づけは十分に確認できます。外部検索が必要な固有概念の導入ではありません。

## 2. Exploration Framework のカテゴリ選定
カテゴリ F（原論文の未活用アイデアを導入する）は適切です。

理由:
- proposal は explain モードに既にある DATA FLOW ANALYSIS を compare に持ち込む提案で、Objective.md の F「他のタスクモードの手法を compare に応用する」に一致します。
- 変更の主眼は compare テンプレの根拠の粒度変更であり、A/B/E のような順序変更や単なる表現改善より、F としての位置づけが自然です。

ただし「カテゴリ F であること」と「その導入のしかたが安全であること」は別です。今回はカテゴリ選定は妥当でも、導入の文言が強すぎます。

## 3. compare 影響の実効性チェック
### 1) Decision-point delta
- IF/THEN 形式で 2 行（Before/After）になっているか: YES
- Trigger line（発火する文言の自己引用）が差分プレビュー内にあるか: YES

評価:
- Before は「changed code → test assertion outcome を trace」、After は「asserted key value を 1 つ特定し、その data-flow で trace」で、条件も行動も一応変わっています。
- したがって、単なる理由の言い換えではなく、compare 時の証拠化の仕方を変える提案にはなっています。
- ただし、変わる意思決定ポイントは主に「どう根拠を書くか」であり、「いつ追加で探すか」「どの条件で generic trace から別の因果境界へ切り替えるか」は未定義です。このため、説明強化に寄り、実際の compare 分岐の柔軟性を落とすリスクがあります。

### 2) Failure-mode target
- 狙い: 偽 EQUIV と偽 NOT_EQUIV の両方
- メカニズム:
  - 偽 NOT_EQUIV を減らす側面: 見た目の構造差や call-chain 差だけでなく、アサーションが実際に読む値まで到達するかを見ることで、影響の過大視を減らす。
  - 偽 EQUIV を減らす側面: 中間で握りつぶされがちな差分でも、asserted value までの到達を強制することで、影響の見落としを減らす。

### 3) Non-goal
- 新規の必須ゲート純増はしない、という境界条件は明示されている。
- ただし実質面では、Claim 行そのものに「data-flow of asserted key value」を必須化しており、証拠様式の自由度は狭まっています。
- したがって「総量不変」の宣言はあるが、「何を optional 化/統合した代わりに何を必須化するのか」という支払いは弱いです。

### Discriminative probe
抽象ケース:
- 2 つの変更で内部 helper の呼び出し列は違うが、テストが最終的に読む state/value は同一で、assert はその値しか見ていないケースでは、変更前は call-chain 差を過大視して NOT_EQUIV 誤判定しやすい。
- 変更後は asserted value までの data-flow を見れば、その差が観測結果に到達しないことを示しやすく、誤 NOT_EQUIV を避けやすい。
- ただし、観測結果が「例外の有無」「副作用の回数」「順序」「未到達そのもの」に依存するケースでは、単一キー変数中心の mandatory 化が逆に誤判定を増やしうる。

### 支払い（必須ゲート総量不変）の明示
- A/B 対応付けが proposal 内で明示されているか: 部分的に YES
- コメント: 「compare テンプレ内の 2 行置換」とあるため差し替え対象は明確です。ただし、generic trace の自由度を捨てて data-flow slice を必須にする副作用への説明が不足しています。

## 4. EQUIVALENT / NOT_EQUIVALENT の両方向への作用
### EQUIVALENT 側への期待効果
- call-chain 差や構造差があっても asserted value に到達しないと示しやすくなり、偽 NOT_EQUIV を減らす可能性があります。
- 特に、同じ観測値へ収束する実装差の扱いでは有効です。

### NOT_EQUIVALENT 側への期待効果
- 差分が assertion-relevant な値へ到達することを明示しやすくなり、途中で「たぶん同じ」に寄せる偽 EQUIV を減らす可能性があります。
- 特に、値変化が test oracle へ伝播するタイプの差分では効きます。

### 逆方向の悪化リスク
- 今回の文言は「key variable/value を 1 つ特定し、その Created/Modified/Used を追う」としており、control-flow・exception-flow・side-effect ordering・call occurrence のような差分を扱いにくくします。
- そのため、値到達型のケースには効いても、非値中心の oracle では逆に両方向を悪化させえます。
- よって、片方向最適化が明白とまでは言わないものの、「片方にも効く」ことを担保するには mandatory wording が強すぎます。

## 5. failed-approaches.md との照合
### 本質的再演か
結論: YES、かなり近いです。

主な該当箇所:
- 「証拠種類の事前固定を避ける」への抵触: YES
  - 原因文言: 「アサーションが読んでいるキー変数（または出力）を1つ特定し、Created/Modified/Used を両パッチで追う」
  - 理由: compare の根拠を data-flow slice という特定証拠様式へ事前固定しているため。

- 「探索経路の半固定」への抵触: YES
  - 原因文言: 同上
  - 理由: changed code → assertion outcome の自由な因果トレースを、asserted key value という特定の入口と tracking direction に寄せているため。

- 「必須ゲート増」への抵触: NO
  - 明示的な新欄追加や新規メタ判定の増設はない。
  - ただし、既存 Claim 行の mandatory 内容を強化しているため、体感上は軽い gate 強化に近い。

補足:
failed-approaches.md 22-25 行の「既存の汎用ガードレールを、特定の追跡方向や観点で具体化しすぎない」にほぼ直結しています。今回の提案は compare の generic trace を data-flow 方向へ置換しており、この失敗原則の中心部に触れています。

## 6. 汎化性チェック
### 明示的ルール違反の有無
- 具体的な数値 ID: なし
- リポジトリ名: なし
- テスト名: なし
- ベンチマーク実コード断片: なし

この点は問題ありません。

### 暗黙のドメイン前提
軽微ではない懸念があります。
- 提案は「assertion が読む key variable/value」を中心に据えており、テスト oracle が最終値比較で表現されるケースを暗黙に優先しています。
- しかし compare では、例外送出、ログ/イベント、副作用回数、ミューテーション、タイミング、順序依存など、値 1 個へ還元しにくい差分もあります。
- したがって、文面どおり mandatory にすると、言語非依存というより「data-flow で表しやすいケースにやや偏る」設計です。

## 7. 全体の推論品質への期待
良い方向:
- 「何が test oracle に到達するか」を意識させる点は、compare の根拠を観測可能な因果へ寄せるので、雑な call-chain 比較より質が上がる余地があります。
- explain 側で有効だった粒度を compare に部分移植する、という発想も研究コアから大きく逸脱していません。

悪い方向:
- compare の根拠様式を 1 種類へ寄せすぎると、反証の取り方が単調化し、むしろ有力な差分境界を見落とします。
- 特に「値以外の oracle」を扱う比較で、推論の柔軟性が落ちる懸念が強いです。

総合すると、「到達性を重視する」という着想自体は有望ですが、今の wording は compare の自由度を削りすぎています。

## 停滞診断（必須）
- 懸念 1 点: 今回の提案は、監査 rubric 上は「推論過程の具体化」「研究コアの踏襲」として説明しやすい一方で、compare の意思決定を変えるというより、Claim の書きぶりを data-flow 風に揃える方向へ寄っています。つまり、監査に刺さる説明強化に見えて compare の実分岐を狭める恐れがあります。

- 探索経路の半固定: YES
  - 原因文言: 「アサーションが読んでいるキー変数（または出力）を1つ特定し」
- 必須ゲート増: NO
- 証拠種類の事前固定: YES
  - 原因文言: 「その data-flow（Created/Modified/Used）で両パッチの到達性をトレースする」

## 修正指示（2〜3点）
1. mandatory な置換先を弱めてください。
   - 現案の「via data-flow of the asserted key value (created/modified/used)」は削り、
   - 「via the assertion-relevant causal path (for example, data-flow of an asserted value/state when that is the clearest route)」のように、data-flow を例示に下げてください。
   - これで compare 影響は残しつつ、証拠種類の事前固定を避けられます。

2. Decision-point delta を「条件分岐」として明確化してください。
   - 追加ではなく置換で、
   - 値/状態の伝播が主要因なら data-flow を使う
   - 例外・分岐・副作用・順序が主要因ならその因果境界を追う
   という 2 分岐にしてください。
   - 今は generic trace を data-flow に一本化しており、compare の実効差が偏っています。

3. 「1つのキー変数」を必須にしないでください。
   - 「key variable/value を1つ特定」は削るか optional 化し、
   - 「assertion-relevant state/value/effect」を必要に応じて 1 つ以上示す、程度に留めてください。
   - これも行数は増やさず、既存の generic trace 文言との置換で収められます。

## 最終判断
承認: NO（理由: compare の根拠を asserted key value の data-flow に実質固定しており、failed-approaches.md の「証拠種類の事前固定」と「探索経路の半固定」の本質的再演になっているため）
