# Iteration 34 — 変更理由

## 前イテレーションの分析

- 前回スコア: 未参照（この作業ではスコア記録を参照していない）
- 失敗ケース: 未参照
- 失敗原因の分析: compare の結論直前に独立した self-check gate があり、既に verdict に必要な per-test trace と counterexample / no-counterexample が揃っていても、非決定的な未解決事項を理由に追加探索や保留へ戻りやすい構造だった。

## 改善仮説

独立した pre-conclusion self-check は、既存の compare certificate がすでに要求している証拠を終盤で再度 mandatory な別ゲートとして課していた。これを削除し、verdict を左右しない未解決事項は CONFIDENCE に送るよう結論規則へ統合すれば、研究コアを維持したまま compare の最終分岐を軽くし、過度な保留や不要な再探索を減らせる。

## 変更内容

- 独立した「Pre-conclusion self-check (required)」セクションを削除した。
- Formal conclusion の直下に、compare certificate が既に test outcome を確立している場合は、非決定的な未解決事項を CONFIDENCE に持ち込んで結論してよい、という 1 行を追加した。
- これにより、Decision-point delta は「checklist の NO で Step 6 を止める」から「verdict 非決定の不確実性だけを CONFIDENCE に残して Step 6 に進む」へ変わった。
- Trigger line (final): "If the compare certificate already establishes identical or different test outcomes, conclude and carry any remaining non-decisive uncertainty into CONFIDENCE rather than reopening analysis."
- この Trigger line は proposal の差分プレビューにあった planned trigger line と一致しており、compare 直前の分岐を発火させる位置にそのまま入っている。

## 期待効果

既に verdict を支える証拠が揃っている場面で、周辺の未検証要素だけを理由に結論を引き延ばす挙動が減ることを期待する。特に EQUIV / NOT_EQUIV のどちらでも、非決定的な未解決事項を保留トリガではなく confidence 調整として扱えるため、compare の実効差を保ったまま停滞を抑えやすくなる。