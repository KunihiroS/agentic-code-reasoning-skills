# Iter-108 監査ディスカッション

## 総評

提案の狙い自体は理解できる。`compare` モードで EQUIVALENT 方向の早期収束が起きるなら、反証候補を先に言語化してから per-test tracing に入らせる、という発想は一般的には妥当である。とくに「前向き追跡が単なる PASS 確認で終わる」という失敗像に対して、探索の目的を先に与えるという設計意図は筋が通っている。

ただし、今回の差分を「変更前との差分」で見ると、実効的には完全に中立とは言いにくい。既存テンプレートはすでに末尾で `COUNTEREXAMPLE` / `NO COUNTEREXAMPLE EXISTS` を持っており、NOT_EQUIVALENT 側には具体的 counterexample 構成義務がすでに存在する。その上でさらに分析冒頭に「counterexample のために必要な semantic difference を先に述べよ」を足すと、実効差分としては「反証方向の仮説生成を earlier に強める」変更になる。これは EQUIVALENT の false positive を減らす可能性はあるが、片方向の探索圧だけを相対的に強めるリスクもある。

現時点の監査判断は 承認 NO。

---

## 1. 既存研究との整合性

DuckDuckGo MCP 経由で取得した URL と要点:

1. https://en.wikipedia.org/wiki/Backward_chaining
   - backward chaining は「goal から逆算して、その goal を成立させる前提を探索する」推論法として説明されている。
   - 提案の divergence seed は「counterexample が存在するなら何が必要か」を先に置くので、形式としては backward reasoning / goal-driven reasoning に整合的。
   - よって、「逆方向に必要条件を先に立ててから証拠を追う」という発想自体は一般研究と矛盾しない。

2. https://en.wikipedia.org/wiki/Confirmation_bias
   - confirmation bias は、いったん仮説や結論が頭の中で立つと、それを支持する情報探索に寄りやすい現象として説明されている。
   - 提案が問題視している「per-test の前向き追跡を終えた時点で EQUIVALENT への確証バイアスが生じる」という診断は、一般心理学の説明と整合的。
   - したがって「先に反証側の観点を置くことで one-sided search を和らげたい」という狙いには一定の理論的裏づけがある。

3. https://en.wikipedia.org/wiki/Pre-mortem
   - premortem は「失敗したと仮定して、そこに至る原因を先に洗い出す」手法であり、overconfidence や groupthink を下げるための技法として説明されている。
   - 今回の divergence seed も、「NOT EQUIVALENT だとしたら、どの差異・入力・コードパスで露呈するか」を先に書かせる点で prospective hindsight に近い。
   - つまり、提案の根本アイデアは generic な debiasing 手法としては妥当。

4. https://hbr.org/2007/09/performing-a-project-premortem
   - Gary Klein の premortem 記事でも、「失敗したと仮定してから原因を洗い出すことで、言いにくい懸念や弱点を表に出しやすくする」という趣旨が述べられている。
   - これは「分析末尾の形式的反証」よりも「分析冒頭の failure-oriented framing」の方が反証探索を活性化する可能性がある、という提案の方向性を支持する。

研究整合性の結論:
- 提案の発想そのものは、backward reasoning / premortem / confirmation bias 低減という一般研究と整合する。
- ただし、これらの研究は「失敗を先に想定すること一般」の有効性を支持するものであり、今回の 1 行追加が `compare` テンプレート上で最適な実装であることまで直接保証するわけではない。

---

## 2. Exploration Framework のカテゴリ選定は適切か

結論: カテゴリ A（推論の順序・構造を変える）は概ね適切。

理由:
- 提案の本質は「逆方向推論を末尾から先頭へ移す」ことであり、主作用は順序変更にある。
- Objective.md のカテゴリ A にある「結論から逆算して必要な証拠を特定する（逆方向推論）」と明確に一致する。
- したがってカテゴリ選定自体は妥当。

ただし補足:
- この変更は単なる順序変更だけでなく、analysis 冒頭に新しい認知ステップを 1 つ追加している。
- そのため A であると同時に、failed-approaches.md の観点では「analysis 前の仮説生成・ラベル生成」に近い副作用も持つ。
- つまりカテゴリ A の宣言は妥当だが、「A だから failed principle #7 と無関係」とまでは言えない。

---

## 3. EQUIVALENT / NOT_EQUIVALENT の両判定への作用

### 変更前の構造
- per-test tracing を行う
- NOT_EQUIVALENT を主張するなら、末尾で具体的 counterexample を示す
- EQUIVALENT を主張するなら、末尾で hypothetical counterexample を考え、検索結果を添えて「NO COUNTEREXAMPLE EXISTS」を書く

### 変更後の実効差分
追加文:
- `Divergence seed: Before tracing any test, state what semantic difference between A and B would be required for a counterexample — what diverging behavior, and what code path or input would expose it.`

この差分が実際に増やすものは何か:
- 既存テンプレートにすでにある counterexample 系思考を、分析の前段に持ち込むこと
- per-test tracing を「difference search に目的づけられた tracing」へ寄せること

### EQUIVALENT への作用
プラス面:
- 早期の「両方 PASS だから SAME」という浅い収束を崩しやすい。
- 末尾の `NO COUNTEREXAMPLE EXISTS` が形式的儀式になるのを防ぎうる。
- false EQUIVALENT の抑制には効く可能性が高い。

マイナス面:
- まだ証拠が薄い段階で「ありうる差異」を先に自己生成させるため、モデルがその seed にアンカーされる危険がある。
- 1 個のもっともらしい divergence story を立てると、その story に沿った selective search が起き、別の可能性や等価性の証拠整理が粗くなる恐れがある。
- したがって EQUIVALENT を慎重にしすぎて、曖昧ケースで過剰に NOT_EQ 寄りの探索になるリスクがある。

### NOT_EQUIVALENT への作用
プラス面:
- 真に差異があるケースでは、差異の露出条件を先に書くことで tracing が sharper になる可能性がある。
- counterexample 構成を後付けでなく前提付きの探索にできる。

ただし限界:
- NOT_EQUIVALENT 側はもともと末尾に concrete counterexample obligation があり、差異発見の方向づけは既に一定程度存在する。
- したがって今回の差分の marginal benefit は、NOT_EQUIVALENT よりも EQUIVALENT 側の tightening に偏る可能性が高い。

### 片方向にしか作用しないか
厳密には「片方向にしか作用しない」とまでは言わない。真の NOT_EQ ケースでも役立ちうるからである。

しかし、failed-approaches.md の原則 #6 に照らすと重要なのは「文面の対称性」ではなく「変更前との差分」である。既に存在する要件との相対差で見ると:
- NOT_EQUIVALENT 側: すでに concrete counterexample が必須
- EQUIVALENT 側: 末尾の no-counterexample search はあるが、analysis 開始時点では divergence-oriented framing が弱い
- 今回の追加: divergence-oriented framing を analysis 開始時点に追加

このため、実効差分は「反証方向の salience を前倒しで強化する」ものであり、完全に対称とは評価しにくい。つまり、片方向専用ではないが、片方向優位の作用を持つ懸念は強い。

---

## 4. failed-approaches.md の汎用原則との照合

### 原則 #1 判定の非対称操作
提案文は「中立」と主張しているが、監査上はそのまま受け取れない。

理由:
- 変更前から NOT_EQ には concrete counterexample 義務がある。
- 今回はさらに analysis 冒頭で counterexample に必要な差異を先に書かせる。
- 差分として見ると、反証方向の cognitive pressure を早い段階に持ち込んでいる。

よって「明示的な非対称命令」ではないが、実効的には #1 / #6 の系統リスクを持つ。

### 原則 #6 「対称化」は既存制約との差分で評価せよ
最も強く該当する懸念はこれ。

提案側は「発散シードは EQUIV/NOT_EQ どちらにも中立」と述べているが、監査では変更前との差分を見る必要がある。既存テンプレートにはすでに counterexample 関連の要求があるため、今回の追加は「両方向に等量の新情報を与える」のではなく、「反証探索のタイミングと salience を強める」変更として働く。

この点で、提案文の自己評価は甘い。

### 原則 #7 分析前の中間ラベル生成
完全一致ではないが、近い危険がある。

- 提案は単なるカテゴリラベルではなく、counterexample の構造仮説を先に書かせるので、単なる tag ではない。
- ただし evidence 収集前に「どんな semantic difference が必要か」を自己生成させる点は、pre-analysis hypothesis anchoring を導入する。
- しかも文面が単数形寄りで、複数候補を並列に保持することや、seed が refute された場合に探索軸を更新することを指示していない。

したがって #7 には「完全に抵触しない」とは言えず、少なくとも部分的な再演リスクがある。

### 原則 #11 探索順序の固定
提案側は「片側起点ではないので #11 ではない」としているが、原則の本質は「最初に固定された探索軸が後続の注意を支配する」ことにある。

今回も:
- 最初に divergence seed を固定する
- その seed に沿って per-test tracing を進める

という構図なので、片側読み順序の固定ではないにせよ、「先に立てた 1 つの framing に探索を寄せる」という意味で #11 の変種に近い。

### 原則 #23 具体的検証手順を伴わないソフトフレーミング
提案文は「前向きトレースで検証せよという手順と対になっている」と主張している。

ここは半分正しいが、半分弱い。
- 既存の per-test tracing があるので、完全なソフトフレーミングではない。
- ただし追加された 1 行そのものは「どう seed を検証・更新・破棄するか」までは規定していない。
- そのため実運用では、seed を 1 回書いて満足し、後続 tracing との結合が弱いまま終わる可能性がある。

つまり #23 への抵触は決定的ではないが、「確実に回避できている」とも言えない。

### 総括
failed-approaches.md との照合結果としては、特に以下が重い:
- #6 実効差分ベースの非対称性
- #7 analysis 前アンカリング
- #11 初期 framing による探索偏り

このため、「表現は新しいが本質は過去失敗と独立」とまでは評価できない。

---

## 5. 汎化性チェック

### 5-1. 具体的な禁止対象の混入有無
提案文を確認した範囲では、以下のルール違反は見当たらない。
- 特定のベンチマーク case ID
- 特定リポジトリ名
- 特定テスト名
- ベンチマーク対象実コード断片
- 特定関数名 / クラス名 / ファイルパス

含まれているのは:
- `compare` モード
- `ANALYSIS OF TEST BEHAVIOR` など SKILL.md 自身の見出し引用
- Change A / Change B という抽象表現
- `equiv` / `not_eq` という判定ラベル

これらは SKILL.md 自体の構造・抽象概念の引用であり、Objective.md の R1 減点対象外に収まる。

### 5-2. 暗黙のドメイン依存
大きなドメイン依存は弱いが、軽微な偏りはある。

- 提案は「テストを単位に比較し、counterexample をテスト入力・コードパスで構成できる」タイプのタスクをかなり強く想定している。
- これは `compare` モードの本質と整合する一方で、動的言語・静的言語・フレームワーク差を超えた汎用性は維持している。
- ただし「semantic difference → code path → test input」という三段分解は、API レベルの observable behavior が複雑なケースではやや call-path 寄りのバイアスを持つ。

結論:
- 明示的な overfitting 証拠はない。
- ただし reasoning style としては test/counterexample-centric であり、完全な無色透明ではない。
- それでも R1 観点では大きな違反ではない。

---

## 6. 全体の推論品質がどう向上すると期待できるか

期待できる改善:
1. 形式的な per-test PASS 確認から、差異露出条件の検証へ tracing の目的を変えられる可能性がある。
2. EQUIVALENT 側の premature closure を抑えられる可能性がある。
3. 末尾の `NO COUNTEREXAMPLE EXISTS` を空文化しにくくできる可能性がある。

一方で想定される副作用:
1. 早い段階で seed を立てることで、その seed がアンカーとなり、他の可能な差異や同値性根拠の探索を狭める。
2. 既存テンプレートとの相対差では、反証方向の salience だけを強める実効非対称性がある。
3. 1 行追加ゆえ低コストだが、逆に言うと「seed をどう検証・更新するか」が曖昧で、儀式的記述に落ちる可能性もある。

総合すると:
- false EQUIVALENT 抑制には効く可能性がある。
- しかしその改善が全体精度改善に直結するかは不明で、false NOT_EQ や探索アンカリングを通じた回帰リスクも無視できない。
- とくに failed-approaches.md が強調する「差分ベースでの非対称性」への配慮が提案文では不足している。

---

## 最終判断

承認: NO（理由: 発想自体は backward reasoning / premortem と整合し汎用性も概ね保っているが、既存テンプレートとの差分として見ると counterexample 方向の salience を analysis 前に前倒しする実効非対称性が強く、failed-approaches.md の原則 #6 を中心に #7 と #11 の再演リスクがあるため。false EQUIVALENT の抑制には効いても、全体最適としては片方向バイアスとアンカリングの副作用をまだ十分に回避できていない。）
