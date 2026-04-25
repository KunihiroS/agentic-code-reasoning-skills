# Iteration 53 — Discussion / 監査コメント

## 1. 既存研究との整合性

検索なし（理由: 一般原則の範囲で自己完結）。

提案は、特定の新規研究概念に依拠するというより、既存の SKILL.md / docs/design.md が重視する「per-test iteration」「assert/check result へのトレース」「unsupported claim を避ける certificate-based reasoning」を、Compare template の 1 行でより明確化するもの。README.md / docs/design.md にある、構造化テンプレートにより unsupported claims と premature conclusion を防ぐ設計方針と整合している。

## 2. Exploration Framework のカテゴリ選定

カテゴリ E（表現・フォーマット改善）として適切。

理由:
- 変更対象は Compare template 内の `Comparison:` 行の語彙と条件の明確化であり、探索順序・証拠取得方法・比較単位そのものを大きく変えていない。
- 「UNVERIFIED を SAME/DIFFERENT 証拠として消費しない」という判断境界は増えるが、新しいモードや新しい分析セクションではなく、既存の per-test comparison 欄のラベル選択を具体化する変更である。
- 研究コアである番号付き前提、仮説駆動探索、手続き間トレース、必須反証は維持される。

## 3. EQUIVALENT / NOT_EQUIVALENT の両方向への作用

EQUIVALENT 側:
- 片側または両側の assert/check result が未検証なのに `SAME` と書いてしまう偽 EQUIV を減らす効果がある。
- 特に、内部挙動の差分を見つけたが実際の assertion outcome まで追えていない場合に、`Impact: UNVERIFIED` として confidence / additional exploration に残せる。

NOT_EQUIVALENT 側:
- 未検証 result を `DIFFERENT` として扱う偽 NOT_EQUIV を減らす効果がある。
- 「semantic difference がある」ことと「assert/check result が異なる」ことを分離するため、差分シグナルを verdict-bearing evidence へ過剰昇格する誤りを抑える。

変更前との差分:
- 変更前は `Comparison: SAME / DIFFERENT assertion-result outcome` が、UNVERIFIED を含む行でも二択ラベルを埋める圧力を作っていた。
- 変更後は、両側が traced PASS/FAIL のときだけ SAME/DIFFERENT を使い、未検証が混じる場合は `Impact: UNVERIFIED` に残す。
- これは EQUIV だけ、または NOT_EQUIV だけへの片方向最適化ではなく、UNKNOWN を verdict evidence に変換してしまう共通誤りを両方向で抑える変更である。

## 4. failed-approaches.md との照合

本質的な再演ではないと判断する。

- 原則 2「未確定な relevance や脆い仮定を、常に保留側へ倒す既定動作にしすぎない」:
  - 懸念はあるが、提案は relevance 未確定一般を保留に送るものではなく、per-test の assert/check result が UNVERIFIED の場合に限定して SAME/DIFFERENT ラベルを禁止するもの。
  - 広い fallback ではなく、既存欄の証拠ラベル誤用を防ぐ局所ルールなので、原則 2 の本質的再演とはいえない。

- 原則 3「差分の昇格条件を新しい抽象ラベルや必須の言い換え形式で強くゲートしすぎない」:
  - `Impact: UNVERIFIED` は新しい抽象分類体系というより、既存 SKILL.md でも使われている UNVERIFIED の明示である。
  - 差分を verdict に使うには assertion outcome へ結びつく必要がある、という既存 Step 5.5 の方向と整合する。

- 原則 5「最初に見えた差分から単一の追跡経路を即座に既定化しすぎない」:
  - 特定の探索経路や単一アンカーからの逆向き追跡を強制していない。
  - per-test comparison の出力ラベル条件を変えるだけなので、探索経路の半固定には当たらない。

## 5. 汎化性チェック

問題なし。

- 具体的なベンチマーク ID、数値ケース ID、リポジトリ名、テスト名、実コード断片は含まれていない。
- `file:line`, `PASS/FAIL/UNVERIFIED`, `assert/check`, `C[N]` は SKILL.md 自身のテンプレート語彙・疑似記法であり、Objective.md の R1 減点対象外に該当する。
- 特定の言語、フレームワーク、テストパターンへの依存も見当たらない。assert/check result を比較するという前提は Compare mode の定義そのものに属する。

## 6. compare 影響の実効性チェック

0) 実行時アウトカム差:
- 実際の compare 実行で、片側または両側の result が UNVERIFIED の per-test 行に対し、`Comparison: SAME/DIFFERENT` ではなく `Impact: UNVERIFIED` と書く出力が増える。
- その結果、ANSWER を確定する前に confidence を下げる、追加探索へ戻る、または conclusion で未検証影響を明示する動きが観測可能に変わる。

1) Decision-point delta:
- IF/THEN 形式で 2 行（Before/After）になっているか？ YES。
- Before/After は「条件も行動も同じで理由だけ言い換え」ではない。条件が「result field が PASS/FAIL/UNVERIFIED で埋まっている」から「both sides have traced PASS/FAIL」に変わり、行動も SAME/DIFFERENT から `Impact: UNVERIFIED` へ分岐する。
- Trigger line が差分プレビュー内に含まれているか？ YES。
- 発火する文言の自己引用もあり、実装時のズレは比較的小さい。

2) Failure-mode target:
- 対象は両方。
- 偽 EQUIV: 未検証側を SAME と推測して equivalence evidence にしてしまう誤りを減らす。
- 偽 NOT_EQUIV: 未検証側を DIFFERENT と推測して non-equivalence evidence にしてしまう誤りを減らす。
- メカニズムは、UNKNOWN / UNVERIFIED を verdict-bearing evidence から外し、PASS/FAIL が両側で traced された場合だけ assertion-result comparison に使うこと。

2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？ NO。
- Structural triage の早期 NOT_EQUIV 条件は追加・変更していない。
- したがって、impact witness 要求の有無は今回の主ブロッカーではない。

3) Non-goal:
- 探索経路の半固定はしない。
- 必須ゲート総量は増やさず、既存 `Comparison:` 行の置換として支払う。
- 証拠種類を新たに事前固定するのではなく、既存の assert/check result 欄における PASS/FAIL と UNVERIFIED の混同を防ぐ。

## 7. 停滞診断

監査 rubric に刺さる説明強化へ偏り、compare の意思決定を変えていない懸念:
- 懸念は小さい。提案は単なる rationale 強化ではなく、per-test comparison のラベル選択を `both traced PASS/FAIL` 条件に変更しており、実行時の ANSWER / CONFIDENCE / additional exploration に観測可能な差が出る。

failed-approaches.md への該当:
- 探索経路の半固定: NO。
- 必須ゲート増: NO。Payment として既存 MUST の置換が明示されている。
- 証拠種類の事前固定: NO。assert/check result は既存 Compare template の中心証拠であり、新たに証拠種類を狭く固定しているわけではない。ただし、実装時に「UNVERIFIED が一つでもあれば常に結論禁止」と広げると原則 2 に近づくため、提案文どおり per-test comparison label の局所変更に留めるべき。

## 8. Discriminative probe

抽象ケース:
- Change A は relevant test の assert/check まで traced され PASS と分かるが、Change B は途中の外部依存または未読分岐により assert/check result が UNVERIFIED のまま。
- 変更前は `Comparison: SAME / DIFFERENT` を埋める圧力により、B を推測して偽 EQUIV または偽 NOT_EQUIV に倒れやすい。
- 変更後は既存行の置換だけで `Impact: UNVERIFIED` に残るため、未検証情報を verdict evidence に変換する誤判定を避けられる。新しい必須ゲートの増設ではなく、既存 comparison 行の条件付きラベル化で説明されている。

## 9. 支払い（必須ゲート総量不変）の確認

問題なし。

proposal 内で A/B の対応付けが明示されている:
- add MUST: `Comparison: SAME / DIFFERENT only when both traced assert/check results are PASS/FAIL; if either side is UNVERIFIED, write Impact: UNVERIFIED instead of using it as equivalence evidence.`
- demote/remove MUST: `Comparison: SAME / DIFFERENT assertion-result outcome; note any internal semantic difference separately.`

これは必須行の追加ではなく置換として扱えるため、compare 停滞を招くチェックリスト増加にはなりにくい。

## 10. 全体の推論品質への期待効果

期待効果は明確。

- per-test analysis の中心である assertion-result comparison が、verified result と unknown result を混同しにくくなる。
- Step 5.5 の「semantic difference used for the verdict changes a traced assert/check result; otherwise the impact is marked UNVERIFIED」と整合し、既存の自己チェックが per-test template 内でも発火しやすくなる。
- 結論を過度に保留へ倒すのではなく、verdict-bearing evidence と uncertainty の境界を明確にするため、EQUIV / NOT_EQUIV の両方で premature verdict を減らす可能性がある。

## 修正指示（最小限）

1. 実装時は必ず既存 `Comparison:` 行の置換に留め、追加の checklist や Guardrail を増やさないこと。
2. `Impact: UNVERIFIED` は「結論禁止」ではなく「SAME/DIFFERENT の証拠として使わない」意味に限定すること。
3. Trigger line は proposal のプレビューどおり、置換後の `Comparison:` 行そのものとして入れること。

承認: YES
