# Iteration 10 — 監査コメント

## 総評

提案の狙い自体は理解できる。Step 4 の Rules にある

- Read the actual definition. Do not infer behavior from the name.

は重要だが、禁止形だけだと「では Behavior 列に何を書くべきか」が弱く、運用上のばらつきが出やすい。したがって「読んだ結果を列にどう反映するか」を補う方向性は、研究コアにも整合し、変更規模も小さい。

ただし、今回の具体案は "summarize its control flow" という表現がやや狭すぎる。Step 4 の Behavior 列は本来「actual behavior after reading the definition」を書く欄であり、制御フローだけでなく、データ変換・返り値条件・例外条件・副作用・設定依存なども含みうる。ここを control flow に寄せると、名前依存推論は減っても、意味論の要約が「分岐の説明」に偏る副作用がある。

そのため、方向性は良いが、提案文言はそのままでは承認しにくい。

---

## 1. 既存研究との整合性

注: DuckDuckGo MCP の search エンドポイントは本セッションでは複数回 "No results were found" を返したため、同じ DuckDuckGo MCP の fetch_content で既知の関連資料を直接確認した。

### 参照 1
- URL: https://arxiv.org/abs/2603.01896
- 要点:
  - semi-formal reasoning は explicit premises, execution-path tracing, formal conclusion を要求する「certificate」として働き、ケースの取りこぼしや unsupported claim を減らす。
  - この提案は、Step 4 の VERIFIED behavior 記録をより具体化しようとするものであり、研究の中核である tracing/certification を弱める方向ではない。
  - 特に README.md と docs/design.md が強調する「read actual definitions」「verified behavior records」の思想とは整合的。

### 参照 2
- URL: https://www.nngroup.com/articles/recognition-and-recall/
- 要点:
  - 人は recall より recognition のほうが容易であり、追加の文脈があると正しい情報を取り出しやすい。
  - 今回の提案を好意的に解釈すると、「何をしてはいけないか」だけでなく「Behavior 列をどう埋めるか」を明示することで、実行時の想起負荷を下げる効果が見込める。
  - その意味で、曖昧な禁止文より具体的な記録指示を与える設計は一般原則として妥当。

### 参照 3
- URL: https://en.wikipedia.org/wiki/Cognitive_load
- 要点:
  - working memory には制約があり、タスク提示の仕方は extraneous cognitive load を増減させる。
  - Step 4 は探索中リアルタイムで表を埋める設計なので、Behavior 列の期待値が明示されること自体は認知負荷の削減に寄与しうる。
  - ただし、instruction が狭すぎると「本来見るべき意味論」を捨てて別の過剰単純化を生む。今回の "control flow" 指定にはこの懸念がある。

結論:
- 「曖昧な禁止を、具体的な記録行動に寄せる」という発想は研究・認知原則の両方と整合する。
- しかし「control flow に限定する」点は、SKILL.md と論文が意図する verified behavior の広さより狭く、完全整合とは言いにくい。

---

## 2. Exploration Framework のカテゴリ選定は適切か

判定: 半分妥当だが、主分類としては E より B に近い。

理由:
- 実装者は「曖昧な指示を具体化する」ので E と説明している。これは表面的には正しい。
- ただし実効的には、この変更は単なる wording polish ではなく、「コードを読んだ後に何を抽出して記録するか」という情報取得・記録プロトコルの変更である。
- Objective.md の B には「コードの読み方の指示を具体化する」「何を探すかではなく、どう探すかを改善する」とある。今回の効果はまさにそこにある。

したがって、監査上は以下の整理が適切:
- 表現上の見た目: E
- 実際のメカニズム: B/E 境界だが、より本質的には B

この点は分類ミスそのものが即否決理由ではないが、提案の作用点を見誤ると failed-approaches との照合や回帰リスク評価を甘くするので、記録上は修正したほうがよい。

---

## 3. EQUIVALENT 判定と NOT_EQUIVALENT 判定の両方への作用

### 変更前との実効的差分
変更前:
- 「名前から推測するな」という禁止が中心
- ただし、Behavior 列に何を書くべきかの最小粒度が弱い
- 結果として、定義を読んでも要約が粗くなり、VERIFIED の質にムラが出うる

変更後案:
- 「定義を読み、その control flow を Behavior 列に要約せよ」が追加される
- これにより、少なくとも「読んだ結果を列に転写する」という具体行動が強化される

### EQUIVALENT への作用
正方向の効果:
- 表面差分や関数名の印象ではなく、実際の分岐・到達経路を明示する習慣がつけば、「見た目は違うがテスト上は同じ」を説明しやすくなる。
- 特に compare モードでは、同一のテスト到達パスを落ち着いて揃えて見る助けになる。

負方向のリスク:
- EQUIVALENT 判定では「制御フローは違うが観測結果は同じ」ケースがありうる。
- control flow の要約を強く求めると、観測上同値かどうかよりも、フロー差分そのものを過大評価する危険がある。
- つまり false NOT_EQUIVALENT を増やす方向の副作用がわずかにある。

### NOT_EQUIVALENT への作用
正方向の効果:
- 名前や表面説明で同一視せず、実際の分岐・条件・例外経路を見るようになるので、隠れた差異を見つけやすくなる。
- misleading name による false EQUIVALENT の抑制には効く。

負方向のリスク:
- もし差異が control flow ではなく、返り値の構築・データ整形・状態更新の細部にある場合、control flow 要約中心だと見逃しうる。

### 片方向にしか作用しないか
- いいえ。原理上は両方向に作用する。
- ただし、現在の wording では「actual behavior」ではなく「control flow」に焦点を当てるため、EQUIVALENT 側にはやや不利、NOT_EQUIVALENT 側にはやや有利に傾く可能性がある。
- 監査観点として重要なのは、提案者が「全モードに波及する」と書いている点は概ね正しいが、「両ラベルに対して対称に効く」とまでは言えないこと。

監査結論:
- 片方向専用の変更ではない。
- ただし現行案は完全対称ではなく、差異検出バイアスを少し強める懸念がある。

---

## 4. failed-approaches.md の汎用原則との照合

### 原則 1: 探索を「特定シグナルの捜索」へ寄せすぎない
- 判定: おおむね非抵触
- 根拠:
  - この提案は「次に何を探せ」と証拠タイプを固定するものではない。
  - したがって確認バイアスを直接増やすタイプではない。
- ただし軽微な懸念:
  - Behavior 欄の要約軸を control flow に限定すると、読む際の注意が flow シグナルに寄りすぎる可能性がある。
  - これは「探索」ではなく「記録」の制約だが、運用上は探索にも逆流しうる。

### 原則 2: 探索の自由度を削りすぎない
- 判定: 軽微な懸念あり
- 根拠:
  - 変更規模は小さく、対象・順序・範囲は変えていないので大きな抵触ではない。
  - しかし "summarize its control flow" は、Behavior の概念を事実上 flow 中心に狭める。これは compare / explain / audit で必要な意味論の幅を少し削る。

### 原則 3: 結論直前の自己監査に新しい必須メタ判断を増やしすぎない
- 判定: 非抵触
- 根拠:
  - Step 5.5 には触れておらず、新しい mandatory meta-check を増やしていない。

総合すると、failed-approaches の「本質再演」ではない。しかし wording 次第では「局所的具体化が探索の幅を狭める」失敗原則に近づく余地がある。

---

## 5. 汎化性チェック

### 明示的なルール違反の有無
提案文を確認した限り、以下の禁止要素は含まれていない。
- ベンチマーク固有の数値 ID
- 特定の外部リポジトリ名
- 特定テスト名
- ベンチマーク対象実装コード断片

含まれているのは SKILL.md 自身の変更前後引用のみであり、Objective.md の R1 の減点対象外に該当するため問題ない。

### 暗黙のドメイン依存性
- 特定言語、特定フレームワーク、特定テストパターンへの露骨な依存は見られない。
- ただし "control flow" を前面に出す発想は、分岐や例外が明瞭な命令型コードには相性が良い一方、宣言的設定、データ駆動 dispatch、型レベル制約、DSL、クエリ構築、メタプログラミングなどでは十分でないことがある。
- よって汎化性は高めだが、表現をこのまま固定すると「幅広い言語・表現形式を扱う skill」としては少し狭い。

監査結論:
- 形式上の overfitting 違反はない。
- ただし wording の抽象度としては「behavior」のほうが汎化性が高い。

---

## 6. 全体の推論品質がどう向上すると期待できるか

期待できる改善:
1. VERIFIED 欄の空洞化を防ぎやすい
   - 「読んだ」という事実だけでなく、「読んだ結果を行動要約として残す」ことが明示されるため、表の実質が上がる。
2. 名前依存推論の抑制
   - 関数名やメソッド名の印象で埋める雑な記録を減らせる。
3. Step 3 と Step 4 の接続強化
   - exploration journal と trace table の往復が明示的になり、途中の reasoning artifact が残りやすい。

一方で、現行案のままでは次の限界がある:
1. control flow 偏重
   - actual behavior 全体ではなく flow に焦点が寄る。
2. semantics の重要要素を落としうる
   - 返り値の shape、state mutation、data contract、error propagation などは flow だけでは十分に表せない。
3. compare モードで差異過敏になる恐れ
   - フロー差分を見た瞬間に、観測的差分より先に「違う」と感じやすくなるリスクがある。

したがって、品質向上は「ある」が、最大化するには wording を少し修正したほうがよい。たとえば次のような方向ならより安全:
- Read the actual definition and summarize its actual behavior (including key control flow when relevant) in the Behavior column. Do not infer behavior from the name.

この形なら、提案の狙いである具体的行動指示を保ちつつ、flow への過剰収束を避けられる。

---

## 最終判断

承認: NO（理由: 方向性は良いが、"summarize its control flow" は Step 4 の Behavior 列が本来扱う「actual behavior」より狭く、推論を control-flow 偏重にしうる。結果として NOT_EQUIVALENT 側にややバイアスし、汎化性と対称性を少し損なう懸念がある。少なくとも wording は behavior 中心に再設計してから再提案すべき。）
