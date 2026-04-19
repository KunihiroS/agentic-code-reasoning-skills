# iter-37 proposal 監査コメント

## 総評
提案の主眼は、STRUCTURAL TRIAGE で見つけた structural gap をそのまま NOT EQUIVALENT の結論根拠にせず、既存の COUNTEREXAMPLE 要件に接続して「結論根拠の型」を統一することにある。これは compare の実行時分岐を実際に変える提案であり、単なる説明強化ではない。加えて、研究コア（前提・探索・トレース・反証）を崩さず、既存テンプレート内の不整合を狭く補正する方向なので、監査 PASS の下限は満たしうる。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

README.md と docs/design.md が強調するコアは「structured certificate により unsupported claims を防ぐこと」であり、SKILL.md 自身も compare で NOT EQUIVALENT 時に COUNTEREXAMPLE を必須としている。今回の提案は新理論導入ではなく、既存 compare テンプレート内部の整合化として読める。

## 2. Exploration Framework のカテゴリ選定
カテゴリ C「比較の枠組みを変える」は適切。

理由:
- 提案は「何を先に読むか」「何を探すか」の固定ではなく、差異から結論への写像を変えている。
- structural gap を「即時結論」ではなく「witness 付きなら NOT_EQ、無ければ ANALYSIS 継続」という二段階判定に変えるため、比較粒度・差異重要度の扱いの修正に当たる。
- A/B/D/E ではなく C に置いたのは妥当。探索順の固定や自己監査の純増が主題ではない。

## 3. EQUIVALENT / NOT_EQUIVALENT 両方向への作用
片方向最適化ではない。

- EQUIVALENT 側:
  structural gap だけで早期 NOT_EQ に倒れていたケースを ANALYSIS 側へ戻せるため、偽 NOT_EQ を減らす。結果として EQUIVALENT に到達できる余地が増える。
- NOT_EQUIVALENT 側:
  NOT_EQ を禁止するのではなく、witness を伴うときに確定させるため、真の NOT_EQ は維持可能。むしろ「ファイル差がある」だけの弱い根拠から、「テスト結果が分岐する」という D1 準拠の根拠へ強化される。
- 実効差分:
  変更前は S1/S2 の structural gap があれば ANALYSIS を飛ばして即 NOT_EQ に倒れうる。変更後は structural gap があっても witness 不在なら NOT_EQ を保留して ANALYSIS に戻る。この分岐変更は compare 実行時に観測可能。

## 4. failed-approaches.md との照合
本質的再演ではない、ただし境界は要注意。

適合している点:
- 「読解順序の半固定」は導入していない。どこから読むかは固定せず、NOT_EQ に進む条件だけを狭めている。
- 「証拠種類の事前固定」も限定的。witness は新しい探索テンプレの固定というより、既存 COUNTEREXAMPLE 欄の整合的適用である。
- 「必須ゲート純増」についても、既存の NOT_EQ にはもともと counterexample が required と明記されているため、完全な新設ではなく bypass の解消に近い。

要注意点:
- failed-approaches.md は「既存の判定基準を特定の観測境界だけに過度に還元しすぎない」と警告している。今回の提案はこの危険に最も近い。
- ただし proposal は witness を「diverging assertion 等」としており、特定の 1 種類に固定していない。また compare の定義 D1 が test outcome 同一性である以上、NOT_EQ の根拠を test-impact witness に寄せることは compare モードでは自然。
- よって「本質的再演」とまでは言えないが、実装文言が assertion-only に狭まると失敗原則の再演になりうる。

## 5. 汎化性チェック
汎化性違反は見当たらない。

- 提案文中に具体的な数値 ID、ベンチマーク対象リポジトリ名、テスト名、コード断片はない。
- 具体例は「補助ファイル」「relevant tests」など抽象ケースに留まっている。
- 特定言語・特定テストフレームワーク・特定リポジトリ前提も薄い。
- ただし “diverging assertion” を唯一の witness 例として強く読ませると、assert 文ベースのテスト観を暗黙前提にしやすい。実装時は import failure, exception boundary, output mismatch なども witness に含む広い表現を維持すべき。

## 6. 全体の推論品質への期待効果
期待効果はある。

- compare テンプレート内の局所不整合（early NOT_EQ bypass vs required counterexample）を解消できる。
- structural diff を「差異検出」と「差異の結論化」に分離するため、早計な NOT_EQ を減らしやすい。
- しかも full ANALYSIS の常時強制ではないため、複雑性増加を小さく抑えながら、必要なときだけ追加探索へ戻せる。

## 停滞診断
- 懸念 1 点: 「counterexample witness を出すべき」という監査受けのよい説明強化に見える危険はある。ただし本 proposal は early NOT_EQ の可否という compare の分岐自体を変えるので、理由の言い換えだけではない。

### failed-approaches 該当性
- 探索経路の半固定: NO
- 必須ゲート増: NO（既存の NOT_EQ counterexample 要件の bypass 解消という位置づけ。ただし実装で新しい独立ゲートのように書くと YES 化しうる）
- 証拠種類の事前固定: NO（現提案文の範囲では witness の型は広い。assertion のみに狭めると YES）

## compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  structural gap 発見時に、即 NOT_EQ で終わるケースの一部が「ANALYSIS へ戻る / 不確実性を明示する / 最終的に EQUIV へ到達する」に変わる。これは ANSWER と CONFIDENCE と追加探索要求に観測差が出る。

- 1) Decision-point delta:
  Before: IF S1/S2 で clear structural gap THEN ANALYSIS を飛ばして NOT EQUIVALENT に進む。
  After: IF S1/S2 で clear structural gap THEN NOT_EQ に進む前に counterexample witness を述べ、無ければ ANALYSIS に戻る。
  IF/THEN 形式で 2 行か: YES
  Trigger line の自己引用があるか: YES

- 2) Failure-mode target:
  主対象は偽 NOT_EQ。メカニズムは「file-list difference alone」による早期断定を防ぎ、test-impact に結び付く差だけを NOT_EQ 根拠として採用すること。
  副次的には、根拠の弱い NOT_EQ を減らすことで、真の EQUIV を取りこぼしにくくする。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か:
  YES
  impact witness を要求しているか: YES
  評価: ここが明示されているため、「ファイル差があるだけ」の粗い NOT_EQ 退化は回避方向。

- 3) Non-goal:
  structural gap の検出自体は維持し、探索順・読解開始点・特定の証拠収集順序は固定しない。full ANALYSIS の常時必須化もしない。

### Discriminative probe
片側だけが周辺ファイルを触るが、そのファイルは relevant tests の呼び出し経路に乗らない抽象ケースを考える。変更前は「片側だけが触るファイルあり」で NOT_EQ に落ちやすい。変更後は witness 不在なら ANALYSIS 継続に戻るため、既存文言の置換だけで偽 NOT_EQ を避けやすい。

### 支払い（必須ゲート総量不変）確認
A/B の対応付けは概ね明示されている。
- 追加するもの: early NOT_EQ 時の witness 要件
- 支払うもの: full ANALYSIS を常時必須にはせず、「ANALYSIS 省略可」は維持

このため、mandatory load の純増ではなく、既存 bypass の閉塞として成立している。

## 最大のブロッカー
なし。

## 修正指示（最小限）
1. 実装文言では witness を「diverging assertion 等」に限定せず、「test outcome difference を具体化する観測点（assertion / exception boundary / import failure / returned-output mismatch など）」と広めに書くこと。assertion-only に狭めると failed-approaches の「特定観測境界への過度な還元」に近づく。
2. 変更差分では「new gate を追加した」のではなく、「既存 COUNTEREXAMPLE required を STRUCTURAL TRIAGE bypass にも整合適用する」と明記すること。これで必須ゲート純増の誤読を防げる。
3. 可能なら After 文の末尾を「otherwise continue analysis or state uncertainty if test impact remains unverified」として、ANALYSIS 復帰と不確実性明示の両分岐を残すこと。これで EQUIV 側への戻しだけでなく、根拠不足時の中立処理も明確になる。

承認: YES