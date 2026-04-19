# Iteration 36 — 変更理由

## 前イテレーションの分析

- 前回スコア: 不明（参照制約により、この文書内では確認できない）
- 失敗ケース: 不明（参照制約により列挙しない）
- 失敗原因の分析: `compare` で STRUCTURAL TRIAGE の「早期 NOT EQUIVALENT」分岐が、構造差そのものだけで短絡しやすく、(a) 偽 NOT EQUIVALENT を生みうること、(b) 監査時に「なぜそれがテスト結果差に接続するのか」の説明密度が薄くなりうることがボトルネックになりうる。

## 改善仮説

STRUCTURAL TRIAGE で早期に NOT EQUIVALENT を結論づける場合、構造差がテスト結果差に接続することを示す最小限の「impact witness」を必須要件として結論文に含めるようにすると、短絡的な偽 NOT EQUIVALENT を抑えつつ、真の NOT EQUIVALENT の速度は維持できる。

## 変更内容

- `compare` 証明書テンプレ冒頭の「ANALYSIS を必ず完了してから結論へ進め」を、STRUCTURAL TRIAGE で早期終了する場合の例外として整理し、早期終了時には結論内で impact witness の明記を MUST にした。
- STRUCTURAL TRIAGE の早期 NOT EQUIVALENT への分岐条件を、「structural gap がある」だけではなく「impact witness を述べられる場合のみ」に変更した。

Trigger line (final): "impact witness (test/assertion boundary or concrete usage)"
上の Trigger line は、提案の差分プレビューにあった Trigger line と一致している（一般化の意図も同一）。

## 期待効果

- 偽 NOT EQUIVALENT の抑制: structural gap が見えても、テスト/assertion boundary あるいは具体使用への接続（impact witness）が示せない場合は早期結論に進みにくくなる。
- 監査の改善: NOT EQUIVALENT 結論が「影響の目撃」を伴うため、説明責任（なぜテスト結果差につながるか）が上がる。
- 回帰リスクの抑制: 変更は STRUCTURAL TRIAGE からの早期終了分岐に局所化され、通常の ANALYSIS 手順全体を増やさない。