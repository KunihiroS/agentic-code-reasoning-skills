# iter-35 discussion

- Web調査: 検索なし（理由: 提案は既存の SKILL.md / Objective / failed-approaches の内部整合と一般原則の範囲で自己完結しており、特定研究用語や外部主張への依存が強くない）

## 総評
この提案は、Compare の `STRUCTURAL TRIAGE` にある「構造差だけで NOT EQUIVALENT へ早期直行できる抜け道」を、D1 の定義（ relevant tests の PASS/FAIL 同一性 ）へ接続し直すものです。新しい探索入口を追加するより、既存の `COUNTEREXAMPLE` 要件を早期結論枝にも適用する再配線なので、研究コア（番号付き前提・仮説駆動探索・手続き間トレース・必須反証）を壊しにくく、compare の実行時アウトカム差も比較的はっきりしています。

## Exploration Framework のカテゴリ選定
- 判定: おおむね適切
- 主カテゴリ: A. 推論の順序・構造を変える
- 理由: 提案の本質は「STRUCTURAL TRIAGE→即 FORMAL CONCLUSION」という枝を、「impact witness があるときだけ直行、なければ ANALYSIS へ戻る」に再配線することだから。これは探索入口の追加や証拠メニューの新設より、既存ステップ間の接続条件の変更。
- 補足: G. 認知負荷の削減（loophole の整理）も少し含むが、中心は A で妥当。

## compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  - 変更前は S1/S2 の構造差だけで `ANSWER: NO not equivalent` に早期着地しうる。
  - 変更後は、早期 NOT_EQUIVALENT には `concrete test-impact witness` が必要になり、出せなければ ANALYSIS 継続になる。これは compare 実行時に「追加探索が要求される」「早期 NOT_EQ が減る」という観測可能な差。

- 1) Decision-point delta:
  - Before: IF `S1/S2 shows a clear structural gap` THEN `jump to FORMAL CONCLUSION (NOT EQUIVALENT)`
  - After: IF `S1/S2 shows a clear structural gap AND you can cite a concrete test-impact witness` THEN `jump to FORMAL CONCLUSION`; ELSE `continue into ANALYSIS`
  - IF/THEN 形式で 2 行になっているか: YES
  - Before/After が条件も行動も同じで理由だけ言い換えか: NO
  - Trigger line（発火する文言の自己引用）が差分プレビュー内にあるか: YES

- 2) Failure-mode target:
  - 主対象: 偽 NOT_EQUIV
  - 副次対象: 偽 EQUIV も間接的に抑制しうる
  - メカニズム: 構造差の存在そのものではなく、テスト結果差に接続する証拠を要求することで premature NOT_EQ を減らす。さらに「影響不明なら ANALYSIS に戻る」ため、差の有無を relevant tests 上で詰める流れが増え、雑な SAME 判定も抑えやすくなる。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か?: YES
  - `impact witness` を要求しているか?: YES
  - 「ファイル差がある」だけに退化していないか: 退化していない。むしろその退化を防ぐ提案。

- 3) Non-goal:
  - 変えないことは妥当。全ケースに特定の探索順を強制しない、証拠種類を固定テンプレート化しない、新しい独立メタゲートを純増しない、という境界が明示されている。

## EQUIVALENT / NOT_EQUIVALENT 両方向への作用
- NOT_EQUIVALENT 側:
  - 効き目は明確。従来は「missing file / missing module update / missing test data」のような構造差だけで NOT_EQ に寄りうるが、変更後は relevant test の assertion/import/use などへの接続が必要になるため、偽 NOT_EQUIV を直接減らす方向。
- EQUIVALENT 側:
  - 効き目は間接的。提案自体は EQUIV の判定条件を直接緩めたり厳しくしたりしない。
  - ただし、構造差を見た瞬間に NOT_EQ で打ち切られず ANALYSIS に戻るケースが増えるので、本来 EQUIV なものが正しく EQUIV に収束する余地は増える。
- 片方向最適化か:
  - 完全対称ではないが、逆方向の明白な悪化は見えない。主に NOT_EQ 側の早すぎる結論を是正し、その副作用として EQUIV の取りこぼしも減らしうる、という非対称だが許容可能な改善。

## failed-approaches.md との照合
- 本質的再演か: いいえ、再演の度合いは低い
- 理由:
  - failed-approaches は「探索経路の半固定」「必須ゲート増」「証拠種類の事前固定」を警戒している。
  - 今回は新しい探索入口を固定するのでなく、既存の早期ショートカットを D1/COUNTEREXAMPLE に接続し直す案で、自由探索そのものは ANALYSIS 側へ戻される。
  - `Payment: none` の主張も概ね整合的。厳密には早期直行枝に条件を足しているが、`COUNTEREXAMPLE (required if claiming NOT EQUIVALENT)` は既に SKILL.md にあるため、新規原則追加というより抜け道の封止。
- 注意点:
  - `impact witness (e.g., import/use/assert)` の例示は、実装時に例示を強く書きすぎると「証拠種類の事前固定」へ寄るおそれがある。ここは witness の定義を「relevant test outcome に接続する具体的根拠」と抽象度高めに維持するのが安全。

## 停滞診断
- 懸念 1 点:
  - 「監査 rubic に刺さる説明強化」だけで compare の実行を変えない案ではないか、という懸念は小さい。今回の提案は `clear structural gap` からの分岐行動自体を `即結論` から `witness がなければ ANALYSIS 継続` に変えており、理由の言い換えに留まっていない。
- 探索経路の半固定: NO
- 必須ゲート増: NO
- 証拠種類の事前固定: NO
  - ただし原因になりうる文言候補は `e.g., import/use/assert`。これは例示に留め、閉じた列挙にしない方がよい。

## 汎化性チェック
- 具体的な数値 ID / リポジトリ名 / テスト名 / コード断片の混入: 問題なし
- SKILL.md 自身の文言引用は Objective の R1 で許容されている自己引用の範囲。
- ドメイン・言語・特定テストパターンへの暗黙依存:
  - 小さい。`import/use/assert` は多言語に広く通じる一般概念。
  - ただし `file:line` や assertion ベースの書き方はテストフレームワークが明示 assertion でない環境にはやや寄るため、実装時は「PASS/FAIL 境界に接続する具体的観測点」くらいに一般化しておくとさらによい。

## Discriminative probe
- 抽象ケース: 片方の変更だけが補助設定ファイルを触るが、relevant tests はその設定を読まない。変更前ルールだと `files modified` の差から早期 NOT_EQ に流れやすい。
- 変更後ルールでは、その構造差がどの test outcome に効くかの witness を出せない限り ANALYSIS へ戻るので、構造差はあるが outcome は同じ、という EQUIV ケースを救いやすい。
- これは新しい必須ゲートの増設ではなく、既存の NOT_EQ 用 `COUNTEREXAMPLE` 義務を早期結論枝へ接続し直す説明になっている。

## 期待される推論品質の改善
- D1（test outcomes identical/different）と早期結論枝の整合が上がる。
- 「構造差を見つけた瞬間に結論化する」短絡を抑え、relevant tests への因果接続を要求するため、compare の証拠密度が上がる。
- 変更規模が小さく、Compare セクション内の局所変更で済むため、他モードへの回帰リスクも比較的低い。

## 修正指示（最小限）
1. `impact witness` の例示は閉じた証拠種リストに見えないよう弱めること。`e.g., import/use/assert` をそのまま強く固定せず、「relevant test outcome に結びつく具体的観測点」と表現しておく。
2. 提案本文では「両方に効く」と言い切りすぎず、主効果は偽 NOT_EQUIV 抑制、EQUIV 側は ANALYSIS 復帰による二次効果だと明示すること。

## 結論
承認: YES