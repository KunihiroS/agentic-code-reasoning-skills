# Iter-37 監査コメント

## 総評
提案の狙い自体は理解できる。差分読解の初動で意味的に重要な変更へ注意を寄せる、という発想は一般論としてもっともらしい。
ただし、今回の具体案は `failed-approaches.md` に明記された失敗方向とかなり近く、しかも `import-only changes` を付随的変更として一段低く扱う文言が汎化性を損ねる。
結論として、現状の文案のままでは承認しにくい。

---

## 1. 既存研究との整合性

### 参照した Web 情報
1. arXiv: Agentic Code Reasoning
   - URL: https://arxiv.org/abs/2603.01896
   - 要点: 明示的前提、実行経路トレース、形式的結論からなる semi-formal reasoning が、patch equivalence / fault localization / code QA の精度を改善すると述べる。つまり「探索を構造化して、重要な証拠に注意を集中させる」方向性そのものは研究と整合的。

2. Google Engineering Practices: What to look for in a code review
   - URL: https://google.github.io/eng-practices/review/reviewer/looking-for.html
   - 要点: コードレビューでは style より design / functionality / complexity を重視すべきとされる。したがって「まず機能的・意味的差分を見る」という高レベル方針には一般的妥当性がある。

3. Google Engineering Practices: Small CLs
   - URL: https://google.github.io/eng-practices/review/developer/small-cls.html
   - 要点: 大きい変更ほど重要点が見落とされやすく、レビュー品質が下がる。提案が「限られた探索コストを核心差分へ寄せたい」と考える根拠にはなる。

4. Martin Fowler: Definition of Refactoring
   - URL: https://martinfowler.com/bliki/DefinitionOfRefactoring.html
   - 要点: refactoring は observable behavior を変えない変更である。つまり cosmetic / structural cleanup と semantic change を区別する発想自体はソフトウェア工学上自然。

5. Python Language Reference: The import system
   - URL: https://docs.python.org/3/reference/import.html
   - 要点: import は単なる見た目ではなく、モジュール探索・初期化・名前束縛・副作用を伴う。したがって `import-only changes` を一般に「付随的変更」とみなすのは危険。

### 研究整合性の結論
- 良い点:
  - 「証拠収集の注意を重要差分へ集中させる」方向は、semi-formal reasoning の趣旨と矛盾しない。
  - style より functionality を優先する、という一般的レビュー原則とも整合する。
- 問題点:
  - 提案文の具体化が粗い。特に `import-only` を formatting/comment と同列に落とすのは、言語横断の一般原則として弱い。
  - 研究が推しているのは「重要な証拠の取りこぼし防止」であって、「読解順序の半固定」それ自体ではない。

---

## 2. Exploration Framework のカテゴリ選定は適切か

### 判定
カテゴリ B「情報の取得方法を改善する」は表面的には妥当。
実際、提案は「何を結論するか」ではなく「差分をどう読むか」を変えているため、A/C/D/E/F よりは B に近い。

### ただし重要な留保
今回のメカニズムは B の中でもかなり危うい部類で、実質的には「読解順序の半固定」である。
`Objective.md` の B には確かに「探索の優先順位付けを変える」が含まれるが、`failed-approaches.md` はまさにこの種の変更に対して警戒を明示している。

特に以下と近い:
- `failed-approaches.md`:
  - 「探索ドリフト対策を追加する際は、探索の自由度を削りすぎない」
  - 「とくに『どこから読み始めるか』『どの境界を先に確定するか』のような読解順序の半固定は…探索経路を早期に細らせ…構造差分や別粒度の手掛かりを拾う余地を減らしやすい」

したがって、カテゴリ B を選んだこと自体は不自然ではないが、選んだメカニズムは blacklist に非常に近い。

---

## 3. EQUIVALENT 判定と NOT_EQUIVALENT 判定への作用

## 3.1 変更前との実効的差分
現行の `SKILL.md` は compare モードでまず:
- S1: modified files 比較
- S2: completeness 確認
- S3: 大規模差分では structural / high-level semantic comparison を優先

ここに提案は新たに:
- 「任意サイズのパッチで logic/control-flow changes を formatting/comment/import-only より先に読む」

を加える。これは見た目以上に強い追加で、単なる補足ではなく、全サイズ・全ケース向けの読解順序ルールになる。

## 3.2 EQUIVALENT 側への作用
プラスに働く可能性:
- cosmetic diff が多いケースで、些末差分に認知コストを使いすぎず、意味差分の有無を先に確認できる。
- その結果、表面的差分に引きずられて NOT_EQUIVALENT に寄る誤りは減る可能性がある。
- 逆に、真の semantic difference を先に見つけやすくなるため、浅い探索のまま誤って EQUIVALENT と言う事故も減る可能性がある。

ただし限界:
- 本当に EQUIVALENT かを示すには、最後は「差分が cosmetic に留まる」ことの確認が必要であり、後回しにした差分も結局読む必要がある。
- したがって改善幅は「初動の注意配分」レベルに留まる。

## 3.3 NOT_EQUIVALENT 側への作用
提案文は「NOT_EQUIVALENT は既に 100% なので悪化しにくい」と述べるが、これは楽観的すぎる。

悪化しうる点:
1. `import-only` が意味的変更である場合
   - Python では import は副作用・初期化・名前束縛に関与する。
   - 他言語でも import/use/include/annotation/registration/dependency wiring のみの変更が挙動差を生む。
   - そのため `import-only` を付随扱いすると、NOT_EQUIVALENT の決定的証拠を初動で軽視しうる。

2. 構造差分よりローカルなロジック差分へ意識が吸われる場合
   - 現行 S1/S2 は「ファイル欠落」「モジュール欠落」「test data 欠落」のような強い NOT_EQ シグナルを先に拾う設計。
   - 追加文は S3 にぶら下がる形でも、「まず logic/control-flow を読め」という別の優先軸を与えるため、実運用では S1/S2 の早期判定力を相対的に弱めるおそれがある。

3. ロジック差分が目立たない NOT_EQ ケースを取りこぼす可能性
   - 設定、登録、データ、import、例外伝播、デコレータ、メタデータ変更などは、見た目上 `logic/control-flow` ではなくてもテスト結果を変えうる。

### 小結
この変更は実効的には両方向対称ではない。
- 主作用: 「cosmetic ノイズより semantic 差分に注意を寄せる」ことで EQUIVALENT/NOT_EQUIVALENT の双方に理論上プラス
- ただし実際の文言は `import-only` を過度に軽視するため、NOT_EQUIVALENT 側の安全性を削るリスクがある

よって「片方向にしか作用しないか」という問いへの答えは:
- 形式上は両方向に作用する
- しかし実質上は、ロジック変更が前面に出るケースに偏って効く
- その一方で、非ロジック系の意味差分を含む NOT_EQUIVALENT を悪化させうる

---

## 4. failed-approaches.md との照合

### 結論
抵触なしとは言いにくい。むしろ、かなり近い再演である。

### 理由
提案は「証拠の種類は固定していないからセーフ」と主張するが、`failed-approaches.md` が禁じているのはそれだけではない。より本質的には、探索の経路を初期段階で細らせること自体が危険だと述べている。

該当箇所の趣旨:
- 「探索の自由度を削りすぎない」
- 「どこから読み始めるか」の半固定は、構造差分や別粒度の手掛かりを拾う余地を減らす

今回の追加文はまさに:
- どこから読み始めるか
- 何を先に読み、何を後回しにするか

を固定している。
これは failed-approaches の警告の中心にかなり近い。

### 監査判断
提案書内の「抵触なし」という自己評価には同意しない。
少なくとも「明確な懸念あり」であり、ブラックリスト方向との距離は近い。

---

## 5. 汎化性チェック

### 明示的なルール違反の有無
- ベンチマーク対象リポジトリ名: なし
- テスト名: なし
- ケース ID: なし
- ベンチマーク実コード断片: なし

この点では大きな overfitting の痕跡は見当たらない。

### ただし補足
提案内には `SKILL.md` 自身の文言引用があるが、これは変更前/後比較のための自己引用であり、`Objective.md` の R1 の減点対象外と読める。したがって、これ自体を違反とは扱わない。

### 暗黙のドメイン依存性
ここが本質的懸念。
提案は以下を暗に仮定している:
- semantic difference は主に logic/control-flow に表れる
- import-only changes は多くの場合 cosmetic である
- formatting/comment/import は同じ「付随的変更」群として扱ってよい

これらは一般原則としては強すぎる。
- Python: import 自体が実行・副作用・初期化に関与しうる
- Java/C#/Go/TypeScript などでも annotation, registration, dependency wiring, module resolution, build metadata 変更が挙動差を生みうる
- 設定ファイルや test data の差分は control-flow 変更なしでも test outcome を変える

よって、表面上は具体名を出していないが、実質的には「意味差分はロジックに現れやすい」という特定パターンへ寄った提案であり、汎化性は満点ではない。

---

## 6. 全体の推論品質への期待効果

### 期待できる改善
- 差分のノイズに振り回されず、意味のある変化へ早く到達するという点では一定の改善余地がある。
- 特に「大差分で探索コストが不足しがち」という問題意識は妥当。

### ただし現行文案の問題
- 効果の源泉が「重要差分への注意集中」であるのに、実装文言が「読解順序の固定」と「import-only の軽視」になっている。
- そのため、改善の核より副作用の方が目立つ。

### より安全な方向性
もし同じ狙いを維持するなら、以下のような弱いヒューリスティックに留める方がよい。
例:
- cosmetic-only edit と potential semantic edit を区別して triage せよ
- ただし import / config / registration / metadata changes は cosmetic とみなすな
- S1/S2 の structural gap 検出を最優先とし、それを上書きしない

つまり、「読解順序の固定」ではなく「semantic-risk tagging の注意喚起」に寄せるならまだ検討余地がある。

---

## 最終判定
承認: NO（理由: `failed-approaches.md` が禁じる「読解順序の半固定」に実質的に近く、`import-only changes` を付随扱いする文言が汎化性と NOT_EQUIVALENT 側の安全性を損なうため）
