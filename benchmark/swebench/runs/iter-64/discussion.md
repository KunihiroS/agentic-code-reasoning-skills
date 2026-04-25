# Iteration 64 — 監査ディスカッション

## 1. 既存研究との整合性

検索なし（理由: 一般原則の範囲で自己完結）。

提案は、特定の新概念や外部研究用語へ強く依拠していない。README.md / docs/design.md にある semi-formal reasoning のコア、すなわち「premise → hypothesis-driven exploration → interprocedural tracing → refutation → formal conclusion」と、patch equivalence における per-test outcome / counterexample obligation の範囲内で評価できる。

整合性としては良い。docs/design.md は per-test iteration と interprocedural tracing を anti-skip mechanism として位置づけており、今回の提案は「内部 helper の網羅」から「PASS/FAIL prediction に未接続の link」へ探索優先度を寄せるため、証拠収集を verdict に近い形へ接続する変更である。研究コアを削るものではない。

## 2. Exploration Framework のカテゴリ選定

カテゴリ B「情報の取得方法を改善する」の選定は適切。

理由:
- 結論ラベルや equivalence 定義を変えていない。
- Step 3 の NEXT ACTION RATIONALE と Compare checklist の tracing 対象を調整し、次に読む情報の優先順位を変える提案である。
- 「何を結論するか」ではなく「未完成の PASS/FAIL link を完成させるために次にどこを読むか」を変えるため、Objective.md の B「探索の優先順位付けを変える」に合う。

ただし、実装時に INFO GAIN を optional から新たな必須欄へ昇格させる意図なら、failed-approaches.md 原則 6 に近づく。proposal の主旨は Step 3 の理由づけの置換と Compare checklist の 1 行置換なので、実装では `OPTIONAL — INFO GAIN` の optional 性を維持するか、NEXT ACTION RATIONALE へ統合しすぎないことが望ましい。

## 3. EQUIVALENT / NOT_EQUIVALENT の両方向への作用

両方向に作用する見込みがある。

EQUIVALENT 側:
- Before では、内部挙動差を詳しく読んだだけで「差がある」と見なし、実際に relevant test へ到達するか未確認のまま NOT_EQUIV へ寄る可能性がある。
- After では、差分が PASS/FAIL link に接続するかを caller/test reference で確認しやすくなるため、未到達差分・吸収済み差分による偽 NOT_EQUIV を減らせる。

NOT_EQUIVALENT 側:
- Before では、内部 helper の追加精査に寄り、実際に test outcome が分岐する caller/test path の確認が遅れて、差分が outcome に出るケースを EQUIV と誤る可能性がある。
- After では、既知の side behavior を relevant test の PASS/FAIL へ接続する読みが前倒しされるため、到達する差分を prediction pair の DIFFERENT として拾いやすくなる。

片方向最適化ではない。結論条件を EQUIV または NOT_EQUIV のどちらかへ直接傾けるのではなく、両側の prediction pair を支える未完成 link を先に読む変更であるため、偽 EQUIV と偽 NOT_EQUIV の両方に対して証拠密度を上げる方向に働く。

## 4. failed-approaches.md との照合

本質的な再演ではないと判断する。

- 原則 1「再収束を比較規則として前景化しすぎない」: NO。再収束を既定化していない。caller/test link を読むことで、差分が吸収されるか、到達して結果差になるかを確認するだけである。
- 原則 2「未確定 relevance を保留側へ倒しすぎない」: NO。未検証なら保留するゲートではなく、未完成 link を次に読む探索優先度の変更である。
- 原則 3「差分の昇格条件を新ラベルや必須言い換えで強くゲート」: NO。新しい抽象ラベルを導入していない。ただし `missing PASS/FAIL link` が新分類として過度に儀式化される実装は避けるべき。
- 原則 4「証拠十分性チェックを confidence へ吸収」: NO。むしろ Step 5.5 で late repair になりがちな不足 link を Step 3 の探索へ前倒しする提案であり、confidence-only への逃げではない。
- 原則 5「最初に見えた差分から単一追跡経路を既定化」: NO。`nearest caller/test reference` という近傍優先はあるが、発火条件が「side behavior は VERIFIED だが caller/test link が missing」の場合に限られ、assertion boundary や単一経路へ固定していない。
- 原則 6「探索理由と情報利得を短く潰しすぎる」: おおむね NO。proposal は INFO GAIN を残している。ただし preview の `INFO GAIN:` が optional でなくなるなら軽微な懸念あり。必須ゲート総量不変のため、実装時は optional 性を維持するのが安全。

## 5. 汎化性チェック

汎化性違反は見当たらない。

- 具体的な数値 ID: なし。iter-64 という出力先文脈以外に、ベンチケース ID はない。
- リポジトリ名: なし。
- テスト名: なし。`test reference` / `relevant test` は一般概念。
- コード断片: ベンチ対象コードの引用はなし。proposal 内のコードブロックは SKILL.md 自身の文言引用・差分プレビューであり、Objective.md の減点対象外に該当する。
- 特定ドメイン・言語前提: なし。caller/test reference, PASS/FAIL link, interprocedural trace は Go/JS/TS/Python いずれにも一般化できる。

## 6. compare 影響の実効性チェック

0) 実行時アウトカム差
- compare 実行中、内部 helper をさらに読む代わりに nearest caller/test reference を読む場面が増える。
- ANSWER 前に A/B の PASS/FAIL prediction pair が caller/test reachability で裏付けられやすくなる。
- UNVERIFIED や低 CONFIDENCE へ late repair で逃げるより、Step 3 の追加探索で不足 link を解消する動きが増える。

1) Decision-point delta
- IF/THEN 形式で 2 行（Before/After）になっているか: YES。
- Before: IF changed-code behavior is partly VERIFIED but the caller/test link is still missing THEN continue tracing functions called in changed code because the checklist foregrounds called-function coverage.
- After: IF changed-code behavior is partly VERIFIED but the caller/test link is still missing THEN read the nearest caller/test reference next because the unresolved information is the PASS/FAIL link needed for D1.
- 条件も行動も同じ言い換えか: NO。行動が「called-function coverage 継続」から「caller/test reference 取得」へ変わっている。
- 差分プレビュー内に Trigger line の自己引用があるか: YES。`If a side's behavior is VERIFIED but its caller/test link to PASS/FAIL is still missing, read the nearest caller or test reference next before tracing more internal helpers.` が明記されている。

2) Failure-mode target
- 対象: 両方。
- 偽 NOT_EQUIV: 内部差分を test 到達性なしに outcome 差と見なす誤りを、caller/test link 確認で減らす。
- 偽 EQUIV: 内部差分を読んだが relevant test への接続確認が不足し、実は outcome が分岐するケースを見落とす誤りを減らす。

2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？
- NO。proposal は候補 2 を明示的に落としており、STRUCTURAL TRIAGE から FORMAL CONCLUSION へ進む早期 NOT_EQUIV 条件は変更対象にしていない。
- impact witness 要求の確認: 該当なし。早期結論ルールへ触れていないため、今回の承認条件にはしない。

3) Non-goal
- 早期 NOT_EQUIV の新条件を追加しない。
- assertion boundary への固定を追加しない。
- 未検証なら保留する新ゲートを追加しない。
- `For each function called in changed code` という広い coverage 要求を、`unresolved PASS/FAIL path` 上の関数へ置換することで、必須ゲート総量を増やさない。

## 7. Discriminative probe

抽象ケース: Change A/B の内部条件分岐差は VERIFIED だが、その分岐が relevant test から呼ばれるか未読。Before は呼び出し先 helper の詳細化を続け、未到達差分を NOT_EQUIV と誤るか、到達差分を EQUIV と見落としやすい。

After は次に caller/test reference を読むため、到達すれば DIFFERENT prediction pair、到達しなければ SAME prediction pair へ進める。これは新しい必須ゲートの増設ではなく、広い called-function coverage 要求を unresolved PASS/FAIL path へ置換する説明になっている。

## 8. 停滞診断

監査 rubric に刺さる説明強化へ偏り、compare の意思決定を変えていない懸念:
- 懸念は低い。proposal は「説明を丁寧にする」だけでなく、次に読む対象を internal helper から caller/test reference へ変える具体的な実行時アウトカム差を持つ。

failed-approaches 該当性:
- 探索経路の半固定: NO。`nearest caller/test reference` は条件付き優先であり、単一 assertion や単一 trace path への固定ではない。
- 必須ゲート増: NO。Payment として `For each function called in changed code` を `For each function on the unresolved PASS/FAIL path` へ置換する対応がある。ただし INFO GAIN を optional から required へ変える実装は避けること。
- 証拠種類の事前固定: NO。caller/test reference は D1 の PASS/FAIL link を完成させるための自然な探索対象で、特定言語・特定テストパターン・特定 assertion boundary への固定ではない。

支払い（必須ゲート総量不変）の確認:
- 明示あり。`add MUST("If a side's behavior is VERIFIED...")` と `demote/remove MUST("For each function called in changed code...")` の A/B 対応が proposal に書かれている。
- 実装時の注意: preview の `INFO GAIN:` は `OPTIONAL — INFO GAIN:` のまま維持するか、必須化しない形にするのが望ましい。ここを別の必須行として増やすなら、proposal の payment 範囲外になる。

## 9. 全体の推論品質向上の期待

期待できる改善は、trace の深さではなく verdict への接続性を上げる点にある。

現在の SKILL.md には、Step 4 の real-time trace と Compare checklist の called-function coverage があり、定義を読まずに名前で推測する失敗は抑えられている。一方で、広い called-function coverage は、既に十分に分かった内部挙動をさらに深掘りし、D1 の test outcome への接続を後回しにする可能性がある。

今回の変更は、interprocedural tracing を弱めずに「unresolved PASS/FAIL path 上の関数」へ絞るため、以下が期待できる。
- 読んだ挙動が actual test outcome に接続しているかを早く確認できる。
- EQUIV/NOT_EQUIV の conclusion が、内部意味差分だけでなく PASS/FAIL prediction pair により近くなる。
- late self-check で不足を見つけて保留・低 confidence に倒すより、探索中に不足 link を埋める流れになる。
- 既存の paper-derived core である per-test iteration / verified trace / counterexample obligation を維持しつつ、無差別な関数網羅の負荷を下げられる。

## 修正指示（最小限）

1. `INFO GAIN` を新たな必須欄として増やさないこと。現行の `OPTIONAL — INFO GAIN` は optional のまま維持するか、NEXT ACTION RATIONALE の文言置換だけに留める。
2. Compare checklist の置換は必ず payment として実装すること。つまり、Trigger line を追加するだけでなく、`For each function called in changed code` を `For each function on the unresolved PASS/FAIL path` へ置換し、必須ゲート総量を増やさない。
3. `nearest caller/test reference` は単一の assertion boundary 固定ではなく、side behavior / caller-test reachability / counterexample search のうち未完成の PASS/FAIL link を解くための優先読みに限定して書くこと。

## 結論

proposal は、汎化性違反や failed-approaches.md の本質的再演には当たらず、compare の実行時アウトカム差も具体的である。特に Decision-point delta と Trigger line が明示され、Payment も提示されているため、監査 PASS の下限を満たしたまま compare 改善へ結びつく見込みがある。

承認: YES
