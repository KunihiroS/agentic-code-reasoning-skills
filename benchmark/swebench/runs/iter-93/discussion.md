# Iter-93 Discussion

## 提案の要約

提案は `compare` モードの `ANALYSIS OF TEST BEHAVIOR` にある

- `trace through code`

を

- `trace through code to the test assertion`

へ 2 行だけ置換するものである。狙いは、中間的な意味論差分を見つけた時点で NOT_EQUIVALENT に倒れる早計を減らし、最終的なテストの観測点まで因果追跡させることにある。

---

## 1. 既存研究との整合性

### 整合する点

1. `docs/design.md` は compare の本質を「per-test iteration」「counterexample obligation」「incomplete reasoning chains の防止」と整理している。したがって、最終的な観測可能結果へ追跡するという発想自体は研究コアと整合する。
2. `SKILL.md` の D1 も「relevant test suite produces identical pass/fail outcomes」を同値性の定義にしており、観測境界をテスト結果側に置くこと自体は自然である。

### Web 調査で得られた一般知見

1. Test oracle - Wikipedia
   URL: https://en.wikipedia.org/wiki/Test_Oracle
   要点: テストオラクルは「入力に対して正しい出力を記述する情報」であり、テストは SUT の実結果を期待結果と比較する営みだと説明している。提案が「最終的な観測結果」へ因果を伸ばしたいという意図は、このオラクル中心の考え方と整合する。

2. Formal specifications and test: Correctness and oracle
   URL: https://link.springer.com/chapter/10.1007/3-540-61629-2_52
   要点: 動的テストの正しさ判断には、プログラム内部ではなく「observable results」を解釈する oracle framework が必要だと述べる。これも、中間状態ではなく観測結果に結びつけるべきという提案の方向性を支持する。

3. Program slicing - Wikipedia
   URL: https://en.wikipedia.org/wiki/Program_slicing
   要点: slicing は「point of interest / slicing criterion に影響する文」を求める。つまり追跡の終点は“意味論的な関心点”であるべきで、具体的な構文トークンに固定する必要はない。

4. Observational equivalence - Wikipedia
   URL: https://en.wikipedia.org/wiki/Observational_equivalence
   要点: 観測可能な含意が同じなら区別不能、という定義。compare モードの D1 と親和的であり、同値性判断は観測可能結果ベースで行うべきだという抽象原理を補強する。

5. Assertion (software development) - Wikipedia
   URL: https://en.wikipedia.org/wiki/Assertion_(software_development)
   要点: assertion はプログラム点に結びつく真偽条件であり、 precondition/postcondition も含む広い概念。ただし、すべてのテストフレームワークが単一の `assert` 文を中心に構成されるわけではない。スナップショット比較、例外期待、ゴールデンファイル、差分比較、property-based testing などでは「観測点」は assertion 行そのものとは限らない。

### 研究整合性の結論

方向性としては整合するが、研究・一般原理が支持しているのは「observable outcome / oracle」までの追跡であって、「test assertion」という物理的対象の特定までは必ずしも支持していない。したがって、提案は発想レベルでは妥当だが、文言レベルではやや過具体化している。

---

## 2. Exploration Framework のカテゴリ選定は適切か

### E 主カテゴリ

これは妥当。実際の変更はテンプレート文言の精緻化であり、構造追加でも新フィールド追加でもないため、第一義的には E（表現・フォーマット改善）である。

### C 副カテゴリ

部分的には妥当だが、言い過ぎもある。比較対象を「中間差分」から「最終観測結果」へ寄せるという意味では C 的側面がある。しかし、既存の `SKILL.md` はすでに D1 で pass/fail outcome を定義し、Guardrail #4/#5 でも downstream handling と relevant test tracing を求めている。したがって、今回の変更で比較枠組みそのものが新しくなるわけではなく、既存枠組みの終点を明示化する程度である。

### 監査所見

- 主カテゴリ E: 適切
- 副カテゴリ C: 「全く不適切」ではないが、実効差分の大きさをやや大きく見積もっている
- 本質的には B（どう探すかの改善）にもまたがるが、変更内容だけ見れば E が最も近い

---

## 3. EQUIVALENT / NOT_EQUIVALENT の両判定への作用

ここが最大の懸念点である。文面上は A/B 両側対称だが、`failed-approaches.md` 原則 #6 が言う通り、評価すべきは「変更後の見た目」ではなく「変更前との差分」である。

### 変更前にすでに存在する制約

`SKILL.md` には既に以下がある。

- D1: 同値性は test outcome の一致で定義される
- Guardrail #2: test outcome を tracing なしに主張するな
- Guardrail #4: semantic difference を見つけたら relevant test を trace せよ
- Guardrail #5: downstream handling を確認せよ
- Compare checklist: 差異が見つかったら relevant test を trace して impact を確認せよ

つまり、「差異を見たらテスト影響まで追え」という原理は既にかなり強く入っている。

### 実効的にどちらへ強く作用するか

増分として新たに強化されるのは、主に「差異を見つけた時点で止まる」パターンの抑制である。これは NOT_EQUIVALENT を出す場面の方に強くかかる。

理由:

1. NOT_EQUIVALENT は、通常「ここが違う」から一気に結論へ飛びやすい失敗モードと接続している。
2. EQUIVALENT 側は、もともと `NO COUNTEREXAMPLE EXISTS` 節で counterexample 不在の探索を要するため、既に outcome ベースの検討を比較的要求されている。
3. したがって差分としては、NOT_EQUIVALENT を出す側の立証責任を引き上げる効果が大きい。

これは文面の対称性にもかかわらず、実効的には片方向作用である可能性が高い。

### 期待される正の効果

- 中間差分の早計な採用を減らし、偽 NOT_EQUIVALENT を減らす可能性はある。

### 予想される負の効果

- assertion 行の物理的特定を要求することで、短い反例構成が難しくなり、正しい NOT_EQUIVALENT まで出しにくくなる恐れがある。
- 既存でも outcome tracing は要求されているため、今回の差分は「追加の明確化」よりも「追加の負担」として働くリスクがある。

### この観点での結論

「両方向に均等に効く」とは評価しにくい。実効差分は NOT_EQUIVALENT 抑制寄りであり、回帰リスクがある。

---

## 4. failed-approaches.md の汎用原則との照合

提案文自身は多くの原則に抵触しないと主張しているが、その自己評価は楽観的すぎる。

### 抵触懸念が低い点

- 原則 #2 出力制約: 結論を直接指示していないため、ここには抵触しない。
- 原則 #3 探索量の削減: 直接の探索削減提案ではない。
- 原則 #9 メタ認知的自己チェック: 自己評価項目追加ではない。

### 実質的に抵触懸念が高い点

1. 原則 #6 「対称化」は既存制約との差分で評価せよ
   - 前述の通り、既に outcome tracing はかなり入っている。
   - 今回の増分は、既存の曖昧さを均等に埋めるというより、特に NOT_EQUIVALENT 側の早計な主張を抑える方向へ効きやすい。

2. 原則 #20 目標証拠の厳密な言い換えや対比句の追加
   - `trace through code` を `trace through code to the test assertion` に厳密化する変更は、まさに「より厳格・排他的な言い換え」に近い。
   - 意図は明確化でも、モデルには警告的な追加要件として働きうる。

3. 原則 #22 抽象原則での具体物の例示
   - ここで研究コアが本来要求しているのは「observable effect / final outcome」である。
   - それを `test assertion` という具体物に落とすと、エージェントは assertion 文そのものを再検索・特定・引用すべき物理ターゲットとして扱う可能性がある。
   - この原則との衝突はかなり強い。

4. 原則 #26 中間ステップでの過剰な物理的検証要求
   - 提案は per-test Claim の because 節で `to the test assertion` を要求する。
   - これは「結論時」ではなく「中間分析ループ」の各 test で、特定コード要素の命名・同定を促す。
   - failed-approaches 側が名指しで危険視しているパターンにかなり近い。

### この観点での結論

提案の核心は「最終観測点まで追え」であり、その抽象方向は良い。しかし実装手段として `test assertion` を入れるのは、failed-approaches 原則 #22 と #26 の再演に見える。

---

## 5. 汎化性チェック

### 明示的なルール違反の有無

- ベンチマーク対象リポジトリ名: なし
- 特定テスト名: なし
- 特定コードベースの関数名/クラス名/ファイルパス: なし
- ベンチマーク固有コード断片: なし

よって、ベンチマークへの露骨な過適合を示す固有識別子は見当たらない。

### ただし注意点

1. 提案文には SKILL.md 自己引用のコードブロックがある。
   - これは対象リポジトリの実コードではなく、テンプレート文言の比較であるため、通常は許容範囲。

2. `test assertion` という語は、暗黙に assertion-centered なテスト構造を標準形として想定している。
   - しかし現実のテストは `assert` 文だけで構成されない。
   - 例外期待、ログ比較、 snapshot/golden file、 property-based test、 fuzz regression、 SQL 結果比較、 CLI 出力比較、 HTTP レスポンス検証などでは、観測点は assertion 文そのものではなく、より広い oracle / observable outcome である。

3. したがって、この提案は「具体的なベンチマークケースへの過適合」ではないが、「assertion という特定テスト様式への概念的偏り」はある。

### 汎化性の結論

ケース固有性の点では概ね問題ないが、表現がやや assertion-biased であり、任意言語・任意テスト形態への汎化性は満点ではない。

---

## 6. 全体の推論品質がどう向上すると期待できるか

### 改善が期待できる部分

- semantic difference を見つけた時点で prematurely NOT_EQUIVALENT に飛ぶ誤りには、一定の抑制効果がありうる。
- 特に downstream handling の見落としを意識させる点は `docs/design.md` の error analysis と整合する。

### ただし改善幅を制限する要因

1. 既存 SKILL.md がすでに同じ方向の guardrail を持っている
   - したがって今回の増分は、根本的な新規能力追加というより既存ルールの再強調である。

2. 「observable outcome」ではなく「test assertion」に固定している
   - これにより、良い抽象原理を過度に具体物化してしまっている。

3. 追加コストが claim ごとにかかる
   - 2 行変更でも、実行時の認知コストは per-test/per-claim で累積する。
   - そのコストに見合うだけの新情報が得られるとは限らない。

### 期待値の総括

- 偽 NOT_EQUIVALENT を減らす局所効果はありうる
- しかし、既存制約との差分として見ると「assertion の物理的特定」という余計な探索負担を持ち込みやすく、全体精度改善の確度は高くない
- よって、推論品質の改善期待は「中程度未満」。少なくとも、この文言のまま即実装を承認するには弱い

---

## 総合判断

提案の良い点は、「比較の終点は中間差分ではなく観測可能なテスト結果である」という方向性を再確認していること。これは研究コアとも整合する。

しかし監査上は、改善の抽象原理そのものではなく、その実装文言が問題である。

`to the test assertion` は

- 既存制約との差分としては NOT_EQUIVALENT 側の立証責任を重くしやすい
- `failed-approaches.md` 原則 #22 と #26 にかなり近い
- assertion-centered なテスト観を暗黙に前提しており、汎化性も少し落とす

ため、このままの形では承認しにくい。

もし同じ狙いを維持するなら、`test assertion` のような具体物ではなく、`final observable test outcome` や `observable effect checked by the test` のように、観測境界を意味論的に表現する方が安全である。

## 承認

承認: NO（理由: 発想は妥当だが、`test assertion` という具体物への固定が failed-approaches の危険原則 #22/#26 に近く、実効差分として NOT_EQUIVALENT 側に偏った追加負担になりやすいため）
