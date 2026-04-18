1) 過去提案との差異: 早期 NOT_EQUIV 条件の「観測境界への還元」や探索経路の半固定ではなく、差異の“重要度クラス”で比較の粒度と優先順位を変える提案。
2) Target: 両方（偽 EQUIV と偽 NOT_EQUIV を同時に下げ、片方向最適化を避ける）
3) Mechanism (抽象): 差分を「影響ティア（契約/データ/内部）」に分類し、そのティアを反証対象選択（Step 5 の最初の当たりどころ）に使う。
4) Non-goal: STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を特定の観測境界へ狭めたり、証拠種類や探索順序を事前固定することはしない。

---

カテゴリ C 内での具体的メカニズム選択理由
- Objective.md のカテゴリ C は「差異の重要度を段階的に評価する」「変更のカテゴリ分類を先に行う」を含む。
- 既存 compare は (a) 構造差の検出、(b) テスト単位の行動トレース、(c) 反証（Step 5）という枠はあるが、「差異をどういう種類として扱い、どれを先に疑うか」の比較枠（importance / change taxonomy）が明示されていない。
- その結果、(i) 内部差分を過大評価して偽 NOT_EQUIV、(ii) 契約差分を過小評価して偽 EQUIV、の両方が起きうる。ここを“方向非依存”に整えるのがカテゴリ C と今回フォーカス（overall/equiv/not_eq）に合う。

改善仮説（1つ）
- 差分を「CONTRACT / DATA-STATE / INTERNAL」の3ティアで最小限に分類し、反証の最初の対象を最高ティア差分に寄せると、
  - 偽 EQUIV: 契約・データ差分の見落とし（“内部っぽい”と誤判定）を減らす
  - 偽 NOT_EQUIV: 内部差分を“即ち挙動差”として扱う過反応を減らす
  という両方向の誤りが同時に減る。

SKILL.md 該当箇所（短い引用）と変更案
- 現状の compare テンプレートは、テストごとの Claim と比較に入った後、次に「EDGE CASES RELEVANT TO EXISTING TESTS」へ進む:
  - "EDGE CASES RELEVANT TO EXISTING TESTS:"
  - "(Only analyze edge cases that the ACTUAL tests exercise)"
- ここに 2 行だけ追加し、edge case に入る前に「差分のティア分類→観測可能性の言語化」を挟む（重要度評価を明示）。

Decision-point delta (IF/THEN 2行)
Before: IF Step 5 の反証を開始する THEN "key intermediate claim" を任意順（見つけた順・目立つ順）で当てに行く because 反証対象の選択規則が明示されていない
After:  IF Step 5 の反証を開始する THEN DELTA LEDGER の最高ティア差分から当てに行く because 差異重要度（CONTRACT/DATA/INTERNAL）はテスト観測へ写像されやすい根拠型だから

変更差分プレビュー（Before/After 3–10行）
Before:
  For pass-to-pass tests (if changes could affect them differently):
    ...
  EDGE CASES RELEVANT TO EXISTING TESTS:
  (Only analyze edge cases that the ACTUAL tests exercise)
    E[N]: [edge case]

After:
  For pass-to-pass tests (if changes could affect them differently):
    ...
  DELTA LEDGER (1–3 rows, before edge cases): Δ[N]=[difference], Tier=CONTRACT/DATA/INTERNAL, Observable=[what would differ]
  Use Tier to choose the first refutation target in Step 5 (highest tier first).
  EDGE CASES RELEVANT TO EXISTING TESTS:
  (Only analyze edge cases that the ACTUAL tests exercise)
    E[N]: [edge case]

failed-approaches.md との照合（整合する原則 1–2点）
- 「判定基準を特定の観測境界だけに過度に還元しすぎない」に整合: 早期 NOT_EQUIV 条件を狭めず、むしろ差分の“種類”→“観測可能性”の言語化で比較の視野を広げる（境界固定ではない）。
- 「証拠種類をテンプレートで事前固定しすぎる変更は避ける」に整合: Tier は差分の分類であり、探す証拠の種類（テスト/ドキュメント等）を固定しない。Observable は抽象（何が違えば反例になるか）に留め、探索経路の半固定を避ける。

変更規模の宣言
- SKILL.md への変更は compare テンプレートへの 2 行追加のみ（5行以内、必須ゲート純増なし、新規モード追加なし）。
