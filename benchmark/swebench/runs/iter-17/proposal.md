1) 過去提案との差異: 早期 NOT_EQUIV の条件を観測境界へ狭める/新トリガを足すのではなく、反証(Step 5)で「何を反証対象に選ぶか」を論文の divergence analysis 発想で変える。
2) Target: 両方（偽 EQUIV と 偽 NOT_EQUIV）
3) Mechanism (抽象): compare の反証対象を「結論を反転させる主張」から「A/B の最小の振る舞い分岐（divergence candidate）」優先へ切り替える。
4) Non-goal: STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件や観測境界の定義（VERIFIED/UNVERIFIED 等）を新たに制限・ゲート化しない。

本文

カテゴリ F 内での具体的メカニズム選択理由
- docs/design.md が示す通り、原論文は compare とは別タスク（fault localization）で「DIVERGENCE ANALYSIS → RANKED PREDICTIONS」を中核機構としている。SKILL.md には diagnose にこの機構が入っている一方、compare の Step 5（反証）では“反証対象の選び方”が一般形（結論反転レバレッジ）に留まり、論文由来の「分岐点を局在化してから検証する」利点が compare に移植されていない。
- 論文のエラー分析（subtle difference dismissal / incomplete chains）に対し、差分を見つけても「影響なし」と早く丸めてしまう失敗は compare で偽 EQUIV を生みやすい。一方で、差分の“場所”だけで NOT_EQUIV を言い切ると偽 NOT_EQUIV も起こる。よって「最小の分岐（どの入力・どの assert で分かれるか）」に反証対象を寄せるのが両方向に効く。

改善仮説（1つ）
- compare の Step 5 で、反証対象を「最終結論を反転させる主張」ではなく「A/B の最小の振る舞い分岐候補（divergence candidate）を 1–3 個に局在化し、上位から潰す」へ変えると、(a) 見つけた差分の影響を過小評価する偽 EQUIV を減らし、同時に (b) 反例（分岐する assert/入力）を示せない差分での早期 NOT_EQUIV を抑制できる。

SKILL.md 該当箇所（短い引用）と変更
引用（現状）:
- Step 5: "Prioritize the claim/assumption whose negation would flip the final answer (EQUIV↔NOT_EQUIV / PASS↔FAIL) when choosing what to refute first."
変更方針:
- compare に限り、反証の優先順位付けを diagnose の「DIVERGENCE ANALYSIS / RANKED PREDICTIONS」発想へ寄せ、A/B の“最小の分岐点”を反証対象の単位にする（新しい必須ゲートは増やさず、既存の優先順位付け文を差し替える）。

Decision-point delta（IF/THEN 2行）
Before: IF Step 5 で最初に反証する対象を選ぶ THEN 「否定すると結論が反転する主張」を優先する because leverage（結論反転の影響が最大）。
After:  IF `compare` で Step 5 の反証対象を選ぶ THEN 「A/B の最小の振る舞い分岐候補（divergence candidate）を 1–3 個に局在化し、上位を先に反証する」を優先する because discriminative（差分の影響を“分岐する assert/入力”に結びつけ、過小評価/過大評価の両方を減らす）。

変更差分プレビュー（Before/After, 3–10行）
Before:
- Prioritize the claim/assumption whose negation would flip the final answer (EQUIV↔NOT_EQUIV / PASS↔FAIL) when choosing what to refute first.

After:
- In `compare`, prioritize refuting the top-ranked divergence candidate first (a minimal A↔B behavioral branch on a relevant call path; list 1–3 candidates).
- Otherwise, prioritize the claim/assumption whose negation would flip the final answer (EQUIV↔NOT_EQUIV / PASS↔FAIL) when choosing what to refute first.

failed-approaches.md との照合（整合 1–2点）
- 「特定の観測境界（VERIFIED/UNVERIFIED, test-oracle 可視性 等）に判定基準を還元」して早期 NOT_EQUIV 条件を狭めない（禁止方向の回避）。
- 証拠種類をテンプレで事前固定するのではなく、既存 Step 5 の“優先順位付け”だけを、論文由来の方向非依存な分岐局在化へ差し替えるため、探索自由度を削りすぎにくい。

変更規模の宣言
- SKILL.md 変更は 2–3 行の置換/追記で完結（hard limit 5 行以内）。新しい必須ゲート（MUST/required の純増）は行わない。