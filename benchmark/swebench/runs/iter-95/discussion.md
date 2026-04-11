# Iteration 95 — 監査コメント

## 総評
提案の狙いは明確です。既存 Guardrail #4 の「trace at least one relevant test through the differing code path」という指示に対して、どこまで追えばよいかという停止条件を「test assertion boundary での observable effect」へ寄せて明文化しようとしています。これは結論そのものを指示する変更ではなく、差分から観測点までの因果追跡の終点を具体化する変更であり、方向性としては妥当です。

ただし、提案文の「only dismiss the difference if this effect is absorbed before reaching that boundary」という末尾は、実効差分としては主に EQUIVALENT 側の立証を厳しくする変更です。NOT_EQUIVALENT 側にも一定の波及はありますが、変更前との差分でみると対称性は完全ではありません。ここが最大の監査論点です。

---

## 1. 既存研究との整合性

DuckDuckGo MCP の search は一般語クエリで結果取得に失敗したため、同 MCP の fetch_content で関連する公開資料を確認しました。確認した URL と要点は以下です。

1. https://en.wikipedia.org/wiki/Observational_equivalence
   - 要点: observational equivalence は「外部から観測可能な結果が同じなら区別できない」という概念。
   - 本提案との関係: 「差分が伝播した場合に assertion boundary で何が変わるか」を問うのは、比較対象の差を内部状態ではなく観測可能な振る舞いで評価する発想であり、整合的です。

2. https://en.wikipedia.org/wiki/Test_oracle
   - 要点: test oracle は「入力に対する正しい出力や期待結果を与える情報源」であり、実際の結果と expected results を比較する。
   - 本提案との関係: assertion boundary を戻り値・例外・副作用という観測可能な効果で捉えるのは、テストが最終的に何を観測して PASS/FAIL を決めるかを明示化する方向で、テストオラクル中心の考え方に合っています。

3. https://en.wikipedia.org/wiki/Side_effect_(computer_science)
   - 要点: side effect は戻り値以外の observable effect であり、非局所変数更新や I/O などを含む。
   - 本提案との関係: 提案文が observable effect を return value / exception / side effect と分けているのは、観測可能な振る舞いの代表カテゴリとして自然です。

4. https://en.wikipedia.org/wiki/Assertion_(software_development)
   - 要点: assertion はプログラム中の特定点で真であるべき述語であり、事後条件や期待状態の記述にも使われる。
   - 本提案との関係: 「assertion boundary」という表現は、テストが最終的に検査する状態・値に着地させるという意味で理解可能です。

研究コアとの整合性:
- docs/design.md は、論文のコアを「premises → iterative evidence gathering → refutation → formal conclusion」と整理し、特に「incomplete reasoning chains」を guardrail 化することを重視しています。
- 提案は Guardrail #4 を拡張して downstream handling の見落としを減らす狙いなので、研究コアからの逸脱ではなく補強に近いです。
- ただし、論文系の知見と整合するのは「observable outcome まで追う」部分であって、「dismiss できる条件をより厳しく書く」末尾の phrasing まで自動的に正当化されるわけではありません。そこは別途、判定バランスの観点で吟味が必要です。

評価: 研究整合性は概ね良好。ただし phrasing の一部に回帰リスクあり。

---

## 2. Exploration Framework のカテゴリ選定は適切か

提案は Category E「表現・フォーマットを改善する」を選んでいますが、これはおおむね妥当です。

理由:
- 変更対象は Guardrail #4 の文言 1 行追記であり、フレームワーク構造や順序の変更ではない。
- 新しいテーブル列や新手順の追加ではなく、既存の tracing 指示に終点条件を補う形なので、カテゴリ E の「曖昧な指示をより具体的な言い回しに変える」に合致する。
- 同時に、実質的には Category B「情報の取得方法を改善する」にもやや接しています。なぜなら agent に「どこまで追うか」という探索終点を与えているからです。

したがって結論は以下です。
- 主分類として E は許容範囲。
- ただし、単なる wording polish ではなく「探索停止条件の意味論的具体化」なので、E の中でもかなり process-facing な提案です。

汎用原則としての妥当性:
- 「中間ノードで止まらず、観測境界まで差分伝播を確認する」は一般原則として理にかなっています。
- 特定言語・特定テストフレームワーク・特定実装パターンに依存しません。
- 「assertion boundary」という語は unit test 文化寄りではありますが、より一般には「test oracle が観測する境界」と読めるため、十分汎化可能です。

懸念:
- “assertion boundary” は一部のテストでは暗黙的です。明示 assert がない snapshot test、 golden file、 property-based test、 crash/no-crash 判定などでも成立するよう、語義上は「test-observable boundary」や「oracle boundary」の方がさらに一般的です。
- したがってカテゴリ選定は適切だが、 wording 自体にはまだ汎化余地があります。

---

## 3. EQUIVALENT 判定 / NOT_EQUIVALENT 判定の両方への作用

ここは提案文の自己評価より慎重に見るべきです。

### 変更前の基準
現行 Guardrail #4:
- semantic difference を見つけたら
- at least one relevant test を
- differing code path で trace してから
- no impact と結論せよ

この時点で、少なくとも文面上は「差異を無害とみなす前に downstream 追跡しろ」という要求は既にあります。弱いのは「どこまで trace すればよいか」が曖昧な点です。

### 変更後の実効差分
追加文が実際に増やす義務は二つです。

1. trace の終点を assertion boundary の observable effect に寄せる
2. dismiss の条件を「その効果が boundary 前に absorbed された場合に限る」と明示する

このうち 1 は比較的対称的です。
- EQUIVALENT を主張するなら、差分が観測点に届かないことを確認する必要がある。
- NOT_EQUIVALENT を主張するなら、差分が観測点に届く形を説明しやすくなる。

しかし 2 は非対称寄りです。
- “only dismiss the difference if ... absorbed ...” は直接には「impact なし」と言う側、つまり EQUIVALENT 側にだけ追加の停止条件を課しています。
- NOT_EQUIVALENT 側は既存でも「差が test outcome を変える」と言えば済む場面があり、今回の文言追加で同程度に強く拘束されるわけではありません。

### 実効的な作用分析
EQUIVALENT 側への作用:
- 強い。中間ノードで「ここで正規化されるはず」と雑に打ち切る誤判定を減らす見込みがある。
- 一方で、複雑なフレームワークや多段抽象化では assertion boundary までの追跡負荷が上がり、十分に確認しきれず EQUIVALENT を避ける方向に働く可能性がある。

NOT_EQUIVALENT 側への作用:
- 中程度。observable effect を明示させることで、根拠の薄い「差があるから違う」の飛躍を抑制する効果はある。
- ただし追加文の命令形は dismiss 側を主対象にしているので、NOT_EQUIVALENT の立証義務が同じ強度で増えるわけではない。

### 片方向にしか作用しないか
完全な片方向専用ではありません。理由は、observable effect / assertion boundary という概念自体は NOT_EQUIVALENT の説明品質も上げるからです。

ただし、変更前との差分でみると「主作用は EQUIVALENT 側のハードル引き上げ」です。failed-approaches.md の原則 #6 が言う通り、文面が対称的でも差分が非対称なら効果も非対称です。今回の差分はまさにそれに近いです。

結論:
- 提案者の「両方向に同じ観測義務を課すため非対称化しない」という主張は、変更後の字面だけを見た評価であり、変更前との差分評価としては弱い。
- 実効差分は EQUIVALENT 側により強く作用する。

---

## 4. failed-approaches.md の汎用原則との照合

提案者は #1, #2, #3, #8, #9, #15, #17, #18, #22, #26 との整合を主張しています。いくつかは妥当ですが、見落としがあります。

### 整合している点
- 原則 #17「中間ノードの局所的な分析義務化は E2E 追跡を阻害する」
  - 本提案はむしろ中間ノード打ち切りを減らし、終点を観測境界へ寄せるので方向として整合的です。

- 原則 #15「固定長 hop で観測境界を近似するな」
  - hop 数ではなく意味論的境界を指定しているため整合的です。

- 原則 #22「具体物ではなく状態や性質で指示すべき」
  - return value / exception / side effect は具体的な repo 要素ではなく、観測可能な効果のカテゴリなので比較的よい抽象度です。

### 抵触リスクがある点
1. 原則 #6「対称化は既存制約との差分で評価せよ」
   - もっとも重要な懸念です。
   - 既存 Guardrail #4 はすでに「差異を見つけたら relevant test を trace せよ」と言っており、今回の追加で実質的に増えるのは「impact なしで切り上げるための追加条件」です。
   - よって差分効果は EQUIVALENT 側に強く、提案者の「非対称性なし」評価は過大です。

2. 原則 #20「厳密な言い換えや対比句の追加は立証責任の引き上げになりうる」
   - “only dismiss the difference if ...” はまさに排他的 phrasing であり、明確化であると同時にハードル引き上げでもあります。
   - 提案の本質的な価値は前半の「observable effect at the test assertion boundary を identify せよ」にあります。後半の排他的条件は、価値よりも回帰リスクを増やしている可能性があります。

3. 原則 #18 / #26 の周辺リスク
   - 提案者は「file:line の物理的裏付け要求ではないから安全」としていますが、問題は必ずしも file:line 義務だけではありません。
   - “assertion boundary” の同定を毎回強く求めると、複雑なテストでは test oracle の実体把握に追加探索が必要になり、結果的に予算圧迫が起こりえます。
   - ここは軽微な 1 行変更なので致命的とは言いませんが、「抵触なし」と断言するほど安全でもありません。

結論:
- 過去失敗の再演ではないが、#6 と #20 に対する警戒が不足しています。
- 特に「明確化」と「EQUIVALENT 側の追加立証要求」は紙一重です。

---

## 5. 汎化性チェック

### 具体的な数値 ID / リポジトリ名 / テスト名 / コード断片の有無
確認結果:
- 特定のベンチマーク対象リポジトリ名: なし
- 特定テスト名・テスト ID: なし
- 特定ファイルパス・関数名・クラス名（ベンチマーク対象由来）: なし
- ベンチマーク対象コード断片の引用: なし

含まれているもの:
- “Iteration 95” というワークフロー上の反復番号
- “Guardrail #4”, “Category E”, failed-approaches 原則番号
- SKILL.md 自身の変更前後の文言引用

これらは監査ルーブリック上の減点対象外に近く、ルール違反とは見なしません。

### 暗黙のドメイン想定
- 提案は「relevant test」「assertion boundary」「return value / exception / side effect」という一般概念で書かれており、特定言語・特定フレームワーク前提ではありません。
- ただし “assertion boundary” という語は、テストが明示 assertion を持つスタイルをやや強く想起させます。
- たとえば property-based testing、snapshot testing、approval testing、differential testing のようなテスト様式では「assertion」というより「oracle」や「observed outcome」の方が広く適合します。

汎化性評価:
- 重大な overfitting は見当たりません。
- ただし wording の汎化性は満点ではなく、「assertion boundary」より「test-observable boundary / oracle boundary」の方がさらに良いです。

---

## 6. 全体の推論品質がどう向上すると期待できるか

期待できる改善:
1. 中間ノード打ち切りの減少
   - 差異を見つけた直後に「たぶん吸収される」と推測で止める誤りを減らしやすい。

2. compare モードの観測点意識の明確化
   - docs/design.md が強調する「per-test iteration」の終点を、より test outcome に近い形で意識させられる。

3. NOT_EQUIVALENT 根拠の品質向上
   - 「差分あり」だけでなく「どの observable effect が変わるか」を言わせることで、雑な差分主義を抑えられる。

4. Guardrail #5 との補完関係
   - Guardrail #5 は downstream handling の見落としを戒める一般原則ですが、提案は compare の subtle difference 文脈でより具体的な着地点を与えるため、相互補完になる。

期待しにくい点 / リスク:
1. EQUIVALENT 側の証明コスト増
   - 特に抽象度の高いフレームワークでは、assertion boundary までを毎回意識すると探索が重くなる。

2. wording がやや強すぎる
   - 前半の「identify observable effect」は有益だが、後半の「only dismiss ... if absorbed ...」は安全側バイアスを増やす可能性がある。

3. 既存 Guardrail #4 と #5 の重複感
   - 今回の改善は本質的には有益だが、差分の価値は「新しい概念追加」ではなく「終点の明示」にある。そこを越えて排他的条件まで足すと、明確化より制約追加の色が濃くなる。

---

## 最終判断
現状の提案文のままでは、私は承認しません。

理由の要約:
- 良い点: 観測境界まで追うという中心アイデア自体は汎用的で、研究コアにも整合的。中間ノード打ち切りの抑制には有望。
- 主な問題: 追加文の後半 “only dismiss the difference if this effect is absorbed before reaching that boundary” が、変更前との差分としては EQUIVALENT 側に主として作用する排他的条件になっている。failed-approaches 原則 #6 と #20 のリスクを十分に回避できていない。
- したがって、アイデア自体は有望だが phrasing は未調整。

もし修正するなら、価値の核は前半だけです。つまり:
- 「trace の中で、差分が伝播した場合に test-observable/oracle boundary で何が変わるかを特定せよ」
という形に留め、
- 「only dismiss ... if ...」のような排他的停止条件は避ける
のがより安全です。

承認: NO（理由: 中心アイデアは妥当だが、現行 phrasing の実効差分は EQUIVALENT 側に偏って立証責任を引き上げるため。failed-approaches 原則 #6 と #20 の再演リスクがある）
