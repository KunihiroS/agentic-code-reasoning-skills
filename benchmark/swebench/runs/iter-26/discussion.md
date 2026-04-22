監査結果

1. 既存研究との整合性
- 検索なし（理由: 一般原則の範囲で自己完結）。
- 提案は特定の外部研究の新規事実や経験則に依存せず、SKILL.md 内の compare 分岐の再設計として十分に監査可能。

2. 総評
- 提案の中核は、"semantic difference を見つけた後に SAME へ進める条件" を変える点にある。これは説明の装飾ではなく、compare 実行時の分岐条件そのものを変える提案になっている。
- 特に proposal の Before/After は、変更前が「差分を見つけても one-path trace + no-counterexample search で SAME へ進みやすい」、変更後が「first divergence と downstream absorber の両方を示せるまで SAME に進めない」という条件差になっており、実効差分はある。
- 一方で、failed-approaches.md 原則 1 が警戒している「再収束を既定規範にしすぎる」方向と近接しているため、適用範囲の限定を SKILL.md 上で明確に書かないと再演化するリスクは残る。

3. Exploration Framework のカテゴリ選定
- 適切性: おおむね適切。
- 理由: この提案は探索順序の固定化ではなく、"差分を既に観測した後の compare 判定分岐" を変更するもの。したがって exploration の入口や file reading order を縛る提案ではなく、比較時の evidence interpretation / decision policy に属する。
- 汎用原則としても、"途中差分があるのに SAME と言うなら、その差分がどこで発生し、どこで吸収されるかを示せ" は、特定言語や特定テスト様式に依存しない。

4. 変更前後の実効差分
- 現行 SKILL.md には compare checklist の
  - "When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact"（SKILL.md:233）
  - EQUIVALENT 時の "NO COUNTEREXAMPLE EXISTS ... I searched for exactly that pattern"（SKILL.md:207-213）
  がある。
- proposal はこの組合せを、"差分ありだが outcome 同じ" という場面専用の必須分岐に置換しようとしている。
- そのため、変わるのは説明の厚みではなく、SAME を出力できる条件である。compare のランタイム上は、SAME / 追加探索 / UNVERIFIED / CONFIDENCE 低下の分布が変わるはずで、観測可能な差がある。

5. EQUIVALENT / NOT_EQUIVALENT の両方向への作用
- EQUIVALENT 側への作用:
  - 未説明の中間差分を、"最終 assertion が同じらしい" だけで EQUIV に流しにくくなる。
  - その結果、偽 EQUIVALENT を減らす方向に効く。
- NOT_EQUIVALENT 側への作用:
  - 途中差分が見えた時に、その差分が downstream で吸収されるケースを説明付きで EQUIV に戻せるため、偽 NOT_EQUIVALENT も減らしうる。
  - つまり片方向最適化ではなく、差分を見つけた後の過早な両極化を抑える提案になっている。
- 確認結果:
  - 片方向にしか作用しない提案ではない。
  - ただし、文言次第では EQUIV 側だけを重くし、NOT_EQUIV 側では単に説明負担を増やすだけになるおそれがある。よって "この条件は SAME を書く前にだけ要求され、DIFFERENT の根拠要件を増やすものではない" を明示した方が安全。

6. failed-approaches.md との照合
- 原則 1（探索経路の半固定 / 再収束前景化）: 境界上。
  - failed-approaches.md は、"最初の差分" と "それを吸収する後段処理" の対提示を既定化すると、吸収の説明を先に組み立てる読み方を誘発しうると警告している（failed-approaches.md:10-15）。
  - proposal も first divergence + absorber を中核に置いているため、無条件の一般規範として入れると本質的再演になりうる。
  - ただし今回の提案は、"差分を既に観測し、しかも SAME を主張する時だけ" という限定を置いており、そこは本質的な違い。
- 原則 2（必須ゲート増 / 保留側への既定化）: 直接の再演ではない。
  - proposal は UNVERIFIED や保留を一般化しておらず、特定場面で SAME 要件を厳格化するもの。
- 原則 3（証拠種類の事前固定 / 抽象ラベル化）: 一部注意。
  - "explained reconciliation is the evidence type" という書き方は、証拠型を先に固定しすぎると危うい。
  - ただし実体は新ラベル導入より、既存 MUST の置換に近い。
- 総合判断:
  - 本質的な再演ではないが、原則 1 にかなり近い。適用条件の限定が実装上の生命線。

7. 汎化性チェック
- 具体的な数値 ID, リポジトリ名, テスト名, コード断片:
  - 見当たらない。違反なし。
- 暗黙の特定ドメイン前提:
  - 比較的少ない。"normalization/exception path" という例示はあるが、説明用の抽象ケースの範囲であり、特定言語・特定フレームワーク依存ではない。
- 改善余地:
  - "absorber" は内部用語としては通るが、実装文言としてはやや概念先行。"downstream logic that eliminates the observed outcome difference" のように、観測差と結びつけた平明な語にした方がドメイン非依存性が高い。

8. 推論品質の向上見込み
- 期待できる改善:
  - 差分発見後の早すぎる SAME を抑え、EQUIV の根拠をより因果的にできる。
  - 一方で、途中差分があっても test outcome 同値なら、どこで差が消えるかを示して偽 NOT_EQUIV を防げる。
  - 結果として、"diff を見た瞬間に DIFFERENT 側へ寄る" 失敗と、"最後が同じっぽいので SAME 側へ流す" 失敗の両方に効く。
- 特に compare においては、"差分が見えた後の扱い" は誤判定の密度が高い意思決定点なので、そこを直接変える案として効果は見込める。

9. 停滞診断（必須）
- 監査 rubric に刺さる説明強化へ偏り、compare の意思決定を変えていない懸念:
  - 懸念は小さい。proposal は explanation の追加ではなく、"SAME を書ける条件" を変えるので、比較実行時アウトカム差がある。
- 「探索経路の半固定」: NO
- 「必須ゲート増」: NO（Payment で既存 MUST の demote/remove を対にしており、総量純増を避ける設計）
- 「証拠種類の事前固定」: やや YES 寄り
  - 原因文言: "explained reconciliation is the evidence type"。
  - ここは evidence type の固定化に読めるので、"SAME 主張時の必要説明" 程度に弱めた方がよい。

10. compare 影響の実効性チェック（必須）
- 0) 実行時アウトカム差:
  - 観測可能に変わる点は、途中差分が見つかった案件での Comparison: SAME の出し方。変更後は、first divergence と downstream absorber を示せなければ SAME ではなく、追加探索・UNVERIFIED・CONFIDENCE 低下へ分岐しうる。
- 1) Decision-point delta:
  - Before/After が IF/THEN 形式で 2 行あるか: YES
  - これは理由の言い換えだけか: NO
  - 実際に変わる分岐:
    - Before: IF 中間 semantic difference があっても最終 assertion が同じに見える THEN one-path trace と no-counterexample search で SAME に進みうる。
    - After: IF 中間 semantic difference があり SAME を主張したい THEN first divergence と absorber の両提示ができるまで SAME に進まない。
  - Trigger line（発火する文言の自己引用）が差分プレビューにあるか: YES
- 2) Failure-mode target:
  - 対象は両方。
  - 偽 EQUIV: 未説明差分を outcome sameness だけで飲み込む誤りを減らす。
  - 偽 NOT_EQUIV: 観測された中間差分を、その後段で吸収される可能性を見ずに差分昇格する誤りを減らす。
- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か:
  - NO
  - よって impact witness 必須チェックはこの提案の主論点ではない。
- 3) Non-goal:
  - structural triage の早期 NOT_EQUIV 条件は変えない。
  - NOT_EQUIV の根拠を特定観測境界へ固定しない。
  - 新しい抽象ラベルや前処理ゲートを compare 全体へ増設しない。

11. Discriminative probe（必須）
- 抽象ケース:
  - 2 変更が途中で別の分岐を通るが、片方は例外を握りつぶし、もう片方は sentinel 値を返し、その後の共通 guard で同じ assertion outcome になる。
  - 変更前は、途中差分を見て NOT_EQUIV に寄るか、逆に最終 outcome だけ見て EQUIV に寄るかがぶれやすい。
  - 変更後は、"最初にどこで分岐し、どの後段ロジックが outcome 差を消したか" を示せた場合のみ SAME に進むため、追加の必須ゲート増設なしに誤判定を減らせる。

12. 支払い（必須ゲート総量不変）の確認
- A/B 対応付けは proposal 内で明示されている: YES
- 内容:
  - add MUST("If an intermediate step differs ... localize ... explain ... before writing Comparison: SAME")
  - ↔ demote/remove MUST("No test exercises this difference ... searched for exactly that pattern")
- したがって、支払い不在を理由に差し戻す必要はない。

13. 最小修正指示
- 1) 適用条件をさらに限定すること。
  - "only after an observed intermediate semantic difference in a traced relevant test, and only when proposing Comparison: SAME" を明示し、吸収説明を compare 全体の既定規範にしない。
- 2) "absorber" を観測差に結びつく平明語へ置換すること。
  - 例: "the downstream logic that removes the outcome difference"。抽象ラベル先行を弱める。
- 3) DIFFERENT 側の要件は増やさないことを 1 行で明示すること。
  - これで両方向改善の意図が SKILL.md 上でもズレにくくなる。

14. 最終判断
- 承認: YES
- 理由: compare の実行時分岐を具体に変えており、EQUIVALENT / NOT_EQUIVALENT の両方向に効く。failed-approaches.md 原則 1 に近接はするが、"観測済み差分があり、かつ SAME を主張する時だけ" という限定を実装で明示すれば、本質的再演は回避可能。現状でも PASS 下限は満たしている。