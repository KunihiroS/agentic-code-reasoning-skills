# Iteration 10 Discussion

## 監査サマリ
- 提案の要旨: Step 5.5 の自己チェックを、抽象的な support check から「最弱の UNVERIFIED 仮定を反転させたとき verdict が崩れるか」という weakest-link stability check へ置換する案。
- 監査観点での第一印象: compare の結論直前の分岐を実際に変える提案になっており、単なる説明強化ではない。加えて payment も明示されているため、必須ゲートの純増を避けようとしている点は良い。

## 1. 既存研究との整合性
- 検索なし（理由: 一般原則の範囲で自己完結）。
- README.md / docs/design.md と照合すると、研究コアは「番号付き前提・仮説駆動探索・手続き間トレース・必須反証」であり、本提案はそのうち反証可能性と未検証リンクの扱いを結論直前で具体化するもの。コア構造の置換ではなく、既存 Step 5.5 の具体化として整合的。

## 2. Exploration Framework のカテゴリ選定
- 判定: 適切（D: メタ認知・自己チェック強化）
- 理由:
  - 変更対象が Step 5.5 の pre-conclusion self-check であり、探索順序や比較単位ではなく「結論確定前に自分の弱い推論リンクを点検する」メカニズムだから。
  - B や C ではなく D に置いているのは妥当。実際の変化点は情報取得方法そのものではなく、確定条件の自己監査ルールにある。

## 3. compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  - これまで最終 verdict をそのまま出していた場面の一部で、追加探索 / UNVERIFIED 明示 / CONFIDENCE 低下へ分岐する。
  - 観測可能な差は、ANSWER の即断率低下ではなく「未検証前提が verdict を支える局面での保留化条件」が明文化される点。
- 1) Decision-point delta:
  - Before: IF UNVERIFIED 仮定が残っていても、全体として「結論を変えない」と主観的に見なせる THEN verdict を確定する。
  - After: IF 最弱の UNVERIFIED 仮定を反転すると少なくとも 1 つの test outcome 予測が変わる THEN verdict を確定せず、追加探索 / UNVERIFIED / CONFIDENCE 低下へ分岐する。
  - IF/THEN 形式で 2 行になっているか: YES
  - Trigger line の自己引用が差分プレビューにあるか: YES
- 2) Failure-mode target:
  - 対象: 両方（偽 EQUIV / 偽 NOT_EQUIV）
  - メカニズム: verdict を支える未検証リンクが残るときだけ確定を止めるため、弱い仮定の押し切りを減らす。
- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か:
  - NO
  - impact witness 要求の有無: N/A（この提案の主戦場は早期 NOT_EQUIV ではなく、結論直前の self-check）
- 3) Non-goal:
  - STRUCTURAL TRIAGE の S1/S2 を assertion boundary ベースに狭めない。
  - 新しい証拠種類の必須化はしない。
  - 「未確定なら常に保留」という広い既定動作にはしない。

## 4. EQUIVALENT / NOT_EQUIVALENT の両方向への作用
- EQUIVALENT 側:
  - 現状では、同値と結論したい圧力の中で UNVERIFIED 仮定を「たぶん結論に効かない」と吸収しやすい。
  - 提案後は、その仮定を反転させたとき test outcome 予測が変わるなら確定できないため、偽 EQUIV を減らす方向に効く。
- NOT_EQUIVALENT 側:
  - 現状では、差分を見つけた後にその差分が本当に test outcome 差へ届くか未検証でも、勢いで counterexample 扱いしやすい。
  - 提案後は、NOT_EQUIVALENT を支える最弱リンクが未検証なら、同様に確定を止めるため、偽 NOT_EQUIVALENT も減らせる。
- 総評:
  - 片方向最適化ではない。verdict の符号ではなく「未検証リンクが結論を支えているか」を問うので対称性がある。
  - ただし、両方向で探索追加や UNVERIFIED 表示が増える可能性はあるため、回帰リスクはゼロではない。もっとも payment 付きの置換であり、過剰な新モード追加もないため許容範囲。

## 5. failed-approaches.md との照合
- 本質的再演か: いいえ
- 原則1「再収束を比較規則として前景化しすぎない」:
  - NO。提案は下流の共有観測点への再収束を既定化していない。むしろ未検証リンクが verdict を支えるかを問うローカル check。
- 原則2「未確定な relevance を常に保留側へ倒す既定動作を増やしすぎない」:
  - NO。保留化条件は「最弱リンク反転で verdict が変わる場合」に限定されており、未解決性そのものを強いデフォルト信号にはしていない。
- 原則3「証拠昇格を新しい抽象ラベルで強くゲートしすぎない」:
  - 概ね NO。`most fragile UNVERIFIED assumption` という抽象語はあるが、証拠の種類を事前固定するフィルタではなく、既存 UNVERIFIED の中で verdict 依存性を点検するための局所ラベルに留まる。

## 6. 汎化性チェック
- 固有識別子違反:
  - なし。具体的なベンチマーク ID、リポジトリ名、テスト名、実コード断片は含まれていない。
  - SKILL.md の自己引用は Audit Rubric 上も許容範囲。
- 暗黙のドメイン依存:
  - 目立ったものはない。`helper/library call` は一般的で、言語や特定テストパターンへの依存は薄い。
- 懸念があるとすれば:
  - `decisive path` と `could change the verdict` の判定粒度がやや抽象的で、実装時に説明だけ強化され実効分岐が弱まるおそれはある。ただし proposal 内の Trigger line と Before/After は十分具体で、現段階では blocker ではない。

## 7. 停滞診断（必須）
- 懸念 1 点:
  - 「最弱リンク」という言い方だけが追加され、実際には従来の「supports the conclusion」を言い換えるだけになると、監査 rubic には刺さるが compare の分岐は変わらない。その意味で、実装時に `could change the verdict` と `do not finalize` の両方を落とさないことが重要。
- failed-approaches 該当性:
  - 探索経路の半固定: NO
  - 必須ゲート増: NO（payment が明示され、既存 MUST の置換として提案されているため）
  - 証拠種類の事前固定: NO

## 8. Discriminative probe（必須）
- 抽象ケース:
  - 2 つの変更は表面上同じ high-level branch に到達するが、一方だけ未読の外部 helper の戻り値仮定に依存して assertion 前の真偽が決まる。
  - 変更前は「他の traced evidence が多い」ことに引っ張られ、その helper 仮定を結論非依存と雑に扱って偽 EQUIV か偽 NOT_EQUIV を出しうる。
  - 変更後は、その最弱リンクを反転すると test outcome 予測が変わるかを問うため、追加探索または UNVERIFIED/LOW CONFIDENCE に止まり、誤確定を避けやすい。
- 評価:
  - これは新しい必須ゲートの増設ではなく、既存 self-check 1 行の置換として説明できている。

## 9. 支払い（必須ゲート総量不変）の確認
- A/B の対応付けは明示されているか: YES
- 内容:
  - 追加: weakest-link check
  - 支払い: 既存の抽象的な support check（"The conclusion I am about to write asserts nothing beyond what the traced evidence supports."）の demote/remove
- 評価:
  - 停滞対策として十分。ここが曖昧だと NO にすべきだが、今回は明示済み。

## 10. 全体の推論品質への期待効果
- 既存 Step 5.5 は「証拠の総量は多いが weakest link が致命的」という状況を拾いにくい。提案はその穴を埋める。
- 反証ステップを増築するのではなく、既にある UNVERIFIED 表示を verdict stability に接続するので、研究コアを保ったまま compare の分岐品質を上げやすい。
- 特に、証拠不足そのものではなく「脆い未検証仮定が結論を支えているのに、generic self-check がそれを飲み込む」失敗には有効と期待できる。

## 最小限の修正指示
1. `decisive path` を実装文言で曖昧にしないこと。proposal の Trigger line にある `could change the verdict` をそのまま残し、理由説明だけの一般論に戻さないこと。
2. `continue tracing or mark the conclusion UNVERIFIED / lower CONFIDENCE` の分岐は optional な例示ではなく、`do not finalize as settled` の直後の行動候補として短く保つこと。別の抽象説明を足しすぎないこと。

## 結論
- 監査判断: compare の意思決定ポイントを実際に変える提案になっており、failed-approaches.md の本質的再演でもなく、汎化性違反も見当たらない。
- 最大の注意点は、実装で weakest-link check を単なる説明強化へ薄めないことだけ。

承認: YES
