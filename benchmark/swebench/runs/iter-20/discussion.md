# Iteration 20 — proposal監査 discussion

## 総評
この提案は、Exploration Framework の G. 認知負荷の削減（簡素化・削除・統合）として妥当です。研究コアである「番号付き前提、仮説駆動探索、手続き間トレース、必須反証」は維持したまま、compare 実行の末尾で重複している独立ゲートを certificate 内の要約へ統合する提案になっています。

監査上の重要点として、これは単なる説明強化ではなく、compare 実行時の分岐を実際に変える提案です。具体的には「template を埋めた後、別個の必須 self-check で結論を止める」既定動作を弱め、「未検証点を結論と CONFIDENCE に吸収して前進する」既定動作へ置き換えるため、観測可能なアウトカム差があります。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）

補足: README.md / docs/design.md の要旨は、structured certificate により推論の飛躍を防ぐことにあります。本提案はその certificate 自体を捨てるのではなく、重複ゲートを template 内へ統合するものなので、研究コアとは整合的です。

## 2. Exploration Framework のカテゴリ選定
判定: 適切

理由:
- 提案の中心は「Step 5.5 の独立セクション削除」「Compare checklist の recap 化」であり、新しい探索経路や新ラベル追加ではない。
- Objective.md の G カテゴリにある「重複する指示や冗長な説明を統合・圧縮する」にそのまま対応している。
- Non-goal で STRUCTURAL TRIAGE / relevant tests / 早期 NOT_EQUIV 根拠境界を変えないと明示しており、簡素化の範囲が限定されている。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用
### 変更前との差分
変更前は、template を埋めて主要証拠が揃っていても、Step 5.5 が「NO があれば fix してから Step 6」という独立停止条件として再発火しやすい構造です。これにより、EQUIVALENT / NOT_EQUIVALENT のどちらでも、結論保留・追加探索・過度な低CONFIDENCE に倒れやすくなります。

変更後は、未検証点を conclusion 内で明示し、結論を変えうる未解決性だけを CONFIDENCE 低下に反映させる方向になるため、片方向最適化ではなく「両方向の過保留」を減らす作用です。

### EQUIVALENT 側への作用
- 改善余地が大きいのは EQUIVALENT 側です。
- 反証探索を済ませ、relevant tests 上の差分不在を示せているのに、補助関数や source unavailable が 1 つ残るだけで保留へ流れる癖を弱められます。
- 結果として「UNVERIFIED を明示しつつ EQUIVALENT を出す」分岐が出しやすくなります。

### NOT_EQUIVALENT 側への作用
- すでに counterexample と diverging assertion が見えているケースでも、独立 self-check が再度 stop し、不要な補助探索へ流れる可能性を下げます。
- そのため NOT_EQUIVALENT でも「差分は十分観測済みなのに、末尾ゲートで止まる」症状を減らせます。

### 片方向作用の懸念
片方向にしか効かない提案ではありません。主作用は「証拠不足の検出」ではなく「重複停止の除去」なので、EQUIV / NOT_EQUIV の両方で結論保留過多を減らします。逆に、証拠閾値そのものを下げる提案ではないため、NOT_EQUIV を乱発する方向にも寄りにくいです。

## 4. failed-approaches.md との照合
判定: 本質的再演ではない

理由:
- 原則1「再収束を比較規則として前景化しすぎない」には該当しない。提案は再収束規範の追加ではなく、末尾の重複ゲート削減。
- 原則2「未確定性を常に保留側へ倒す既定動作にしすぎない」に対しては、むしろ逆方向の改善。未検証性を即 stop 条件ではなく conclusion 内の明示へ戻している。
- 原則3「新しい抽象ラベルや必須の言い換え形式で強くゲートしすぎない」にも該当しない。新ラベル追加ではなく既存文言の統合。

## 5. 汎化性チェック
判定: 問題なし

- proposal 中に具体的なベンチマーク case ID、リポジトリ名、テスト名、実コード断片は含まれていません。
- 引用されているのは SKILL.md 自身の文言・セクション名であり、Objective.md の減点対象外ルールにも整合します。
- 暗黙の特定言語依存も薄いです。論点は compare の結論運用であり、特定言語・特定テストフレームワーク・特定パッチ形状に依存していません。

## 6. 推論品質への期待効果
期待される改善は「正しさの閾値を下げる」ことではなく、「同じ証拠量でより適切に結論へ到達させる」ことです。

具体的には:
- duplicate gate による認知負荷を下げる
- 監査向けの再記述ループを減らす
- UNVERIFIED の明示を維持しつつ、compare の停止条件を整理する
- 結論保留と追加探索の過剰発火を抑える

このため、改善の本体は reasoning quality のうち「終盤の意思決定の安定化」にあります。

## 停滞診断
- 懸念点 1つ: 「checklist は recap」と書くだけだと説明強化で終わる危険はあります。ただし本 proposal は Step 5.5 の独立 required gate を remove し、Trigger line と Payment まで明記しているので、今回は compare の意思決定変更まで踏み込めています。

failed-approaches 該当性:
- 探索経路の半固定: NO
- 必須ゲート増: NO
- 証拠種類の事前固定: NO

## compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  - template 完了後に追加探索/保留へ倒れる回数が減る。
  - UNVERIFIED を明示したうえで ANSWER を出すケースが増える。
  - CONFIDENCE を下げつつ結論する分岐が、結論保留より選ばれやすくなる。

- 1) Decision-point delta:
  - IF/THEN 形式で 2 行（Before/After）になっているか: YES
  - Trigger line（発火する文言の自己引用）が差分プレビューに含まれているか: YES
  - 評価: 条件も行動も変わっている。Before は「NO/曖昧なら stop」、After は「relevant outcomes を変えない未検証なら state + lower confidence + answer」で、理由の言い換えではない。

- 2) Failure-mode target:
  - 主対象: 両方
  - メカニズム: 偽 EQUIV / 偽 NOT_EQUIV そのものより、まず「不要な保留・追加探索・過度低CONFIDENCE」を減らす提案。その副次効果として、証拠は十分なのに結論を出し切れないことによる比較ミスを減らす。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か:
  - NO

- 3) Non-goal:
  - STRUCTURAL TRIAGE の結論条件は変えない。
  - relevant tests 規則は変えない。
  - 早期 NOT_EQUIV の根拠境界は変えない。
  - つまり、探索経路の半固定・必須ゲート増・証拠種類の事前固定を新たに導入しない。

追加チェック:
- Discriminative probe:
  - 抽象ケースとして、relevant tests の traced path は同一 outcome だが補助関数 1 つだけ source unavailable の状況を置いている。
  - 変更前は Step 5.5 が stop を誘発しやすく、保留または不必要な修復へ寄る。
  - 変更後は、その未検証点を conclusion に吸収して CONFIDENCE 調整で済ませられるので、compare の誤った非確定化を避けやすい。
  - これは新ゲート追加ではなく、独立必須 gate を既存 conclusion へ置換する説明になっている。

- 支払い（必須ゲート総量不変）の明示:
  - YES
  - add/remove の A/B 対応が proposal 内で明示されているため、compare 実効差が曖昧なままになっていない。

## 監査コメント
この proposal は、「監査に通りやすい説明」だけでなく compare の runtime decision を具体的に変えています。特に Trigger line と Payment が入っているため、単なる文章整理ではなく stop condition の置換として読めます。failed-approaches.md の本質的再演でもなく、汎化性違反も見当たりません。

一方で、実装時には refutation の必須性を弱めたように読めないよう注意が必要です。Step 5 を保持し、Step 5.5 で担っていた「証拠以上を言わない」「UNVERIFIED を明示する」は FORMAL CONCLUSION の注記として残すべきです。ここが曖昧だと、認知負荷削減ではなく安全弁削除に見えて監査で不利になります。

## 修正指示（最小限）
1. Step 5.5 を削る代わりに、FORMAL CONCLUSION 直前の注記へ「unverified items that can change compared test outcomes only affect whether to lower confidence vs continue searching」を明文化してください。単なる recap ではなく分岐条件として残すべきです。
2. Compare checklist の recap 化を明示するなら、同時に "Before writing the formal conclusion... fix it before Step 6" 系の停止文言は完全に削除してください。両方を残すと runtime branch が変わらず停滞します。
3. 実装文言では「UNVERIFIED が残っても常に結論してよい」とは読めないよう、relevant outcomes を変えうる未解決性は引き続き追加探索対象である境界を 1 行で残してください。

承認: YES