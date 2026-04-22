# iter-33 proposal 監査コメント

## 総評
提案の狙い自体は明確です。compare において「意味差を見つけた後の次アクション」を具体化し、粗い per-test trace のまま verdict に進むのを減らそうとしており、監査 rubric の R2/R3/R4 には刺さりやすい内容です。特に Decision-point delta、Trigger line、Payment、Discriminative probe まで書いてあり、単なる説明強化ではなく compare の実行時分岐を変えたい意図は十分あります。

ただし、最大の問題は、提案の中心規則が failed-approaches.md の原則1「再収束を比較規則として前景化しすぎない」の危険域にかなり近いことです。"最初の意味差" の直後に "最初の downstream consumer/handler" を既定の追跡先にする設計は、差分の検出よりも「吸収されるか」を標準読解にしてしまいやすく、過去失敗の本質を再演する懸念が強いです。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

docs/design.md にある "incomplete reasoning chains" を compare 側の具体ルールへ落とし込もうとしている点は研究整合的です。番号付き前提・仮説駆動探索・手続き間トレース・必須反証も壊していません。

## 2. Exploration Framework のカテゴリ選定
カテゴリ F の選定は一応妥当です。根拠は docs/design.md の error analysis / Guardrail #5 を compare の意思決定に移植しようとしているからです。

ただし機構の実体は「原論文未活用アイデアの導入」そのものというより、探索順序の変更です。したがって分類としては F/B の境界にあり、主作用は B（探索の優先順位付け変更）に近いです。カテゴリ誤りとまでは言いませんが、F だから安全という整理にはなりません。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用
変更は両方向に作用します。
- EQUIVALENT 側: 最初の差分を見て即 NOT_EQUIV に寄るのを抑え、下流で吸収されるかを確認させる。
- NOT_EQUIVALENT 側: 最初の差分の受け手で divergence が露出するなら、assertion boundary へ至る反例の足場を早く作れる。

ただし実効上は EQUIVALENT 側への作用がやや強く、NOT_EQUIVALENT 側での利益は「consumer が divergence を露出する」場合に限られます。逆に consumer/handler 確認が既定化すると、差分そのものの判別力を一段 provisional に落としやすく、偽 NOT_EQUIV は減っても偽 EQUIV を増やす回帰リスクがあります。よって「両方に効く」は成立するが、対称性は弱いです。

## 4. failed-approaches.md との照合
最重要懸念は原則1との近接です。

failed-approaches.md の原則1:
- 「最初の差分」と「それを吸収する後段処理」の対提示を既定化すると、吸収の説明を先に組み立てる読み方を誘発しやすい
- Guardrail へ追加すると、局所差を provisional 扱いする方向に過剰適応しやすい

今回の提案はまさに
- 「When Change A and B first diverge ... inspect the first downstream consumer/handler ... before deciding SAME / DIFFERENT」
- 「If that consumer normalizes the divergence ...」
- 「treat the first downstream consumer/handler as the default next inspection point」
を中核にしており、差分発見後の既定動作を downstream 吸収/露出点へ半固定しています。

このため、表現上は「再収束を結論条件にしない」と回避していても、本質的には「再収束・吸収確認を読む規範の既定化」にかなり近いです。ここは wording の違いでは済みにくいです。

## 5. 汎化性チェック
明示的なルール違反は見当たりません。
- 具体的な数値 ID: なし
- ベンチマーク固有のリポジトリ名: なし
- テスト名: なし
- ベンチマーク実コード断片: なし

用語も一般的で、特定言語・特定フレームワークへの露骨な依存はありません。

ただし "consumer/handler" という語は例外処理・パイプライン・中間表現正規化が多いコード様式をやや強く想定します。一般化不能ではないものの、全言語・全設計スタイルに自然に乗るとは限りません。例えば純粋関数的な直列変換や declarative config 主体の差分では、"first downstream consumer/handler" という見方自体がやや人工的です。

## 6. 推論品質の向上見込み
良い点:
- 差分を見つけた後に粗い no-impact 説明で止まる失敗は減らせそうです。
- 「次にどこを読むか」が明確なので、compare の探索が観測可能に変わる提案です。
- Trigger line と Payment があるため、実装差分も小さく保てます。

限界:
- 改善の核が downstream 吸収/露出点への既定誘導なので、差分の初期シグナルを弱める副作用がある。
- compare の判別力改善というより、差分後の読み筋を一方向へ寄せる提案になっている。

## 停滞診断
- 懸念 1 点: 監査 rubric には刺さるが、compare の決定を「よりよくする」というより「差分後は consumer/handler を見る」と読解順を固定する方向に寄っており、誤判定を減らす理由が downstream 吸収/露出の物語に依存しすぎる。

- 探索経路の半固定: YES
  - 原因文言: "inspect the first downstream consumer/handler on that path before deciding SAME / DIFFERENT"
- 必須ゲート増: NO
  - Payment があり、既存 MUST の置換として提案されているため。
- 証拠種類の事前固定: YES
  - 原因文言: "treat the first downstream consumer/handler as the default next inspection point"

## compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  - 差分検出後、すぐ verdict に進まず、first downstream consumer/handler の読解が追加される。
  - SAME / DIFFERENT の根拠位置が、初期差分や粗い test trace から、中間差分を最初に受けるコード点へ移る。

- 1) Decision-point delta:
  - Before: IF 意味差を見つけ、ある test への影響を概略説明できる THEN verdict に寄りやすい
  - After: IF 最初の意味差が中間挙動に現れ、受け手未確認 THEN first downstream consumer/handler を次アクションにする
  - IF/THEN 形式で 2 行になっているか: YES
  - Trigger line の自己引用が差分プレビュー内にあるか: YES

- 2) Failure-mode target:
  - 対象: 両方
  - メカニズム: 偽 NOT_EQUIV は「最初の差分のみで差を過大評価」を減らすことで抑制、偽 EQUIV は「受け手で差が露出するのに no-impact 扱い」を減らすことで抑制

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か:
  - NO

- 3) Non-goal:
  - structural triage の結論条件は変えない
  - 未確定なら広く UNVERIFIED / 保留へ倒す既定動作は増やさない
  - 新しい抽象ラベルで差分昇格をゲートしない

- Discriminative probe:
  - 抽象ケースは成立しています。中間表現差が直後の normalizer で吸収される場合と露出する場合を分けており、変更前の粗い trace では両方向の誤判定が起こりうる、変更後は first consumer/handler 確認で避けやすい、という筋も理解できます。
  - ただし、この probe 自体が「差分の後は normalizer/consumer を見る」という読み筋の有効例になっており、過去失敗の“再収束優先読解”を正当化してしまっている点が懸念です。

- 停滞対策の検証（支払い）:
  - A/B の対応付けは明示されている: YES

## 結論
この proposal は「compare に効く形で具体化されている」という点では良いです。Decision-point delta、Trigger line、Payment、Discriminative probe が揃っており、監査通過のためだけの作文ではありません。

しかし、最大ブロッカーは failed-approaches.md 原則1 の本質的再演に近いことです。差分発見後の既定分岐を "first downstream consumer/handler" に置くのは、結論条件を変えないだけで、実際の読解規範としては「最初の差分と吸収/露出点の対提示」を標準化しています。これは compare を改善する可能性もありますが、過去失敗で警戒されている回帰パターンに非常に近く、このままでは承認できません。

## 修正指示（2-3点）
1. "first downstream consumer/handler を既定の次アクションにする" という半固定を外してください。
   - 追加ではなく置換で修正すること。
   - 例: "first downstream consumer/handler" を唯一の既定先にせず、"difference resolution point" のようなより広い表現にして、normalizer / branch condition / assertion boundary / state read のいずれが最も判別的かを選ばせる形へ弱める。

2. 吸収確認と露出確認を対称化してください。
   - 現状は normalizes 側の記述が前景化しています。
   - "If that consumer normalizes..." を残すなら、同じ強さで "if an earlier branch/assertion boundary already makes outcomes diverge..." を並置し、吸収だけを既定物語にしないこと。

3. Guardrail #5 への寄せ方を弱め、Compare checklist 側の軽い探索優先度指示に留めてください。
   - Guardrail 化は failed-approaches 原則1 の再演リスクを高めます。
   - 支払いを維持したまま、Guardrail 追加ではなく既存 checklist 行の言い換えに閉じる方が安全です。

承認: NO（理由: failed-approaches.md 原則1「再収束を比較規則として前景化しすぎない」の本質的再演に近く、差分発見後の探索経路を downstream consumer/handler へ半固定しているため）