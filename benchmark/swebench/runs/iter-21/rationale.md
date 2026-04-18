# Iteration 21 — 変更理由

## 前イテレーションの分析

- 前回スコア: （未記録）
- 失敗ケース: （未記録）
- 失敗原因の分析: 前提が「事実」と「仮定/定義」で混ざったまま扱われ、後段の主張がどの弱い前提に依存しているかが露出しにくいと、結論が片方向に寄った後に反転可能性の高い仮定を検査し損ねやすい。

## 改善仮説

番号付き前提に provenance（OBS/ASM/DEF）を付けて依存関係の弱点（反転しうる仮定）を早期に可視化すれば、偽 EQUIV / 偽 NOT_EQUIV の両方を同時に減らせる。

Trigger line (final): "Tag premises as OBS (observed), ASM (assumed), or DEF (definition) so downstream claims can surface their weakest dependency."
上の Trigger line は提案の差分プレビューにあった Trigger line と一致する（同一文言）。

## 変更内容

- 番号付き前提テンプレートを OBS/ASM/DEF タグ付きの書式に統一した。
- 主張が ASM タグの前提に依存している場合、その ASM を最優先の反証対象として扱う指示を明文化した。

## 期待効果

- 「後段の主張が何に依存しているか」を常時露出させることで、反転しうる仮定への検査が遅れて結論が固定化するリスクを下げる。
- 新しい必須ゲートの純増なしに、弱い環（ASM）を選びやすくして反証努力の配分を改善する。