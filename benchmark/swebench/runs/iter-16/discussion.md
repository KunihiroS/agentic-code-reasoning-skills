# iter-16 discussion

## 総評
提案の主眼は、意味差を見つけた後の compare の比較単位を「単発の traced path」から「shared test-facing obligation」へ置き換える点にあります。これは `SKILL.md` の compare checklist にある既存の no-impact 吸収規則を、より分岐的で対称な比較ルールへ差し替える提案であり、研究コア（番号付き前提・仮説駆動探索・手続き間トレース・反証）を壊さずに compare の最終判断点へ作用します。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

この提案は、README.md / docs/design.md にある「certificate-based reasoning」「per-item iteration」「subtle difference dismissal の防止」と整合的です。特に docs/design.md の「per-item iteration as the anti-skip mechanism」と、SKILL.md Guardrail 4 の「subtle differences を安易に no impact 扱いしない」に沿っており、論文コアから外れた新奇モード追加ではなく compare の比較粒度の調整として理解できます。

## 2. Exploration Framework のカテゴリ選定
カテゴリ C（比較の枠組みを変える）は適切です。

理由:
- 提案は探索順序そのものよりも、差分発見後に何を比較単位として verdict に反映するかを変えている。
- D2 の relevant tests 発見規則や STRUCTURAL TRIAGE の発火条件を直接いじるのではなく、「見つかった意味差をどう畳むか」を変えている。
- したがって A/B/D/E/F/G よりも、比較フレームの変更として整理するのが最も自然です。

## 3. EQUIVALENT / NOT_EQUIVALENT の両方向への作用
片方向最適化ではなく、両方向に実効差があります。

- EQUIVALENT 側:
  変更前は「relevant test を 1 本 trace して同じ outcome」が見えると、差分を no-impact として早く吸収しやすい。変更後は obligation-preserving の確認が要るので、代表 path の一致だけで吸収しにくくなり、偽 EQUIV を減らせる。
- NOT_EQUIVALENT 側:
  変更前は内部差分や構造差が見えたときに、それ自体を重く見て NOT_EQUIV 方向へ寄りやすい。変更後は obligation-breaking を要求するので、「見た目の差がある」だけでは足りず、shared obligation に結びつく破れが要る。これにより偽 NOT_EQUIV も抑えられる。
- したがって、提案は EQUIV だけを厳しくするものでも、NOT_EQUIV だけを出しやすくするものでもなく、比較単位を揃えることで両側の誤判定メカニズムに効いています。

## 4. failed-approaches.md との照合
本質的再演ではない、という評価です。ただし 1 点だけ注意は必要です。

整合する点:
- 原則1「再収束を比較規則として前景化しすぎない」:
  本提案は downstream 一致を既定吸収規則にするのではなく、差分を obligation 単位で保留・維持できるようにしており、むしろ再収束偏重を弱める方向です。
- 原則2「未確定 relevance や脆い仮定を常に保留へ倒しすぎない」:
  提案文上は unresolved をローカルな分類結果として扱っており、全体 verdict の既定を一律保留に変えるとは書いていません。
- 原則3「差分の昇格条件を新しい抽象ラベルで強くゲートしすぎない」:
  obligation ラベルは新しい抽象語ではあるが、差分を探索開始前にふるい落とす gate ではなく、差分発見後の比較項目整理として使われています。このため、本質は「抽象フィルタの追加」より「no-impact 吸収基準の置換」に近いです。

注意点:
- `shared test-facing obligation` が抽象的なままだと、実装時に「新しいラベルで差分昇格をゲートする」再演へ寄る余地があります。ここは obligation を“テストが観測する assert/assertion boundary に接続された義務”として短く定義しておく方が安全です。

## 5. 汎化性チェック
明示的なルール違反は見当たりません。

- 具体的な数値 ID: なし
- 特定リポジトリ名: なし
- 特定テスト名: なし
- ベンチマーク実コード断片: なし
- 特定言語/特定フレームワーク前提: なし

また、提案は「input normalization before assertion」のような抽象例に留まっており、特定の言語仕様やテストランナーに依存していません。compare 一般における「テストが観測する義務」という表現なので、汎化性は保たれています。

## 6. 全体の推論品質への期待効果
期待できる改善は、差分発見後の premature absorption と premature divergence の両方を減らすことです。

- 既存 compare は per-test tracing を持つ一方で、差分発見後の吸収単位が path witness に寄りやすい。
- この提案は、その最後の判断点で「何をもって同じと言うか」を obligation 単位に揃えるため、test-facing relevance を保ったまま比較粒度だけを一段上げられる。
- 研究コアを増築するのではなく、既存の trace / edge case / counterexample を再利用するので、複雑性増も比較的小さい。

## 停滞診断
- 懸念点 1 つだけ: `shared test-facing obligation` の定義が弱いままだと、監査 rubric 上はもっともらしく見えても、実際の compare では単に「1 本 trace した結果」を obligation と言い換えるだけになり、意思決定が変わらない恐れがあります。

failed-approaches 該当性:
- 探索経路の半固定: NO
- 必須ゲート増: NO（既存 MUST の demote/remove を payment として明示）
- 証拠種類の事前固定: NO

## compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  - 代表 1 経路の一致だけでは EQUIVALENT に吸収されず、`UNRESOLVED` 明示・追加探索要求・CONFIDENCE 低下が観測可能に増える。
  - 逆に、単なる内部差分だけでは NOT_EQUIV に倒れず、`BROKEN IN ONE CHANGE` を要求する方向へ変わる。

- 1) Decision-point delta:
  - Before/After が IF/THEN 形式で 2 行になっているか: YES
  - Trigger line（発火する文言の自己引用）が差分プレビューにあるか: YES
  - 評価: 条件も行動も変わっている。Before は「1 本 trace して same outcome なら no-impact 吸収」、After は「obligation 未分類なら comparison item として保持し、追加探索/UNVERIFIED/confidence reduction」。理由の言い換えだけではない。

- 2) Failure-mode target:
  - 対象: 両方
  - メカニズム:
    - 偽 EQUIV: 単発 witness path で差分を吸収しすぎる誤りを減らす
    - 偽 NOT_EQUIV: 内部差分や構造差を obligation 破れの確認前に重く見すぎる誤りを減らす

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？: NO
  - したがって impact witness 要件はこの提案の承認可否の主要争点ではない。

- 3) Non-goal:
  - D2 の relevant tests 発見規則を狭めない
  - STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件をこの提案で広げたり狭めたりしない
  - 未解決差分を一律保留へ送る新しい既定動作にしない

追加チェック:
- Discriminative probe:
  - 代表入力では同じ assert を通るが、片側だけ別入力群に対する前処理義務を外しているケースを考える。
  - 変更前は「代表 path で同じ outcome」を理由に no-impact 吸収しやすく、偽 EQUIV が起きる。
  - 変更後は、その差分を assertion boundary に接続した obligation として保持するため、追加探索または NOT_EQUIV に進める。これは新しい必須ゲート追加ではなく、既存の no-impact 規則の置換で説明できている。

追加チェック（停滞対策の検証）:
- 支払い（必須ゲート総量不変）の A/B 対応付けが proposal 内で明示されているか: YES
  - `add MUST(...)` ↔ `demote/remove MUST(...)` が明記されているため、この点は通過。

## 最小限の修正指示
1. `test-facing obligation` を 1 行で定義してください。
   - 追加するより、既存 Trigger line の末尾に「= an obligation connected to a concrete assertion boundary in existing tests」程度を統合する形がよいです。
2. `UNRESOLVED` の扱いを「verdict 保留の既定」ではなく「追加探索 or confidence reduction の局所シグナル」と明記してください。
   - 新しい guardrail を足すのでなく、After 文の後半をこの趣旨に圧縮して置換するのがよいです。
3. `Only PRESERVED BY BOTH differences may be absorbed` に対応して、NOT_EQUIV 側も「BROKEN IN ONE CHANGE requires a concrete test-facing divergence claim」と 1 行だけ対称化してください。
   - 行数を増やすなら、EDGE CASES 見出し下の既存補足 1 行を統合して相殺するのが望ましいです。

## 結論
この提案は、compare の実行時アウトカム差が具体で、Decision-point delta も IF/THEN で明示され、Trigger line と payment も備えています。failed-approaches.md の本質的再演でもなく、片方向最適化でもありません。懸念は obligation 概念の抽象度だけで、これは小さな明確化で足ります。

承認: YES
