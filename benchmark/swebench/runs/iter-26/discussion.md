# Iteration 26 — 監査ディスカッション

## 総評

提案の狙い自体は理解できる。現行の compare モードが STRUCTURAL TRIAGE を通じて NOT EQUIVALENT の早期検出に寄りやすく、EQUIVALENT 側の「同じ目的を別実装で達成している」ケースに弱い、という問題設定は README.md の評価傾向とも整合する。

ただし、今回の文言追加は「変更カテゴリが同じ」「同じ defect / abstraction boundary を対象にしている」という粗いメタ情報を、詳細トレース前に EQUIVALENT の prior evidence として扱う点が問題である。これは比較の補助情報というより、結論方向に傾く事前バイアスを新たに入れる変更であり、EQUIVALENT の取りこぼしを減らす代わりに NOT_EQUIVALENT を誤って寄せる回帰リスクがある。

結論として、研究的整合性は「部分的にはある」が、提案文のままでは片方向バイアスが強く、failed-approaches.md の原則にも一部抵触する懸念があるため、現状では承認しない。

---

## 1. 既存研究との整合性

### 1-1. Semi-formal reasoning / structured reasoning との整合

1) Agentic Code Reasoning
- URL: https://arxiv.org/abs/2603.01896
- 要点: 明示的な premises、execution path tracing、formal conclusion を要求する semi-formal reasoning は、patch equivalence verification を含む複数タスクで精度改善を示す。
- 監査コメント: これは「詳細トレース前に、比較のための枠組みを少し整える」こと自体には整合的。ただし論文の中心は coarse category による prior ではなく、具体的証拠の積み上げである。したがって「カテゴリ一致を EQUIVALENT の強い事前証拠にする」点は、論文の中核メカニズムからは一段離れている。

2) VentureBeat summary of the paper
- URL: https://venturebeat.com/orchestration/metas-new-structured-prompting-technique-makes-llms-significantly-better-at
- 要点: structured certificate によって unsupported guesses を減らし、function calls と data flows を系統的に追わせることが有効だと説明している。
- 監査コメント: ここでも有効性の源泉は「証拠追跡の強制」であり、「高レベルカテゴリの一致を prior にすること」ではない。したがって今回提案は、structured reasoning の精神には反しないが、効果の根拠は直接には支持されていない。

3) InfoWorld summary of the paper
- URL: https://www.infoworld.com/article/4153054/meta-shows-structured-prompts-can-make-llms-more-reliable-for-code-review.html
- 要点: 事前に assumptions を明示し、関連 code paths を trace してから conclusion を出すことで reliability が上がる。
- 監査コメント: これも同様に、改善の中核は trace-first である。カテゴリ分類は補助的ならまだしも、判定 prior として強く使うのは研究的には飛躍がある。

### 1-2. Change intent / refactoring classification との整合

4) Large-scale intent analysis for identifying large-review-effort code changes
- URL: https://www.sciencedirect.com/science/article/pii/S0950584920300033
- 要点: software changes には bug fix / feature addition / refactoring といった change intents があり、それを使うと review-effort prediction のような context-aware analysis が改善しうる。
- 監査コメント: 「change intent が分析に有益な補助情報になりうる」ことは支持される。したがって、比較の文脈で変更カテゴリを見る発想そのものは不自然ではない。

5) Microsoft Research page for the same study
- URL: https://www.microsoft.com/en-us/research/publication/large-scale-intent-analysis-for-identifying-large-review-effort-code-changes/
- 要点: Feature / Refactor などの intent を考慮すると、文脈依存の分析性能が上がる場合がある。
- 監査コメント: ただしこの研究は review effort 予測の文脈であり、patch equivalence の semantic judgment を直接扱っていない。よって「intent を使うこと一般」は支持できても、「intent 一致が EQUIVALENT の強い prior」という飛躍までは支えない。

6) Detecting refactoring type of software commit messages based on ensemble machine learning algorithms
- URL: https://www.nature.com/articles/s41598-024-72307-0
- 要点: refactoring は internal structure を改善し external behavior を変えないという定義を再確認しつつ、実際の refactoring 検出は難しく、しかも refactoring は他の変更と混在しやすいと述べている。
- 監査コメント: この点は今回提案への重要な留保である。つまり「refactoring / bug-fix / feature-addition」の 3 分類は概念としては自然でも、実際のパッチは mixed-intent であることが多い。したがって triage 段階で単純分類を強く使うと、曖昧なケースで誤誘導を起こしやすい。

### 1-3. 研究整合性の総合判断

- 整合する点:
  - 変更の意図や change intent を補助情報として見る発想自体は一般研究と矛盾しない。
  - compare の前段で高レベルな framing を与えること自体は semi-formal reasoning と整合しうる。
- 整合しない/弱い点:
  - 既存研究が直接支持しているのは「intent は補助情報になりうる」までであり、「intent 一致 + 同一 defect/boundary → EQUIVALENT の stronger prior evidence」という強い使い方までは支持していない。
  - refactoring/bug-fix/feature-addition の分類は現実には混在しやすく、ノイズが大きい。

要するに、研究整合性は「部分的にあり、ただし提案の効かせ方が強すぎる」。

---

## 2. Exploration Framework のカテゴリ選定は適切か

### 判定
カテゴリ C「比較の枠組みを変える」を選んだこと自体は妥当。

### 理由
この提案は、テスト単位の追跡そのものを削るのではなく、比較の出発点に置く観点を追加しているため、A/B/E というより C に最も近い。

ただし、カテゴリ選定が妥当であることと、メカニズムが汎用原則として良いことは別問題である。

### 汎用原則としての評価
良い点:
- 「同じ目的を別実装で達成している可能性」を早めに意識させる、という発想は EQUIVALENT の見逃し対策として理解できる。
- 追加が S3 の精緻化に留まっており、テンプレート全体を大改造しない点は複雑性の面で良い。

悪い点:
- 3分類が粗すぎる。現実の change は bug-fix を伴う refactoring、feature-addition を伴う bug-fix など混合しやすい。
- 「target the same defect or abstraction boundary」を triage 段階で判定させるのは、実質的に先に境界を固定することに近い。これは探索を導くというより、探索を狭める危険がある。
- しかも文言が「stronger prior evidence for EQUIVALENT before detailed tracing begins」と明言しており、比較の枠組み変更というより、EQUIVALENT 側への方向づけになっている。

総じて、カテゴリ選定は適切だが、カテゴリ C の中でも今回の具体メカニズムは coarse で、強く効かせすぎている。

---

## 3. EQUIVALENT 判定 / NOT_EQUIVALENT 判定の両方への作用

### 変更前の実効
変更前の S3 は、あくまで large patch で line-by-line tracing を避けるためのスケール指針であり、結論方向への prior は入れていない。

### 変更後の実効差分
変更後は S3 が次の役割を持つことになる。
- patch の大きさを見る
- patch の change category を分類する
- 同じ category かつ同じ defect / abstraction boundary を対象にしているなら、EQUIVALENT の prior evidence を強める

つまり、実効的には「スケール判断」から「スケール判断 + 粗い意味論的ラベリング + EQUIVALENT 方向の先行バイアス」へ変わる。

### EQUIVALENT 側への作用
期待される正の作用:
- 別実装の refactoring 的変更や、同じ不具合を異なる局所手段で直している変更について、早い段階で『同じ目的かもしれない』と見やすくなる。
- その結果、構造差分だけで早々に NOT EQUIVALENT へ倒れる誤りは減る可能性がある。

懸念:
- coarse category の一致は非常にありふれており、同じ bug-fix 同士でも test outcomes は容易に異なりうる。
- したがって、EQUIVALENT の recall は上がっても precision を落とす危険がある。

### NOT_EQUIVALENT 側への作用
期待される正の作用:
- 限定的。もしカテゴリが明確に異なれば「同じ性質の変更ではない」と気づく助けにはなるが、提案文はそこを強く書いていない。

主な懸念:
- 提案文は「same category and same target provide stronger prior evidence for EQUIVALENT」としか書いておらず、NOT_EQUIVALENT 側の対称的な使い方が定義されていない。
- そのため、同じカテゴリの非等価パッチに対して false EQUIVALENT を増やす危険がある。
- 特に compare モードは最終的に test outcomes の一致/不一致で判定すべきであり、カテゴリ一致は semantic equivalence の弱い proxy にすぎない。

### 片方向性の判定
この変更は実質的に片方向である。

理由:
- 文言上、EQUIVALENT 側の prior 強化だけが明示されている。
- NOT_EQUIVALENT 側の検出力を同程度に高める対称な規則がない。
- したがって「両方向の比較品質改善」ではなく、「EQUIVALENT の見逃し補正」という片肺運用に近い。

監査上、これは重要な減点点である。

---

## 4. failed-approaches.md の汎用原則との照合

提案文は「全原則に抵触しない」としているが、その自己評価には同意しない。

### 原則1: 探索で探すべき証拠の種類をテンプレートで事前固定しすぎない
抵触懸念あり。

今回の変更は、詳細トレース前に「まず category を見よ」「same defect / abstraction boundary かを見よ」という新しい上位シグナルを導入している。これは証拠の種類を完全固定するほどではないが、比較の出発点として特定シグナルを優先させる変更である。

特に「abstraction boundary」を先に見ることは、構造境界に合う証拠を先に探させるバイアスを生みやすい。

### 原則2: 探索の自由度を削りすぎない / 読解順序の半固定を避ける
部分的に抵触。

failed-approaches.md には「どこから読み始めるか」「どの境界を先に確定するか」の半固定を避けるべきとある。今回の提案はまさに triage 段階で「同じ defect / abstraction boundary か」を見よとしており、境界の先行確定を促している。

これはファイル順の固定ではないが、探索の framing を早い段階で細らせる危険がある。

### 原則3: 局所的な仮説更新を前提修正義務に直結させすぎない
ここは大きな抵触ではない。

提案は探索中の更新義務を増やしてはいないため、この点の懸念は比較的小さい。

### 原則4: 結論直前の自己監査に新しい必須のメタ判断を増やしすぎない
ここも直接抵触ではない。

追加位置が Step 5.5 ではなく S3 なので、この原則への直接抵触は弱い。

### failed-approaches 照合の総合判断
- 完全抵触ではない
- しかし「探索の自由度を削りすぎない」「境界を先に確定しすぎない」という原則には、実質的な再演リスクがある

よって「全原則に抵触しない」という提案側の主張は強すぎる。

---

## 5. 汎化性チェック

### 5-1. 禁止された具体識別子の有無
以下を確認した。
- 特定のベンチマーク case ID: なし
- 特定のリポジトリ名: なし
- 特定のテスト名: なし
- ベンチマーク対象コード断片の引用: なし

提案文にあるコードブロックは SKILL.md 自身の変更前/変更後の引用であり、Objective.md の R1 減点対象外ルールに照らして違反ではない。

数値についても、"~200 lines" や "5 行以内" は benchmark 固有 ID ではなく、一般的なテンプレート閾値/変更規模宣言であるため、この観点では違反としない。

### 5-2. 暗黙のドメイン仮定
ただし、別の意味での汎化性懸念はある。

- 提案は software changes が refactoring / bug-fix / feature-addition のいずれかに比較的きれいに分類できることを暗黙に仮定している。
- 実際には mixed-intent change が多く、言語・フレームワーク・開発文化によって commit / patch の粒度も異なる。
- compare タスクでは commit message や PR title のような補助メタデータが無い場合も多く、static diff だけで意図分類を安定に行うのは難しい。

したがって、表面的な overfitting はないが、推論手法としての汎化性は「中程度」であり、「強い汎用性」とまでは言いにくい。

---

## 6. 全体の推論品質がどう向上すると期待できるか

### 期待できる改善
- EQUIVALENT 側で、目的は同じだが構造が違うパッチを早々に切り捨てない効果は見込める。
- 大規模変更で line-by-line tracing が破綻しやすい場面では、高レベル比較の観点を増やすこと自体は有益。

### 期待しにくい点 / 悪化リスク
- 現行 compare の強みは D1/D2 と test-outcome tracing による concrete evidence であり、今回の追加はその前に coarse semantic prior を入れる。これにより、比較の焦点が「実テストでどう振る舞うか」から「同じ種類の変更に見えるか」へずれる恐れがある。
- 特に NOT_EQUIVALENT 事例で、同じカテゴリ・同じ周辺境界を触っているが実際は結果が違うケースに弱くなる可能性がある。
- つまり、改善があるとしても主に EQUIVALENT 側の recall に偏り、overall の安定改善につながるかは不透明。

### 監査者としての要約
提案の方向性は理解できるが、現状の文言では「比較フレームの改善」より「EQUIVALENT への心理的アンカー追加」に近い。推論品質向上の可能性はあるものの、同程度以上に confirmation bias と false EQUIVALENT の回帰リスクがある。

---

## 最終判断

承認: NO（理由: 変更カテゴリ一致を EQUIVALENT の stronger prior evidence として扱う設計が片方向であり、NOT_EQUIVALENT 側への対称性を欠く。さらに「same defect / abstraction boundary」を triage 段階で先に見せることは、failed-approaches.md が警戒する早期の境界固定・探索狭窄に部分的に重なるため。）

## 補足

もし再提案するなら、より安全なのは次の方向である。
- category は prior evidence ではなく non-binding hypothesis として扱う
- 「category match alone is never evidence of equivalence」と明示する
- EQUIVALENT だけでなく NOT_EQUIVALENT にも対称に効く形、例えば「カテゴリ差は exploration scope を広げる」「カテゴリ一致でも必ず test-outcome trace を優先する」といったガードを先に入れる

この修正があれば、同じカテゴリ C の範囲でより承認しやすくなる。