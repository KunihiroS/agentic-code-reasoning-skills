# Iteration 14 Discussion

## 総評
提案の核は、compare の per-test tracing を「各 change を前向きに個別追跡してから比較する」既定から、「verdict-setting assertion/check を先に固定し、その直前の判定ピボットを両 change で並べて比較する」既定へ置換する点にあります。これは監査向けの説明追加ではなく、compare 実行時の分岐点そのものを変える提案です。

結論として、この proposal は PASS の下限を満たしつつ compare 改善に結びつく具体性があります。failed-approaches.md の本質的再演にも当たりません。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

README.md / docs/design.md が強調する研究コアは、番号付き前提・仮説駆動探索・手続き間トレース・必須反証・per-item iteration です。本提案はこれらを削らず、compare 内の per-test iteration の開始点だけを置き換えるものなので、研究コアと整合しています。特に docs/design.md の「per-item iteration as the anti-skip mechanism」を壊しておらず、item は依然として relevant test のままです。

## 2. Exploration Framework のカテゴリ選定
カテゴリA「推論の順序・構造を変える」が最も適切です。

理由:
- 変更対象が compare の tracing order そのものだから
- 新しい証拠種別や抽象ラベルを導入するより、既存の per-test analysis の起点を入れ替える提案だから
- Objective.md のカテゴリ定義にある「結論から逆算して必要な証拠を特定する（逆方向推論）」に直接一致するから

副次的にカテゴリB要素（探索優先順位の変更）もありますが、主作用は情報取得法ではなく意思決定順序の再設計です。

## 3. EQUIVALENT / NOT_EQUIVALENT 両方向への作用
片方向最適化ではありません。

- EQUIVALENT 側:
  下流の構造差や patch 形状差が目立っても、assertion を左右する最短ピボットで両 change が同値なら、不要な偽 NOT_EQUIV を減らせます。
- NOT_EQUIVALENT 側:
  見かけ上の再収束や長い前向き trace に埋もれる前に、assertion を分ける分岐が見つかれば、偽 EQUIV を減らせます。

実効的差分は「何を読んだか」の説明の仕方ではなく、「どの条件で結論を出すか／追加探索に回すか」の順序にあります。したがって compare の runtime outcome に観測可能な差が出ます。

## 4. failed-approaches.md との照合
本質的再演ではありません。

- 原則1「再収束を比較規則として前景化しすぎない」: 再収束を救済規則として強化する方向ではなく、むしろ下流再収束より先に判定ピボットを見る提案なので逆向きです。
- 原則2「未確定な relevance や脆い仮定を常に保留側へ倒しすぎない」: UNVERIFIED/保留トリガーを増やしていません。
- 原則3「差分の昇格条件を新しい抽象ラベルで強くゲートしすぎない」: 新しい昇格ゲートは増やしておらず、比較開始点の置換に留まっています。

ただし注意点として、実装時に「まず assertion/check 以外を見てはいけない」のような強い一本道にすると、failed-approaches.md にない別種の探索硬直を招きます。proposal 自体はそこまで言っていないので許容範囲です。

## 5. 汎化性チェック
違反は見当たりません。

- 具体的な数値 ID: なし
- 特定リポジトリ名: なし
- 特定テスト名: なし
- ベンチマーク実コード断片: なし

含まれているのは SKILL.md 自身の文言引用と抽象的な compare テンプレートだけで、Objective.md の R1 減点対象外に収まります。

暗黙のドメイン前提についても、assertion/check と upstream decision は言語非依存・フレームワーク非依存の一般概念です。例外として、oracle が単一 assertion ではなく複数観測点の総和で決まるテストでは「verdict-setting assertion/check」を広く解釈する必要がありますが、これは汎化性違反ではなく実装時の書き方の問題です。

## 6. 全体の推論品質への期待効果
期待できる改善は次の通りです。

- 前向き全追跡のコストを下げ、relevant test ごとの識別力を上げる
- 「patch 形状差は大きいが verdict は同じ」ケースで偽 NOT_EQUIV を減らす
- 「見かけ上は再収束するが assertion 境界では分岐する」ケースで偽 EQUIV を減らす
- compare を、構造差の説明や長い trace の記述量ではなく、test oracle に近い証拠で駆動させる

## 停滞診断
- 懸念点 1つだけ: 「assertion/check を先に固定する」という説明が監査 rubric には刺さりやすい一方、実装文言が弱いと agent が単に記述順を言い換えるだけで、実際の compare の分岐を変えない恐れはあります。ただし本 proposal は Trigger line と Payment を明記しており、この懸念はかなり抑えられています。

failed-approaches 該当性:
- 探索経路の半固定: NO
- 必須ゲート増: NO
- 証拠種類の事前固定: NO

補足: 本 proposal は「assertion/check と nearest upstream decision を優先して見る」既定を置くが、他の証拠を禁止しておらず、また新しい通過ゲートも増やしていないため、上の3類型には当たりません。

## compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  - 追加探索へ進む条件が変わる。前向き trace を長く続ける前に、判定ピボットが一致すれば早く EQUIV に寄り、不一致なら早く counterexample 候補へ寄る。
  - NOT_EQUIV の出し方が変わる。patch 形状差ではなく、assertion を分ける pivot 差が観測されたときに結論しやすくなる。

- 1) Decision-point delta:
  - IF/THEN 形式で 2 行（Before/After）になっているか: YES
  - Before/After が分岐として変わっているか: YES
  - Trigger line（発火する文言の自己引用）が差分プレビューに含まれているか: YES

- 2) Failure-mode target:
  - 対象: 両方
  - メカニズム: 偽 EQUIV は「下流再収束を先に見てしまう」ことで起きやすく、偽 NOT_EQUIV は「構造差や追跡量の差を先に見てしまう」ことで起きやすい。提案はその両方を、assertion 直近の識別的 pivot へ比較の起点を寄せることで減らす。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か: NO
  - impact witness の要求有無: N/A

- 3) Non-goal:
  - relevant test ごとの per-test iteration は維持する
  - 新しい保留ゲートや UNVERIFIED 優先規則は増やさない
  - 証拠種別を assertion/check のみに固定せず、未解決時は下流展開を許す

追加チェック:
- Discriminative probe:
  - 抽象ケースとして、「片方は upstream 分岐条件を変更、もう片方は downstream 正規化を変更」では、変更前は前向き trace が再収束に引っ張られて偽 EQUIV、あるいは構造差に引っ張られて偽 NOT_EQUIV になりうる。
  - 変更後は、assert を直接反転させうる nearest pivot を先に比較するので、同値なら EQUIV、分岐するなら NOT_EQUIV を早く切り分けられる。これは新ゲート追加ではなく tracing order の置換で説明されている。

- 停滞対策の検証:
  - 「支払い（必須ゲート総量不変）」の A/B 対応付けが proposal 内で明示されているか: YES
  - 内容: 新しい MUST を足す代わりに、既存の MUST「Trace each test through both changes separately before comparing」を demote/remove する Payment が書かれている。

## 最小修正指示
1. 「verdict-setting assertion/check」は単一 assert に限定されず、test outcome を決める最終観測境界全般を指す、と 1 行だけ補うとよい。
2. 実装時は “first” を「唯一の開始点」ではなく「既定の優先開始点」と読めるようにし、探索硬直を避けること。

## 最終判定
承認: YES