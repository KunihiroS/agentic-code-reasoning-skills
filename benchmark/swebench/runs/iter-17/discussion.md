# iter-17 discussion

## 総評
提案の狙いは明確で、compare の Step 5 における「何を最初に反証するか」という意思決定点を、結論反転レバレッジ中心から、A/B の最小の振る舞い分岐候補中心へ差し替えるものです。これは結論文の言い換えではなく、反証対象の選び方そのものを変える提案になっており、compare の実効差につながる可能性があります。

過度に新しいゲートを増やさず、既存の必須反証ステップの内部優先順位だけを置換する構造なので、今回の運用方針（監査 PASS の下限を満たしたまま compare 改善につなげる）にも比較的沿っています。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

docs/design.md では、原論文から fault localization 側の「Divergence Analysis → Ranked Predictions」を抽出済みであり、README.md / docs/design.md / SKILL.md の範囲だけで「未活用の論文由来アイデアを compare に移植する」という提案の妥当性は評価できます。追加の外部確認がないと成立しない固有概念依存ではありません。

## 2. Exploration Framework のカテゴリ選定
カテゴリ F（原論文の未活用アイデアを導入する）は適切です。

理由:
- 提案の中心は、diagnose にある divergence analysis の発想を compare の反証対象選定へ移す点にあります。
- これは docs/design.md の「他タスクの手法を translate して使う」という方針と整合します。
- 副次的には B（探索の優先順位付け変更）にも見えますが、主たる根拠が「論文由来で SKILL compare には未移植」という点にあるため、F が第一カテゴリで妥当です。

## 3. compare 影響の実効性チェック
- Decision-point delta:
  - Before: IF Step 5 で反証対象を選ぶ THEN 「否定すると最終結論が反転する主張」を優先する。
  - After: IF compare で Step 5 の反証対象を選ぶ THEN 「A/B の最小の振る舞い分岐候補を 1–3 個に局在化し、上位から反証する」を優先する。
- IF/THEN 形式で 2 行になっているか: YES
- Before/After が理由の言い換えだけか: NO。条件に compare 限定が入り、行動も「claim を潰す」から「divergence candidate を潰す」へ変わっています。
- Trigger line（発火する文言の自己引用）が差分プレビュー内にあるか: YES
  - `In compare, prioritize refuting the top-ranked divergence candidate first ...`

- Failure-mode target:
  - 主対象は両方です。
  - 偽 EQUIV 側: 差分を見つけても「影響なし」と丸める前に、どの入力/どの assert で分岐するかを詰めるので、 subtle difference dismissal を減らしやすいです。
  - 偽 NOT_EQUIV 側: 差分の存在だけでなく、実際に test-relevant な分岐候補として具体化できるかを問うため、差分の場所だけを根拠に早期 NOT_EQUIV へ倒れるのを抑えやすいです。

- Non-goal:
  - STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件は変えない。
  - 新しい必須ゲートは増やさない。
  - 証拠種類を固定せず、既存 Step 5 の優先順位付けだけを置換する。

- Discriminative probe:
  - 抽象ケースとして、A/B に小さな条件分岐差はあるが、実際に既存テストが踏む assert 条件は一部しか関係しない場合を考える。
  - 変更前は「結論を反転しそうな主張」を先に触るため、差分の重要性を大きくも小さくも雑に扱いやすいです。
  - 変更後は「どの入力・どの assert で分岐するか」を先に候補化するため、既存テストに刺さる差分かどうかをより早く識別できます。これは新ゲート追加ではなく、既存の反証優先順位の置換として説明されています。

- 支払い（必須ゲート総量不変）の A/B 対応付けが明示されているか:
  - YES。既存の Step 5 優先順位文を compare 向けの divergence candidate 優先へ差し替え、その他モードでは既存ルールを残す、という対応が proposal に書かれています。

## 4. EQUIVALENT / NOT_EQUIVALENT の両方向への作用
片方向最適化には見えません。実効差分は両方向にあります。

- EQUIVALENT 判定への作用:
  - 「差分はあるがテスト結果は同じ」を主張する際、単に大きな主張を守るのではなく、最小分岐候補ごとに潰す方向になるため、安易な偽 EQUIV を減らす方向に働きます。
  - しかも `NO COUNTEREXAMPLE EXISTS` と相性がよく、反例像をより具体的に作りやすくなります。

- NOT_EQUIVALENT 判定への作用:
  - 「違いがある」ではなく「この assert / この入力で分岐する」と結びつける圧力が強くなるため、差分の存在だけで早く NOT_EQUIVALENT を出す誤りを減らせます。
  - 既存の COUNTEREXAMPLE 節とも整合的です。

- 変更前との実効差分:
  - 変更前は、反証の単位が抽象 claim/assumption で、結論反転の leverage が主軸でした。
  - 変更後は、compare に限って反証の単位が「test-relevant な最小分岐候補」へ寄るため、差分の実害/無害の判定がテスト挙動に近い粒度になります。

## 5. failed-approaches.md との照合
本質的な再演には見えません。ただし 1 点だけ、文言次第では半固定化のリスクがあります。

- 探索経路の半固定: NO
  - 理由: 提案は Step 3 の読解順序や「どこから読み始めるか」を固定していません。Step 5 の反証優先順位だけを compare で変える提案です。

- 必須ゲート増: NO
  - 理由: proposal 自身が「新しい必須ゲートは増やさず、既存の優先順位付け文を差し替える」と宣言しています。

- 証拠種類の事前固定: NO
  - 理由: divergence candidate は反証対象の粒度指定であって、特定の証拠種別テンプレートの固定ではありません。

補足懸念:
- `list 1–3 candidates` の書き方は、軽い報告義務として働く可能性があります。現状でも致命的ではありませんが、compare に効く本体は「minimal behavioral branch を優先する」点であり、数の明示が強すぎると形式適応に寄るおそれがあります。

## 6. 汎化性チェック
汎化性違反は見当たりません。

- 具体的な数値 ID: なし（Step 番号や 1–3 candidates は手順表現であり、ベンチマーク固有 ID ではない）
- リポジトリ名: なし
- テスト名: なし
- ベンチマーク固有コード断片: なし

また、提案は特定の言語・フレームワーク・テストランナーを暗黙前提にしていません。`minimal A↔B behavioral branch`、`relevant call path`、`assert/input` といった表現は、任意言語の静的コード推論へ概ね持ち運べます。

## 7. 全体の推論品質への期待効果
期待効果はあります。

- compare で「差分を見つけた後の扱い」がよりテスト判定に近い粒度になります。
- subtle difference dismissal と location-only な過剰 NOT_EQUIV の両方を同時に減らす筋が通っています。
- 既存の研究コア（premises / hypothesis-driven exploration / interprocedural tracing / mandatory refutation）を壊さず、Step 5 の反証運用だけを sharpen するので、変更規模に対する改善効率も悪くありません。

## 停滞診断
懸念を 1 点だけ挙げると、「監査 rubric に刺さる説明強化」で終わる危険は低いものの、`1–3 candidates を list` の部分は compare の分岐改善そのものより“ちゃんと考えた感の報告”に寄る余地があります。効く本体は candidate を列挙することではなく、「反証対象の単位を最小分岐へ変える」ことです。

## 修正指示
1. `list 1–3 candidates` は compare 効果の本丸ではないので、必須の列挙義務に読める文言は弱めてください。
   - 追加するのではなく、既存の priority 文の置換に留める形で、`when identifiable, start from the smallest test-relevant divergence candidate` のように簡素化するのがよいです。

2. `minimal A↔B behavioral branch` だけだと抽象度がやや高いので、Trigger line の後半に「e.g. the earliest branch that could change a relevant assertion outcome or exercised input class」程度の一般化された補足を 1 フレーズだけ入れてください。
   - 新欄追加ではなく、同一行の説明置換で十分です。

3. `Otherwise, prioritize ... flip the final answer` の退避先ルールは残してよいですが、compare で divergence candidate が特定できない場合だけ使うことを明記してください。
   - これも新ゲート追加ではなく、fallback 条件の明確化です。

## 結論
承認: YES

理由:
- Decision-point delta が具体で、Trigger line もある。
- 両方向（偽 EQUIV / 偽 NOT_EQUIV）に作用する筋がある。
- failed-approaches.md の本質的再演ではなく、必須ゲート純増もない。
- compare 改善に効く中身があり、監査通過のための説明強化だけに留まっていない。