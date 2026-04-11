# Iteration 69 — 変更理由

## 前イテレーションの分析

- 前回スコア: 前イテレーションのスコアデータ参照不可
- 失敗ケース: 具体的な ID は記載しない（制約）
- 失敗原因の分析: ANALYSIS セクションで `Comparison: DIFFERENT` という結論を得た後、COUNTEREXAMPLE セクションに進む際に当該クレームを参照せず一から再構築を試みる「解析ドリフト」が観察された。再構築時の不確実性の高まりにより、証拠が揃っているにもかかわらず EQUIVALENT 側に後退する後退ドリフトが生じていた。

## 改善仮説

COUNTEREXAMPLE セクションのヘッダーに「ANALYSIS で DIFFERENT と記録したクレームを起点とすること」を明示することで、ANALYSIS と COUNTEREXAMPLE の構造的な接続が強化され、後退ドリフトを防止できる。これはテンプレート内の既存フィールド間に認知的な足場を追加する Category E（表現・フォーマットの改善）の適用である。

## 変更内容

`SKILL.md` の Compare モード証明書テンプレート内 `COUNTEREXAMPLE` セクションの見出し行を1行変更した。変更前は「required if claiming NOT EQUIVALENT」のみの記述だったが、変更後は「ANALYSIS 内で `Comparison: DIFFERENT` と記録されたテストを起点とし、そのクレームからトレースを構築すること」という接続指示を付記した。

## 期待効果

- ANALYSIS セクションで差異を発見済みの場合、COUNTEREXAMPLE 構築時に既存クレームを転用する経路が明確になり、再構築による不確実性が低下する。
- 後退ドリフトが構造的に抑制され、証拠が揃っている NOT_EQUIVALENT ケースの正答率が向上する。
- 判定閾値は変化しないため、EQUIVALENT 判定の正答率への悪影響はない。
