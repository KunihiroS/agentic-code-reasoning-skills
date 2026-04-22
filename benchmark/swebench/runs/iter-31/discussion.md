# iter-31 discussion

## 総評
カテゴリ選定は D（メタ認知・自己チェック強化）として自然です。提案は Step 5.5/6 の近接箇所を置換し、重複 self-check を confidence 校正へ振り替えるので、変更規模も小さく、研究コア（番号付き前提・仮説駆動探索・手続き間トレース・必須反証）を直接壊してはいません。

ただし、提案の中心である「weakest verdict-critical link の特定」と「その検証状態による confidence 上限化」は、failed-approaches.md の原則2が既に失敗一般形として警告している領域にかなり近いです。しかも compare 実行時の観測可能差が主に CONFIDENCE/UNVERIFIED 表示へ寄っており、ANSWER 自体の分岐変更は弱いです。このため、監査 rubic には刺さりやすい一方、compare の改善としては停滞しやすい提案だと見ます。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

README.md / docs/design.md が示す研究コアは「証拠先行の semi-formal reasoning を certificate 化して、ステップ飛ばしや unsupported claim を防ぐ」ことです。本提案はその外側に新しい理論を持ち込まず、結論直前の自己監査と confidence 表現の結び付けを強めるだけなので、研究コアから大きく逸脱はしていません。

## 2. Exploration Framework のカテゴリ選定
D は適切です。
- 変更対象が Step 5.5 の self-check と Step 6 の confidence 付与であり、探索順序・比較枠組み・情報取得法の変更ではない。
- 「推論チェーンの弱い環を特定させる」「確信度と根拠の対応を明示させる」は Objective.md の D カテゴリ例と一致する。

ただし、D カテゴリとして適切であることと、failed-approaches の禁則を回避できていることは別問題です。今回の懸念はカテゴリ誤認ではなく、D の中でも「弱い環を必須化して結論出力へ結び付ける」型が既失敗原則に近い点です。

## 3. EQUIVALENT / NOT_EQUIVALENT の両方向への作用
両方向に作用する設計意図はあります。
- EQUIVALENT 側: 反例未発見だけで HIGH-confidence EQUIV に寄る過信を抑える。
- NOT_EQUIVALENT 側: 反例パスが 1 本見えても、その途中依存が未検証なら過信を抑える。

ただし、実効差はほぼ対称な「過信抑制」に限られます。つまり、両方向の誤判定を直接減らすというより、両方向の“言い切り方”を弱める提案です。ANSWER の誤りを修正する方向より、CONFIDENCE の校正に作用する比重が高いです。

## 4. failed-approaches.md との照合
本質的再演の懸念があります。

failed-approaches.md 原則2には、以下が明示的に近い失敗として書かれています。
- 「結論直前に『未検証の最弱リンクが verdict を左右しうるなら確定しない』のような不安定性チェックを Guardrail 化」
- 「比較ごとの証拠の弱い側を必ず特定させ、その側の未検証性を次の必須行動に結びつける」
- 「verdict を左右する claim ごとに『未検証依存なら結論前に非確定化する』といった判定を必須化」

今回の proposal は wording 上は「保留を既定化しない」「same provisional verdict も許す」と逃がしていますが、実際の中核文言は
- 「Name the weakest verdict-critical link」
- 「Confidence may not exceed the verification status of the weakest verdict-critical link」
- 「UNVERIFIED 明示と CONFIDENCE 低下、必要なら追加探索」
であり、弱いリンクの特定を必須にし、その未検証性を結論直前の次行動へ強く接続しています。これは原則2が警戒するメカニズムにかなり近いです。

したがって、「表現を少し softer にした同系統の再演」である疑いは強いです。

## 5. 汎化性チェック
汎化性違反は見当たりません。
- 具体的な数値 ID、リポジトリ名、テスト名、実コード断片は含まれていません。
- SKILL.md 自身の文言引用は Objective.md の R1 減点対象外に該当します。
- 特定言語や特定ドメイン前提も薄いです。

一方で、暗黙には「confidence 出力が compare の実効改善につながる」という前提があります。しかし compare の主タスクは最終的に EQUIV / NOT_EQUIV 判定であり、confidence 校正がそのまま正答率改善へ結びつくとは限りません。ここは汎化性違反ではなく、効果機序の弱さの問題です。

## 6. 全体の推論品質への期待効果
期待できる改善はあります。
- unsupported certainty を減らす
- Step 5.5 と Step 6 の関係を近づける
- 結論と未検証事項の対応を明示しやすくする

ただし、これは主に calibration 改善です。compare ベンチマークで欲しいのは calibration だけでなく discriminative accuracy の改善です。今回の差分は、探索や判定分岐より、結論の慎重表現へ重心があります。

## 停滞診断
懸念あり: 提案は「監査 rubric に刺さる説明強化」へ寄っており、compare の意思決定そのものより、結論文の自己監査と confidence 記法を改善している比重が高いです。

- 探索経路の半固定: NO
- 必須ゲート増: NO（名目上は置換で支払いあり）
- 証拠種類の事前固定: YES
  - 原因文言: 「Name the weakest verdict-critical link」「Confidence may not exceed the verification status of the weakest verdict-critical link.」
  - 理由: verdict-support を必ず weakest-link という特定形式で表現させ、その検証状態を出力行動へ結び付けているため。

## compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  - 観測可能に変わるのは主に CONFIDENCE の下がり方、UNVERIFIED の明示、場合によっては追加探索要求です。
  - 一方、ANSWER 自体を変える明示条件は弱く、同じ provisional verdict のまま残る設計です。

- 1) Decision-point delta:
  - IF/THEN 形式で 2 行（Before/After）になっているか: YES
  - Trigger line（発火する文言の自己引用）が差分プレビュー内にあるか: YES
  - ただし Before/After の実質差は「同じ verdict を出しつつ confidence を縛る」が中心で、結論を出す/保留する/追加探索する分岐の変化が弱いです。compare 影響は中程度以下です。

- 2) Failure-mode target:
  - ターゲットは両方。
  - 机制は「偽 EQUIV / 偽 NOT_EQUIV そのものの減少」より、「両者の過信を減らす」方向です。
  - したがって、誤答修正より calibration 改善に寄っています。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か:
  - NO
  - impact witness 要求の有無: N/A

- 3) Non-goal:
  - structural triage や early NOT_EQUIV 境界を変えない点は明確です。
  - ただし、「比較判断そのものではなく weakest-link 校正だけを触る」という境界の取り方が、逆に compare 改善の弱さにつながっています。

- 追加チェック: Discriminative probe
  - 抽象ケースは提示されていますが、変更前の誤判定を変更後にどう“判定分岐として”避けるかより、「EQUIV のままでも LOW/MEDIUM にする」が中心です。
  - つまり probe は calibration の差は示すものの、compare の意思決定差の説明としては弱いです。

- 追加チェック（支払い）:
  - A/B の対応付けは明示されています: Step 5 の actual-search self-check を外す/弱める代わりに weakest-link confidence cap を入れる。
  - この点は明確です。

## 監査判断
最大のブロッカーは (ii) failed-approaches.md の本質的な再演です。

この proposal は、保留強制ではなく confidence cap だと説明しているものの、実装メカニズムの中心が「結論直前に weakest verdict-critical link を必ず特定し、その未検証性を出力行動へ接続する」ことにあります。これは failed-approaches.md 原則2の警戒点と本質的に近く、compare を強くするより“不確実性の管理を前景化する”方向へ再び最適化しやすいです。

## 修正指示（最小限）
1. weakest-link の必須特定を削り、代わりに既存 Step 5/5.5 の反証チェック内で「いまの verdict を反転させうる未検証依存があるか」を optional な局所補助に下げてください。
   - 追加するなら、現在の self-check 1 行を置換する形に留め、結論直前の新しい既定分岐にはしないこと。

2. compare に効くよう、confidence 校正ではなく decision-point delta を 1 つだけ具体化してください。
   - 例: どの条件で「結論を出す」から「追加で探す」に分岐が変わるのかを、Before/After で条件と行動の両方が変わる形にする。
   - 逆に、same verdict + lower confidence に留まる変更なら採用しない方がよいです。

3. 支払いは維持しつつ、証拠種類を weakest-link へ固定しないでください。
   - 置換先は「最弱リンク命名」ではなく、既存の refutation search をより verdict-discriminative にする方向の統合が望ましいです。

承認: NO（理由: failed-approaches.md 原則2の本質的再演であり、compare への実効差が calibration 偏重で弱い）
