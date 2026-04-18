# iter-13 proposal 監査コメント

## 総評
提案の狙い自体は妥当です。pass-to-pass の関連性を「名前参照が見つからない」だけで空集合扱いすると、間接到達テストを落として偽 EQUIV を出しやすい、という問題設定は compare の実務上もっともらしいです。加えて、提案文は固有のケース ID・リポジトリ名・テスト名・実コード断片に依存しておらず、汎化性の面でも大きな違反は見当たりません。

ただし、この proposal の中心トリガ

- "If reachability is UNVERIFIED, do not treat pass-to-pass as empty; keep exploring or narrow the conclusion and set CONFIDENCE=LOW."

は、failed-approaches.md が警戒している「未検証要素の有無を見張る専用トリガ」にかなり近いです。探索経路を直接固定していない点は良いのですが、compare の結論直前に局所的な未検証状態を専用監視して保留/縮小へ倒す構造になっており、偽 EQUIV を減らす代わりに、EQUIV 側の決め切りを系統的に弱める回帰リスクがあります。このため現状のままでは承認しません。

## 1) 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）

この提案は、新規理論の導入というより、既存の semi-formal reasoning の中で「負の証拠の扱い」と「未検証状態の結論反映」を compare にどう埋め込むかの調整です。README.md / docs/design.md / SKILL.md だけで十分評価できます。

## 2) Exploration Framework カテゴリ選定
判定: 概ね適切

- proposal は「何を探すか」の固定ではなく、「見つからない」をどう解釈するかという取得・判定の仕方を変えようとしている。
- したがって主分類は B. 情報の取得方法を改善する でよい。
- ただし実際の差分プレビューは D2 の取得説明だけでなく Step 5.5 の自己チェック側にも効かせており、実装の効き方は B 単独より「B 寄りだが D にもまたがる」。

## 3) EQUIVALENT / NOT_EQUIVALENT の両方向への作用
### EQUIVALENT 側
- 明確に効きます。従来の「参照が見つからない → pass-to-pass 無関係 → EQUIV に進む」を弱めるため、偽 EQUIV は減りうる。
- 一方で、到達性 UNVERIFIED が残りやすいケースでは、正しい EQUIVALENT まで LOW/条件付き/保留に寄せやすい。

### NOT_EQUIVALENT 側
- proposal 文面上は、UNVERIFIED を理由に直ちに NOT_EQUIVALENT へ倒すわけではないため、片方向最適化は露骨ではない。
- ただし「追加探索 or 条件付き結論」への偏りが強いので、NOT_EQUIVALENT を出すための反例構築そのものを改善する変更ではない。主作用は偽 EQUIV 抑制で、NOT_EQUIVALENT 側は間接効果に留まる。

### 実効差分の評価
- 変更前: 負の参照検索が pass-to-pass 非関連の近似根拠として機能しやすい。
- 変更後: reachability=UNVERIFIED を独立の観測状態として扱い、空集合扱いを止める。
- よって実効差分はある。
- ただしその差分が「より良い反例探索」ではなく「未検証なら結論縮小」に寄っているため、compare 改善としては守り寄りです。

## 4) failed-approaches.md との照合
### 本質的再演か
判定: かなり近い

特に近いのは次の原則です。

- 「結論直前の自己監査に、新しい必須のメタ判断を増やしすぎない」
- 「既存の結論基準を、未検証要素の有無を見張る専用トリガへ置き換える変更も同類」
- 「証拠の種類をテンプレで事前固定しすぎる変更は避ける」

今回の提案は証拠種類を reference/import/call-path の3種に固定“必須化”してはいません。この点はセーフです。

しかし中核は「reachability が UNVERIFIED なら空集合扱い禁止・結論縮小」という専用トリガです。これは failed-approaches.md が警戒する「未検証要素監視による保留方向への過剰適応」にかなり重なります。D2 定義の局所修正に見えても、compare 実行時には事実上の新しい結論ゲートとして作用しうるのが懸念です。

## 5) 汎化性チェック
判定: 合格

- 具体的な数値 ID: なし
- ベンチマーク対象リポジトリ名: なし
- テスト名: なし
- ベンチマーク実コード断片: なし
- 特定言語/特定フレームワーク前提: なし

注意点として、"reference, import, traced call path" という例示は静的言語/動的言語をまたいで概ね一般化可能ですが、import を前面に出しすぎると「import があれば reach」と短絡される危険はあります。ここは例示の粒度をさらに抽象化した方が無難です。

## 6) 期待される推論品質の向上
見込みはあります。

- 負の探索結果を過信しない、という compare の弱点補正になる。
- pass-to-pass の見落としによる早期 EQUIV を減らす可能性がある。
- 「関連テストがない」という強い主張のハードルを少し上げる点は、反証可能性の維持にも整合する。

ただし改善の主成分が「保留/縮小」なので、推論の識別性能を上げるというより、結論を慎重化する方向に寄っています。compare の精度改善として通すなら、未検証時の扱いを増やすより、「負の参照検索だけでは D2 を満たしたとみなさない」という定義精緻化に留めた方が安全です。

## 停滞診断（必須）
- 懸念点 1つ: 提案は compare の意思決定点を変えてはいるが、その主作用が「よりよく区別する」より「未検証なら縮小する」に寄っており、監査 rubric には刺さる一方で compare の識別力改善が弱く、説明強化に寄って停滞する恐れがある。

### failed-approaches 該当性
- 探索経路の半固定: NO
- 必須ゲート増: YES
  - 原因文言: "If reachability is UNVERIFIED, do not treat pass-to-pass as empty; keep exploring or narrow the conclusion and set CONFIDENCE=LOW."
  - 理由: MUST/required の語を増やしていなくても、compare 結論前に専用トリガを追加しており、実質ゲート化している。
- 証拠種類の事前固定: NO

## compare 影響の実効性チェック（必須）
- 1) Decision-point delta
  - Before/After が IF/THEN 2行形式になっているか: YES
  - Trigger line が差分プレビュー内に自己引用されているか: YES
  - 評価: 条件も行動も変わっており、理由の言い換えだけではない。ただし行動変化の中身が「追加探索/縮小」で、識別能力向上より慎重化に寄る。

- 2) Failure-mode target
  - 主対象: 偽 EQUIV
  - メカニズム: 「負の参照検索」を「到達不能」の証拠と見なす短絡を止め、pass-to-pass の取りこぼしを防ぐ。
  - 副作用懸念: 正しい EQUIVALENT でも UNVERIFIED を理由に決め切れず、偽 NOT_EQUIV というより低確信・条件付き結論の増加を招く。

- 3) Non-goal
  - 読解順序は固定しない。
  - 特定証拠タイプを必須化しない。
  - 必須ゲート総量は増やさない、という境界を守るべき。
  - ただし現文面は最後の境界を実質的に破りかけている。

### Discriminative probe
抽象ケース: テストが変更シンボルを直接参照しないが、間接呼び出しで変更箇所に到達する。変更前は direct reference 不在だけで pass-to-pass を外し、EQUIV に誤寄りしやすい。変更後は「負の参照検索だけでは外せない」という D2 の定義精緻化なら誤りを減らせる。だが現 proposal のように UNVERIFIED 専用トリガで保留/縮小まで義務づけると、正しい EQUIV まで決めにくくする恐れがある。

### 支払い（必須ゲート総量不変）確認
- proposal では「支払い不要」と主張しているが、実質上は新しい結論トリガを入れているため、この説明では不十分。
- A/B の対応付けが不要な純置換にするなら、Step 5.5 への波及をやめ、D2 の定義文だけを置換する形に狭めるべき。

## 最大のブロッカー
failed-approaches.md の「未検証要素の有無を見張る専用トリガ」型の失敗を、reachability=UNVERIFIED という局所版で再演していること。

## 修正指示（2〜3点）
1. Step 5.5 連動を削り、D2 の定義精緻化だけに縮めてください。
   - 追加するなら「負の reference 検索のみで pass-to-pass を空集合扱いしない」まで。
   - 削る対象は "keep exploring or narrow the conclusion and set CONFIDENCE=LOW" の後半。

2. Trigger line を「未検証なら縮小」ではなく「negative reference search alone is insufficient to rule out pass-to-pass relevance」という定義文へ置換してください。
   - これなら compare の分岐点は保てる一方、新しい結論ゲート化を避けやすいです。

3. もし LOW/confidence 連動を残したいなら、どの既存文言を optional 化/統合して総量不変にするかを proposal 内で明示してください。
   - 現状の「支払い不要」は通りません。

## 結論
承認: NO（理由: reachability=UNVERIFIED を専用トリガにした結論縮小ルールが、failed-approaches.md の本質的再演に近く、compare を改善するというより新しい実質ゲートを増やしているため）
