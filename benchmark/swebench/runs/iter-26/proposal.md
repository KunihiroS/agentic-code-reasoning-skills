過去提案との差異: 反証の優先順位や探索経路を特定観点へ半固定せず、差分の「分類ラベル」を追加して反証対象の選び方だけを変える。
Target: 偽 EQUIV / 偽 NOT_EQUIV の両方
Mechanism (抽象): 差分を「影響軸＋発火前提＋オラクル接点」で分類し、その分類に基づいて counterexample 形状を定義する。
Non-goal: STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件や観測境界の制限ルールは変更しない。

カテゴリ C 内での具体的メカニズム選択理由
- C の要件（比較粒度・差異重要度・変更分類）に対し、「テスト結果」という最終オラクルへ直接飛ぶのではなく、差分を“何が変わりうるか”の軸（出力/例外/副作用/性能など）で分類してから比較するほうが、偽 EQUIV（重要差分の見落とし）と偽 NOT_EQUIV（見かけ差分の過大評価）の両方を同時に減らしやすい。
- これは「証拠種類のテンプレ固定」ではなく「差分（比較対象）の分類」なので、探索対象の選び方だけを改善し、探索手順や観測境界を狭めない。

改善仮説（1つ）
- 差分を“影響軸＋発火前提＋オラクル接点”で分類してから counterexample 形状を言語化すると、(a) EQUIV 側では「反例があるならどの軸で、どの前提で、どのアサーションが割れるか」が具体化され探索が漏れにくくなり、(b) NOT_EQUIV 側では「どの軸の差分か」を明示できない見かけ差分の暴発が減る。

SKILL.md 該当箇所（短い引用）と変更方針
引用:
- "Complete every section; first sketch the minimal counterexample shape (reverse from D1) ..."
- "Diverging assertion: [test_file:line — the specific assert/check that produces a different result]"
- "[describe concretely: what test, what input, what diverging behavior]"
変更方針:
- “minimal counterexample” を 1発で作るのではなく、まず差分を分類するための最小メモ（Divergence Ledger）を挟み、counterexample の形状を「影響軸＋発火前提＋オラクル接点」で固定化（= 具体化）してから探索・反証する。

Decision-point delta（IF/THEN）
Before: IF EQUIVALENT を主張する THEN counterexample 形状を「テスト/入力/挙動」で記述して検索する because パターン検索で反例不在を示す。
After:  IF EQUIVALENT を主張する THEN counterexample 形状を「影響軸/発火前提/割れるはずのアサーション」で記述して検索する because 反例の“観測可能な破れ方”を分類して漏れを減らす。

変更差分プレビュー（Before/After、8行）
Before:
- Complete every section; first sketch the minimal counterexample shape (reverse from D1), then use ANALYSIS to try to produce/refute it.
-   Diverging assertion: [test_file:line — the specific assert/check that produces a different result]
-     [describe concretely: what test, what input, what diverging behavior]
- - Trace each test through both changes separately before comparing
After:
- Complete every section; first write a Divergence Ledger: list candidate differences and tag each with (impact axis, trigger preconditions, oracle touchpoint), then use ANALYSIS to produce/refute it.
-   Divergence axis + trigger: [output/exception/side-effect/perf + precondition]; Diverging assertion: [test_file:line — the specific assert/check that differs]
-     [describe concretely: trigger precondition + axis + what assert/check would differ]
- - Before comparing, build a Divergence Ledger (axis+trigger+oracle touchpoint) for candidate differences; then trace tests through both changes with the ledger in view

failed-approaches.md との照合（整合点）
- 「証拠種類をテンプレで事前固定しすぎる変更は避ける」: 本提案は“証拠の種類”ではなく“差分の分類ラベル”を導入するだけで、どの証拠を先に探すかを固定しない。
- 「観測境界への過度な還元を避ける／探索の自由度を削りすぎない」: 影響軸と発火前提は複数観点を許容する抽象分類であり、特定境界（例: テスト依存等）に有効条件を狭めない。

変更規模の宣言
- SKILL.md の既存文言の置換のみ（合計4行、追加の必須ゲート純増なし）。
