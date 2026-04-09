# Iter-107 Discussion

## 総評
提案の問題意識自体は理解できる。`docs/design.md` は原論文のコアを「explicit premises, per-item code tracing, formal conclusion」という certificate 化に置いており、さらに失敗パターンとして `Incomplete reasoning chains` を明示している (`docs/design.md:3-8, 19-27`)。また現行 `SKILL.md` の compare モードにも、各テストを両変更で別々にトレースすること、差異を見つけたら relevant test を差分経路まで追うことが既に要求されている (`SKILL.md:214-220`)。したがって、「compare における推論鎖の不完全さを減らしたい」という方向性は研究コアから大きく外れていない。

ただし、今回の具体案は「call sequence を作る」という一般原則そのものよりも、「最初の分岐点を記録する」という停止条件・注目点の与え方に実効的な偏りがある。変更前との差分で見ると、EQUIVALENT 側には新しい厳格化が入る一方、NOT_EQUIVALENT 側には既存要件とかなり重複しており、対称的な文言ほどには対称に作用しない可能性が高い。結論として、着想は妥当だが、この文言のままの採用には反対。

## 1. 既存研究との整合性

### 整合する点
1. 原論文 `Agentic Code Reasoning` は semi-formal reasoning の要点を「明示的 premises」「execution path tracing」「formal conclusion」と説明しており、structured certificate が unsupported claims を防ぐとしている。提案はこの tracing を compare モードでもう一段具体化するものなので、研究コアとの方向整合性はある。
   - URL: https://arxiv.org/abs/2603.01896
   - 要点: semi-formal reasoning は execution-free なコード推論で、premises・execution path tracing・formal conclusion を強制することで patch equivalence / fault localization / code QA を改善する。

2. `docs/design.md` でも、per-item iteration が premature conclusions を防ぐ主機構であり、interprocedural tracing は advice ではなく構造として要求すべきだとしている (`docs/design.md:42-55`)。compare における trace の粒度を少し上げる発想は、この設計方針と概ね一致する。

3. VentureBeat の紹介記事も、structured certificate によって agent が function calls を step-by-step に追うことが forced され、表面的な name guessing を減らす点を強調している。
   - URL: https://venturebeat.com/orchestration/metas-new-structured-prompting-technique-makes-llms-significantly-better-at
   - 要点: semi-formal reasoning は premises・concrete execution paths・formal conclusion を埋めさせることで、表層パターンへの依存を減らし、execution-free code review の精度を上げる。

4. 再現実験ブログでも、structured certificate が「patches are equivalent か」を判断する前に per-test tracing を強制し、特に表面的には似た patch での誤判定を減らしたと報告している。
   - URL: https://muninn.austegard.com/blog/replicating-agentic-code-reasoning.html
   - 要点: 自由推論よりも、premises と per-test tracing を課した semi-formal template の方が patch verification で安定しやすい、という経験的支持。

5. より一般の root-cause analysis 文脈でも、trace-first で実際の経路を追うことが原因特定を助ける、という考え方自体は広く整合している。
   - URL: https://cloud.google.com/blog/products/devops-sre/using-cloud-trace-and-cloud-logging-for-root-cause-analysis
   - 要点: root-cause analysis では trace で実際の call / span の経路を辿り、症状から原因箇所へ絞る。

### ただし研究からは直接導けない点
原論文・設計文書が支持しているのは「execution path を構造化して追え」であって、「最初の分岐点を記録せよ」という compare 専用の stopping/anchoring rule までは直接支持していない。`docs/design.md` が localize の Phase 2 にある `Build the call sequence` を説明しているのは事実だが (`proposal.md:7-20` が指摘するとおり)、localize の call sequence は divergence の“最初の一点”への注意固定ではなく、test expectation と実装のズレを downstream まで辿るための導線である。ここは区別すべき。

## 2. Exploration Framework のカテゴリ選定
カテゴリ F の選定は、おおむね妥当。

理由:
- `Objective.md` は F を「原論文の未活用アイデア導入」、特に「他のタスクモードの手法を compare に応用」と定義している (`Objective.md:168-171`)。
- 提案はまさに localize の Phase 2 にある call sequence 構築 (`SKILL.md:242-253`) を compare checklist に移植する、という構図である (`proposal.md:19-20, 53`)。

ただし、実際の変更の効き方は F だけでなく B/E 的でもある。
- B: compare 時に「どう trace するか」を具体化する
- E: 既存 checklist 文言の精緻化

したがってカテゴリ F は不適切ではないが、「localize の未活用アイデア導入」だけで自動的に有効とは言えない。重要なのは、localize で有効だった構造を compare に移したとき、compare 固有の判定バランスを壊さないかである。

## 3. EQUIVALENT / NOT_EQUIVALENT の両判定への作用

### 提案者の主張
提案者は「分岐を記録する OR 分岐なしを確認する」の双方向要件だから対称だと述べている (`proposal.md:71-75`)。

### 実効差分の分析
しかし、`failed-approaches.md` 原則 #6 が言う通り、対称性は「変更後の文言」ではなく「変更前との差分」で見るべき (`failed-approaches.md:20`)。

変更前の compare checklist (`SKILL.md:214-220`) には、すでに以下がある。
- 各 relevant test を両変更で別々に trace する
- 変更コード内で呼ばれる各 function の定義を読む
- semantic difference を見つけたら、relevant test を differing path まで trace して impact を確認する

この前提で今回 1 行を置き換えると、実効差分は次のようになる。

1. EQUIVALENT 側への新規作用は大きい
   - 変更前: 「各テストを両方 separately trace」
   - 変更後: 「call sequence を構築し、assertion まで identical outcomes を確認」
   これは、差異が見つからないケースでより長い追跡と明示確認を要求する。

2. NOT_EQUIVALENT 側への新規作用は小さいか、ほぼ重複
   - もともと semantic difference を見つけたら relevant test を differing path まで trace する義務がある (`SKILL.md:219`)。
   - compare certificate 本体でも、NOT EQUIVALENT を主張するには counterexample と異なる test outcome が必要 (`SKILL.md:190-193, 203-210`)。
   - したがって「最初の分岐点を記録する」は、新しい検証強化というより既存要件の言い換えに近い。

3. しかも「first call where behavior diverges」は中間ノードへの注意固定を誘発しうる
   - compare で本当に必要なのは test outcome の same/different であり、最初の分岐点そのものではない (`SKILL.md:167-181, 203-210`)。
   - 提案文言は、差分を見つけた時点で「first divergence を記録する」ことを局所目標化しやすい。これは `failed-approaches.md` 原則 #17「中間ノードの局所的な分析義務化はエンドツーエンド追跡を阻害する」に近い危険がある (`failed-approaches.md:42`)。

### 片方向にしか作用しないか
厳密には「完全に片方向だけ」ではない。EQUIVALENT でも NOT_EQUIVALENT でも trace の書き方に影響は出る。

しかし、実効的には EQUIVALENT 側により強く作用する可能性が高い。理由は以下。
- EQUIVALENT では「分岐がないことを assertion まで確認」という追加負担が純増になる。
- NOT_EQUIVALENT では既に counterexample obligation があるため、first divergence 記録の増分価値が小さい。
- 変更後文言は「最初の分岐点」に注意を寄せるので、NOT_EQUIVALENT 側ではむしろ中間差異の早期発見で満足する危険もある。

したがって、「双方向なので原則 #1 に抵触しない」という提案者の自己評価には同意しない。少なくとも原則 #6 の観点では、差分は実質的に非対称。

## 4. failed-approaches.md の汎用原則との照合

### 抵触懸念がある原則
1. 原則 #6: 「対称化」は既存制約との差分で評価せよ (`failed-approaches.md:20`)
   - 本件はこれが最重要。変更後文言は対称に見えるが、変更前に既に NOT_EQ 側の trace 強化がかなり入っているため、追加差分は主に EQUIVALENT 側へ乗る。

2. 原則 #17: 中間ノードへの注意固定 (`failed-approaches.md:42`)
   - 「first call where behavior diverges」を記録目標にすると、最終観測点ではなく中間分岐へのアンカリングが起こりうる。
   - compare に必要なのは divergence の存在自体ではなく、それが test outcome を変えるかどうかである。ここを誤ると guardrail #4 の趣旨をむしろ弱めうる。

3. 原則 #20: より厳格な言い換えは実質的立証責任の引き上げとして働く (`failed-approaches.md:48`)
   - 「trace each test separately」から「call sequence を作り、assertion まで identical outcomes を確認」に変えるのは、単なる明確化よりもかなり厳格化された表現である。
   - その厳格化が、正当な EQUIVALENT 判定まで躊躇させるリスクがある。

### 抵触が比較的弱い原則
- 原則 #8 の「受動的記録フィールド追加」ではない。今回の変更は field 追加ではなく trace 行動自体の要求なので、ここは提案者の主張どおり直接の再演ではない。
- 原則 #25 の「事前検証手順の義務化」でもない。独立した pre-check は増やしていない。
- 原則 #3 の「探索量の削減」ではなく、むしろ増加方向。

### 総合判断
過去失敗の完全な再演ではないが、原則 #6 と #17 の複合にかなり近い。特に「対称っぽい文言だが実効差分は非対称」という点で、危険度は高い。

## 5. 汎化性チェック

### 形式的チェック
提案文中には、禁止対象になりうる具体的ベンチマーク固有識別子は見当たらない。
- 特定リポジトリ名: なし
- 特定テスト名 / ケース ID: なし
- 実装コード断片: なし
- 特定言語の API 名やフレームワーク名: なし

`test → f1 → f2 → …` や `method1 → method2` は一般的な擬似表現であり、`Objective.md` の R1 減点対象外に近い抽象記法と見なしてよい (`Objective.md:202-212`)。

### 暗黙のドメイン想定
ただし、提案は「call sequence が比較的素直に書ける」スタイルのコードをやや前提している。動的 dispatch、イベント駆動、設定駆動、データ依存の分岐が強いコードでは、"first call where behavior diverges" は安定な単位にならないことがある。つまり overt な overfitting ではないが、比較的 call-chain 的に記述しやすいケースを暗黙に優遇する可能性はある。

結論として、汎化性ルール違反ではないが、call-sequence bias は少しある。

## 6. 全体の推論品質への期待効果

### 改善が期待できる点
- 抽象的な「この変更は呼ばれないはず」という早期打ち切りを減らす効果は期待できる。
- compare でも interprocedural trace をより具体的に想起させるので、表層差分だけで equivalence を決める誤りの抑制には寄与しうる。
- `docs/design.md` のいう anti-skip mechanism を、compare checklist の一文として強める意図は合理的。

### 懸念点
- 現行 SKILL は既に per-test tracing と differing path tracing を要求しており、ボトルネックが本当に「call sequence の明示欠如」かは不明。
- 追加される厳格さの大半が EQUIVALENT 判定時の「分岐なし立証」へ寄るため、全体精度ではなく EQUIVALENT の recall/throughput を落とす可能性がある。
- 「first divergence」を局所目標にすると、difference を見つけた後の end-to-end 因果確認よりも、差分の発見自体が目的化しうる。

### 監査上の見立て
この変更で局所的に reasoning chain の見た目は整うかもしれないが、compare タスク全体の品質向上という意味では、利益より回帰リスクの方がやや大きい。もし call-sequence 発想を活かすなら、"first divergence" を主目標にするのではなく、既存の test-outcome 중심の compare 構造を壊さない形で、trace の具体性だけを上げる言い方の方が安全。

## 最終判断
承認: NO（理由: 研究コアとの整合性と汎用性は概ねあるが、変更前との差分で見ると実効作用が EQUIVALENT 側へ偏りやすく、`failed-approaches.md` の原則 #6「対称化は差分で評価せよ」と原則 #17「中間ノードへの注意固定」に抵触する懸念が強い。特に `first call where behavior diverges` は compare の本来の観測境界である test outcome ではなく中間分岐点へのアンカリングを生みうるため、この文言のままでは採用に反対。）
