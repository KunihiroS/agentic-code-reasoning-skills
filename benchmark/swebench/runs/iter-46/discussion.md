# iter-46 discussion

## 総評
提案の中身は、STRUCTURAL TRIAGE や終盤 self-check の新設ではなく、compare の EQUIV 側 `NO COUNTEREXAMPLE EXISTS` の書き方を「既に観測した意味差分に再接続する形」へ置換するものです。差分発見後でも generic な不在証明で EQUIV に閉じやすい、という実行時の弱点に対して、最小差分で分岐条件を変えようとしており、方向性は妥当です。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

README.md / docs/design.md と照合すると、この提案は研究コアである「番号付き前提・仮説駆動探索・手続き間トレース・必須反証」を削らず、compare テンプレート内の反証記述の粒度だけを上げる変更です。論文由来の core structure を崩すものではありません。

## 2. Exploration Framework のカテゴリ選定
カテゴリ E（表現・フォーマット改善）は概ね適切です。

理由:
- 主対象は新規ステップ追加ではなく、既存の EQUIV 側テンプレート文言の置換。
- 変更の効き方も「何を必須セクションにするか」より「既存セクションで何を結論根拠として書かせるか」にある。
- 一方で、単なる wording polish ではなく compare の分岐を実効的に変える提案なので、E の中でも “decision wording that changes branch behavior” として扱うのが正確です。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用
EQUIVALENT 側への作用は明確です。既に意味差分を見つけたのに generic な「反例なし」で閉じる経路を弱め、
- その差分に anchored な具体テストで同一 assertion outcome を示す
- できなければ UNVERIFIED を残す
という分岐へ変えます。

NOT_EQUIVALENT 側への直接作用は弱いです。`COUNTEREXAMPLE` ブロック自体は変えていないため、NOT_EQUIVALENT の成立条件を直接緩和・強化する提案ではありません。したがってこの案は本質的には「偽 EQUIV を減らし、必要時に保留へ戻す」方向の変更です。

ただし逆方向の悪化は現時点では明白ではありません。理由は、NOT_EQUIVALENT に必要な diverging assertion の要求を増やしていないため、偽 NOT_EQUIV を増やす主因にはなりにくいからです。提案文の `Target: 両方` はやや強めで、実態は「主に EQUIV / UNVERIFIED 分岐へ効き、NOT_EQUIVALENT には間接効果のみ」と見るのが妥当です。

## 4. failed-approaches.md との照合
本質的再演ではない寄りです。

- 原則1「再収束を比較規則として前景化しすぎない」
  - NO
  - この提案は「後段で吸収できるから EQUIV」を強めるのではなく、逆に generic absorption をしにくくする方向です。
- 原則2「未確定なら常に保留へ倒す既定動作」
  - NO（軽微な注意あり）
  - `otherwise mark the impact UNVERIFIED` は保留化を含みますが、条件が「semantic difference observed かつ EQUIV still claimed」の局所条件に限定され、全体の fallback を Guardrail 化していません。
- 原則3「差分の昇格条件を新しい抽象ラベルや必須の言い換え形式で強くゲートしすぎない」
  - NO（ここが最重要）
  - 新しいラベル体系を導入せず、既存の `NO COUNTEREXAMPLE EXISTS` ブロック内の根拠記述を具体化するだけに留めています。
- 原則5「最初に見えた差分から単一の追跡経路を即座に既定化しすぎない」
  - NO 寄り
  - “one concrete relevant test/input” は単一路線固定に見えうるものの、適用位置が exploration の次アクション固定ではなく EQUIV 主張の根拠提示なので、探索経路そのものの半固定まではしていません。

## 5. 汎化性チェック
汎化性違反は見当たりません。

- 具体的な数値 ID: なし
- リポジトリ名: なし
- テスト名: なし
- 実コード断片: なし（SKILL.md 自己引用のみ）

また、提案は特定言語や特定テストフレームワークを前提にしていません。`test/input`, `assert/check:file:line`, `assertion outcome` は比較的一般的な抽象度に保たれています。

軽微な注意として、`one concrete relevant test/input` はテスト中心に読まれやすいので、実装時は README / SKILL の既存定義と整合するよう「relevant test or observable assertion boundary」程度にしておくとさらに言語横断性が高まります。

## 6. 推論品質の改善期待
期待できる改善は次の通りです。

- 差分を見つけた後の premature EQUIV を減らせる
- 「差分はあるが test outcome には効かない」を言うときの根拠が具体化される
- generic counterexample search の空振りを、そのまま equality witness と誤用しにくくなる
- 追加探索が必要なケースを UNVERIFIED / lower confidence に送り直しやすくなる

要するに、compare の弱点だった「差分発見後の雑な吸収」を減らし、EQUIV の証明責務を assertion outcome レベルへ近づける効果が見込めます。

## 停滞診断
懸念は 1 点だけです。

- この提案は監査 rubric 上は説明しやすいが、compare 実行時の差が `generic search` から `anchored witness` へ本当に置換される実装文言になっていないと、説明強化だけで止まる恐れがあります。ただし今回は Trigger line が差分プレビューに入っており、この懸念はかなり抑えられています。

failed-approaches 該当性:
- 探索経路の半固定: NO
- 必須ゲート増: NO
- 証拠種類の事前固定: NO

## compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  - 意味差分を観測済みなのに EQUIV を出していたケースの一部が、追加探索要求または `UNVERIFIED` 明示に変わる。
- 1) Decision-point delta:
  - IF/THEN 形式で 2 行（Before/After）になっているか？ YES
  - Before/After が理由の言い換えだけか？ NO。After は「anchored concrete test/input with same traced assertion outcome、できなければ UNVERIFIED」という行動変化を含む。
  - Trigger line（発火する文言の自己引用）があるか？ YES
- 2) Failure-mode target:
  - 主対象は偽 EQUIV。機序は「差分発見後の generic no-counterexample を equality witness として使う」誤りを減らすこと。
  - 偽 NOT_EQUIV への直接抑制効果は限定的。
- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？
  - NO
  - impact witness の要求有無: N/A（早期 NOT_EQUIV 改変案ではないため）
- 3) Non-goal:
  - STRUCTURAL TRIAGE は変更しない
  - 新しい必須ゲートは増やさない
  - 証拠種類を新ラベルで固定しない
  - 既存 EQUIV ブロックの置換に限定する

## Discriminative probe
抽象ケース:
- 両変更が同じ高レベル目的を持つが、片方だけ途中の条件分岐順序が異なり、意味差分は確認できている。一方で、どの既存 assertion に実際に到達するかはまだ未確定。
- 変更前は「それらしい反例が見つからない」で EQUIV に閉じやすい。変更後は、その差分に結びついた具体テスト/入力で同一 assertion outcome を示せない限り `UNVERIFIED` を残すため、偽 EQUIV を避けて追加探索へ戻れる。

これは新しい必須ゲート追加ではなく、既存 `NO COUNTEREXAMPLE EXISTS` の equality witness を generic 不在証明から anchored witness に置換する説明になっています。

## 支払い（必須ゲート総量不変）の確認
A/B の対応付けは明示されています。

- 追加するもの: anchored witness の要求
- 支払い: 既存 generic `NO COUNTEREXAMPLE EXISTS` 文言を置換し、新規 MUST を純増しない

この点は比較的明確で、停滞しやすい「説明だけ増えて実効差がない」型にはなっていません。

## 最終判断
最大の懸念は、NOT_EQUIVALENT への直接改善を少し言い過ぎていることですが、これは blocker ではありません。提案の実体は明確で、Trigger line・Before/After・Payment・Discriminative probe がそろっており、failed-approaches の本質的再演でもありません。

修正指示（最小限）:
1. `Target: 両方` は少し広いので、「主に EQUIV/UNVERIFIED 分岐、NOT_EQUIVALENT には間接効果」と表現を弱める。
2. `one concrete relevant test/input` は、実装時に `one concrete relevant test/input or observable assertion boundary` のようにわずかに一般化する。
3. `same traced assertion outcome` の requirement は維持しつつ、探索順固定に読まれないよう「existing observed difference に対する witness」であることを一貫して明記する。

承認: YES
