# Iter-6 Discussion

## 総評
提案の核は、「構造差分を見たら早期 NOT EQUIVALENT に倒せる」という現行 compare の近道を、そのまま残すのではなく、(1) 先に最小反例形を仮置きする、(2) 早期 NOT EQUIVALENT は relevant test path 上の欠落に限定する、の 2 点で decision point を差し替えることにあります。これは単なる監査向けの説明補強ではなく、compare の分岐条件そのものを変える提案になっています。

現時点の判断は「条件付きで承認寄り」です。最大の懸念は、逆方向推論の書き方次第では failed-approaches.md が警戒している「読解順序の半固定」に寄りうることです。ただし今回の文案は、固定された証拠種類の追加や必須ゲート増設ではなく、既存の Compare / Certificate template のごく小さな置換として収まっており、修正余地も明確です。

## 1. 既存研究との整合性
Web で確認できた関連研究・概念との整合は概ねあります。

1) Agentic Code Reasoning
- URL: https://arxiv.org/abs/2603.01896
- 要点: semi-formal reasoning は「explicit premises」「execution path tracing」「formal conclusions」を強制することで、unsupported claim や case skipping を減らすという立場。今回の提案はこのコアを壊しておらず、compare における反証義務を「先に仮置きした counterexample shape を produce/refute する」という形で前倒しするものなので、研究コアとは整合的。
- 監査コメント: 直接の根拠として最も強い。compare の判断を「反例があるか」に寄せる方向は、この論文の certificate 発想と相性がよい。

2) Counterexample-Guided Abstraction Refinement (CEGAR)
- URL: https://en.wikipedia.org/wiki/Counterexample-guided_abstraction_refinement
- 要点: まず counterexample を作り、それが本物か spurious かで探索を refine する枠組み。提案の「最小反例形を先に仮置きし、ANALYSIS を produce/refute として使う」は、厳密には同一手法ではないが、counterexample を探索の駆動力にするという一般原理と整合。
- 監査コメント: これは LLM の compare にそのまま移植できる証明ではないが、「反例先行で探索を引っ張る」こと自体は汎用的に理にかなう。

3) Predicate Transformer / Weakest Preconditions
- URL: https://en.wikipedia.org/wiki/Predicate_transformer_semantics
- 要点: postcondition から backward に必要条件を辿るという、古典的な backward reasoning の定式化。提案の reverse from D1 は、実装詳細より先に「何が観測されれば非同値か」を置くため、この backward reasoning と概念的に整合する。
- 監査コメント: これも直接エージェント用プロンプト研究ではないが、「後件から必要条件へ戻る」こと自体は一般理論として十分に自然。

結論:
- 研究整合性は YES。
- ただし強い言い方をすると「反例形を固定する」方向に見えると、論文の core である hypothesis-driven exploration より、探索経路固定の色が強くなる。したがって文言は「仮置きして更新する」に留めるのが重要。

## 2. Exploration Framework のカテゴリ選定
判定: 適切

- 提案は Objective.md の A「推論の順序・構造を変える」に素直に入ります。
- 実際に変えようとしているのは、compare の中で
  - いつ早期結論してよいか
  - ANALYSIS を何のために走らせるか
 という順序と分岐構造です。
- B「情報取得方法」や D「メタ認知」ではなく A に置いたのは妥当です。なぜなら、追加で新しい情報源を読む話でも、新しい自己監査項目を増やす話でもなく、既存証拠の使い始める順番と早期打ち切り条件を差し替える話だからです。

補足:
- ただし「反例形を先に書く」が強くなりすぎると、A の中でも failed-approaches.md が禁じる「読解順序の半固定」に接近します。カテゴリ自体は正しいが、文言運用は慎重にすべきです。

## 3. EQUIVALENT / NOT_EQUIVALENT の両方向への作用
### 実効的差分
現行 SKILL.md の compare では、STRUCTURAL TRIAGE のあとに
- S1/S2 で clear structural gap が見えれば
- full ANALYSIS を飛ばして NOT EQUIVALENT に進める
という強いショートカットがあります。

今回の提案はこれを次のように変えます。
- 早期 NOT EQUIVALENT の条件を「relevant test path 上の gap」に限定する
- それ以外では、先に minimal counterexample shape を仮置きして ANALYSIS を継続する

この差分は理由の言い換えではなく、実際に「いつ止めるか」「いつ継続するか」の条件を変えています。

### EQUIVALENT 側への作用
- 改善見込み: 反例形を先に置くことで、「何を見つければ非同値になるか」が先に明確になるため、偽 EQUIV を減らす方向に働く。
- メカニズム: EQUIVALENT を出す前に、counterexample が成立する具体形を一度立て、その不成立を trace/search で潰す運用になるため、反証探索が弱いままの EQUIV を出しにくくなる。
- リスク: 反例形の初期仮置きが狭すぎると、別種の反例を見落とす可能性はある。したがって「single best counterexample only」ではなく「minimal shape, updateable」でなければならない。

### NOT_EQUIVALENT 側への作用
- 改善見込み: 関係ない構造差分での早計な偽 NOT_EQUIV を減らす方向に働く。
- メカニズム: structural gap を relevant test path に結びつけられない限り、早期 NOT EQUIVALENT に倒せなくなる。
- リスク: 関連テスト経路の立証要求を重くしすぎると、明らかな非同値でも判断が遅くなる可能性はある。ただし提案は full gate 追加ではなく、既存 S2 の言い換えなので、運用次第で抑制可能。

### 片方向最適化か
判定: 片方向だけではない

- 主効果は偽 NOT_EQUIV の削減に見えます。
- しかし minimal counterexample shape の前倒しは、EQUIV 側の「反例探索不足」も改善しうるので、両方向作用の説明は成立しています。
- ただし proposal 文面の現状では、NOT_EQUIVALENT 側の改善がより具体で、EQUIVALENT 側の改善は一段抽象的です。compare への効き目を強めるなら、EQUIV 時にも「どの種類の counterexample を refute したか」を 1 行で明示する方がよいです。

## 4. failed-approaches.md との照合
総評: 本質的な再演ではないが、境界が近い箇所が 1 つある

- 「証拠種類の事前固定」
  - 判定: NO
  - 理由: 新しい証拠カテゴリを増やしていない。relevant test path と counterexample は、既存 compare の D1/S2/COUNTEREXAMPLE の枠内での再配置。

- 「探索経路の半固定」
  - 判定: やや近いが、現状は NO 寄り
  - 理由: 問題になるのは proposal の「first sketch the minimal counterexample shape」という表現。これが実装で強い先行義務として書かれると、failed-approaches.md が警戒する「どこから読み始めるか」「どの境界を先に確定するか」の半固定に近づく。
  - ただし proposal 本文では「仮置きして更新する」「探索の開始点であって拘束条件ではない」と補足しており、この補足込みなら本質的再演とはまでは言えない。

- 「必須ゲート増」
  - 判定: NO
  - 理由: 既存 Compare / Certificate template 内の置換で、必須の節や自己監査項目を増設していない。総量不変の方針とも整合する。

結論:
- 本質的な blacklist 再演とまでは判定しません。
- ただし実装文言が強すぎると、「新しい証拠欄を足していないだけの順序固定」に見えうるので、その一点だけは修正必須です。

## 5. 汎化性チェック
判定: 概ね良好

明示的違反の有無:
- 具体的な数値 ID: なし
- 特定リポジトリ名: なし
- 特定テスト名: なし
- ベンチマーク実コード断片: なし

補足:
- proposal には SKILL.md の自己引用があるが、Objective.md の R1 減点対象外に明記されている範囲。
- file/module/test-data/import/exercise という語彙はややモジュール型言語やテストフレームワークを想起させるが、一般概念として読める範囲で、特定ドメイン前提までは行っていない。
- ただし「relevant tests import/exercise a path」という書き方は、実行経路の可視性が低い設定や、明示 import を持たない環境では若干表現が偏る。実装時には「import/exercise」より「reach/cover/execute relevant code path」の方が汎用です。

## 6. 全体の推論品質への期待効果
期待できる改善は 3 点あります。

1) 早期結論の質が上がる
- 現行は structural gap が見えると、意味差分の立証がやや甘いまま NOT EQUIVALENT に流れやすい。
- relevant test path に結びつけることで、「見た目の差」ではなく「テスト結果に効く差」で止まるようになる。

2) ANALYSIS の目的が明確になる
- ただトレースを積むのではなく、「仮置きした反例形を作れるか / 潰せるか」を見にいくので、trace の焦点が上がる。

3) EQUIVALENT 結論の反証可能性が上がる
- 先に反例形を明示するため、EQUIVALENT を出すときの no-counterexample claim が空文化しにくい。

一方で、品質改善の上限は文言次第です。反例形を「更新可能な仮説」として書けばよい改善になりやすく、逆に「まずこれを書け」と強く固定すると探索の柔軟性を落とす恐れがあります。

## 停滞診断（必須）
- 懸念 1 点: proposal は compare の decision point を実際に動かしているが、EQUIVALENT 側の効き方はまだ抽象度が高く、実装次第では「監査 rubic で説明しやすい反証言語の補強」に留まり、compare の意思決定変化が主に NOT_EQUIVALENT 側だけになる危険はある。

failed-approaches 該当性:
- 探索経路の半固定: NO（ただし「first sketch the minimal counterexample shape」が強すぎると境界に近い）
- 必須ゲート増: NO
- 証拠種類の事前固定: NO

## compare 影響の実効性チェック（必須）
1) Decision-point delta
- Before: IF S1/S2 で structural gap が見える THEN early NOT EQUIVALENT に進みうる
- After: IF S2 で relevant test path 上の structural gap が立証できる THEN early NOT EQUIVALENT、ELSE minimal counterexample shape を仮置きして ANALYSIS 継続
- IF/THEN 形式で 2 行（Before/After）になっているか？: YES
- 評価: 条件と行動の両方が変わっているので、理由の言い換えだけではない

2) Failure-mode target
- 主対象: 偽 NOT_EQUIV
- 副対象: 偽 EQUIV
- メカニズム: structural shortcut を relevant-test-path 条件に縛って偽 NOT_EQUIV を減らし、counterexample shape の先行仮置きで反証探索不足の偽 EQUIV を減らす

3) Non-goal
- 変えないこと: 新しい必須ゲートは増やさない、証拠カテゴリは追加固定しない、反例形は探索拘束ではなく更新可能な仮説に留める

追加チェック:
- Discriminative probe:
  - 抽象ケース: 片方の変更だけが追加ファイルを触っているが、そのファイルは relevant tests の到達経路外にある。変更前は structural gap を見て NOT EQUIVALENT に倒しやすい。
  - 変更後は、「relevant test path 上か」を先に見るので早期 NOT EQUIVALENT を保留し、counterexample shape が立たなければ EQUIVALENT 側の精査へ進める。
  - これは新ゲート追加ではなく、既存 structural shortcut の発火条件を狭め、空いた分だけ ANALYSIS の反例探索を前に出す置換になっている。

## 修正指示（2〜3 点）
1) 「first sketch the minimal counterexample shape」は固定感が強いので、実装では「briefly sketch an initial counterexample shape and update it during analysis」へ弱めてください。
- 支払い: 新しい説明文を足すのでなく、既存の「Do not skip...」文の置換に留めること。

2) early NOT EQUIVALENT 条件の文言は「import/exercise」より「reach / execute the relevant code path」に寄せてください。
- 支払い: 具体例（file/module/test-data）は残してもよいが、言い換え追加ではなく既存語の置換で行うこと。

3) EQUIVALENT 側の効き目を compare に明示するため、NO COUNTEREXAMPLE EXISTS 節に新行追加ではなく、既存文の「what test, what input, what diverging behavior」を「initial counterexample shape, updated as analysis proceeds」と統合してください。
- 支払い: 新規必須欄を増やさないこと。

## 最終判断
承認: YES

理由:
- Decision-point delta が具体で、compare の分岐を実際に変えている
- failed-approaches.md の本質的再演ではない
- 主効果は偽 NOT_EQUIV 削減だが、偽 EQUIV 側にも作用する説明が成立している
- 汎化性違反は見当たらない

ただし、実装文言は「反例形の仮置き」を探索拘束に見せないよう弱めることが前提です。