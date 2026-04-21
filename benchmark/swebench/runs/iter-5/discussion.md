# Iteration 5 — Proposal Discussion

## 総評
提案の主眼は、compare の EQUIV 側で「同じ観測結果に再収束した」という sink agreement だけで安心せず、そこに至るまでの earliest divergence と、その差を無害化する downstream handler/normalizer を対で言語化させる点にある。これは README / docs/design.md にある原論文由来の failure pattern（symptom vs root cause confusion / incomplete reasoning chains）を compare の分岐に落とし込む提案であり、監査説明の追加だけでなく、EQUIV を即断する条件を狭める実効差がある。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。
README.md と docs/design.md だけで、論文由来の「incomplete reasoning chains」「symptom vs root cause confusion」を compare に翻訳する根拠は足りている。今回の提案は新奇概念の持ち込みではなく、既存の guardrail / appendix 系の未活用部分を compare の decision point に移す話なので、追加の Web 検索は必須ではない。

## 2. Exploration Framework のカテゴリ選定
判定: 妥当（F: 原論文の未活用アイデアを導入する）

理由:
- 提案の中心は、Appendix A の per-test / counterexample 義務に、README / docs/design.md が整理している error analysis の知見を compare 用の分岐条件として接続すること。
- これは主に「原論文の未活用アイデアを compare に移植する」提案であり、A/B/D/E ではなく F が最も近い。
- 付随的には D（自己チェック強化）の側面もあるが、主機構は self-check の一般強化ではなく、paper 由来の failure pattern を compare の no-counterexample 分岐へ具体化することなので、F 主分類でよい。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用
### EQUIVALENT 側
- 変更前は「共有された観測結果に達した」「明示的 counterexample が未発見」の組み合わせで、途中の挙動差があっても EQUIV に寄りやすい。
- 変更後は、共有 observed outcome の前に trace divergence が見えた時点で、earliest divergence と downstream absorber の両方が埋まるまで EQUIV を保留できる。これは偽 EQUIV の抑制に効く。

### NOT_EQUIVALENT 側
- 提案は NOT_EQUIV を直接拡張するより、「局所差を見た瞬間に違うと感じる」早計を抑え、下流吸収の有無を確認させる方向に働く。
- したがって、局所差だけに引っ張られた偽 NOT_EQUIV も減らしうる。
- ただし、proposal の本文では NOT_EQUIV branch 自体の trigger を新設していないため、効果は EQUIV 側より間接的。ここは実装時に「差が見えたら即 NOT_EQUIV ではなく、assertion boundary までの影響を見る」という既存 counterexample 義務との接続を崩さないことが重要。

結論として、片方向最適化ではないが、一次効果は偽 EQUIV 抑制、二次効果として偽 NOT_EQUIV 抑制、という非対称な効き方をする提案である。

## 4. failed-approaches.md との照合
判定: 本質的再演ではない。

理由:
- failed-approaches.md が禁じているのは、「再収束を優先する規範を新たな既定動作にすること」。
- 今回はその逆で、再収束を見たときこそ upstream/downstream の因果鎖を閉じるよう求めており、「再収束したから大丈夫」という shortcut を弱めている。
- また「未確定 relevance を常に保留へ倒す既定動作」を広く増やしているわけでもない。発火条件は「same observed outcome の前に divergence がある場合」に限られている。

注意点:
- 実装文言が広がりすぎて「分岐が見えたら常に保留」という既定動作になると failed approach 2 に近づく。したがって、発火条件は proposal の Trigger line のように conditional に保つべき。

## 5. 汎化性チェック
判定: 問題なし

- proposal 内に具体的な数値 ID、ベンチマーク対象リポジトリ名、テスト名、コード断片は見当たらない。
- 含まれているのは SKILL.md 自身の文言引用、一般概念（earliest divergence / downstream handler / normalizer / assertion）と抽象ケースのみで、Objective.md の R1 減点対象外に収まる。
- 特定言語・特定ドメイン前提も薄い。normalizer / handler という語は例外処理やデフォルト化を連想させるが、実質は「下流で差を吸収する機構」を指しており、言語非依存の説明として読める。

## 6. 全体の推論品質への期待効果
- sink agreement だけで十分と誤認する短絡を減らせる。
- upstream divergence と downstream absorption を同一証拠単位で扱うため、reasoning chain の切れ目が見えやすくなる。
- 既存の per-test / counterexample テンプレートを維持したまま、compare に欠けていた「途中差分が最終 outcome にどう消えるか」の説明責任を追加できる。
- Payment で既存 checklist 義務を統合する構成なので、必須ゲートの純増を避けつつ decision quality を上げる方向になっている。

## 停滞診断（必須）
- 懸念 1 点: EQUIV の説明はかなり具体化されている一方、NOT_EQUIV 側の分岐そのものをどう変えるかは間接的なので、実装が甘いと「説明だけ増えて compare の結論分岐はほぼ不変」という停滞が起こりうる。

### failed-approaches 観点の YES/NO
- 探索経路の半固定: NO
- 必須ゲート増: NO（Payment で既存 MUST / checklist 義務を置換する設計が明示されているため）
- 証拠種類の事前固定: NO（全ケース一律ではなく、「same observed outcome 前に divergence がある場合」という条件付き要求に留まるため）

## compare 影響の実効性チェック（必須）
- 0) 実行時アウトカム差:
  - divergence が見えているのに downstream absorber が未確認なケースで、従来なら EQUIV に進みえた出力が、追加探索要求または UNVERIFIED/LOW CONFIDENCE に変わる。

- 1) Decision-point delta:
  - Before: IF 同じ観測結果/assertion に到達し、明示的 counterexample が未発見 THEN EQUIV/no-counterexample を出しやすい。
  - After: IF 同じ観測結果の前に trace divergence がある AND earliest divergence と downstream absorber の両方が未提示 THEN EQUIV を保留し、追加探索または UNVERIFIED/LOW CONFIDENCE に倒す。
  - IF/THEN 形式で 2 行（Before/After）になっているか: YES
  - Trigger line（発火する文言の自己引用）が差分プレビューにあるか: YES

- 2) Failure-mode target:
  - 主対象は偽 EQUIV。
  - 副次対象は偽 NOT_EQUIV。
  - メカニズムは「局所差を見ても sink agreement を見ても、assertion までの因果鎖が閉じるまで結論を急がない」にある。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？: NO

- 3) Non-goal:
  - structural triage の早期 NOT_EQUIV 条件はそのままにし、新比較モードも増やさない。
  - 発火条件のない常時保留ルールにはしない。
  - 既存の必須反証を置き換えるのであって、別腹の mandatory gate を増設しない。

### Discriminative probe（必須）
抽象ケース: 2 つの変更が同じ assertion 値に達するが、一方は入力を早期正規化し、他方は後段 fallback でのみ同値化する。変更前は「最終的に同じ」で EQUIV に寄りやすい。
変更後は、earliest divergence と downstream absorber を対で要求するため、「その fallback が別入力では効かない」という分岐が見つかれば NOT_EQUIV に修正され、見つからなければ EQUIV をより強い因果鎖つきで正当化できる。これは新ゲート追加ではなく、既存の「semantic difference を traced test に落とす」義務の置換で説明できている。

### 停滞対策の検証（必須）
- 支払い（必須ゲート総量不変）の A/B 対応付けは proposal 内で明示されているか: YES
- 対応付け内容: add MUST("earliest divergence + downstream handler/normalizer") ↔ demote/remove MUST("semantic difference found ... trace at least one relevant test ...")

## 監査判断
良い点:
1. Decision-point delta が具体で、Trigger line もあり、compare の分岐変更として実装しやすい。
2. failed-approaches の「再収束を優先する規範」の再演ではなく、むしろ再収束 shortcut への対抗策になっている。
3. Payment があるため、複雑性の純増を抑えながら compare に効く変更として成立している。

最小限の修正指示:
1. 「downstream handler/normalizer」は例外処理に限定されないよう、「later logic that absorbs the earlier divergence」などの補足を 1 句だけ添え、言語・実装様式への見かけ上の偏りを下げる。
2. EQUIV 保留条件の文末に、「or else continue searching for a concrete counterexample」を足して、LOW CONFIDENCE に逃がすだけの運用にならないようにする。
3. Payment 先の既存 checklist 文言を完全削除するのではなく、重複しない最短形で統合すること。理由は、NOT_EQUIV 側の test-tracing 義務まで弱めると逆方向の回帰が起こりうるため。

承認: YES
