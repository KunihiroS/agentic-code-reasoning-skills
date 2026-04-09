# Iteration 114 — 監査ディスカッション

## 総評
結論から言うと、この提案は発想自体は理解できるが、現状の文言のままでは承認しにくい。理由は、
「逆方向推論によって観測差分を先に意識させる」という一般原理には一定の妥当性がある一方で、
実際の差分は compare チェックリスト上で「まず差異を想定して述べよ」と要求しており、
分析前アンカリングと NOT_EQ 側への事実上のバイアスを導入する危険があるためである。

参照根拠:
- 提案の変更対象: `benchmark/swebench/runs/iter-114/proposal.md:40-54`
- 現行 checklist: `SKILL.md:214-220`
- Exploration Framework 定義: `Objective.md:138-171`
- 過去失敗原則: `failed-approaches.md:8-62`
- 研究コアの要約: `docs/design.md:1-76`

---

## 1. 既存研究との整合性

DuckDuckGo MCP で取得した関連 URL と要点:

1. https://en.wikipedia.org/wiki/Backward_chaining
   - 要点: backward reasoning は「goal/hypothesis から逆向きに必要条件をたどる」推論法であり、目標から必要証拠を逆算するという提案の基本発想とは整合する。
   - 監査コメント: 提案が述べる「先に想定される挙動差異と観測点を言語化する」は、一般論としては backward reasoning 系の発想に近い。

2. https://en.wikipedia.org/wiki/Counterexample-guided_abstraction_refinement
   - 要点: CEGAR は「もし性質が破れるならどういう counterexample が現れるか」を軸に反例候補を作り、偽反例なら refinement する。反例を先に具体化することで探索を鋭くする。
   - 監査コメント: compare タスクにおいて「NOT_EQ ならどんな観測差分になるか」を先に具体化する考え方自体は、反例駆動の探索として一定の研究整合性がある。

3. https://en.wikipedia.org/wiki/Symbolic_execution
   - 要点: symbolic execution は「どの入力がどの分岐・失敗を生むか」を逆算的に求める。観測される失敗や分岐条件から入力条件を絞る点で、観測可能結果を先に定める戦略と親和的である。
   - 監査コメント: 観測可能な差分（return value / exception / side-effect）を意識すること自体は、プログラム解析上かなり自然な観点である。

整理すると、
- 「観測結果から逆算する」発想そのものは既存研究と整合する。
- ただし既存研究では通常、goal/backward step は単なる自由記述ではなく、反例検証・制約解消・到達可能性確認のような具体的検証操作に結びついている。
- 本提案は `proposal.md:51-53` の文言上、まだ「仮説を先に書く」段階に留まっており、研究的に妥当な backward reasoning を十分に operationalize できていない。

---

## 2. Exploration Framework のカテゴリ選定は適切か

提案は Category A「推論の順序・構造を変える」を選び、mechanism を reverse reasoning としている (`proposal.md:3-23`, `Objective.md:143-147`)。

判断:
- 部分的には妥当。確かに「trace の前に divergence 仮説を置く」ので、順序変更という意味では A に入る。
- ただし純粋な A だけではなく、実質的には D「メタ認知・自己チェック」や E「表現・フォーマット変更」にもまたがっている。
- 特に今回の差分は、新しい検証ループを追加するより「事前に何を書くか」を変える性質が強く、A としての強さは限定的。

汎用原則として見た評価:
- 良い点: 観測境界を先に意識させるのは、`docs/design.md:24-27` の incomplete reasoning chains / subtle difference dismissal 対策として筋が良い。
- 懸念点: 実装が「逆方向の検証」ではなく「逆方向の事前叙述」になっている。つまり、順序変更というより pre-commit 的な仮説生成であり、探索改善よりアンカリングを生みやすい。

したがって、カテゴリ選定は「完全に不適切」ではないが、提案の実体は Category A の強い実装というより、A を名目にした仮説先行フレーミングに近い。

---

## 3. EQUIVALENT 判定と NOT_EQUIVALENT 判定への作用

### 変更前との差分
現行:
- `SKILL.md:218` `Trace each test through both changes separately before comparing`

提案後:
- `proposal.md:51-53`
  `Before tracing, state what behavioral divergence the diff could introduce and what observable outcome ... would differ; then trace ...`

実効的差分は「trace 前に divergence 仮説を明示させる」ことである。これは単なる明確化ではなく、推論の初期状態に差異仮説を注入する変更である。

### NOT_EQUIVALENT への作用
正方向の効果はある。
- subtle な差異が存在するケースでは、先に「どんな観測差分になりうるか」を考えることで、差異の見落としを減らす可能性がある。
- 特に proposal が狙う `subtle difference dismissal` (`proposal.md:70-73`) には一定の効き目がある。

### EQUIVALENT への作用
提案文では「equiv 判定の精度には直接作用しない」(`proposal.md:84-85`) としているが、この評価には同意しない。

理由:
1. 変更は trace 前に「差異があるとしたら何か」を必ず述べさせるため、探索の初期 prior を divergence 側に傾ける。
2. その結果、実際には test outcome が同一でも、局所差分を過大評価して NOT_EQ に寄る危険がある。
3. 現行 skill にはすでに Guardrail #4 があり、差異を見つけた後は relevant test まで trace するよう要求している (`SKILL.md:415-416`)。今回の追加は、既存の「見つけた差異を追う」能力の前段に「差異をまず想定する」圧を足すので、増分としては NOT_EQ 側に強く作用する。

### 片方向にしか作用しないか
「文言上は両方向に適用される」は正しいが、「変更前との差分としての実効」は非対称である。
これは `failed-approaches.md:20-21` の原則 #6 に一致する。

具体的には:
- NOT_EQ ケースでは: 差異候補を先に組み立てることが、そのまま反例探索の補助になる。
- EQUIV ケースでは: 追加されたのは「差異があるなら何かをまず考える」操作であり、「差異がないことを示す探索」を同程度には強めない。

よって、この変更は実効的には NOT_EQ 側に強く作用し、EQUIV 側には回帰リスクを持つ。

---

## 4. failed-approaches.md の汎用原則との照合

### 原則 #1 判定の非対称操作 (`failed-approaches.md:10`)
提案は明示的に判定閾値を動かしてはいないが、実効的には NOT_EQ の立証を先に構成させるため、非対称作用の懸念が強い。
「差異仮説の先行生成」は、EQUIV に必要な no-counterexample 探索より、NOT_EQ に必要な counterexample 想像を直接助ける。

### 原則 #6 対称化は既存制約との差分で評価 (`failed-approaches.md:20`)
ここが特に重要。
提案は「EQUIV/NOT_EQ 両方に使える」と主張するが、差分ベースで見ると新規追加は divergence 仮説の先行要求だけである。既存の trace / counterexample / no-counterexample の枠はすでに存在するため、増分は対称ではない。

### 原則 #7 分析前の中間ラベル生成はアンカリング (`failed-approaches.md:22`)
提案は自ら「ラベルではない」と主張する (`proposal.md:94-95`) が、本質的には分析前に
「この diff はどんな behavioral divergence を起こしうるか」を言わせている。これは category 名こそ違うが、分析前の中間表象を先に固定する点でかなり近い。
特に observable outcome を例示しているため、モデルはその自己生成仮説に引っ張られやすい。

### 原則 #23 ソフトフレーミング (`failed-approaches.md:54`)
この提案は完全に抽象的ではなく、return value / exception / side-effect という観測カテゴリを与えている点は前進。
ただし、依然として「具体的に何を search / inspect / trace するか」は増えていない。したがって、抽象フレーミングから完全には脱していない。

### 原則 #20 厳格な言い換えは立証責任を上げる (`failed-approaches.md:48`)
単純な trace 指示を、事前 divergence 記述つきの要求に書き換えているため、各 test 分析ループの前段コストは増える。規模は小さいが、性質としてはこの原則に接する。

総合判断:
- failed-approaches の中で最も近い再演は #6 と #7。
- 文言は違うが、本質としては「分析前に差異仮説を立てさせることで、後段の推論をその仮説へ寄せる」タイプの失敗にかなり近い。

---

## 5. 汎化性チェック

### 5.1 具体的な数値 ID・repo 名・テスト名・コード断片の有無
指摘結果:
- proposal 文書には `Iteration 114` という数値 ID が含まれる (`proposal.md:1`)。
  - ただしこれは提案内容そのものというより文書メタデータであり、過剰適合の実質的証拠としては弱い。
- failed-approaches や docs/design の節番号・原則番号への参照はあるが、これは監査上の内部参照であり、repo/test 依存の固有識別子ではない。
- ベンチマーク対象リポジトリ名、テスト名、ファイルパス、関数名、コード断片の持ち込みは見当たらない。
- 変更前/後の SKILL.md 文言引用は SKILL.md 自己引用であり、監査ルーブリック上も通常は許容範囲。

結論:
- 厳密に言えば数値 ID は proposal タイトルにある。
- ただし overfitting の観点で問題になるような「特定 repo / テスト / 実コード断片」の混入は確認できない。

### 5.2 暗黙のドメイン依存
提案文の「return value, exception, or side-effect」は比較的一般的で、特定言語には閉じていない。
一方で懸念もある:
- diff から先に behavioral divergence を述べるやり方は、差分が意味論的に読み取りやすい言語・テストスタイルでは有効だが、宣言的設定・メタプログラミング・フレームワーク駆動コードでは空振りや思い込みを生みやすい。
- つまり、言語非依存ではあるが「diff から挙動差分を想像しやすいコード」に若干寄っている。

したがって汎化性は中程度。露骨な overfitting ではないが、完全にドメイン中立とも言い切れない。

---

## 6. 全体の推論品質がどう向上すると期待できるか

期待できる改善:
- 差分から観測点までの因果連鎖を意識させることで、subtle difference dismissal を減らす可能性はある。
- 「観測可能な差異」を先に言語化するため、単なる局所コード差分で止まらず、return/exception/side-effect まで考えやすくなる。

ただし上限は限定的:
- 現在の変更は探索行動そのものを増やしておらず、主に framing を変えるだけ。
- `docs/design.md:42-55` が強調する本丸は per-item iteration と interprocedural tracing であり、今回の差分はそこを直接強化していない。
- そのため、良くても「trace の焦点合わせ」にはなるが、研究コアを強く押し上げる改善とは言いにくい。

副作用リスク:
- 仮説先行により false positive 的な NOT_EQ が増える可能性がある。
- 各テストごとに pre-trace 仮説を考える負担が増え、軽微ながら認知コストも上がる。

総合すると、
- NOT_EQ の一部失敗には効く見込みがある。
- しかし EQUIV 側の回帰リスクとアンカリングリスクを相殺しきれるほど強い改善とは現時点では言えない。

---

## 最終判断
承認: NO（理由: 変更の実効差分が「分析前に divergence 仮説を先に固定する」点にあり、failed-approaches の原則 #6 と #7 に近い。文言上は対称でも、変更前との差分としては NOT_EQ 側に偏って作用し、EQUIV 側の回帰リスクを持つため。）
