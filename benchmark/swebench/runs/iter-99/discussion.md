# Iter-99 改善案 監査ディスカッション

## 結論要約

提案の狙い自体は理解できる。コード差分を見つけただけで「影響なし」と早期棄却する誤りを減らしたい、という問題設定は妥当であり、既存研究の「observable behavior まで追う」「test oracle に接続する」という考え方とも整合する。

ただし、今回の具体的変更は「文面上は対称」に見えても、**変更前との差分としては EQUIVALENT 側の立証責任を主に引き上げる**。そのため failed-approaches.md の失敗原則、とくに #1, #6, #20, #22, #26 に強く接触している。加えて、提案文そのものに具体的な数値 ID が含まれており、汎化性ルールにも軽度だが明確な違反がある。

したがって、現案のままの承認は難しい。

---

## 1. 既存研究との整合性

DuckDuckGo MCP で取得した参考 URL と要点:

1. https://en.wikipedia.org/wiki/Observational_equivalence
   - 要点: 観測可能な含意が同一なら区別できない、というのが observational equivalence の基本。
   - 本提案との関係: 「コード差分の存在」ではなく「観測可能な結果への到達」で判定する、という方向性自体は整合的。

2. https://en.wikipedia.org/wiki/Test_oracle
   - 要点: テストオラクルは入力に対する正しい出力や期待結果を与えるもの。テストでは実際の結果と期待結果の比較が本質。
   - 本提案との関係: 差異が本当に重要かどうかを test assertion / oracle まで結び付けて考える発想は妥当。

3. https://en.wikipedia.org/wiki/Program_slicing
   - 要点: program slicing は、ある地点・変数の値に影響しうる文を依存関係から遡って求める考え方であり、観測点に影響する要因を追う手法。
   - 本提案との関係: 「発散した値がどこまで伝播するか」を追う、という発想は slicing 的で、汎用的な静的推論原則として理解できる。

評価:
- 研究整合性は「概念レベル」ではある。
- しかし研究が支持しているのは一般に「observable effect まで追う」ことであって、毎回「test assertion か吸収点を明示せよ」という厳しめの具体ルールまで直接支持しているわけではない。
- つまり、方向性は研究と整合するが、**今回の運用レベルの強制方法は別問題**であり、ここは failed-approaches の知見で追加検証すべき領域。

---

## 2. Exploration Framework のカテゴリ選定は適切か

提案はカテゴリ B「情報の取得方法を改善する」を選んでいる。

部分的には妥当:
- これは「何を結論するか」を直接変えるより、「差異を見つけた後にどう追跡するか」を具体化している。
- その意味では、探索・追跡の方法に関する変更なので B と言えなくはない。

ただし、純粋な B とは言い切れない:
- 実際に追加される文は、「どう探すか」だけでなく「何を示さなければならないか」という**結論直前の証明要件**を強めている。
- これは B に加えて E（表現の精緻化）や D（自己拘束的チェック）にもまたがる性質を持つ。
- 特に「test assertion」「absorbed before any assertion」という終点指定は、探索方法の改善というより**到達すべき物理的ターゲットの追加**に近い。

監査判断:
- カテゴリ B 選定は完全な誤分類ではない。
- ただし本質的には「探索方法の軽い改善」ではなく、「棄却時の立証要件の強化」であり、proposal の自己説明はやや楽観的。

---

## 3. EQUIVALENT / NOT_EQUIVALENT の両方にどう作用するか

ここが最大の懸念点。

### 文面上の主張
proposal は以下を主張している。
- NOT_EQUIVALENT: 発散値が assertion に到達することを示す
- EQUIVALENT: 発散値が assertion 前に吸収されることを示す
- よって対称である

### 変更前との差分ベースの実効分析
しかし、failed-approaches.md #6 が重要である。

> 既に片方向をカバーしている制約を「両方向に拡張」しても、既存方向には実効的変化がなく、新規方向にのみ制約が作用する。

今回まさにこれに近い。

変更前の SKILL.md には既に以下がある。
- Compare template の COUNTEREXAMPLE: NOT EQUIVALENT を主張するなら、具体的テストで PASS/FAIL 差分を assertion or exception まで追え、とほぼ同義の要求がある。
- Compare checklist: 「Do not conclude NOT EQUIVALENT from a code difference alone — verify that the difference produces a different observable test outcome by tracing through at least one test」
- 既存 Guardrail #4: semantic difference を見つけたら、それを no impact と棄却する前に relevant test を differing code path で trace せよ。

つまり変更前から:
- NOT_EQUIVALENT 側には、すでに「observable test outcome まで出せ」という要求がかなり強く入っている。
- EQUIVALENT 側は「差異を見つけても no impact と言う前に trace せよ」まではあるが、「どこで吸収されたか」までは明示要求されていない。

この状態で今回の文を足すと、実効差分は主に以下になる。
- EQUIVALENT 側: 「影響なし」と言うには absorption point か assertion 非到達を示す必要がある
- NOT_EQUIVALENT 側: 実質的には既存要件の再表現に近く、新しい負荷は小さい

### 実効的帰結
したがって、この変更は**片方向にしか作用しない可能性が高い**。

予想される挙動:
- 良い面: 根拠のない早期 EQUIVALENT を減らす
- 悪い面: EQUIVALENT の正答ケースでも追加探索を強い、時間切れ・証明不足・安全側フォールバックを増やす
- その結果、NOT_EQUIVALENT の precision 向上よりも、EQUIVALENT 側の recall 悪化や UNKNOWN/過剰保守化を招くリスクが高い

結論:
- proposal の「対称性」主張は**変更後の文面だけ**を見た評価であり、変更前との差分評価になっていない。
- failed-approaches.md #6 に照らすと、現案は非対称作用の疑いが強い。

---

## 4. failed-approaches.md の汎用原則との照合

### 強く抵触・準抵触する原則

1. 原則 #1 判定の非対称操作は必ず失敗する
   - 名目的には対称だが、実効差分は EQUIVALENT 側への追加立証負荷。
   - したがって実質的には非対称操作の疑いが強い。

2. 原則 #6 「対称化」は既存制約との差分で評価せよ
   - 今回もっとも重要。
   - NOT_EQUIVALENT 側は既存 Compare template がすでにかなりカバーしているため、新規効果は主に EQUIVALENT 側へ出る。

3. 原則 #20 目標証拠の厳密な言い換えや対比句の追加は、実質的な立証責任の引き上げとして作用する
   - "reaches a test assertion or is absorbed before any assertion" は、まさに既存の「no impact と言う前に trace」をより厳格・排他的な言い回しで言い換えている。
   - proposal は「具体化であって厳格化ではない」と述べるが、運用上は厳格化として働く可能性が高い。

4. 原則 #22 抽象原則での具体物の例示は、物理的探索目標として過剰適応される
   - "test assertion" は一般概念ではあるが、エージェントから見ると「必ず探すべき具体ターゲット」に化けやすい。
   - 現行設計は observable test outcome までの追跡を求めているので十分であり、さらに assertion という名指しを足すと再検索負荷を増やす。

5. 原則 #26 中間ステップでの過剰な物理的検証要求は、探索予算の枯渇と安全側への誤判定を誘発する
   - 今回は file:line 義務ではないが、「assertion か absorption point を毎回示せ」という新たな終点確認が入る。
   - これは各差異ごとに追加検証行動を誘発しやすく、ターン予算/認知予算を圧迫する。

### 軽度に関連する原則

6. 原則 #18 特定の証拠カテゴリへの厳格な物理的裏付け要求
   - proposal は file:line を求めていないので直撃ではない。
   - ただし「assertion / absorption」という具体的終点の明示は、実務上これに近い探索負荷を生む可能性がある。

### proposal の自己弁護への反論
proposal は #1, #12, #20, #22, #26 への非抵触を主張しているが、以下の理由で弱い。
- #1/#12: 文面対称性だけでは足りず、差分の実効対称性が必要
- #20: 既存棄却要件の「具体化」と言っても、実際には必要証拠の粒度を引き上げている
- #22: assertion は抽象語でも、探索実務では具体ターゲット化しやすい
- #26: file:line を要求しなくても、assertion 命名・吸収点特定は探索追加を誘発する

総評:
- 過去失敗の単純再演ではないが、**本質的には #6 と #20 を中心とした失敗方向の再演にかなり近い**。

---

## 5. 汎化性チェック

### 明示的ルール違反の有無
提案文には以下が含まれる。
- タイトルの `Iter-99`

これは「具体的な数値 ID」に該当するため、あなたが今回明示したルール
「提案文中に具体的な数値 ID, リポジトリ名, テスト名, コード断片が含まれていないか。含まれていれば実装者のルール違反」
に照らすと、**軽微だが明確な違反**である。

一方で、以下は直ちに NG とは言いにくい。
- Guardrail #4 の変更前/後引用
- `not_eq`, `EQUIVALENT`, `NOT_EQUIVALENT` といった抽象ラベル
- `test assertion`, `absorbed` のような一般概念

### 暗黙のドメイン依存性
提案は表面上は言語・フレームワーク中立である。
しかし以下の暗黙依存がある。
- 「assertion」を物理的に同定しやすい単体テスト文化を暗黙に想定している
- 実際には property-based tests, snapshot tests, exception-based tests, indirect oracles, golden-file tests, integration tests では「どの assertion か」を局所的に指さしにくい
- 「absorbed before any assertion」も、吸収点が明示的な変数正規化ではなく、テスト oracle の粗さや観測粒度によって生じるケースでは定義しにくい

したがって汎化性は満点ではない。
この提案は任意言語に完全非依存というより、**xUnit 的な assertion 中心のテスト観に少し寄っている**。

---

## 6. 全体の推論品質がどう向上すると期待できるか

期待できる改善:
- semantic difference 発見後の早期打ち切りを減らす
- 「差がある」から即「影響あり/なし」へ飛ぶ雑な推論を抑える
- difference から observable outcome までの因果連鎖を意識させる

ただし、改善の質は限定的で、代償が大きい可能性がある。

理由:
1. 既存 SKILL.md はすでに compare mode で
   - per-test tracing
   - counterexample obligation
   - observable test outcome の確認
   をかなり強く要求している。
   したがって新規利得は限定的。

2. 一方で、新ルールは「差異を棄却するには assertion / absorption を示せ」と追加要求するため、主に EQUIVALENT 側の検証コストを上げる。

3. その結果として想定されるのは、
   - false EQUIVALENT 減少
   - しかし EQUIVALENT 正答の一部で探索不足・保守化・判定遅延が増加
   であり、全体精度改善は不確実。

要するに、
- 問題意識は良い
- しかし改善幅より副作用のほうが目立つ設計に見える

---

## 最終判断

承認: NO（理由: 変更前との差分で見ると実効的には EQUIVALENT 側に偏った立証責任の追加となる可能性が高く、failed-approaches.md の原則 #1・#6・#20・#22・#26 に強く抵触するため。さらに提案文タイトルに具体的数値 ID `Iter-99` を含み、今回の汎化性ルールにも違反しているため。）
