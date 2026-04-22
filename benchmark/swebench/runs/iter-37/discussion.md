# Iteration 37 Discussion

## 総評
提案の中心は、semantic difference 発見後の比較粒度を「single traced test」から「tested input/state partition」へ切り替える条件分岐を明示することにある。これは compare の実行時分岐を実際に変える提案であり、単なる監査向け説明強化には留まっていない。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

README.md / docs/design.md が示す研究コアは「番号付き前提・仮説駆動探索・手続き間トレース・必須反証」であり、今回の提案は compare テンプレート内の比較スコープ決定を調整するもので、コア構造そのものは維持している。特に per-test iteration を捨てるのではなく、semantic difference 発見後に比較対象を広げるか据え置くかの判断規則を追加する形なので、研究の主筋からは逸脱していない。

## 2. Exploration Framework のカテゴリ選定
カテゴリ C（比較の枠組みを変える）は適切。
理由:
- 提案の主語が「差分をどの粒度で比較するか」であり、探索順や自己チェックの強化ではない。
- 単一テスト単位の局所比較から、tested partition という比較単位へスコープ変更する点は、Objective.md の C「比較の枠組みを変える」に素直に入る。
- しかも新しい task mode を増やさず、既存 compare 内の分岐規則だけを差し替えるため、カテゴリ適合性は高い。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用
変更前との実効差分はある。

- EQUIVALENT 側:
  単一 traced test では同じ assertion outcome でも、その差分が tested partition 自体を変えるなら premature EQUIV を避けて追加比較へ進みやすくなる。よって偽 EQUIV を減らす方向に作用する。
- NOT_EQUIVALENT 側:
  semantic difference が同一 partition 内の representative computation 差分に留まる場合、局所差分をすぐ大きく扱わず、比較を current traced test に留めやすくなる。よって局所差分の過大評価による偽 NOT_EQUIV を減らす方向にも作用しうる。
- 片方向最適化か:
  片方向だけではない。提案本文で PARTITION-CHANGING と REPRESENTATIVE-ONLY の二分を置いており、scope expand と local keep の両方の分岐を定義しているため、EQUIV / NOT_EQUIV の両側に効く設計になっている。
- ただし注意点:
  実効性の中心は PARTITION-CHANGING 判定にあるので、実装時に REPRESENTATIVE-ONLY が「差分軽視」の別名になると逆方向悪化の余地はある。したがって分類ラベルは verdict ラベルではなく scope 制御ラベルであることを明確に保つべき。

## 4. failed-approaches.md との照合
本質的再演ではないが、原則 3 には軽い近接がある。

- 原則1「再収束の前景化」: NO
  再収束や downstream handler を中心規則にしていない。
- 原則2「保留側への既定動作の過剰化」: NO
  UNVERIFIED や広い保留への既定分岐を増やしていない。
- 原則3「新しい抽象ラベルや必須の言い換え形式で強くゲートしすぎない」: 軽微な懸念はあるが、本質的再演まではいかない。
  理由は、PARTITION-CHANGING / REPRESENTATIVE-ONLY という新ラベルを mandatory にしている点。ただし今回は「差分を証拠へ昇格させる前の抽象フィルタ」ではなく、「見つかった semantic difference の次の比較スコープを決める用途」に限定されている。つまり差分信号を弱めるためのゲートではなく、比較範囲を調整するための分岐なので、failed-approaches.md の禁止形そのものではない。

## 5. 汎化性チェック
汎化性違反は見当たらない。

- 具体的な数値 ID: なし
- リポジトリ名: なし
- テスト名: なし
- コード断片: ベンチマーク対象コードの引用なし
- ドメイン固定: なし
- 言語固定: なし
- テストパターン固定: 「tested inputs/states の partition」という抽象概念で記述されており、特定言語や特定テストフレームワーク前提にはなっていない

また、proposal 内の change preview は SKILL.md 自己引用と抽象テンプレート文言に留まっており、Objective.md の R1 減点対象外に収まっている。

## 6. 全体の推論品質への期待効果
期待できる改善は比較スコープの適正化。

- 単一 traced test の一致だけで impact なしとみなす早計を減らせる
- 逆に、semantic difference の存在だけで差分を大きく見積もる粗い NOT_EQUIV も抑えられる
- 「何を追加で比較すべきか」を semantic difference の種類から決めるため、追加探索の理由が説明しやすい
- 既存の per-test analysis, counterexample obligation, structural triage を温存したまま compare の分岐精度だけを上げるので、改善コストに対して効果の見込みはある

## 停滞診断
懸念は 1 点だけある。監査 rubric に刺さりやすい「payment 付きの整った説明」にはなっているが、実装時に PARTITION-CHANGING 判定基準が曖昧だと、compare の実行時アウトカム差が「説明の言い換え」へ縮むおそれがある。したがって discussion 段階では、ラベル自体よりも「どの条件で scope expand が発火するか」を SKILL 文言として落とし込めることが重要。

failed-approaches 該当性:
- 探索経路の半固定: NO
- 必須ゲート増: NO
- 証拠種類の事前固定: NO

## compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  semantic difference 発見後、比較対象が current traced test のまま終わるケースの一部で、関連 partition に触れる他テストまで比較拡張が要求される。結果として premature EQUIV のまま結論する挙動が減る、という観測可能な差がある。

- 1) Decision-point delta:
  Before/After が IF/THEN 形式で 2 行になっているか: YES
  Trigger line（発火する文言の自己引用）があるか: YES
  評価: 条件も行動も変わっている。Before は「one traced relevant test still reaches same assertion outcome」なら local keep、After は「classified as PARTITION-CHANGING」なら scope expand なので、理由の言い換えではなく分岐変更になっている。

- 2) Failure-mode target:
  両方。主対象は偽 EQUIV（単一 traced test 一致による impact 見落とし）だが、REPRESENTATIVE-ONLY を用意しているため、局所差分の過大評価による偽 NOT_EQUIV も抑える設計。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？: NO

- 3) Non-goal:
  structural triage の早期 NOT_EQUIV 条件は変えない。新しい必須ゲートや証拠種類固定は増やさず、semantic difference 発見後の比較スコープ制御だけを変える。

追加チェック:
- Discriminative probe:
  抽象ケースは十分ある。入力正規化の位置変更により tested partition の広さが変わるが、単一 failing test では同じ outcome になるケースでは、変更前は偽 EQUIV に寄りやすい。変更後は partition-changing として関連 test family へ比較を広げるため、少なくとも premature EQUIV を避ける。この説明は新ゲート増設ではなく、既存の edge-case mandatory を差分分類へ置換する形で述べられている。

追加チェック（停滞対策）:
- 支払い（必須ゲート総量不変）の A/B 対応付けが proposal 内で明示されているか: YES
  `add MUST(...) ↔ remove MUST("EDGE CASES RELEVANT TO EXISTING TESTS:")` があり、総量不変の説明は足りている。

## 最小修正指示
1. PARTITION-CHANGING の説明を verdict 用語ではなく scope 制御用語として固定すること。
   - 追加ではなく、After preview の `Kind` 行に 1 句補う形で足りる。
2. `representative computation within a shared partition` の文言はやや抽象的なので、compare 実装時には「same tested partition, potentially different local implementation path」のように、比較対象が outcome ではなく path/scope であることが伝わる表現へ置換すること。
3. 置換先の mandatory 文が長くなりすぎるなら、既存 checklist の `trace at least one relevant test...` 行を統合して、必須総量不変を厳密に守ること。

## 結論
この提案は、monitoring 用の監査説明ではなく、compare の実行時分岐を実際に変える提案になっている。failed-approaches.md の本質的再演でもなく、汎化性違反もない。軽い懸念は分類ラベルの抽象性だけで、これは実装文言の明確化で十分に制御可能。

承認: YES
