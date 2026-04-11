# Iteration 9 — Proposal Audit Discussion

## 総評

提案は、SKILL.md の Step 5.5 に「推論チェーンの最も弱い環を特定し、その弱さが Step 6 の confidence と整合するか確認する」という 1 行を追加するもの。

監査結論を先に述べると、これは
- 研究コア（premises / hypothesis-driven exploration / interprocedural tracing / mandatory refutation）を壊さない
- failed-approaches.md の禁止方向に直接は抵触しない
- EQUIVALENT 側で出やすい「証拠はあるが weakest claim を見逃したまま過信する」失敗を抑える方向に働く
- NOT_EQUIVALENT 側でも、差分のインパクト主張が weakest link になっていないかを点検させるため、片方向専用の誘導にはなっていない

という点で、全体として妥当性は高い。

一方で、文言中の "lowest evidence density" はやや擬似定量的で、厳密な測定手続きがないため、実装時には「least-supported claim」程度の表現の方が解釈ぶれを減らせる懸念がある。とはいえ、この懸念は否決理由というより wording 改善のレベル。

## 1. 既存研究との整合性

### 参照した外部情報

1) A Chain-of-Thought Is as Strong as Its Weakest Link: A Benchmark for Verifiers of Reasoning Chains
URL: https://arxiv.org/abs/2402.00559
URL: https://aclanthology.org/2024.acl-long.254/
要点:
- reasoning chain 全体の品質は局所ステップの弱さに制約される、という発想を前提にしている。
- REVEAL は reasoning step ごとの relevance / evidence attribution / logical correctness を評価対象にしており、単に最終答えだけでなく「どのステップが弱いか」を検査する方向性を支持している。
- 論文要約では、既存の verifier は logical correctness や contradiction 検出に苦戦するとされており、結論直前に weakest link を洗い出すチェック追加はこの問題意識と整合的。

2) Large Language Models lack essential metacognition for reliable medical reasoning
URL: https://www.nature.com/articles/s41467-024-55628-6
要点:
- 高い正答率があっても、モデルの metacognitive ability は不十分で、knowledge limitation を認識できず confident に誤答する傾向があると要約されている。
- そのため、信頼できる評価フレームワークには confidence と reasoning quality の対応づけが必要だという問題意識が示されている。
- 本提案の「最も弱いクレームを特定し、その弱さが confidence level を支えられるか確認する」は、まさに confidence-calibration を軽量な self-check として導入するもので、研究的方向性と一致する。

### 既存リポジトリ内資料との整合

- README.md では、この skill の中核は「explicit premises, concrete code tracing, formal conclusion によって unsupported claims を防ぐこと」とされている。
- docs/design.md では failure pattern として "Incomplete reasoning chains" と "Subtle difference dismissal" が明示されている。
- 提案は新しい別系統の手法を足すのではなく、既に設計文書で問題視されている失敗パターンに対して Step 5.5 の self-check を 1 項目補うもの。

よって、既存研究・既存設計の両方と整合している。

## 2. Exploration Framework のカテゴリ選定は適切か

提案者はカテゴリ D「メタ認知・自己チェックを強化する」を選んでいる。これは適切。

理由:
- 変更箇所が Step 3 の探索戦略ではなく Step 5.5 の pre-conclusion self-check である。
- 何を検索するか、どのファイルから読むか、どのシグナルを優先するかを事前固定していない。
- compare / diagnose / explain / audit-improve のいずれにも横断的に効く「結論前の自己監査」の追加であり、探索手順そのものの再設計ではない。

カテゴリ C（比較の枠組み変更）ではない理由:
- compare に効く側面はあるが、文言は compare 専用ではなく reasoning chain 一般に対する点検である。

カテゴリ F（原論文の未活用アイデア導入）でも一部説明可能ではあるが、今回の主作用は論文新規要素の導入よりも metacognitive checkpoint の強化であり、D が第一分類として自然。

## 3. EQUIVALENT / NOT_EQUIVALENT の両判定への作用

### 変更前との差分

変更前 Step 5.5 は以下を確認している:
- file:line にトレースされているか
- trace table の VERIFIED / UNVERIFIED が整理されているか
- Step 5 の refutation が実際の search / inspection を伴うか
- conclusion が evidence を超えていないか

これらは「証拠の存在」「反証プロセスの実施」「主張の逸脱禁止」は見るが、推論チェーン内で相対的に最も脆い主張がどれか、という優先度付けは問わない。

提案後は、結論の weakest link を 1 つ明示させ、その弱さで HIGH / MEDIUM / LOW の confidence が正当化できるかを確認する。

つまり実効的差分は、
- binary な checklist から一段進んで
- reasoning chain 内の「最小支持点」を自己特定させる
- confidence を strongest evidence ではなく weakest justified claim に合わせて下げる圧力をかける

という点にある。

### EQUIVALENT 判定への作用

最も効くのは EQUIVALENT 側。

EQUIVALENT 誤判定は、しばしば
- 一通り追ったが pass-to-pass 影響範囲の確認が薄い
- subtle difference を見つけたが「たぶん影響なし」と処理する
- no counterexample exists の主張が weakest claim なのに HIGH confidence で締める
という形で起きる。

この提案は、その weakest claim を結論前に露出させるため、
- EQUIVALENT のままでも confidence を下げる
- あるいは counterexample search を追加させる
- 場合によっては NOT_EQUIVALENT に反転させる
可能性がある。

特に SKILL.md compare テンプレートの "NO COUNTEREXAMPLE EXISTS" 節との相性がよく、「反証不在」の根拠が薄いまま等価とする過信を抑えやすい。

### NOT_EQUIVALENT 判定への作用

NOT_EQUIVALENT 側にも作用する。

よくある誤りは、差分を見つけた時点で
- その差分が relevant tests に実際に波及するか
- diverging assertion まで到達するか
- structural gap があるとしても test outcome difference が確実か
の詰めが甘いまま NOT_EQUIVALENT とするケース。

提案された weakest-link チェックにより、NOT_EQUIVALENT の場合も
- 「この差異は test outcome を変える」が weakest claim ならそこを再点検する
- 具体的に divergence claim の証拠密度が confidence と見合うか確認する
必要が出る。

したがって、この変更は EQUIVALENT 側だけに働くものではない。主作用は EQUIVALENT の過信抑制に寄るが、NOT_EQUIVALENT に対しても「差分発見 = 判定確定」という短絡を抑える。

### 片方向バイアスの有無

片方向専用の誘導には見えない。

ただし、実務上は EQUIVALENT の HIGH confidence を削る方向により強く働くはず。理由は、NOT_EQUIVALENT は元々 counterexample / diverging assertion によって比較的局所的な証拠が立ちやすい一方、EQUIVALENT は「差が効かない」ことの立証負荷が高く、weakest link が出やすいから。

この非対称性はあるが、それは判定バイアスというより、両ラベルの立証難易度の差に対応した自然な作用。

## 4. failed-approaches.md の汎用原則との照合

failed-approaches.md の原則は大きく 2 つ:
1. 探索で探すべき証拠の種類をテンプレートで事前固定しすぎない
2. ドリフト抑制で探索の自由度を削りすぎない

本提案は原則 1 と本質的に異なる。
- 追加されるのは探索前テンプレートではなく、結論直前の self-check。
- 「何を探せ」と事前指定していない。
- 特定シグナルの探索を強制せず、既に構築した reasoning chain を再評価させるだけ。

本提案は原則 2 にも直接は抵触しない。
- 探索の入り口・経路・優先順位を狭めない。
- 再探索を必須化しているわけでもない。
- ただし、弱い環を見つけたときに追加探索へ向かう可能性はあるが、それは結論の適正化であり、探索の自由度を先に狭めるものではない。

よって、表現を変えただけの過去失敗の再演とは評価しない。

## 5. 汎化性チェック

### 明示的なルール違反の有無

proposal.md を確認した限り、以下の禁止寄り要素は含まれていない。
- ベンチマークケース ID: なし
- 特定リポジトリ名: なし
- 特定テスト名: なし
- ベンチマーク対象コード断片の引用: なし

含まれている具体語は、SKILL.md 自身の構造参照（Step 5.5, Step 6, HIGH/MEDIUM/LOW, compare モード等）と docs/design.md 上の一般的失敗パターン名であり、Objective.md の R1 減点対象外に概ね当たる。

### 暗黙のドメイン依存性

強いドメイン依存は見えない。
- weakest link の発想は任意の言語・フレームワーク・タスクモードに適用可能。
- compare だけでなく explain / diagnose / audit-improve にも通る。
- テスト駆動の差分判定で特に有効だが、それは SKILL 全体の主要ユースケースと整合している。

### 軽微な懸念

"claim with the lowest evidence density" という表現は、汎用ではあるが定義が少し曖昧。
- density をどう数えるのか不明
- file:line 数なのか、独立根拠の数なのか、反証済み度合いなのかが未定義

このため、モデルによっては表面的に「一番弱そうな文」を選ぶだけで終わる可能性がある。ここは
- "least-supported claim"
- "the claim whose failure would most weaken the conclusion"
のような表現の方が、言語・タスク横断で安定する可能性がある。

ただし、これは汎化性違反ではなく、語の精度の問題。

## 6. 全体の推論品質への期待効果

期待できる改善は 3 つある。

1. 過信の抑制
- strongest evidence に引っ張られて結論を出すのではなく、chain 全体のボトルネックに attention を戻す。
- とくに HIGH confidence の濫用を減らしやすい。

2. 反証プロセスの実効性向上
- Step 5 自体は既に mandatory だが、Step 5.5 で weakest link を再点検させることで、refutation が形式的に終わるのを防ぎやすい。
- 「一応 search した」だけで終わるのではなく、どの claim の裏付けが最も薄いかを意識させる。

3. incomplete reasoning chains の捕捉率向上
- docs/design.md で言う downstream handling の見落としや subtle difference dismissal は、しばしば chain の一箇所だけ支持が薄いまま残る形で起きる。
- その局所点検を最後に追加するのは、低コストで全体品質を上げる筋の良い変更。

加えて、変更規模が 1 行で非常に小さいため、複雑性増加やテンプレート肥大の副作用は限定的。

## 留保・改善提案

承認寄りだが、実装文言には次の改善余地がある。

現行提案文:
- Identified the weakest link in the reasoning chain (the claim with the lowest evidence density) and verified it is sufficient to support the confidence level I will assign in Step 6.

懸念:
- "lowest evidence density" がやや曖昧で、擬似定量化された印象を与える。

より安定しそうな代替案:
- Identified the weakest link in the reasoning chain (the least-supported claim) and verified it is sufficient to support the confidence level I will assign in Step 6.

または
- Identified the claim whose failure would most weaken the conclusion, and verified the available evidence is sufficient for the confidence level I will assign in Step 6.

ただし、監査対象は提案の方向性そのものなので、この wording 懸念だけで否決する必要はない。

## 最終判定

承認: YES

理由:
- 研究・設計文書と整合する
- failed-approaches.md の禁止方向を再演していない
- EQUIVALENT / NOT_EQUIVALENT の両方に作用し、片方向専用の誘導ではない
- 汎化性違反となる具体的 ID / repo 名 / test 名 / 実コード断片を含まない
- 1 行追加という小変更で、過信抑制と weakest-claim の自己監査を導入できるため、費用対効果が高い
