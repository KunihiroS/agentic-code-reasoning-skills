# Iteration 8 — 変更理由

## 前イテレーションの分析

- 前回スコア: 不明（このイテレーションの入力に含まれていないため）
- 失敗ケース: 不明（このイテレーションの入力に含まれていないため）
- 失敗原因の分析: compare において、片側だけが触るファイルが「関連テストに import される」ことを十分条件に NOT EQUIVALENT を早期確定しやすく、テスト境界で観測されない差でも偽 NOT_EQUIV に倒れうる。

## 改善仮説

「構造差（片側だけのファイル変更）」は NOT_EQUIV の十分条件ではなく反例候補（探索のリード）として扱い、NOT_EQUIV の早期結論はテスト境界（PASS/FAIL を左右する具体的根拠）に結び付いた場合に限定すれば、偽 NOT_EQUIV を減らしつつ偽 EQUIV を増やしにくい。

## 変更内容

- SKILL.md の Compare > STRUCTURAL TRIAGE の S2 を置換し、「import されている」だけでは NOT EQUIVALENT を確定せず、「関連テストの PASS/FAIL が当該ファイルの挙動に依存する」と言える場合に NOT EQUIVALENT とするよう明確化した。
- Compare > Compare checklist の先頭 bullet を 1 行だけ置換し、構造非対称を“counterexample lead”として扱い、PASS/FAIL 境界に結び付かない限りは即断しない方針を明示した。

## 期待効果

- 片側だけのファイル変更が存在しても、それがテスト境界で観測可能な差（PASS/FAIL を変える根拠）に写像できない限り NOT_EQUIVALENT を早期確定しにくくなり、偽 NOT_EQUIV を抑制する。
- 一方で、構造差は checklist 上で反例探索の優先対象（lead）として残るため、観測可能な差がある場合は既存の COUNTEREXAMPLE 探索の枠内で拾いやすく、偽 EQUIV の増加を抑える。