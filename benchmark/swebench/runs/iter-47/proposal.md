過去提案との差異: 構造差を特定の観測境界へ写像して早期 NOT_EQUIV 条件を狭めるのではなく、原論文の localize/explain 由来の「最初の発散事実を次の消費点まで追う」分岐へ置換して、局所差分からの premature closure を減らす。
Target: 両方
Mechanism (抽象): semantic difference 発見時の次アクションを「関連テスト全体を通す」から「発散した state/value/control fact の次の consumer を確認してから SAME/DIFFERENT に進む」へ変える。
Non-goal: STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を assertion boundary / oracle visibility / test-dependency などの固定境界へ狭めない。

カテゴリ F 内での具体的メカニズム選択理由:
- docs/design.md は原論文の Fault Localization を「Code Path Tracing → Divergence Analysis → Ranked Predictions」、Code QA を「Function trace table with VERIFIED behavior, data flow tracking」と整理している。Compare には per-test trace はあるが、「発散した事実そのものを data/control consumer へ渡す」明示分岐が弱い。
- failed-approaches.md の禁止は、差分を抽象ラベルや単一アンカーへ固定すること、または未確定性を保留既定へ倒すこと。今回の変更はラベル分類や保留ではなく、既に見つけた発散事実を次の実使用点で検査して verdict の材料にする。

Step 1 — 禁止された方向の列挙:
- 再収束を比較規則として前景化し、途中差分を弱める方向。
- relevance 未確定や弱い仮定を常に保留/UNVERIFIED 側へ倒す方向。
- 差分の昇格条件を新しい抽象ラベル、特定 premise/assertion、観測可能性分類で強くゲートする方向。
- 終盤の証拠十分性チェックを confidence 調整へ吸収し、早期 closure を増やす方向。
- 最初の差分から単一の共有テスト・単一アンカーへ探索経路を固定する方向。
- 直近却下履歴の「STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を特定の観測境界だけへ写像して狭める」方向。

Step 2 / 2.5 — overall に効く意思決定ポイント候補:
1. Compare checklist の semantic difference 発見時分岐。
   現在のデフォルト挙動: 差分を見つけたら「関連テストを通す」か、逆に局所差分だけで影響なし/ありを早く言いがち。
   変更後の観測可能アウトカム: 追加探索の単位が発散事実の次 consumer になり、偽 EQUIV と偽 NOT_EQUIV の両方で CONFIDENCE/ANSWER が変わりうる。
2. Step 5.5 の UNVERIFIED 扱い。
   現在のデフォルト挙動: UNVERIFIED が結論を変えないと書ければ進むが、何が verdict-critical か曖昧なまま confidence へ吸収しがち。
   変更後の観測可能アウトカム: UNVERIFIED 明示または結論保留が変わりうるが、failed-approaches 原則 2/4 に近づくリスクがある。
3. NO COUNTEREXAMPLE EXISTS の検索パターン分岐。
   現在のデフォルト挙動: EQUIV 主張時に反例検索を行うが、検索対象が test name / code path / input type に広く、最初の差分からの検索単位がぶれやすい。
   変更後の観測可能アウトカム: 追加探索と EQUIV confidence が変わりうるが、既存 iter-46 の有効変更と重複しやすい。

Step 3 — 選択する分岐:
候補 1 を選ぶ。
- Compare の中で ANSWER 直前に効く分岐であり、semantic difference を見た後に「結論へ進む / 追加探索する / SAME とみなす / DIFFERENT とみなす」の実行時アウトカムが変わる。
- IF 条件は同じ semantic difference 発見時だが、THEN 行動を「関連テストを通す」から「発散した事実の次 consumer を確認する」に変えるため、理由の言い換えではない。

改善仮説:
Compare で semantic difference を見つけた直後、差分の存在やテスト全体の粗い pass/fail ではなく、発散した state/value/control fact が次に消費される地点を確認してから verdict に進ませると、局所差分の過大評価による偽 NOT_EQUIV と、途中差分の見落としによる偽 EQUIV を同時に減らせる。

SKILL.md の該当箇所と変更案:
引用: 「When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact」
変更: この checklist bullet を、localize の Divergence Analysis と explain の data-flow tracking を compare 向けに圧縮した bullet へ置換する。
Payment: add MUST("When a semantic difference is found, name the divergent state/value/control fact and trace it to its next consumer before deciding SAME/DIFFERENT") ↔ demote/remove MUST("When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact")

Decision-point delta:
Before: IF a semantic difference is found THEN trace at least one relevant test through the differing path before concluding no impact because the evidence type is a broad relevant-test path.
After:  IF a semantic difference is found THEN name the divergent state/value/control fact and trace it to its next consumer before deciding SAME/DIFFERENT because the evidence type is the actual consumed divergence.

変更差分プレビュー:
Before:
- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact

After:
- Trigger line (planned): "When a semantic difference is found, name the divergent state/value/control fact and trace it to its next consumer before deciding SAME/DIFFERENT."
- If the consumer masks the fact, treat the difference as non-diverging for that path; if it consumes the changed fact into an assertion/output/error branch, use that as the counterexample candidate.

Discriminative probe:
抽象ケース: Change A and B both reach the same test, but one changes an intermediate normalized value; downstream code may either mask it with a default or feed it into an assertion/output branch.
Before は「関連テストを通した」とだけ記録して、局所差分を過大評価して偽 NOT_EQUIV、または pass/fail の粗い一致で偽 EQUIV が起きがち。
After は差分 fact の next consumer を見るため、mask されれば NOT_EQUIV に進まず、assertion/output/error に消費されれば EQUIV に進まない。これは新規必須ゲート純増ではなく既存 checklist bullet の置換である。

failed-approaches.md との照合:
- 原則 3/5 に対して: 新しい抽象ラベルや単一アンカーへ固定しない。state/value/control fact は分類ゲートではなく、既に観測した差分を次の使用点へ運ぶための最小表現である。
- 原則 1/2/4 に対して: 再収束を既定化せず、未確定性を保留既定にも confidence 吸収にも倒さない。consumer が差分を mask するか消費するかという追加証拠で ANSWER/CONFIDENCE を変える。

変更規模の宣言:
SKILL.md では Compare checklist の 1 bullet を 2 bullet 相当へ置換するだけで、差分は 2〜3 行予定、hard limit 15 行以内。研究コアである番号付き前提、仮説駆動探索、手続き間トレース、必須反証は維持する。
