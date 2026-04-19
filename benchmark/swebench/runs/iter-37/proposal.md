過去提案との差異: 「証拠源や読解順序を局所的に固定する」のではなく、STRUCTURAL TRIAGE の早期 NOT EQUIVALENT を既存の counterexample 証拠枠へ接続して“結論根拠の型”だけを揃える。
Target: 偽 NOT_EQUIV（副次的に偽 EQUIV も抑制）
Mechanism (抽象): 「構造差」から直接結論へ飛ぶ比較をやめ、構造差を“テスト影響の根拠型（witness）”で分類してから結論へ進める。
Non-goal: 構造差の検出基準を特定の観測境界（テスト依存・オラクル可視など）へ還元して探索経路を半固定化しない。

ステップ 1（禁止方向の列挙）
- 禁止: 探索で追うべき証拠タイプをテンプレで事前固定しすぎる（確認バイアス・探索入口の狭窄）。
- 禁止: 既存判定基準を「特定の観測境界だけ」に過度に還元して狭める（境界に乗らない決定的シグナルを捨てやすい）。
- 禁止: 読解順序・探索経路の半固定（どこから読み始めるか／どの境界を先に確定するかの固定）。
- 禁止: 結論直前の新しい必須メタ判断の純増（萎縮・形式適応・既存チェックと重複）。
- 直近却下との注意点: EQUIV 側だけ／NOT_EQ 側だけに効く片方向最適化、または focus_domain の偏りで逆方向を悪化させる提案は不可。

ステップ 2（SKILL.md から decision point 候補を 3 つ）
候補 A: STRUCTURAL TRIAGE の早期終了
- IF: S1/S2 で structural gap を見つけた
- THEN: ANALYSIS を省略して NOT EQUIVALENT 結論へ進む

候補 B: 「関連テスト」が不明/未提示な場合の D1 スコープ調整
- IF: テストスイートが不明で D1 をそのまま適用できない
- THEN: D1 のスコープを制限して比較結論（EQUIV/NOT_EQ/不確実性の明示）へ進む

候補 C: UNVERIFIED が結論へ影響しうる場合の扱い
- IF: 重要関数が UNVERIFIED で、その仮定がテスト outcome を変えうる
- THEN: その仮定を含む強い結論（EQUIV/NOT_EQ）を避けるか、追加探索（副証拠）へ倒す

ステップ 2.5（各候補のデフォルト挙動と、観測可能に変わるアウトカム）
- 候補 A: デフォルトは「ファイル差＝即 NOT_EQUIV」に倒れやすい（ANALYSIS/COUNTEREXAMPLE を迂回）→ 変更後は NOT_EQUIV/追加探索 の分岐が変わる。
- 候補 B: デフォルトは「テスト不明でも形式上 compare を完走し、スコープ制限が曖昧」になりやすい → 変更後は UNVERIFIED/保留/CONFIDENCE が変わる。
- 候補 C: デフォルトは「UNVERIFIED を但し書きしつつ結論へ進む」か「過度な保留」に振れやすい → 変更後は EQUIV/保留/CONFIDENCE が変わる。

ステップ 3（1 つ選ぶ）
選択: 候補 A（STRUCTURAL TRIAGE の早期終了）
選定理由（2 点以内）:
- compare の最終アウトカム（NOT_EQUIV 早期確定 vs 追加探索）が直接変わり、停滞の主因になりやすい「早期断定」を制御できる。
- 現行テンプレート内に「NOT_EQ なら counterexample が必要」という根拠型が既にあるのに、早期終了がそれをバイパスできており、比較枠組みの不整合が起きている。

ステップ 4（改善仮説: 1 つ）
仮説: 「構造差は差異検出には有効だが、それ単体を結論根拠にすると偽 NOT_EQUIV を生む」。STRUCTURAL TRIAGE は“結論”ではなく“差異の分類”として扱い、NOT_EQUIV 結論へ進むときは常にテスト影響の witness（具体的な失敗/差分を生む観測点）で根拠型を揃えると、両方向（EQUIV/NOT_EQ）の判定品質が上がる。

ステップ 5（抽象ケースで Before/After の挙動差）
抽象ケース: 変更 A は「周辺の補助ファイル」も触るが、変更 B は触らない。ただし relevant tests はその補助ファイルに到達せず、期待される PASS/FAIL は両者で同一。
- Before（起きがち）: IF “A だけが触るファイルがある” THEN NOT EQUIVALENT（STRUCTURAL TRIAGE の早期終了）→ 偽 NOT_EQUIV。
- After（避ける）: IF “A だけが触るファイルがある” THEN まず「それが relevant tests に影響する witness があるか」を最小限で示す（例: そのファイルを import/call するテスト、または diverging assertion）; witness が示せないなら早期 NOT_EQ はせず ANALYSIS へ進む → 最終的に EQUIVALENT へ到達（または根拠不足なら不確実性を明示）。

カテゴリ C 内での具体的メカニズム選択理由
- これは探索経路や証拠種類を固定する変更ではなく、「比較の粒度／差異重要度」の扱いを変える提案。
- “構造差＝重要”を一段階の判断にせず、「差異は検出」「重要度は witness で分類」という二段階にすることで、比較枠組み（差異→結論の写像）を改善する。

SKILL.md 該当箇所（自己引用）と変更
引用:
- "If S1 or S2 reveals a clear structural gap ... you may proceed directly to FORMAL CONCLUSION with NOT EQUIVALENT without completing the full ANALYSIS section."
- "COUNTEREXAMPLE (required if claiming NOT EQUIVALENT): ... Diverging assertion: [test_file:line — the specific assert/check that produces a different result]"

変更方針:
- STRUCTURAL TRIAGE の早期終了を「ANALYSIS は省略可」までに留め、NOT EQUIVALENT 結論へ進む場合は counterexample witness（diverging assertion など）を必ず提示する、という比較枠組みに揃える。

Decision-point delta（IF/THEN を 2 行）
Before: IF S1/S2 で structural gap を見つけた THEN ANALYSIS を飛ばして NOT EQUIVALENT に進む because 構造差そのものを結論根拠として許している。
After:  IF S1/S2 で structural gap を見つけた THEN ANALYSIS は省略してよいが、NOT EQUIVALENT に進むなら counterexample witness（diverging assertion 等）を提示し、提示できない場合は ANALYSIS に戻る because NOT_EQ の根拠型を「テスト影響の観測点」に揃える。

変更差分プレビュー（Before/After、Trigger line planned を 1 行含む）
Before:
  If S1 or S2 reveals a clear structural gap ... you may proceed directly to FORMAL CONCLUSION
  with NOT EQUIVALENT without completing the full ANALYSIS section.
After:
  If S1 or S2 reveals a clear structural gap ... you may skip the full ANALYSIS section,
  but only conclude NOT EQUIVALENT after stating a concrete counterexample witness.
  Trigger line (planned): "If you conclude NOT EQUIVALENT from STRUCTURAL TRIAGE, cite a counterexample witness (e.g., a diverging assertion) rather than file-list difference alone."

Discriminative probe（抽象ケース）
- Before: 片側だけが触るファイルがある、という理由だけで NOT_EQ 早期確定 → 実際は relevant tests に影響せず、偽 NOT_EQ が発生しやすい。
- After: 同じ状況でも witness を要求するため、影響が示せない structural gap は「追加探索（ANALYSIS）」へ押し戻され、最終結論が EQUIV（または不確実性明示）に分岐しうる。

failed-approaches.md との照合（整合点）
- 「証拠種類の事前固定」や「読解順序の半固定」を導入しない（witness は“型”であり、どこから読むかを固定しない）。
- 「特定の観測境界への過度な還元」を避けつつ、NOT_EQ 結論の根拠を具体化して偽 NOT_EQ を減らす（境界の固定ではなく、結論根拠の明示）。

変更規模の宣言
- 変更は Compare セクションの STRUCTURAL TRIAGE 早期終了説明に対する置換/追記のみ。差分は五行以内。