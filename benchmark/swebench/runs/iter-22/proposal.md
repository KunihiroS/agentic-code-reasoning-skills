過去提案との差異: Step 5 の「pivot/flip 優先」を強めず、むしろ Step 2 と Step 5 の“優先規則の競合”を解消するための表現・決定規則の整理である。
Target: 両方（偽 EQUIV と 偽 NOT_EQUIV を同時に下げる）
Mechanism (抽象): 反証対象の選び方を「結論反転（flip）」単独から「最弱依存（ASM/UNVERIFIED）」中心へ言い換え、flip はタイブレークに格下げして探索の細りを避ける。
Non-goal: 構造差→NOT_EQUIV の早期条件や観測境界の制限（テスト依存・オラクル可視等）には一切触れない。

本文

1) カテゴリ E（表現・フォーマット）内での具体的メカニズム選択理由
- 現状 SKILL.md には「反証対象の優先規則」が 2 箇所に分散し、かつ方向が異なる。
  - Step 2: ASM 依存を最優先に反証（依存の弱さ基準）
  - Step 5: 結論を flip する主張を最優先（結論反転基準）
- この競合は、compare / diagnose / explain / audit-improve の全モードで「どれを最初に疑うべきか」の判断を不安定にしやすく、結果として (a) 早い段階で一方向（flip）に寄り、(b) 反証経路が細る、という回帰リスクを持つ。
- そこで、表現だけで“単一の整合した選択規則”に圧縮し、認知負荷と探索ドリフトを同時に下げる（新しいゲートは増やさない）。

2) 改善仮説（1つ）
反証対象の選定基準を「結論反転のしやすさ」から「推論チェーンの最弱依存（ASM/UNVERIFIED/未読定義）」へ寄せ、flip は同順位の候補が複数ある場合のタイブレークに落とすと、EQUIV/NOT_EQ の両方向で“見落としやすい脆い前提”に先に当たりやすくなり、片方向最適化による逆側の悪化を避けつつ全体精度が上がる。

3) SKILL.md 該当箇所の短い引用と、どう変えるか
引用（現状）:
- Step 2:
  "If a claim depends on ASM, treat that ASM as the highest-priority refutation target."
- Step 5:
  "Prioritize the claim/assumption whose negation would flip the final answer ... when choosing what to refute first."

変更方針:
- “highest-priority” と “flip first” の二重ルールを、1つの短いルールに統合。
- flip を「常に最優先」から「最弱依存が同点で並ぶときのタイブレーク」へ表現上で格下げ。
- これにより、特定の証拠種類の事前固定や観測境界への還元をせずに、反証対象の選び方だけを安定化する。

4) Decision-point delta（IF/THEN 2行）
Before: IF 反証候補が複数ある THEN 「否定すると結論が flip する主張」を先に反証する because 結論反転（decision-impact）型
After:  IF 反証候補が複数ある THEN 「最弱依存（ASM/UNVERIFIED/未読定義）に支えられた主張」を先に反証する（flip は同点時のタイブレーク） because 依存強度（support-strength）型

5) 変更差分プレビュー（Before/After, 3–10行）
Before:
- If a claim depends on ASM, treat that ASM as the highest-priority refutation target.
- Prioritize the claim/assumption whose negation would flip the final answer (EQUIV↔NOT_EQUIV / PASS↔FAIL) when choosing what to refute first.

After:
- If a key claim depends on ASM/UNVERIFIED, prefer refuting that weakest dependency first; use “would flip the final answer” only as a tie-breaker.
- When choosing what to refute first, optimize for weakest support (ASM/UNVERIFIED/definition not yet read), not just flip-impact.

6) failed-approaches.md との照合（整合 1–2点）
- 「探索で探すべき証拠の種類をテンプレートで事前固定しすぎる変更は避ける」に整合: ASM/UNVERIFIED という“依存の弱さ”を指すだけで、探す証拠種類・観測境界・検索パターンを固定しない。
- 「探索の自由度を削りすぎない」「読解順序の半固定を避ける」に整合: “flip 一本槍の優先”を弱め、反証経路が一方向へ細るリスクを下げる（順序固定の新規導入ではなく、競合する優先規則の整理）。

7) 変更規模の宣言
- SKILL.md の置換は最大 2 行（合計 5 行以内の hard limit を満たす）。新しい必須ゲートの純増はなし（既存 Step 5 の必須性は変更しない）。
