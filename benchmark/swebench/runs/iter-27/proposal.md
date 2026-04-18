1) 過去提案との差異: 直近却下の「観測境界の固定／compare の片方向最適化／探索経路の半固定」ではなく、既存の必須自己チェック内で“反対側の最有力シナリオ”を明示して両方向対称にバイアス検査する。
2) Target: 両方（偽 EQUIV と 偽 NOT_EQUIV を同時に下げる）
3) Mechanism (抽象): 反証 (Step 5) の対象選びを「自分の結論の否定」から一段具体化し、“最ももっともらしい反対ケース→その観測痕跡”へ置換して検索・点検の焦点を安定化する。
4) Non-goal: STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を狭めたり、特定の観測境界（テスト可視・オラクル等）に還元する変更は行わない。

---

カテゴリ D（メタ認知・自己チェック）内でのメカニズム選択理由
- 既存 SKILL.md は Step 5（反証）と Step 5.5（自己チェック）が必須だが、反証の“問い”が抽象的なままだと「都合のよい反証（弱い反例像）を立てて満足する」形の確認バイアスが残りやすい。
- そこで、証拠種類や探索経路を事前固定せずに、反証の“対象の選び方”だけを強化する：最有力の反対ケースを 1 行で書き、そのケースが真なら見えるはずの痕跡をそのまま検索対象に落とす。これなら EQUIV/NOT_EQUIV のどちらにも同じ型で効く（片方向寄りになりにくい）。

改善仮説（1つ）
- 反証チェックで「最ももっともらしい反対ケース」を先に明文化すると、探索が“反対側に都合のよい観測痕跡”へ向くため、偽 EQUIV（反例の見落とし）と偽 NOT_EQUIV（差分の過大評価）の両方が減る。

SKILL.md 該当箇所（短い引用）と変更
- Step 5 テンプレート（compare/audit-improve）
  現状: 「If my conclusion were false, what evidence should exist?」
  変更: 反対ケースを 1 行で明示し、その“期待される痕跡”を検索対象に直結させる。
- Step 5 テンプレート（explain/diagnose）
  現状: 「If the opposite answer were true, what evidence would exist?」
  変更: 同様に“最有力の反対答え”と“期待痕跡”を 1 行化する。
- Step 5.5 checklist（必須項目数は維持）
  既存の「file:line に結びつく」+「証拠以上を主張しない」を 1 行に統合し、空いた 1 行を「反対側の最有力ケースを言えているか」に差し替える。

Decision-point delta（IF/THEN 2行）
Before: IF Step 5 で反証を行う THEN 「結論が偽なら必要な証拠」を一般形で問う because counterfactual placeholder
After:  IF Step 5 で反証を行う THEN 「最有力の反対ケース→期待痕跡」を 1 行で特定し、その痕跡を検索・点検する because adversarial self-check

変更差分プレビュー（Before/After, 3–10行）
Before:
- If my conclusion were false, what evidence should exist?
After:
- OPPOSITE-CASE → EXPECTED EVIDENCE: [most plausible way the conclusion is false] → [what should be observable]

Before:
- If the opposite answer were true, what evidence would exist?
After:
- OPPOSITE-CASE → EXPECTED EVIDENCE: [most plausible opposite answer] → [what should be observable]

Before:
- [ ] Every PASS/FAIL or EQUIVALENT/NOT_EQUIVALENT claim traces to a specific `file:line` — not inferred from function names.
- [ ] The conclusion I am about to write asserts nothing beyond what the traced evidence supports.
After:
- [ ] Every key claim is tied to specific `file:line`, and I assert nothing beyond what that traced evidence supports.
- [ ] I can state the strongest plausible case for the opposite verdict/answer and why the recorded evidence rules it out.

failed-approaches.md との照合（整合 1–2点）
- 「証拠種類の事前固定を避ける」(failed-approaches.md の趣旨) に整合: 本変更は“どの証拠を必ず集めるか”を固定せず、反対ケースから導かれる痕跡をその場で選ぶだけ。
- 「観測境界への過度な還元を避ける」(同) に整合: テスト／オラクル等の特定境界に条件を狭めず、反対ケースに応じた任意の観測痕跡へ開いたままにする。

変更規模の宣言
- SKILL.md 変更は最大 4 行の置換（必須ゲートの純増なし：Step 5.5 のチェック項目数を維持し、2項目を統合して1項目を差し替える）。
