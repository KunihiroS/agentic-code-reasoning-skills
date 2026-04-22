# iter-18 discussion

## 総評
提案は、Step 5.5 の既存 self-check にある「UNVERIFIED だが結論に影響しない」という結論レベルの曖昧免責を、claim 単位の判定へ置換するものです。研究コア（番号付き前提・仮説駆動探索・手続き間トレース・必須反証）を維持したまま、compare 実行時の分岐を実際に変えうる最小差分になっています。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

README.md / docs/design.md の要点と整合しています。
- 本スキルのコアは certificate-based reasoning であり、未読・未検証のまま結論へ進ませないことが主眼。
- docs/design.md の「per-item iteration as the anti-skip mechanism」「interprocedural tracing as structure, not advice」に照らすと、今回の提案は tracing の未検証リンクを結論側で吸収しにくくする補強であり、研究コアの延長にあります。
- 新しい理論や外部概念への強い依拠はなく、最小限の文言具体化として自己完結しています。

## 2. Exploration Framework のカテゴリ選定
判定: 概ね適切（E 寄り、D を少しまたぐが許容範囲）。

理由:
- 変更の主本体は Step 5.5 の曖昧文言の置換であり、「既存 mandatory 枠の内部を書き換えるだけ」という意味では E. 表現・フォーマット改善に当たります。
- ただし作用点は self-check の意思決定分岐なので、実質的には D. メタ認知・自己チェック強化の性格もあります。
- それでも「新しいチェックを増やす」のではなく「既存 bullet の意味を具体化して置換する」ので、E として扱うのは不自然ではありません。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用
片方向最適化ではなく、両方向に作用します。

- EQUIVALENT 側:
  未検証 helper / external behavior / missing row に依存したまま「多分 benign」と語って SAME に寄せる流れを止めやすくなります。結果として、偽 EQUIV を減らし、追加探索または NOT VERIFIED / LOW confidence へ分岐しやすくなります。
- NOT_EQUIVALENT 側:
  差分の存在を見つけたあと、その差分が assertion まで届くか未検証のまま「多分効く」と結論づける流れも止めやすくなります。結果として、偽 NOT_EQUIV も減らし、追加探索または NOT VERIFIED / LOW confidence へ分岐しやすくなります。
- 実効的差分:
  変更前は「結論に影響しない」と叙述できれば UNVERIFIED を narrative で吸収できる。変更後は verdict-distinguishing claim が UNVERIFIED 依存なら、その claim 自体を NOT VERIFIED 化し、探索継続か明示的不確実性表示に倒す。

## 4. failed-approaches.md との照合
本質的再演: ぎりぎり回避しているが、原則2に近づくリスクはある。

- 原則1「探索経路の半固定」: 再演ではありません。読み順や再収束説明の既定化は増えていません。
- 原則2「未確定性を常に保留側へ倒す既定動作」: 近接リスクはありますが、提案は「任意の未確定性」ではなく「verdict-distinguishing claim が UNVERIFIED に依存する場合」に限定しています。つまり不確実性全般を保留トリガー化するのではなく、決定 claim に限定している点で一段狭いです。
- 原則3「証拠種類の事前固定 / 新しい抽象ラベルで強くゲート」: 再演ではありません。VERIFIED / UNVERIFIED という既存ラベルの意味を厳密化しているだけで、新たな証拠カテゴリや昇格前ゲートは増えていません。

結論として、failed-approaches の本質的再演とは言いません。ただし実装時に「未検証なら広く保留」の書き方へ膨らませると原則2の再演になるので、claim 依存条件を外さないことが重要です。

## 5. 汎化性チェック
判定: 問題なし。

- 提案文中に、具体的な数値 ID、ベンチマークのケース ID、特定リポジトリ名、テスト名、コード断片の引用はありません。
- 引用されているのは SKILL.md 自身の既存文言のみで、Objective.md の R1 減点対象外に該当します。
- ドメイン依存性も低いです。helper / assertion boundary / claim 依存という表現は、言語・フレームワーク非依存の静的推論原則として読めます。
- 特定のテストパターンや言語機能を暗黙前提にしていない点も良好です。

## 6. 全体の推論品質への期待効果
期待できる改善は、結論直前の「叙述で押し切る」失敗を減らすことです。

- trace table に UNVERIFIED 行が残っていても、従来は結論単位の説明で吸収できたため、丁寧だが未完了の reasoning chain がそのまま verdict に流れやすかった。
- 今回の変更は「どの claim がその未検証リンクに依存しているか」を見させるため、未検証リンクの重要度を局所化できる。
- その結果、不要な全面保留ではなく、「決定 claim に限って止める」動きが期待でき、誤判定の抑制と説明責任の向上の両方に寄与します。

## 停滞診断（必須）
- 懸念点 1 つ: 監査 rubic に刺さる「不確実性を明示する良い説明」に寄りすぎると、実運用では単に LOW confidence が増えるだけで compare の YES/NO 精度が上がらない危険はあります。ただし本提案は「1 回の targeted search」を分岐に含めており、単なる説明強化で終わらない余地があります。

- failed-approaches 該当性:
  - 探索経路の半固定: NO
  - 必須ゲート増: NO（既存 MUST の置換で、payment も明示あり）
  - 証拠種類の事前固定: NO

## compare 影響の実効性チェック（必須）
- 0) 実行時アウトカム差:
  - 観測可能に変わる点は少なくとも 1 つあります。verdict-distinguishing claim が UNVERIFIED 依存のとき、従来は YES/NO をそのまま出しうるのに対し、変更後は targeted search の追加、NOT VERIFIED 明示、または LOW confidence 化が起こります。

- 1) Decision-point delta:
  - IF/THEN 形式で 2 行（Before/After）になっているか: YES
  - Before/After が分岐として変わっているか: YES。Before は narrative exemption で verdict 続行、After は claim unresolved として search / UNVERIFIED / LOW confidence へ分岐します。
  - Trigger line（発火する文言の自己引用）が差分プレビュー内にあるか: YES

- 2) Failure-mode target:
  - 対象は両方。偽 EQUIV は「未検証だが benign と語る」誤り、偽 NOT_EQUIV は「未検証差分を assertion 到達前に効くとみなす」誤りを減らす方向です。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か:
  - NO

- 3) Non-goal:
  - structural triage、relevant tests 規則、証拠種別の追加には触れない。未検証一般を広く保留トリガーにしない。Step 5.5 の既存 bullet の置換に限定する。

- Discriminative probe:
  - 抽象ケースとして、「見えている差分が test outcome へ届くかどうかが、未読 helper 1 箇所に依存する」場合を考える。変更前は benign / harmful の narrative を先に作って EQUIV または NOT_EQUIV を誤って確定しやすい。変更後は、その helper 依存の claim だけが NOT VERIFIED になり、1 回の追加探索か LOW confidence に倒れるため、誤った二択確定を避けやすい。
  - これは新しい必須ゲート増設ではなく、既存の UNVERIFIED 許容 bullet の置換で説明できています。

- 支払い（必須ゲート総量不変）の A/B 対応付け:
  - 明示あり。旧 MUST を remove し、新 MUST を add する payment が proposal 内で対応付けられています。

## 監査コメント
この proposal は、compare の実行時分岐を本当に変える最小差分として筋が良いです。特に、Trigger line、Before/After の IF/THEN、payment、discriminative probe が揃っており、「監査に通りやすいだけで compare に効かない提案」にはなっていません。

最大の注意点は、実装文言が「UNVERIFIED があれば広く保留」に膨らむことです。ここだけ外すと failed-approaches 原則2の再演になります。したがって修正指示は、その一点を中心に最小限で十分です。

## 修正指示（最小限）
1. After の文言で「keep the verdict explicitly UNVERIFIED / LOW confidence」の部分は、compare の最終 ANSWER 仕様と衝突しないよう、「claim を NOT VERIFIED と明記し、必要なら追加探索し、それでも未解決なら CONFIDENCE を下げて結論範囲を限定する」と寄せてください。未検証 verdict 自体を新制度化しない方が安全です。
2. Trigger line の直後に、「only when a verdict-distinguishing claim depends on that row」という限定句を必ず残してください。これを落とすと failed-approaches 原則2へ滑ります。
3. 追加 bullet は 1 行増えるので、実装時は既存 2 行を 2 行へ圧縮するなど、Step 5.5 の見た目の増量を抑えてください。payment の意図どおり、必須ゲート総量不変を守るのがよいです。

承認: YES