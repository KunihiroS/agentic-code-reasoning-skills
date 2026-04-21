# iter-2 proposal discussion

## 総評
提案は、STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件をいじらずに、意味差を見つけた後の比較粒度だけを「差分経路そのもの」から「次の共有された test-relevant な観測境界まで差が残るか」へ置き換えるものです。これは Objective.md の Exploration Framework では C. 比較の枠組みを変える、に素直に入ります。差異の重要度を段階的に評価する提案であり、研究コア（番号付き前提・仮説駆動探索・手続き間トレース・必須反証）も維持されています。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

補足: proposal の主張は、README.md と docs/design.md にある「per-item iteration により premature conclusion を防ぐ」「incomplete reasoning chains を避ける」という一般原則の延長で説明可能です。特定の外部概念や固有の研究用語に強く依拠していないため、この段階での Web 検索は不要です。

## 2. Exploration Framework のカテゴリ選定
判定: 適切。

理由:
- 変更対象は compare の結論条件そのものではなく、「差異をどの単位で比較し続けるか」という比較枠組み。
- proposal は path-level divergence を provisional に落とし、次の共有された predicate / returned value / asserted state まで追うようにしている。これは Objective.md の C「差異の重要度を段階的に評価する」に一致する。
- 読む順序の固定化ではなく、差を見つけた後の評価単位の変更なので、A/B/D/E/F/G より C が最もしっくりくる。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用
### EQUIVALENT 側
主効果はここです。内部実装や一時的な経路差があっても、次の共有された test-relevant 境界で再一致するなら non-discriminative と扱えるので、早すぎる偽 NOT_EQUIV を減らしやすいです。

### NOT_EQUIVALENT 側
片方向専用ではありません。現在の文言だと「差を見つけたら relevant test を1本差分経路に通して影響なしと判断」という運用に流れやすく、1本の trace が reconverge しただけで安心してしまう余地があります。提案後は「次の共有された test-relevant predicate/value/asserted state まで差が残るか」を確認するため、再一致しない差をよりはっきり discriminative として扱えます。したがって、偽 EQUIV の抑制にも一定の作用があります。

### 実効的差分
変更前は「差を見つけた時点の path divergence」が比較単位になりやすい。変更後は「その差が次の共有観測境界まで生き残るか」が比較単位になる。これは reasoning の説明の仕方だけでなく、追加探索を続けるか、差分結論に進むか、の分岐を実際に変えます。

### 逆方向悪化の懸念
小さな懸念はあります。"shared test-relevant predicate/value/asserted state" が曖昧なままだと、実装者が reconvergence を広く取りすぎ、潜在的な side effect 差を早く捨てる危険があります。ただし proposal には Trigger line と counterexample 維持があり、しかも STRUCTURAL TRIAGE を狭めていないため、現時点では致命的ではありません。

## 4. failed-approaches.md との照合
failed-approaches.md 自体は現状ほぼ空で、具体ブラックリストは載っていません。そのため直接の再演判定は文書単独では強くできません。

ただし、依頼文で指定された過去失敗の本質との照合では以下の通りです。
- 探索経路の半固定: NO
  - 特定ファイル順・特定探索順を強制していない。差異発見後の比較粒度を変えるだけ。
- 必須ゲート増: NO
  - proposal は Payment を明示し、既存 MUST の置換として出している。新しい mandatory を純増していない。
- 証拠種類の事前固定: NO
  - predicate / returned value / asserted state は「test-relevant な観測境界」の例示であり、特定の証拠型だけに固定していない。むしろ差が残るかどうかを見る抽象条件。

結論として、表現を変えただけの本質的再演には見えません。

## 5. 汎化性チェック
判定: 問題なし。

確認結果:
- 具体的な数値 ID: なし
- ベンチマーク対象リポジトリ名: なし
- テスト名: なし
- 実コード断片: なし
- 特定言語・特定フレームワーク前提: なし

また、proposal の中心語彙は path / predicate / returned value / asserted state / reconvergence で、どれも任意の言語・テスト体系に移せる抽象度です。暗黙のドメイン固定も弱いです。

## 6. 全体の推論品質への期待
期待できる改善は明確です。
- 差を見つけた瞬間に結論へ寄りすぎる癖を抑える
- 内部の一時差と、テスト結果を本当に変える差を分離しやすくする
- per-test iteration と相性が良く、どの時点で比較を継続/終了するかを明確化する
- 「差はあるが outcome は同じ」「途中は似るが outcome は違う」の両方をより丁寧に切り分けられる

とくに docs/design.md の anti-skip 原則とは整合的で、incomplete reasoning chains への対策として自然です。

## 停滞診断
- 懸念 1 点: 「reconvergence まで見る」という説明が、単なる説明強化として書かれて終わると compare の分岐を実際には変えない恐れがある。ただし今回の proposal は Decision-point delta と Trigger line を持っており、この懸念は小さめ。

- 探索経路の半固定に該当するか: NO
- 必須ゲート増に該当するか: NO
- 証拠種類の事前固定に該当するか: NO

## compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  - 差を見つけた直後に NOT_EQUIV 寄りへ倒す回数が減る。
  - reconvergence が見えた場合は「差を捨てて下流比較を続行する」という追加探索が観測可能に増える。
  - reconvergence しない場合は、より早く discriminative difference として counterexample 構築へ進む。

- 1) Decision-point delta:
  - IF/THEN 形式で 2 行（Before/After）になっているか: YES
  - Before/After が条件も行動も同じで理由だけ言い換えか: NO
  - Trigger line（発火する文言の自己引用）が差分プレビュー内にあるか: YES
  - 実際に変わる意思決定ポイント:
    - Before: 差分経路を1本 traced して影響有無へ進む
    - After: 次の共有 test-relevant 境界まで差が残るかを見て、保留/継続/差分結論を分ける

- 2) Failure-mode target:
  - 主対象: 両方
  - 偽 NOT_EQUIV: 一時的な内部 divergence を outcome 差と誤認する誤判定を減らす
  - 偽 EQUIV: 1 本の traced path だけで安心し、下流の shared boundary で残る差を見逃す誤判定を減らす

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か:
  - NO
  - したがって、"ファイル差があるだけ" への退化を招く提案ではない
  - impact witness の要求有無: N/A（STRUCTURAL TRIAGE を触っていないため主論点ではない）

- 3) Non-goal:
  - 早期 NOT_EQUIV の structural gate を狭めない
  - 新しい必須ゲートを純増しない
  - 特定の観測境界や特定証拠型を唯一の正解として固定しない

- Discriminative probe:
  - 抽象ケース: 両変更が異なる補助関数列を通るので途中状態は違うが、同じ canonical 値に正規化されて同じ assertion boundary に到達する。
  - 変更前は path divergence を重く見て NOT_EQUIV に倒れやすい。あるいは 1 本だけ trace して EQUIV と雑に済ませる余地もある。
  - 変更後は「次の共有 boundary で再一致したか」を必ず見に行くので、内部差と outcome 差を分離しやすい。これは既存文言の置換で説明でき、新しい必須ゲートの純増ではない。

- 支払い（必須ゲート総量不変）の明示:
  - 明示あり。add MUST("none") ↔ demote/remove 既存 MUST を書いており、A/B の対応付けは十分。

## 修正指示（最小限）
1. Trigger line の "shared test-relevant predicate/value state" に asserted state を入れた本体文言と完全整合させること。現状、After 文と Trigger line の語彙が少しズレている。
2. reconvergence を non-discriminative とみなす条件に、「downstream asserted state に observable residue がない限り」の含意が読めるよう、短い補足を 1 句だけ入れること。追加ではなく既存文言の統合で足りる。
3. 置換後の compare checklist で、旧文言を完全に落とし、"trace one relevant test through the differing path" と二重運用にならないようにすること。

## 最終判定
承認: YES

理由: compare の実行時アウトカム差が具体で、Decision-point delta と Trigger line と Payment がそろっており、汎化性違反も failed-approaches の本質的再演も見当たらないため。主効果は偽 NOT_EQUIV の抑制だが、shared boundary まで差の残存を確認する点で偽 EQUIV 側にも作用しており、片方向最適化とも言い切れない。