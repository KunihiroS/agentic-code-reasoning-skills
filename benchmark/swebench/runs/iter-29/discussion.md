# iter-29 discussion

## 総評
提案の主眼は「結論規則」ではなく、「semantic difference を見つけた後、relevance 未確定なら次にどこを読むか」という探索優先順位の差し替えにあります。これは compare の実行時挙動を実際に変える提案であり、監査 rubic 向けの説明強化だけに留まっていません。変更規模も小さく、研究コア（premises / hypothesis-driven exploration / interprocedural tracing / refutation）を壊していません。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

この提案は「観測側の証拠を先に取りに行くと relevance の誤推定が減る」という、SKILL.md と design.md の既存方針（test outcome に結びつく tracing を優先する、差分を assertion に接続して評価する）で十分に根拠づけられます。特定の学説・用語定義・外部手法への強依存は見当たりません。

## 2. Exploration Framework のカテゴリ選定
判定: 適切（B: 情報の取得方法を改善する）

理由:
- 提案が変えるのは「何を結論するか」ではなく「relevance 未確定時に何を先に読むか」です。
- これは Objective.md の B「探索の優先順位付けを変える」に直接対応します。
- A（順序・構造）とも近いですが、compare 全体の段取り変更ではなく、局所的な読取優先順位の差し替えなので B の方が自然です。

## 3. compare 影響の実効性チェック
0) 実行時アウトカム差
- 観測可能に変わる点: semantic difference 発見後、追加探索先が「差分実装の深掘り」から「その差分を最初に観測しうる test assertion / test-side call entry」へ先に切り替わる。
- その結果、ANSWER の出し方として、relevance 未確定のまま差分を重く見て NOT_EQUIVALENT へ寄るケース、または差分吸収を早合点して EQUIVALENT へ寄るケースの両方で分岐が変わりうる。

1) Decision-point delta
- IF/THEN 形式で 2 行（Before/After）になっているか: YES
- Trigger line（発火する文言の自己引用）が差分プレビュー内にあるか: YES
- 実効差分の評価: 条件も行動も変わっているので、理由の言い換えだけではない。compare 影響は十分ある。

2) Failure-mode target
- 対象: 両方
- 偽 NOT_EQUIV の低減メカニズム: コード側の差分を見た時点で「効きそう」と見積もる早合点を減らし、実際に assertion 境界で吸収されるかを先に見る。
- 偽 EQUIV の低減メカニズム: 差分が本当に test から観測される経路を先に押さえることで、「たぶん影響しない」の楽観を減らす。

2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？
- NO
- よって impact witness 要件での追加ブロックは発生しない。

3) Non-goal
- 変えないことは明確です。STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を再定義しない、UNVERIFIED 側への新規 fallback を増やさない、CLAIM D のような既存ラベルを増設しない、という境界が書かれています。
- この境界設定は「探索経路の半固定」「必須ゲート増」「証拠種類の事前固定」を避ける意図として妥当です。

### Discriminative probe
- 抽象ケースは十分あります。内部差分が一部テストでは assertion 前に吸収され、別のテストでは return 値比較で露出するケースでは、変更前は code-side divergence の印象に引っ張られて偽 NOT_EQUIV または偽 EQUIV を起こしやすい。
- 変更後は「最初の観測点を先に見る」ので、同じ semantic difference でも test ごとに relevance を分けて扱いやすくなる。これは新しい必須ゲート追加ではなく、既存の relevant-test 同定文と semantic-difference 周辺の優先順位を置換する説明として成立しています。

### 支払い（必須ゲート総量不変）の確認
- A/B の対応付けは明示されています。追加 MUST と、既存の changed symbol 参照検索への寄りを demote/remove する支払いが proposal に書かれています。
- この点は compare 停滞回避として重要で、今回の proposal は条件を満たしています。

## 4. EQUIVALENT / NOT_EQUIVALENT の両方向への作用
### EQUIVALENT 側
- 改善見込み: 差分実装の深掘りだけで「何か違うから危ない」と寄る誤判定を減らせる。
- 実効差分: assertion 境界や test-side call entry を先に見て、差分が既存テストで観測されないなら EQUIVALENT の根拠を test outcome ベースで固めやすくなる。

### NOT_EQUIVALENT 側
- 改善見込み: 差分の観測点を先に確認することで、実際にどの assertion が割れるかを早く掴みやすくなる。
- 実効差分: 「差分はあるが relevance は後で考える」から、「relevance を先に観測点で確定してから差分を分類する」へ変わるため、具体的 counterexample 候補の立ち上がりが早くなる。

### 片方向最適化の懸念
- 明白な片方向最適化ではありません。EQUIVALENT だけを守る保守化でも、NOT_EQUIVALENT だけを増やす差分偏重でもなく、relevance 判定の位置を前倒しする提案です。
- ただし、文言が広すぎると「常に test 側から読め」という半固定経路に誤実装される恐れはあります。したがって trigger を proposal の通り「semantic difference is found but its test impact is unclear」に限定するのが重要です。

## 5. failed-approaches.md との照合
総評: 本質的再演ではない。

- 原則1「再収束を比較規則として前景化しすぎない」: NO
  - 提案は再収束の規範化ではなく、relevance 未確定時に観測点を先に読む優先順位変更です。
- 原則2「未確定な relevance や脆い仮定を、常に保留側へ倒す既定動作にしすぎない」: NO
  - proposal 自身が UNVERIFIED 既定化や保留ガード追加を non-goal として明示しており、この失敗を避けています。
- 原則3「差分の昇格条件を新しい抽象ラベルや必須の言い換え形式で強くゲートしすぎない」: NO
  - CLAIM D の維持はあるが、新ラベル追加や新しい再記述ゲートの増設ではなく、その前段の読取順変更です。

## 6. 停滞診断（必須）
- 懸念点 1つだけ: proposal は監査 rubic に刺さる説明は十分ですが、実装時に Trigger line が compare 本文のどこへ入るかが曖昧だと、「良い説明だけ書かれて実際の読取分岐は変わらない」停滞が起こりえます。今回は差分プレビューと payment があるため許容範囲ですが、実装では relevant tests 同定文と semantic difference 周辺のどちらに主置換するかをぶらさないでください。

### failed-approaches 該当性の YES/NO
- 探索経路の半固定: NO
- 必須ゲート増: NO
- 証拠種類の事前固定: NO

補足:
- 「nearest candidate test assertion or test-side call entry」を唯一の正当証拠にしてしまうと証拠種類の事前固定に寄りますが、proposal は lexical-reference 起点や CLAIM D を残しており、そこまで固定していません。

## 7. 汎化性チェック
判定: 問題なし

- proposal 内に、具体的な数値 ID、ベンチマーク対象リポジトリ名、特定テスト名、実リポジトリのコード断片は含まれていません。
- 含まれている引用は SKILL.md 自身の文言であり、Objective.md の R1 減点対象外に該当します。
- 提案内容も特定言語や特定フレームワークに依存せず、「差分の観測点をどこに置くか」という汎用的な比較原則です。
- 暗黙のドメイン依存も比較的薄いです。test assertion / call-site という表現は単体テスト文化にやや寄りますが、既存 compare 定義自体が shared test specification 基準なので許容範囲です。

## 8. 全体の推論品質への期待効果
- relevance の誤推定を減らせるので、compare の中核である「どの差分が既存テスト outcome に効くか」の解像度が上がります。
- 既存の CLAIM D や per-test analysis と競合せず、その前段でより情報量の高い探索順に寄せるため、研究コアを維持したまま局所改善になっています。
- diff も小さく、複雑性増加よりは既存指示の偏り修正に近いので、回帰リスクは相対的に低いです。

## 修正指示（最小限）
1. Trigger の適用条件を proposal のまま明示的に限定してください。
   - 「semantic difference is found but its test impact is unclear」の時だけ発火するようにし、「常に test assertion から読む」と読める一般化は避ける。
2. Payment を実装で必ず守ってください。
   - 新 MUST を足すだけでなく、既存の「changed symbol を参照する test を探す」文は mandatory 性を下げるか統合して、必須ゲート総量を増やさない。
3. 「nearest candidate」の意味だけ少し具体化してください。
   - 空間的に近い、ではなく「その差分を最初に観測しうる assertion / call entry」と読めるようにして、実装のズレを防ぐ。

## 結論
この proposal は、監査向けの説明追加ではなく compare の実行時分岐を実際に変える提案になっています。failed-approaches.md の本質的再演でもなく、EQUIVALENT / NOT_EQUIVALENT の両側に作用しうる点も明確です。最大の注意点は、局所トリガー付きの優先順位変更として実装し、test-side exploration の一般義務化に膨らませないことです。

承認: YES
