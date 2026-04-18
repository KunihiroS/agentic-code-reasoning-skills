過去提案との差異: 早期 NOT_EQUIV 条件や証拠種類の固定ではなく、compare 内の「反例スケッチの置き場所」を順序変更してアンカリングを弱める。
Target: 両方（偽 EQUIV と偽 NOT_EQUIV の同時低減）
Mechanism (抽象): 反例の形を先に決めず、まず構造スコープ（何が比較対象か）を確定してから反例候補を生成する順序にする。
Non-goal: STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件（S2→直行）の制限・細分化はしない。

Step 1（禁止方向の列挙; failed-approaches.md + 却下履歴より）
- 探索で探すべき「証拠種類」をテンプレで事前固定する（確認バイアス・探索経路固定）
- 判定基準を「特定の観測境界」に過度還元して狭める（構造差→NOT_EQUIV を特定境界に写像できた時だけ有効、等）
- 読解順序・追跡方向の半固定（入口を狭めて反証/代替経路を落とす）
- 反証優先順位を局所観点に差し替える（highest-tier-first / pivot-claims 優先などで経路が細る）
- 結論直前の必須メタ判断の純増（ゲート増で萎縮・複雑化）

Step 2（SKILL.md で未探索の改善余地の発見）
- compare 証明書テンプレ冒頭に「first sketch the minimal counterexample shape」があり、探索の入口で“暫定的な反例像”を先置きしやすい。
- failed-approaches.md は「暫定的な反例像や結論形式を冒頭で先に置かせる変更も同類で、探索の入口を狭めやすい」（探索経路の半固定）と明示している。
- ここは “反証のやり方” ではなく “反証対象（どの反例候補を考えるか）” の選び方に直結するが、証拠種類や観測境界を固定しないまま改善できる余地がある。

Step 3（今回の仮説; 1つだけ）
改善仮説: compare の冒頭で反例形状を先に描かせるアンカーを外し、まず STRUCTURAL TRIAGE と最小前提でスコープを固めてから反例候補を生成させると、(a) 早期に不適切な反例像へ探索が寄る偽 NOT_EQUIV と、(b) 反例像の不備により差分を過小評価する偽 EQUIV を同時に減らせる。

カテゴリ A（推論の順序・構造変更）としての選択理由
- 変更点は「何を見るか（証拠種類）」でも「どの境界だけを許すか」でもなく、同一要素（反例生成）をどのタイミングで行うかという“順序”のみ。
- 既存コア（番号付き前提→仮説駆動探索→トレース→必須反証）は維持しつつ、探索の入口のアンカリングを弱めて自由度を保つ。

SKILL.md 該当箇所（短い引用）
- Compare / Certificate template 冒頭:
  "Complete every section; first sketch the minimal counterexample shape (reverse from D1), then use ANALYSIS to try to produce/refute it."
- 直後に:
  "STRUCTURAL TRIAGE (required before detailed tracing):"

Decision-point delta（IF/THEN 2行; 条件/行動が変わる）
Before: IF entering `compare` certificate THEN sketch a minimal counterexample shape first because reverse-from-definition grounding.
After:  IF entering `compare` certificate THEN run DEFINITIONS + STRUCTURAL TRIAGE first, THEN sketch counterexample shape using triage-scoped targets because de-anchoring to preserve exploration breadth.

変更差分プレビュー（Trigger line を含む; 3–10行）
Before:
- Complete every section; first sketch the minimal counterexample shape (reverse from D1), then use ANALYSIS to try to produce/refute it.
-
- DEFINITIONS:
- D1: Two changes are EQUIVALENT MODULO TESTS iff ...
-
After:
- Complete every section; start with DEFINITIONS + STRUCTURAL TRIAGE to scope what must be compared, then sketch the minimal counterexample shape (reverse from D1) using what triage reveals.
-
- DEFINITIONS:
- D1: Two changes are EQUIVALENT MODULO TESTS iff ...
-

failed-approaches.md との照合（整合ポイント）
- 「暫定的な反例像を冒頭で先に置かせる」こと自体が探索経路の半固定になりうる、という警告に整合: 反例像を“後置”して入口の狭窄を避ける。
- 証拠種類の事前固定や観測境界への過度還元を行わない: 反例の“内容”をテンプレ固定せず、順序だけを変える。

変更規模の宣言
- SKILL.md 変更は 1–2行の置換（hard limit 5行以内）。必須ゲートの純増なし（MUST/required の追加なし）。
