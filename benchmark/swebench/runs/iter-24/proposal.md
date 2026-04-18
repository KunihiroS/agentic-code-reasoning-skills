過去提案との差異: 「構造差→早期NOT_EQUIV」や特定の証拠型/観測境界への条件狭窄ではなく、必須 Step 5 の“反証対象選定の順序”だけを両方向対称に入れ替える。
Target: 両方（偽 EQUIV と偽 NOT_EQUIV の同時低減）
Mechanism (抽象): 反証チェックを「結論反転(=pivot)一点集中」から「EQUIV 側と NOT_EQUIV 側を交互に圧力テストする順序」へ置換する。
Non-goal: STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件や、証拠種類/観測境界の定義を狭める変更は一切しない。

# 1) 禁止方向（failed-approaches.md と却下履歴からの列挙）
- 次に探す証拠種類をテンプレで事前固定し、探索を「特定シグナル捜索」へ寄せる（確認バイアスを強める）。
- 既存判定基準を特定の観測境界へ還元しすぎる（構造差などを“その境界に写像できたときだけ有効”にする類）。
- 「どこから読むか／どの境界を先に確定するか」を半固定し、探索経路を早期に細らせる。
- 既存の汎用ガードレールを、特定の追跡方向・局所観点へ置換してしまう（反証優先順位の差し替え等）。
- 結論直前の自己監査に新しい必須メタ判断（実質ゲート）を純増させる。

# 2) 未探索の改善余地（SKILL.md から）と今回の選択理由
SKILL.md の Core Method Step 5 には、反証対象の選び方として次が明示されています:

> - Prioritize the claim/assumption whose negation would flip the final answer (EQUIV↔NOT_EQUIV / PASS↔FAIL) when choosing what to refute first.

この「結論反転(=pivot)一点集中」は、表現が強いほど compare で片方向（いま頭にある暫定結論）へ探索が寄り、反対側の反証経路が細るリスクがあります（直近却下理由と同型）。
一方で、ここを “証拠型” や “観測境界” に結びつけず、単に「順序（スケジューリング）」として両方向対称にするのは、failed-approaches.md が禁じる経路の半固定（特定方向・特定証拠型への具体化）とはメカニズムが異なります。

カテゴリA（推論の順序・構造変更）としては、反証の“対象”を固定せずに、反証の“順番”を「片側集中→交互化」へ変更でき、EQUIV/NOT_EQ のどちらかだけを最適化して逆側を悪化させるリスクを下げられます。

# 3) 改善仮説（1つ）
反証対象の選定を「暫定結論の pivot だけに集中」させず、EQUIV と NOT_EQUIV の両仮説を交互に圧力テストする順序にすると、暫定結論への早期コミット（確認バイアス）を減らし、偽 EQUIV と偽 NOT_EQUIV の双方が減る。

# 4) 具体変更（SKILL.md 該当箇所の引用と変更方針）
変更対象: Core Method / Step 5: Refutation check の最初の箇条書き（反証の“最初に何を狙うか”）

現行（短引用）:
- "Prioritize the claim/assumption whose negation would flip the final answer ... when choosing what to refute first."

提案: これを「両方向の交互スケジューリング」に置換（証拠種類や観測境界の指定は追加しない）。

# 5) Decision-point delta（IF/THEN 2行）
Before: IF 暫定結論に到達し、反証対象を選ぶ THEN “否定したら結論が反転する” 1点を最優先で潰す because 結論反転インパクト（pivot）
After:  IF 暫定結論に到達し、反証対象を選ぶ THEN その結論を支える最も依存度の高い主張を潰したら、次は反対結論側の最有力主張も潰す（交互に進める） because 両仮説に対する対称な反証圧（drift抑制）

# 6) 変更差分プレビュー（Before/After, 3–10行）
Before (Step 5 抜粋):
- Prioritize the claim/assumption whose negation would flip the final answer (EQUIV↔NOT_EQUIV / PASS↔FAIL) when choosing what to refute first.
- "No test exercises this difference" — before asserting this, describe what such a test would look like ...

After (Step 5 抜粋):
- When choosing what to refute first, alternate pressure-testing both sides: refute the most load-bearing claim for your current tentative conclusion, then refute the strongest claim for the opposite conclusion.
- "No test exercises this difference" — before asserting this, describe what such a test would look like ...

# 7) failed-approaches.md との照合（整合 1–2点）
- 「証拠種類の事前固定」をしない: 交互化は“順序”のみで、何を証拠として探すか（テスト/オラクル/接続など）をテンプレで固定しない。
- 「特定方向のガードレールへの置換」を避ける: 片方向（pivot優先）への寄せを弱め、むしろ方向非依存（EQUIV/NOT_EQ 両側）にするため、探索経路の半固定化を起こしにくい。

# 8) 変更規模の宣言
SKILL.md 変更は 1 箇条書きの置換のみ（最大 3–4 行相当、5行以内）。必須ステップの純増なし。