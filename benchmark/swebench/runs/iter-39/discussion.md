# Iteration 39 Discussion

## 総評
提案の狙い自体は理解できる。現行 compare には「semantic difference を見つけた」ことと「DIFFERENT test outcome を立証した」ことの間に、中間状態の扱いの曖昧さがあり、ここを明文化したいという問題設定は妥当である。

ただし、今回の具体案はその中間状態を `IMPACT: UNVERIFIED` へ送る既定分岐として必須化しており、failed-approaches.md の「未確定性をまず保留側へ倒す既定動作」にかなり近い。したがって、compare の観測可能な挙動差はあるが、その差が主に「判定を遅らせる／非確定化する」方向へ働きやすく、両方向の判別力改善としてはまだ弱い。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）

提案は、README.md と docs/design.md が強調する certificate-based reasoning の範囲内にある。特に「差分発見」と「test outcome の相違」の区別を明確にしたいという意図は、per-test iteration と formal conclusion を重視する設計と整合する。

一方で、論文由来のコアは「前提・探索・トレース・反証」であり、新しい中間ラベルを verdict 前の既定遷移として増やすこと自体はコアではない。従って、研究整合性はあるが、今回の具体的な実装形は必須ではない。

## 2. Exploration Framework のカテゴリ選定
カテゴリ E（表現・フォーマット改善）の選定は一応妥当。

理由:
- 主提案は compare テンプレート内の既存文言の置換であり、新しい探索順や新モード追加ではない。
- 実質は「semantic difference 発見後の分岐条件の書き方」を変える案なので、最表層の分類としては E に収まる。

ただし実効としては単なる wording 改善ではなく、compare の verdict 分岐を変える案である。したがって、E として提出するなら「なぜ wording change が runtime decision を変えるのか」をより明確に書く必要がある。そこを proposal はある程度満たしているが、`UNVERIFIED` を必須分岐にした点で D（自己チェック強化）寄りの副作用も持つ。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用
### EQUIVALENT 側
改善余地はある。差分を見つけただけで NOT_EQUIV に飛ぶ早計を抑えられるため、偽 NOT_EQUIV の減少は期待できる。

### NOT_EQUIVALENT 側
悪化リスクがある。`DIFFERENT test outcome` をまだ示せていない段階で `IMPACT: UNVERIFIED` へ送る既定分岐が入ると、すでに高情報量の差分を掴んでいても、判定より先に非確定化・追加探索へ倒れやすくなる。これは偽 EQUIV というより、真の NOT_EQUIV を取り切れず保留化する方向の回帰リスクとして現れる。

### 実効的差分の評価
片方向にしか作用しないとまでは言わないが、重心は明らかに「早すぎる NOT_EQUIV を抑える」側にある。proposal は Target: 両方と書いているが、現状の文言では EQUIV 側の利得が中心で、NOT_EQUIV 側の維持策が十分に書かれていない。

## 4. failed-approaches.md との照合
本質的な懸念は failed-approaches.md 原則 2。

該当しうる理由:
- 原則 2 は「未確定な relevance や脆い仮定を、常に保留側へ倒す既定動作にしすぎない」と警告している。
- proposal の Trigger line は `If a found semantic difference is not yet tied to a DIFFERENT test outcome, record IMPACT: UNVERIFIED and continue tracing.` であり、未確定状態をまず `UNVERIFIED` に送る既定動作そのものに近い。

proposal 側の弁明として「対象は relevant path 上で見つかった差分に限定」とあるので、failed approach の完全再演とまでは言い切れない。しかし「限定付きの UNVERIFIED fallback」を compare の必須分岐に昇格している点は、原則 2 の危険領域にかなり近い。

原則 3 との関係はグレー。`IMPACT: UNVERIFIED` という新しい抽象ラベルを分岐の要に据えているため、差分の昇格条件をラベル化で強くゲートしているようにも読める。主ブロッカーは原則 2 だが、原則 3 の臭いもある。

## 5. 汎化性チェック
明示的な固有 ID、ベンチマークケース名、リポジトリ名、テスト名、実コード断片は含まれていない。ここは問題ない。

また、提案の主張自体は特定言語や特定テストフレームワークに依存していない。

ただし、`DIFFERENT test outcome` に強く錨付ける書き方は、テスト観測可能性が明瞭な compare には合う一方、差分の情報量が高いケースでも verdict を出しにくくする可能性がある。これは汎化性違反というより、判定設計上のバイアスの懸念。

## 6. 全体の推論品質への期待効果
期待できる改善:
- 「差分発見」と「counterexample 成立」の混同を減らす
- verdict 前に per-test outcome を意識させる
- no-impact を雑に断定する誤りを減らす

ただし現案のままだと、改善の主成分は「判定の慎重化」であり、「判別力の向上」そのものではない。compare で欲しいのは、差分を握りつつ必要なときだけ追加探索へ進めることであって、`UNVERIFIED` を新しい安全地帯にすることではない。

## 停滞診断
- 懸念点: 提案は audit rubric に刺さる「説明の明確化」にはなっているが、実際の compare 実行では `UNVERIFIED` 表記が増えるだけで、EQUIV/NOT_EQUIV の最終意思決定が十分変わらないまま停滞する恐れがある。

- 探索経路の半固定: NO
- 必須ゲート増: YES
  - 原因文言: `record IMPACT: UNVERIFIED and continue tracing` を MUST として追加している点。
- 証拠種類の事前固定: NO

## compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  - semantic difference を見つけた直後に NOT_EQUIV / no-impact へ進まず、`IMPACT: UNVERIFIED` を明示して追加 tracing に倒れる出力が増える。

- 1) Decision-point delta:
  - IF/THEN 形式で 2 行（Before/After）になっているか？ YES
  - Trigger line（発火する文言の自己引用）が差分プレビュー内にあるか？ YES
  - 評価: 条件と行動は一応変わっているが、変化の中心が「verdict 条件の改善」より「非確定化の既定化」に寄っている。

- 2) Failure-mode target:
  - 主対象は偽 NOT_EQUIV の削減。
  - メカニズムは「差分発見だけで verdict 化しない」。
  - ただし副作用として、真の NOT_EQUIV を保留化しやすくする恐れがある。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？ NO

- 3) Non-goal:
  - 探索経路の半固定はしない、assertion boundary 固定もしない、必須総量純増もしない、という境界は明記されている。
  - ただし実質上は `UNVERIFIED` 分岐の必須化が新たなゲートとして機能しており、Non-goal と実装案が少しずれている。

## Discriminative probe
抽象ケース: A/B に途中の条件分岐差があるが、あるテストではその差が assertion まで届き、別のテストでは途中で吸収される。

変更前は、差分を見つけた瞬間に NOT_EQUIV へ飛ぶか、逆に no-impact へ雑に寄せる誤判定がありうる。変更後案はその即断を抑える点では有効だが、`UNVERIFIED` を必須にするため、A/B のうち assertion へ届く枝の追跡より先に保留化が学習されるおそれがある。ここは「既存 1 行の置換」で済ませるなら、`UNVERIFIED` ラベル追加ではなく verdict-neutral な追跡要求に留めた方が判別的。

## 支払い（必須ゲート総量不変）の確認
Payment の A/B 対応付け自体は proposal 内に明示されている。ここは要件を満たしている。

ただし、削る対象が「no impact を言う前に trace せよ」という既存の片側制約で、足す対象が「差分ならまず UNVERIFIED を書け」という新たな既定分岐なので、総量不変でも実質的な挙動はより保留寄りになる。量的 payment はあるが、質的 payment が釣り合っていない。

## 最大のブロッカー
`IMPACT: UNVERIFIED` を compare の必須既定分岐として導入している点。これは failed-approaches.md 原則 2 の「未確定性をまず保留側へ倒す既定動作」の再演に近く、compare の runtime outcome を「判別」ではなく「非確定化」に寄せる危険がある。

## 修正指示
1. `record IMPACT: UNVERIFIED` の必須化を削り、既存 1 行との置換として「semantic difference 単体はどちらの verdict にも不十分。DIFFERENT outcome まで追跡するか、同じ test outcome に吸収される具体経路を示す」に言い換えてください。
2. 支払いは現行の片側文言の削除で賄い、`UNVERIFIED` という新ラベルは追加しないでください。compare の分岐を増やすのではなく、既存の COUNTEREXAMPLE / NO COUNTEREXAMPLE に接続する形へ統合してください。
3. `Target: 両方` を維持したいなら、NOT_EQUIV 側の維持策を 1 文だけ足してください。例えば「高情報量の差分を provisional 扱いに固定しない」旨を明示し、保留化が既定動作ではないと分かるようにしてください。

## 承認
承認: NO（理由: `IMPACT: UNVERIFIED` の必須既定分岐が、failed-approaches.md の原則 2 に近い本質的再演になっているため）
