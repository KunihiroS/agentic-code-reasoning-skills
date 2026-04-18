1) 過去提案との差異: STRUCTURAL TRIAGE や観測境界へ判定条件を還元する方向ではなく、全モード共通の Step 5（反証）の“対象選び”を文章フォーマットで明確化する提案。
2) Target: 両方（偽 EQUIV / 偽 NOT_EQUIV を同時に下げる）
3) Mechanism (抽象): 反証セクションに「結論を左右する hinge claim（支点となる主張）を先に特定して反証する」という優先順位づけを 1 行で埋め込み、反証の打ちどころを安定化する。
4) Non-goal: compare の STRUCTURAL TRIAGE / 早期 NOT_EQUIV 条件、ならびに特定の観測境界（テスト可視性・検証接続など）への制限は一切いじらない。

カテゴリ E 内での具体的メカニズム選択理由
- 今回の強制カテゴリは「表現・フォーマット改善」。Step 5 は“必須”である一方、現状は「どの主張を反証の中心に置くべきか」が明示されておらず、(a) 重要でない主張へ反証努力が分散する、または (b) 重要主張の反証が抜け落ちる、の両方向が起きうる。
- 反証の“やり方”を増やす（新しい探索テンプレ・証拠種の固定）ではなく、反証の“対象（主張）選定”を 1 行の優先ルールとして埋め込むのは、探索自由度を削らずに認知負荷だけを下げる（R5 に直結）ため、カテゴリ E と整合する。

改善仮説（1つ）
- 反証対象を「最終結論を反転させる hinge claim」に寄せる最小のフォーマット誘導を入れると、反証が（結論に効かない周辺主張ではなく）判定の支点に集中し、偽 EQUIV と偽 NOT_EQUIV の両方が下がる。

SKILL.md 該当箇所（短い引用）と変更方針
- 現行（Core Method / Step 5）:
  - “**Scope**: Apply counterfactual reasoning ... at every key intermediate claim — especially:”
  - その後に 3 つの代表例（"No test exercises...", "This behavior is X...", "These test outcomes are..."）が列挙されている。
- 変更: 上の列挙を、1–2 個の hinge claim を先に特定して反証する、という優先順位づけの 1 行に置換する（例示の固定ではなく、反証対象の選び方の明確化）。

Decision-point delta（IF/THEN 2行）
Before: IF 重要な中間主張を置く（特に「テストが無い」「振る舞いが X」「結果が同一/相違」等）THEN その主張ごとに反証を試みる because 代表的な落とし穴を網羅するため。
After:  IF 複数の中間主張があり反証の焦点が分散しそう THEN 結論を反転させうる hinge claim を 1–2 個選び（C# として明示）、それを先に反証する because 反証努力を判定の支点に集中させ、見落としと空回りを同時に減らすため。

変更差分プレビュー（Before/After、3–10行）
Before:
- **Scope**: Apply counterfactual reasoning not only at the final conclusion, but at every key intermediate claim — especially:
- - "No test exercises this difference" — before asserting this, describe what such a test would look like and show you searched for exactly that pattern.
- - "This behavior is X" for a non-trivial control flow — before asserting this, ask what evidence would exist if the behavior were not X.
- - "These test outcomes are identical/different" — before asserting this, state what evidence would refute it.

After:
- **Scope**: Apply counterfactual reasoning not only at the final conclusion, but at every key intermediate claim; when there are many, pick 1–2 hinge claims that would flip the verdict if false (label them C#) and refute those first.

failed-approaches.md との照合（整合点 1–2 点）
- 「次の探索で探すべき証拠の種類をテンプレで事前固定しすぎる変更は避ける」: 本提案は“証拠種”を固定せず、反証対象（主張）の優先順位だけを 1 行で明確化するため、探索の自由度を削らない。
- 「判定基準を特定の観測境界だけに過度に還元しすぎない」: 構造差/テスト可視性/検証接続などの境界条件へ判定を還元せず、全モード共通の反証記述の焦点化のみを行う。

変更規模の宣言
- SKILL.md の Step 5 の箇条書き 4 行（Scope 1行 + 例示3行）を、同じ位置の Scope 1 行に置換するのみ（変更規模: 4 行以内、hard limit 5 行以内）。
