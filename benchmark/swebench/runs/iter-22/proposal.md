過去提案との差異: これは「構造差→早期 NOT_EQUIV」を特定の観測境界へ狭める案ではなく、比較前半で何を先に読み、どのテストを relevant と確定するかという取得順序を変える案である。
Target: 両方
Mechanism (抽象): changed-symbol 参照ベースの relevant test 発見を、assertion/output から changed path へ戻る依存トレース優先に置き換える。
Non-goal: STRUCTURAL TRIAGE の結論条件を assertion boundary へ写像して狭めたり、新しい verdict ゲートを増やしたりはしない。

カテゴリ B 内での具体的メカニズム選択理由
- 今の Compare には D2 の「relevant tests の見つけ方」が明示されており、これは verdict そのものではなく retrieval heuristic なので、カテゴリ B として局所変更しやすい。
- compare の停滞は「何を relevant test と見なして先に掘るか」で起きやすく、ここを変えると EQUIV/NOT_EQUIV/追加探索/CONFIDENCE が実際に変わりうる。

Decision-point candidates considered
1. Relevant-test identification
   - 現在のデフォルト挙動: changed function/class/variable を参照するテストを relevant 候補として先に集め、その集合を土台に比較しがち。
   - 変更後の観測アウトカム: irrelevant な候補の早期固定が減り、追加探索要求・EQUIV/NOT_EQUIV・CONFIDENCE が変わる。
2. Structural early exit ordering
   - 現在のデフォルト挙動: S1/S2 の gap が見えると detailed tracing 前に NOT_EQUIV へ進みやすい。
   - 変更後の観測アウトカム: 結論保留または追加探索が増え、偽 NOT_EQUIV を避けうる。
3. UNVERIFIED secondary evidence priority
   - 現在のデフォルト挙動: unavailable source では docs/signature/test usage が並列候補になり、どれを先に取るかが曖昧。
   - 変更後の観測アウトカム: UNVERIFIED の残存量と CONFIDENCE が変わる。

選ぶ分岐
- 1 を選ぶ。理由は 2 点だけ。
  1) compare では「どのテストを relevant と確定したか」がその後の per-test analysis 全体を決めるので、取得順序の差が verdict に直結する。
  2) これは structural-gap の結論条件をいじるのではなく、relevant test 発見のトリガを syntax-first から assertion-backward へ替えるだけなので、禁止方向と機構が異なる。

改善仮説
- compare では、relevant test を「changed symbol への言及」から集めるより、「テストの assertion / expected output から逆向きに traced して changed value・exception・branch へ到達するか」で確定した方が、表面的な参照に引っ張られず、間接経路の差分も拾いやすくなる。

該当箇所と変更方針
- 現行引用 1: "To identify them: search for tests referencing the changed function, class, or variable."
- 現行引用 2: "STRUCTURAL TRIAGE (required before detailed tracing):"
- 変更方針: relevant test の取得を assertion-backward tracing 優先へ置換し、changed-symbol 検索は candidate discovery に降格する。支払いとして、STRUCTURAL TRIAGE の「required before detailed tracing」という順序 MUST は外し、triage 自体は残す。

Decision-point delta
Before: IF a test textually references a changed function/class/variable THEN treat it as relevant enough to anchor comparison because syntactic reference is the retrieval trigger.
After:  IF a candidate test has no traced dependency from its assertion/output back to a changed value/exception/branch THEN keep searching from the assertion and do not lock relevance yet because assertion-to-change reachability is the retrieval trigger.

Payment: add MUST("Treat textual reference to a changed symbol as a candidate-discovery signal, not sufficient evidence that the test is relevant.") ↔ demote/remove MUST("STRUCTURAL TRIAGE (required before detailed tracing)")

変更差分プレビュー
Before:
  To identify them: search for tests referencing the changed function, class,
  or variable. If the test suite is not provided, state this as a constraint
  in P[N] and restrict the scope of D1 accordingly.
  STRUCTURAL TRIAGE (required before detailed tracing):
After:
  To identify them: start from the concrete fail-to-pass assertion or expected
  output, then trace backward to the first changed value, exception, or branch
  it depends on; use changed-symbol search only to seed candidate tests.
  Trigger line (planned): "Treat textual reference to a changed symbol as a candidate-discovery signal, not sufficient evidence that the test is relevant."
  STRUCTURAL TRIAGE:

Discriminative probe
- 抽象ケース: 一方の変更は helper 名を直接触るのでその helper を参照するテストが見つかるが、実際に fail/pass を分けるのは別の caller から同じ changed branch に入る間接テストである。
- Before では direct reference の見えるテスト群だけを relevant と見なし、間接テストを掘り切れず偽 EQUIV か過度な保留になりやすい。After では assertion から逆向きに依存を辿るため、その間接テストが relevant と確定し、実際の分岐差に到達して誤判定を避けられる。

failed-approaches.md との照合
- 原則 2 に整合: relevance 未解決を一律に保留へ倒すのではなく、局所的に assertion-backward tracing を追加するだけで fallback を Guardrail 化しない。
- 原則 3 に整合: 新しい抽象ラベルや CLAIM 形式を増やさず、比較前半の情報取得順序だけを変える。

変更規模の宣言
- 変更は Compare 内の局所置換 8-10 行程度。新規モード追加なし、研究コア（番号付き前提・仮説駆動探索・手続き間トレース・必須反証）は不変。