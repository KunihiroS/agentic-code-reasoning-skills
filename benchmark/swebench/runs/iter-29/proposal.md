1) 過去提案との差異: 「特定の観測境界へ条件を狭める／証拠種類を事前固定する」方向ではなく、既存の“差分を見つけた後”の分岐（no-impact判断）に localize/explain 由来の書き方を移植して誤分岐を減らす。
2) Target: 両方（偽 EQUIV と 偽 NOT_EQUIV）
3) Mechanism (抽象): compare で“意味差分を見つけた”瞬間に、その差分をテストの assertion まで局所化して説明できない限り no-impact/impact を断定しない、という分岐行動へ置換する。
4) Non-goal: STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件の狭窄や、探索で集める証拠種類（例: data-flow の特定形）をテンプレで固定することはしない。

---

ステップ 1（禁止方向の列挙: failed-approaches.md + 却下履歴）
- 探索で「次に探すべき証拠種類」をテンプレで事前固定しすぎる（確認バイアス／探索経路の半固定化）。
- 既存の判定基準を「特定の観測境界だけ」に還元して狭める（境界に乗らない有力反例を捨てる）。
- 読解順序・確定境界の“半固定”で探索の自由度を削る（比較での多観点照合が弱る）。
- compare 改善が片方向（EQUIV 側だけ／NOT_EQ 側だけ）に寄り、もう片側の意思決定変更が未具体化のままになる。
- 提案文中に特定の run/iteration を想起させる具体 ID を含める（汎化性ルール違反）。

ステップ 2（SKILL.md から選ぶ decision point: IF/THEN で書ける分岐を 1 つ）
- 選択した分岐: compare checklist の「意味差分を見つけたとき、それがテスト結果に影響しないと結論してよいか（追加探索へ行くか）」
  - 該当箇所（短い引用）:
    - "When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact"

ステップ 3（改善仮説: 1 つ）
- 仮説: compare の誤分岐は“差分を見つけた後”に起きやすく、差分→テスト assertion への連結（impact）または差分の下流での吸収（no-impact）を、fault localization の DIVERGENCE ANALYSIS と同じ粒度で書かせると、偽 NOT_EQUIV（差分の過大評価）と偽 EQUIV（差分の過小評価）を同時に減らせる。

カテゴリ F（原論文未活用アイデアの選択理由）
- docs/design.md にある失敗類型 "Subtle difference dismissal" は compare の中核リスクで、論文由来の localize（= diagnose）テンプレの "DIVERGENCE ANALYSIS" 形式は、この“差分→期待（assertion）”の接続を強制する。
- つまり「localize/explain 手法の compare 応用」を、証拠種類の固定ではなく“差分に遭遇した瞬間の説明の型”として移植できる。

ステップ 4（Before/After の挙動差として落とす: 抽象ケース 1 つ）
- 抽象ケース: 変更 A/B が中間値の表現（例: 例外型／戻り値の形／順序）で異なるが、下流で正規化・上書き・捕捉され、最終 assertion で観測される値は同一（または逆に、例外捕捉の条件が異なり assertion が差分を観測する）。
  - Before だと「差分を見た」→“1本だけ”テスト経路を追って雰囲気で no-impact/impact を断定しがち。
  - After だと「最初の分岐点（earliest divergence）→ assertion の観測点」まで局所化して書けない限り断定を避け、(a) 下流吸収の証拠 or (b) assertion-level の分岐証拠 のどちらかに寄せて意思決定が変わる。

Decision-point delta（IF/THEN 2 行）
Before: IF semantic difference is found THEN conclude "no impact" after tracing one representative test path because path-level trace evidence
After:  IF semantic difference is found THEN produce an assertion-anchored divergence explanation (impact OR downstream neutralization) before concluding "no impact" because divergence-claim evidence tied to observable test checks

変更差分プレビュー（Before/After, 3–10 行）
Before:
- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact
- Provide a counterexample (if different) or justify no counterexample exists (if equivalent)

After:
- "...When a semantic difference is found, localize the earliest A↔B divergence to a specific test assertion (or show downstream neutralization) before concluding 'no impact'..."
- Provide a counterexample (if different) or justify no counterexample exists (if equivalent)

Discriminative probe（2–3 行）
- 変更前: 中間表現の差分を見た時点で NOT_EQUIV へ倒す／逆に“たまたま追った1経路”で no-impact として EQUIV へ倒す誤分岐が起きがち。
- 変更後: divergence を assertion まで接続（または下流吸収を提示）できない場合は断定を避けるため、差分の過大評価・過小評価の両方を減らせる。

failed-approaches.md との照合（整合 1–2 点）
- 証拠種類を事前固定しない: 何を探すか（data-flow/型/例外/順序など）を固定せず、“差分→assertion”という説明粒度だけを規定する。
- 観測境界への過度還元を避ける: 構造差→早期 NOT_EQUIV の境界狭窄は触らず、差分発見後の意思決定（no-impact断定）を局所化手法で改善する。

変更規模の宣言
- SKILL.md の置換 1 行（compare checklist の 1 bullet を差し替え）。ハード上限 5 行以内を満たす。