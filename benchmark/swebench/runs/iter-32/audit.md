# Iteration 32 — Overfitting 監査

## 判定: PASS
## 合計スコア: 18/21

| # | 項目 | スコア | 根拠 |
|---|------|--------|------|
| R1 | 汎化性 | 3 | 変更は「変更シンボルへの直接参照テストが少ないとき、caller / wrapper / helper を辿って観測可能な出力を検証するテストまで探す」という探索手順の明確化であり、Django や Python 固有の API・構文・ケース知識に依存していない。任意の言語・フレームワークで通用する、一般的な手続き間トレースの強化になっている。 |
| R2 | 研究コアの踏襲 | 3 | README と docs/design.md は、semi-formal reasoning の核を「番号付き前提・仮説駆動探索・手続き間トレース・必須反証」と説明している。原論文も structured template が explicit premises, trace execution paths, formal conclusions を要求する certificate だと述べる。本変更は D2 の relevant test 特定手順を interprocedural に補強するだけで、研究コアを維持しつつ強化している。 |
| R3 | 推論プロセスの改善 | 3 | 変更は EQUIV / NOT_EQ の結論を直接指示していない。代わりに、relevant tests をどう見つけるか、どの caller を優先するか、何を oracle とみなすかという探索プロセスを具体化しているため、結論ではなく推論手順そのものの改善である。 |
| R4 | 反証可能性の維持 | 3 | 「observable outputs を assert する最近接 caller のテスト」を優先させることで、見つけたコード差異が本当にテスト結果へ伝播するかを検証しやすくなる。これは差異の過大評価・過小評価のどちらも反証しやすくし、unsupported claim を減らす方向なので、反証可能性はむしろ強化されている。 |
| R5 | 複雑性の抑制 | 2 | 追加は D2 に対する 2 文のみで全体構造を増やしていない一方、「direct reference が sparse か」「nearest caller をどう選ぶか」といった判断負荷はやや増える。複雑化は小さいがゼロではないため 2 が妥当。 |
| R6 | 回帰リスク | 2 | 影響範囲は compare モードの D2 に限定され、既存の定義や conclusion criteria を壊す変更ではない。ただし relevant tests の探索範囲を広げるため、既に十分だったケースでも探索コスト増や、周辺 caller を追いすぎることで判断がぶれる軽微な回帰リスクはある。改善期待が上回るが、極低リスクの 3 までは言いにくい。 |
| R7 | ケース非依存性 | 2 | SKILL.md の diff 自体は特定ケース名・関数名・パッチ形状を一切書いておらず、一般パターンとして記述されている。一方、rationale は django の具体的失敗ケースを出発点に「direct reference が sparse な EQUIV 誤判定」を主問題としており、その失敗モードに寄せた調整であることは推測可能なので 2 とする。 |

## 総合コメント

本変更は、relevant tests の取りこぼしを減らすために、直接参照だけでなく caller / wrapper / helper を辿る探索規律を追加したものであり、研究の certificate-based reasoning と整合している。特に「observable outputs を assert する最近接 caller」を優先する点は、原論文・README・design.md が重視する execution-free でも証拠に基づく手続き間トレースを補強しており、EQUIV / NOT_EQ の両方向で推論の質を上げる余地がある。

懸念は、relevant test 探索のスコープ拡大により、既存にうまくいっていたケースで探索が過剰になったり、どの caller を最も適切とみなすかで迷う可能性があること。また rationale 上は個別失敗ケースに動機づけられているため、完全にケース独立とは言い切れない。それでも、SKILL.md に埋め込まれた規則そのものは一般化されており、特定ベンチマークの答えを教える変更ではない。したがって監査基準では PASS と判断する。
