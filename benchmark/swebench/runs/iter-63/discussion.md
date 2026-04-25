# Iteration 63 — Proposal Discussion

## 1. 既存研究との整合性

検索なし（理由: 提案は特定の新概念・固有研究主張へ依拠しておらず、SKILL.md / README.md / docs/design.md に既にある semi-formal reasoning、per-test iteration、certificate template、test outcome equivalence の一般原則の範囲で自己完結している）。

提案は、patch equivalence を「各 relevant test の A/B outcome ペアで比較する」という既存 Compare template の中心構造を、より実行順序として明示するもの。docs/design.md の「per-item iteration as the anti-skip mechanism」および「structured template as certificate」と整合する。

## 2. Exploration Framework のカテゴリ選定

カテゴリ A「推論の順序・構造を変える」の選定は適切。

理由:
- 変更の本体は、新しい証拠種類・新しいラベル・新しい探索対象の追加ではなく、既存の per-test 欄を「A の PASS/FAIL 予測 → B の PASS/FAIL 予測 → SAME/DIFFERENT」の順に直列化すること。
- カテゴリ C のように比較単位を変えるわけではなく、カテゴリ D のように新しい self-check を増やすわけでもない。
- カテゴリ E 的な表現改善も含むが、実効差はフォーマット表現より「Comparison を書く前の入力を揃える」という順序制御にあるため、主分類は A でよい。

## 3. EQUIVALENT / NOT_EQUIVALENT 双方への作用

EQUIVALENT への作用:
- 片側 trace の説明がもっともらしく、もう片側の結果予測が曖昧なまま SAME に進む偽 EQUIV を抑える。
- A/B の PASS/FAIL ペアが同じであることを Comparison の入力にするため、「説明が似ている」ではなく「テスト outcome が同じ」で EQUIVALENT を支える方向になる。

NOT_EQUIVALENT への作用:
- 局所的な意味差・内部値差を見つけた時点で DIFFERENT と書く偽 NOT_EQUIV を抑える。
- 差分があっても A/B の PASS/FAIL 予測ペアが同じなら SAME に戻れるため、内部差と outcome 差を分離できる。

変更前との実効的差分:
- 変更前も C[N].1 / C[N].2 は存在するが、Comparison 行が同じブロックにあり、片側説明の勢いで SAME/DIFFERENT を先取りしやすい。
- 変更後は Trigger line により、「両側予測が存在しない状態では Comparison に進まない」という分岐が明示される。
- これは EQUIV 側だけ、または NOT_EQUIV 側だけへの片方向最適化ではなく、premature comparison 自体を減らすため両方向に効く。

## 4. failed-approaches.md との照合

本質的な再演ではないと判断する。

- 原則 1（再収束の前景化）: NO。下流の共有観測点で再収束するかを既定化していない。比較対象は既存 D1 の test pass/fail outcome であり、差分吸収の説明を優先させるものではない。
- 原則 2（未確定 relevance / UNVERIFIED を保留側へ倒す）: NO。UNVERIFIED や relevance 未確定時の fallback を増やしていない。
- 原則 3（差分昇格を新ラベル・固定観測境界・単一 assertion/check 起点へ強くゲート）: おおむね NO。PASS/FAIL prediction pair は既存テンプレートの C[N].1/C[N].2 を再配置するだけで、新しい抽象ラベルではない。assertion boundary を新しい昇格条件にしないと明記している点もよい。ただし「Do not write SAME/DIFFERENT until both A and B predictions...」は必須ゲートに見えるため、既存 checklist の assertion-facing value 要求を demote/remove する payment を実装時に必ず守る必要がある。
- 原則 4（証拠十分性を confidence 調整へ吸収）: NO。Comparison の入力を明示する変更であり、終盤チェックの弱体化ではない。
- 原則 5（探索経路の半固定）: NO。最初に見えた差分から単一追跡経路を固定しない。各 relevant test の既存ループ内で比較順序を整えるだけ。
- 原則 6（探索理由と情報利得の圧縮）: NO。探索理由欄や optional info gain を潰していない。

## 5. 汎化性チェック

固有識別子チェック:
- 具体的な数値 ID: なし。iter-63 などの運用上の回番号以外に、ベンチケース ID はない。
- リポジトリ名: なし。
- テスト名: なし。`Test [name]` は SKILL.md テンプレートの自己引用・疑似スロットであり問題ない。
- コード断片: なし。引用されているのは SKILL.md のテンプレート文言で、実コードではない。
- ファイルパス・関数名・クラス名などのベンチ固有情報: なし。

暗黙のドメイン前提:
- PASS/FAIL outcome を持つ test-based compare への前提は SKILL.md の compare mode 自体の定義と一致する。
- 特定言語、特定フレームワーク、特定 assertion 形式には依存していない。
- 「test outcome」を軸にするため、テスト仕様がないタスクでは既存 D1 と同様に scope を制限する必要があるが、これは新たな汎化性違反ではない。

## 6. 推論品質への期待効果

期待される改善は、説明の類似性・局所差分・片側 trace へのアンカリングを、test outcome ペアの明示比較へ戻すこと。

特に有益な点:
- SAME/DIFFERENT の根拠が「A と B の個別説明」から「A/B PASS/FAIL prediction pair」に近づく。
- Comparison 行の前に最低限の比較入力が見えるため、形式的には書いたが片側の outcome が実質未確定、という証明書の穴が見えやすくなる。
- 既存の checklist から assertion-facing value 要求を外す/弱める payment があるため、failed-approaches.md 原則 3 の「観測点合わせの目的化」をむしろ軽減する可能性がある。

## 停滞診断（必須）

監査 rubric に刺さる説明強化へ偏り、compare の意思決定を変えていない懸念:
- 懸念は小さい。proposal は Decision-point delta と Trigger line を持ち、Comparison を書く前に不足側 prediction を埋めるという実行時分岐を変えている。ただし実装で Trigger line が単なる説明コメント扱いになり、テンプレート順序が変わらない場合は、監査向け説明だけで停滞するリスクが残る。

failed-approaches.md 該当性:
- 探索経路の半固定: NO。各 test 内の比較順序を整えるだけで、次に読むファイル・差分経路を単一固定していない。
- 必須ゲート増: NO（条件付き）。proposal の payment 通り、既存 checklist の「assertion-facing value/API contract」必須行を demote/remove するなら総量不変。payment を実装しない場合は YES になりうる。
- 証拠種類の事前固定: NO。PASS/FAIL は既存 D1 の outcome 定義そのものであり、新しい証拠種類ではない。

## compare 影響の実効性チェック（必須）

0) 実行時アウトカム差:
- SAME/DIFFERENT を書く前に、A/B 双方の PASS/FAIL prediction が明示される。
- 片側 prediction が欠ける場合、Comparison へ進まず不足側の prediction を先に埋める。
- 結果として ANSWER の根拠が説明類似/内部差ではなく outcome pair に寄る。

1) Decision-point delta:
- IF/THEN 形式で 2 行（Before/After）になっているか？ YES。
- Before: IF one side's trace looks semantically similar/different enough THEN write `Comparison: SAME / DIFFERENT outcome` because the per-side explanations appear to support it.
- After: IF both side-specific PASS/FAIL predictions for the same test are recorded THEN write `Comparison: SAME / DIFFERENT outcome`; otherwise fill the missing side prediction first because comparison operates on an outcome pair.
- 条件も行動も変わっている。Before は片側 trace の印象から Comparison、After は両側 prediction の有無で Comparison / 不足側補完を分岐するため、単なる理由の言い換えではない。
- 差分プレビュー内に Trigger line が含まれているか？ YES。`Do not write SAME/DIFFERENT until both A and B predictions for this test are present.` が自己引用されている。

2) Failure-mode target:
- 対象: 両方（偽 EQUIV / 偽 NOT_EQUIV）。
- 偽 EQUIV 低減メカニズム: 片側のもっともらしい trace や説明類似で SAME に進む前に、反対側の PASS/FAIL を独立に書かせる。
- 偽 NOT_EQUIV 低減メカニズム: 内部差を見つけても、A/B の test outcome pair が DIFFERENT になるまで NOT_EQUIV へ進みにくくする。

2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？
- NO。proposal は STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を強めたり弱めたりしないと明記しており、通常の per-test compare 順序だけを対象にしている。
- impact witness 要求の有無は、この提案の主対象ではない。早期結論を変更しないため、ここを承認条件にはしない。

3) Non-goal:
- 探索経路の半固定はしない。次に読むファイルや差分経路を単一の assertion/check へ固定しない。
- 必須ゲート総量は増やさない。新しい Trigger line / prediction-pair 化の代わりに、既存 checklist の assertion-facing value/API contract 要求を demote/remove する。
- 証拠種類は事前固定しない。既存の file:line trace と test PASS/FAIL outcome の範囲で比較順序だけを変更する。

## Discriminative probe（必須）

抽象ケース:
- Change A は内部表現を変えるが最終 test は PASS、Change B は内部表現を変えず別経路で同じ test を PASS させる。変更前は内部差を見て偽 NOT_EQUIV、または説明類似を見て逆に偽 EQUIV が起きやすい。
- 変更後は SAME/DIFFERENT の前に A: PASS / B: PASS または A: PASS / B: FAIL のペアを埋めるため、内部差・説明類似ではなく outcome pair で分岐できる。
- これは既存 C[N].1/C[N].2 と checklist 行の置換・再配置であり、必須ゲートの純増ではない。

## 停滞対策の検証（必須）

支払い（必須ゲート総量不変）:
- proposal 内で A/B の対応付けは明示されている。追加する MUST は `For each test, record the Change A and Change B PASS/FAIL predictions as a pair before writing SAME/DIFFERENT.`、支払いは既存 checklist の `Trace each test through both changes separately; before comparing, name the assertion-facing value/API contract and each side's value at that point.` の demote/remove。
- 実装時はこの payment を必ず反映すること。両方を required として残すと、failed-approaches.md 原則 3 の「比較直前に assertion-facing value を必ず名指しさせる」再演に近づく。

## 修正指示（最小限）

1. 実装時に payment を明確に反映すること。
   - 追加 Trigger line / prediction pair を入れるなら、既存 checklist の assertion-facing value/API contract 必須行は削除または optional 化する。
   - 両方を required のまま併存させない。

2. Trigger line は差分プレビュー通り template 本体に置くこと。
   - rationale だけに書かず、compare 実行中にモデルが見る per-test template 内へ入れる。

3. `Prediction pair for Test [name]` は test outcome の pair であることを保ち、assertion boundary や単一観測点の名指しを新たな必須条件に戻さないこと。

## 総合判定

提案は汎用的で、既存研究の certificate / per-test outcome 比較と整合し、failed-approaches.md の本質的再演にもなっていない。Decision-point delta、Trigger line、Discriminative probe、payment が揃っており、compare の実行時アウトカム差も観測可能である。

承認: YES
