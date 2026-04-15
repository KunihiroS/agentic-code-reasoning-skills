# Iter-57 改善提案

## Exploration Framework カテゴリ: D — メタ認知・自己チェックの強化

### カテゴリ D 内での具体的メカニズム選択理由

カテゴリ D のメカニズムは以下の3つ:
1. 推論途中で思い込みを疑うチェックポイントを追加
2. 結論に至った推論チェーンの弱い環を特定させる
3. 確信度と根拠の対応を明示させる

今回は「3. 確信度と根拠の対応を明示させる」を選択する。

理由: SKILL.md の Step 5.5 は証拠の存在（file:line が引用されているか、VERIFIED マークがあるか、実際の検索が行われたか）を確認するが、「確信度レベルと支持している証拠の強度・数が整合しているか」を問う仕組みがない。HIGH 確信度の主張が単一の観察や弱い推論に依拠している場合でも、現行のチェックリストはそれを検出できない。これは「確信度と根拠の対応を明示させる」が埋める空白であり、かつ既存のチェック項目への精緻化（文言追加）として 5 行以内に収められる。

「推論チェーンの弱い環を特定させる」は failed-approaches.md の「推論中の最弱点を特定して確信度へ結びつける追加評価軸」制限に抵触するリスクがある。「思い込みチェックポイントの追加」は新規ステップとなりやすく、5 行制限と新規セクション禁止に引っかかる。「確信度と根拠の対応」は既存の Step 5.5 最終項目の末尾に文言を補うだけで実現でき、制約を満たす。


## 改善仮説

Step 5.5 の最終チェック項目（結論が証拠の範囲を超えていないかを確認する項）に、「CONFIDENCE: HIGH を主張する場合、複数の独立した証拠が揃っているか」という自己確認の観点を付加することで、証拠が薄いまま過剰な確信度を付与する誤りを抑制できる。


## SKILL.md の変更内容

### 変更箇所

Step 5.5 の 4 番目のチェック項目（SKILL.md 146–148 行目）。

### 変更前

```
- [ ] The conclusion I am about to write asserts nothing beyond what the traced evidence supports.
      If a semantic difference was found, did I trace at least one relevant test through the differing
      path before concluding it affects (or does not affect) the outcome? (cf. Guardrail #4)
```

### 変更後

```
- [ ] The conclusion I am about to write asserts nothing beyond what the traced evidence supports.
      If a semantic difference was found, did I trace at least one relevant test through the differing
      path before concluding it affects (or does not affect) the outcome? (cf. Guardrail #4)
      If claiming CONFIDENCE: HIGH, is that confidence backed by at least two independent pieces of
      traced evidence rather than a single observation or inference?
```

### 変更規模の宣言

追加: 2 行（hard limit 5 行以内。削除: 0 行）


## 一般的な推論品質への期待効果

### 抑制が期待される失敗パターン

1. **過剰確信による誤判定 (overall)**
   単一の証拠（例: 構造上の差分のみ、名前からの推論のみ）から HIGH 確信度の EQUIVALENT/NOT EQUIVALENT 結論を出すケースを抑制する。証拠が 1 つしかないことをモデル自身が気づくと、MEDIUM や LOW への訂正、あるいは追加確認行動が促される。

2. **EQUIV 誤判定 (equiv 方向の精度)**
   2 つの実装が同じ振る舞いをすると誤判定するケースの多くは、差分が見つからなかった（= 単一の「証拠なし」観察）まま HIGH で EQUIVALENT と結論づけるパターン。「独立した証拠が 2 つ以上あるか？」という問いは、こうした消去法ベースの高確信を牽制する。

3. **Guardrail #5 違反（不完全チェーン）との相乗**
   既存の Guardrail #5「下流コードがすでに処理していないか確認する」と組み合わさることで、証拠の量だけでなく下流までの完全性も問うダブルチェックになる。


## failed-approaches.md 汎用原則との照合

| 原則 | 照合結果 |
|------|----------|
| 次の探索で探すべき証拠の種類をテンプレートで事前固定しすぎる | 非抵触。「何を探すか」を固定するのではなく、「主張した確信度が複数証拠に裏付けられているか」という確認を求めるだけで、探索経路は変更しない。 |
| 探索の自由度を削りすぎない | 非抵触。探索の順序・対象・境界を変更しない。結論直前の自己チェックへの追記であり、探索フェーズには介入しない。 |
| 局所的な仮説更新を即座の前提修正義務に直結させすぎない | 非抵触。仮説更新プロセス（Step 3）ではなく Step 5.5 のみに影響し、前提の再点検義務を課すものではない。 |
| 既存ガードレールを特定の追跡方向で具体化しすぎない | 非抵触。特定のトレース方向（例: 「上流を辿れ」）を指示するものではなく、既に辿った証拠の数を振り返る汎用的な確認。 |
| 結論直前の自己監査に新しい必須のメタ判断を増やしすぎない | **要注意**。本変更は既存の Step 5.5 第 4 項への文言追加であり、新規項目の追加ではない。ただし実質的に「確信度の妥当性チェック」という観点が加わる。失敗原則は「特定の検証経路の半必須化」を禁じており、本変更は検証経路ではなく証拠充足性の自己確認であるため抵触しないと判断する。また「反証が見つからなかった場合の記録様式を細かく規定しすぎる」には該当しない（記録様式ではなく確信度と証拠の対応の確認のみ）。 |


## 変更規模の宣言

- 追加行数: 2 行
- 削除行数: 0 行
- 合計変更規模: 2 行（hard limit 5 行以内、適合）
- 変更種別: 既存行への文言追加・精緻化のみ（新規ステップ・新規フィールド・新規セクションなし）
