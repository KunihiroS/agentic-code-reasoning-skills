# iter-40 discussion

## 総評
この提案は、compare における既存の弱点「semantic difference を見つけても、途中の直観で no impact と切り上げてしまう」を、結論ではなく行動分岐の変更として狙っており、監査 PASS の下限は満たしています。変更規模も 1 行置換に留まり、研究コア（前提・仮説駆動探索・手続き間トレース・必須反証）を壊していません。

Web 検索: 検索なし（理由: proposal の根拠は README.md / docs/design.md / SKILL.md / failed-approaches.md の範囲で自己完結しており、特定概念の外部妥当性確認が必須なほど強い新規主張ではない）

## 1. 既存研究との整合性
整合しています。README.md と docs/design.md では、paper のコアは「明示的 premises」「per-item tracing」「counterexample obligation」「incomplete reasoning chains / subtle difference dismissal の抑制」にあります。今回の提案は compare の既存 bullet

- "When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact"

を、downstream 観測点まで届く追跡に具体化するものです。これは paper/design の anti-skip / incomplete-chain 防止を compare 側へ少し強める方向で、研究コアからの逸脱ではありません。

## 2. Exploration Framework のカテゴリ選定
カテゴリ F（原論文の未活用アイデアを導入する）は概ね適切です。
理由:
- localize / explain 由来の「途中で止めず観測可能な地点まで追う」という発想を compare に移している
- error analysis の "subtle difference dismissal" と "incomplete reasoning chains" を、compare の no-impact 分岐に適用している
- 変更の中心が compare の判定分岐の質向上であり、単なる wording polish（E）や自己監査追加（D）ではない

補足すると、実体は F 寄りの B（情報の取得方法の改善）でもありますが、主たる根拠づけは paper の未反映知見の移植なので F でよいです。

## 3. compare 影響の実効性チェック
0) 実行時アウトカム差
- 「semantic difference ありだが no impact」と早期に書いていた実行が、少なくとも 1 回は downstream 観測点までの追加追跡を要求される
- その結果、EQUIVALENT を即断せず、追加探索 / CONFIDENCE 低下 / NOT_EQUIVALENT 反転のいずれかが観測可能に増える

1) Decision-point delta
- IF/THEN 形式で 2 行（Before/After）になっているか？: YES
- Trigger line（発火する文言の自己引用）が差分プレビュー内にあるか？: YES
- 実効差分の評価: 条件も行動も変わっています。Before は「意味差があっても途中で no impact に進みがち」、After は「観測点まで同値を示せない限り no impact を保留して追加探索」。理由の言い換えではなく、分岐先が変わっています。

2) Failure-mode target
- 主対象: 偽 EQUIVALENT
- メカニズム: 差分発見後、テスト観測点まで追わず「影響なし」と切り上げることで、実際には outcome 差があるケースを見逃す
- 副作用の扱い: 根拠薄い NOT_EQUIVALENT も抑制しうる。理由は、観測点で再収束しているケースでは no-impact の根拠が強くなり、単なる局所差分だけで different と言い張りにくくなるため

2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？
- NO
- よって、"file 差があるだけで NOT_EQUIV" への退化懸念や impact witness 要求の不足は、この提案の主問題ではありません

3) Non-goal
- 変えないことは比較的明確です。STRUCTURAL TRIAGE の強化・固定化はしない、特定 witness 型への一本化はしない、新しい必須ゲートを純増しない、という境界が書かれています
- この非目標設定は、failed-approaches.md の禁止方向を意識できています

追加チェック: Discriminative probe
- あります。抽象ケースとして「途中では軽微に見えるが、観測点で値分岐する差」を置いており、変更前は偽 EQUIV、変更後は観測点まで追うので回避できる、という比較が 2〜3 行で成立しています
- しかも説明は「既存 1 行の置換」で成立しており、新しい必須ゲートの増設説明になっていません

追加チェック: 支払い（必須ゲート総量不変）
- 明示あり: YES
- 評価: 1 bullet の置換であり、A/B の対応付けも提案文中で明示されています。ここは停滞対策上の要件を満たします

## 4. EQUIVALENT / NOT_EQUIVALENT の両方向への作用
### EQUIVALENT 側
- 変更前: semantic difference を見つけても、「たぶんテストに見えない」と途中で判断し、偽 EQUIVALENT に倒れやすい
- 変更後: downstream 観測点までの到達が必要になるため、観測点で差が出るケースを拾いやすくなる
- 期待効果: 主に偽 EQUIVALENT 減少

### NOT_EQUIVALENT 側
- 良い方向: 単なる局所差分だけではなく、観測点での差まで追う圧力がかかるので、雑な NOT_EQUIVALENT も減らせる余地がある
- 注意点: 「観測点まで示せない = NOT_EQUIVALENT」と読まれると逆効果です。proposal 本文は "保留して追加探索" と書いており、この点は一応回避されています
- 総評: 片方向最適化ではなく両側に作用しうるが、一次効果は明確に EQUIVALENT 側（偽 EQUIV 抑制）です

## 5. failed-approaches.md との照合
本質的再演とはまでは言えません。理由は、この変更が
- 探索の入口全体を固定していない
- compare 全体の読解順序を縛っていない
- 新しい独立ゲートを増やしていない
- 単一 witness 型だけに判定根拠を還元していない
ためです。

ただし、近接リスクはあります。failed-approaches.md は特に以下を警戒しています。
- 「既存の汎用ガードレールを、特定の追跡方向や観点で具体化しすぎない」
- 「既存の判定基準を、特定の観測境界だけに過度に還元しすぎない」

今回の文言は "first downstream observation point" を入れるので、この 2 つに触れやすいです。ただ、適用範囲が「semantic difference を見つけ、しかも no impact で切ろうとする局面」に限定されており、全探索の半固定ではないため、禁止原則の本質的再演とはまだ言いません。

## 6. 汎化性チェック
提案文中に benchmark 固有の数値 ID、リポジトリ名、テスト名、コード断片は含まれていません。違反なしです。

また、想定している観測点は assertion / check / exception と抽象化されており、特定言語・特定テストフレームワークへの依存も強くありません。唯一の懸念は、"observation point" が単体テストの assert に寄りすぎて読まれる可能性ですが、proposal では check/exception まで広げているため、現状は許容範囲です。

## 7. 停滞診断（必須）
- 懸念 1 点: proposal は監査的には説明がよくできていますが、実装時に "observation point" の定義が曖昧なままだと、compare の実行で単に文章が長くなるだけで、実際の追加探索発火率が上がらない恐れがあります。つまり audit-friendly だが runtime decision change が弱まるリスクは少しあります。

- 探索経路の半固定: NO
  - 理由: 発火条件が「semantic difference を見つけ、かつ no impact を言おうとする局面」に限定されており、最初から読む順番や探索入口を固定していない

- 必須ゲート増: NO
  - 理由: 既存 bullet の置換であり、proposal でも MUST の純増なしと明記されている

- 証拠種類の事前固定: NO
  - 理由: 観測点の概念はやや具体化されるが、assertion のみ固定ではなく check / exception を含む。証拠の型を単一に固定してはいない

## 8. 全体の推論品質への期待
この変更は、compare の中でも特に「差分を見つけた後の扱い」の質を上げます。利点は以下です。
- 途中の直観で no impact と切らず、テスト outcome へ接続する証拠密度が上がる
- EQUIVALENT 判定の根拠が「差分があるが軽微そう」から「観測点まで追って再収束を確認した」へ改善する
- NOT_EQUIVALENT 判定も、単なる局所差分ではなく観測点差分を伴う方向へ寄りやすい
- 変更範囲が compare の 1 bullet に限定され、他モードや研究コアへの副作用が小さい

## 修正指示（最小限）
1. Trigger line の observation point を、"the earliest test-relevant observation point on that path" のように少しだけ補い、「assert だけを追う」と誤読されないようにしてください。
2. 同じ 1 行の中か直後の短い補足で、"failure to establish such an observation does not itself imply NOT EQUIVALENT; it requires further tracing or lower confidence" を明示してください。これで逆方向の誤適用を防げます。
3. 追加説明を増やすなら新 bullet を足さず、既存の no-impact bullet の置換だけで完結させてください。支払い総量不変を崩さないためです。

## 結論
承認: YES