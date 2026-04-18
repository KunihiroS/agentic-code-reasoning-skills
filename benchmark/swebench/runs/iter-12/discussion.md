# Iteration 12 — discussion

## Web search
- 検索なし（理由: 今回の論点は SKILL.md 内の compare 分岐条件の置換が、Objective の Exploration Framework と failed-approaches の汎用失敗原則に整合するかどうかであり、一般原則の範囲で自己完結しているため）

## 総評
提案は compare の意思決定点を実際に動かそうとしており、監査向けの言い換えだけではありません。Decision-point delta と Trigger line も入っており、その点は今回の運用ルールに適合しています。

ただし、中核の変更内容が failed-approaches.md の「既存の判定基準を、特定の観測境界だけに過度に還元しすぎない」にかなり近く、clear structural gap を "VERIFIED relevance link to relevant tests" という単一境界へ狭く再定義しているのが最大の問題です。これは偽 NOT_EQUIV を減らす方向には効きうる一方、構造差そのものが強い反例である場面の初動を鈍らせ、compare の自由な探索・判定を別の意味で細らせる懸念があります。

## 1) 既存研究との整合性
- 研究コア（番号付き前提、仮説駆動探索、手続き間トレース、反証必須）を壊す変更ではありません。README.md と docs/design.md の主眼である「証拠に基づく半形式推論」の範囲内です。
- ただし本提案は、研究コアの追加強化というより compare テンプレート内のローカルなショートカット条件の再定義です。研究のコアを踏襲してはいるが、改善の良し悪しは failed-approaches との距離でほぼ決まります。

## 2) Exploration Framework のカテゴリ選定
- 判定: 概ね妥当
- 理由: 提案の本体は「NOT_EQUIV 直行の発火条件と、その前後の分岐順序を変える」ことなので、Objective.md の A. 推論の順序・構造を変える に入れるのは自然です。
- ただし実態としては、順序変更だけでなく「何を決定打と見なすか」の再定義も含みます。ここが failed-approaches 上の危険点です。

## 3) EQUIVALENT / NOT_EQUIVALENT 両方向への作用
- NOT_EQUIVALENT 側:
  - 改善見込み: 関連テストとの接続未検証の構造差で即断しにくくなるため、偽 NOT_EQUIV は減りうる。
  - 悪化懸念: 構造差自体が強い非同値シグナルであるケースでも、VERIFIED relevance link が明示できない間は直行できず、判断が鈍る。
- EQUIVALENT 側:
  - 提案文は「UNVERIFIED のまま EQUIV を言い切る経路も抑制」と書くが、実効差はやや間接的です。After で直接変わるのは "NOT_EQUIV に直行するか" の条件であり、EQUIV 判定の積極条件は変わっていません。
  - そのため、両方向に効くという主張は完全に空ではないが、主作用は偽 NOT_EQUIV 抑制で、偽 EQUIV 改善は副次的です。
- 結論: 片方向専用ではないが、実効差は非対称です。両方向改善を言うなら、EQUIV 側で何が分岐として変わるかをもう一段具体化すべきです。

## 4) failed-approaches.md との照合
- もっとも強い抵触候補は failed-approaches.md 11-12 行目の原則です。
  - そこでは、既存の判定基準を「特定の観測境界に写像できたときだけ有効」と狭く定義し直す失敗を明示的に避けています。
  - 今回の提案は、まさに structural gap を "relevant tests への VERIFIED relevance link" があるときだけショートカット可、という単一境界へ再定義しています。
- failed-approaches.md 29 行目の「未検証要素の有無を見張る専用トリガへ置き換える変更も同類」にも近いです。
  - Trigger line の "If relevance is UNVERIFIED, do not short-circuit" は、未検証状態を専用トリガにして結論を保留させる形になっています。
- よって、表現を変えた別案というより、本質的にはブラックリストの再演寄りです。

## 5) 汎化性チェック
- 具体的な数値 ID / リポジトリ名 / テスト名 / 実コード断片:
  - 問題なし。proposal 内の引用は SKILL.md 自身の文言であり、Objective.md の R1 減点対象外に当たります。
- 暗黙のドメイン前提:
  - ややあり。"relevant test imports/calls the missing file/module" という説明は一般化可能ではあるものの、import/call path を中心に relevance を捉える傾向が強く、設定駆動・データ駆動・生成物依存・非直接参照のテスト関連性をやや過小評価しうる。
- 判定: 汎化性違反まではいかないが、relevance の観測境界が少し狭い。

## 6) 全体の推論品質向上の期待
- 良い点:
  - 曖昧な "clear structural gap" を、そのまま即断の免罪符にしない方向は、compare の雑なショートカット抑制として筋が良いです。
  - Trigger line と差分プレビューがあり、実装ズレも起きにくいです。
- 限界:
  - 改善の核が「構造差を有効と認める境界の狭化」なので、推論品質全体の改善というより、特定の誤判定型に対する局所補正に寄りすぎています。
  - その局所補正の仕方が failed-approaches の禁止方向に近いため、そのまま通すのは危険です。

## 停滞診断
- 懸念 1 点: compare の意思決定は確かに変わるが、変えているのは主に "NOT_EQUIV 直行の許可条件" だけで、ANALYSIS の中でどんな追加情報が得られれば EQUIV/NOT_EQUIV のどちらへ収束しやすくなるのかまでは再設計していません。結果として、監査 rubric には刺さるが、実運用では "直行しないまま低信頼で悩む" 停滞に寄る可能性があります。
- 「探索経路の半固定」に該当するか: NO
- 「必須ゲート増」に該当するか: NO
- 「証拠種類の事前固定」に該当するか: YES
  - 原因文言: "If S2 yields a VERIFIED relevance link to relevant tests ..." と、それを唯一のショートカット発火条件へ格上げしている部分。構造差の有効性を、事実上この証拠タイプへ寄せています。

## compare 影響の実効性チェック
- 1) Decision-point delta:
  - IF/THEN 形式で 2 行（Before/After）になっているか？: YES
  - Trigger line が差分プレビュー内に含まれているか？: YES
  - 実効性評価: 条件も行動も一応変わっています。ただし変化の軸が "構造差 -> relevance link" という単一境界への置換なので、compare 影響はあるが危ういです。
- 2) Failure-mode target:
  - 主対象: 偽 NOT_EQUIV
  - 副対象: 偽 EQUIV
  - メカニズム: 接続未検証の構造差で即断しないようにすることで過剰反応を減らす。だが偽 EQUIV 改善は indirect で、積極的に EQUIV 判定を変える分岐は弱い。
- 3) Non-goal:
  - 読解順序の固定や MUST 追加は避けている点は良い。
  - ただし "構造差の効力を relevance link へ集約しない" という境界条件が proposal に欠けているため、自由度維持の線引きが足りません。
- Discriminative probe:
  - 抽象ケース: 片側だけに補助モジュール更新があり、そのモジュールはテストから直接 import されないが、実行時設定や登録機構を通じて観測結果に影響する。
  - 変更前は structural gap を手掛かりに NOT_EQUIV 疑いを強く持てる。変更後は VERIFIED relevance link がないため直行を止められ、ANALYSIS に進むが、提案自体はこの種の非直接 relevance をどう拾うかを強化していない。よって誤判定回避が保証されません。
- 支払い（必須ゲート総量不変）:
  - この提案は新しい MUST を増やしていないため、A/B の支払い対応は必須ではありません。

## 修正指示
1. "VERIFIED relevance link のときだけ structural shortcut 可" という単独条件への置換はやめ、clear structural gap の例示として "relevant tests への verified connection がある場合は特に強い" へ弱めてください。
   - 追加ではなく置換で対応すること。
   - structural gap の有効性そのものを単一境界へ還元しないでください。

2. Trigger line は維持しつつ、"UNVERIFIED なら ANALYSIS 継続" を専用トリガとして固定するのでなく、"UNVERIFIED alone is insufficient for shortcut" 程度に弱めてください。
   - これなら未検証専用ゲート化を避けつつ、雑な即断だけ抑えられます。

3. 両方向への効きを本当に主張するなら、EQUIVALENT 側の分岐も 1 行で明示してください。
   - 追加セクションを増やすのではなく、既存の Failure-mode target か 期待される挙動差 の記述を統合・置換して、"After では何が見つからなければ EQUIV 側の確信がどう変わるか" を短く具体化してください。

## 結論
承認: NO（理由: failed-approaches.md の「既存の判定基準を特定の観測境界だけに過度に還元しすぎない」の本質的再演になっているため）
