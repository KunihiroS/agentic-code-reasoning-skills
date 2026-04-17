1) Target misclassification: 偽 NOT_EQUIV（本当は同等なのに早期に NOT EQUIVALENT と断定）を減らす
2) Current failure story (抽象): 「構造差」シグナル（例: 片側だけが触ったファイル）を“テスト可視の差”と短絡し、詳細追跡前に NOT EQUIVALENT へ早期ジャンプしてしまう
3) Mechanism (抽象): “import された”を“テストが依存する（call path / import-time side effects）”へ定義精緻化し、観測できる依存証拠が無い場合は結論を保留して ANALYSIS に進むようにする
4) Non-goal boundary: 読解順序の半固定・証拠種類の事前固定・新しい必須ゲート増設は行わず、既存の STRUCTURAL TRIAGE の表現だけを狭める

---

Exploration Framework のカテゴリ: E（表現・フォーマットを改善する）
- 選んだメカニズム: 定義の精緻化（“構造差→即 NOT_EQUIV”のトリガ文言を、観測可能な「テスト依存」の条件に寄せて誤作動を減らす）
- 理由: compare の誤判定は“判断点のトリガ”が曖昧/過剰強化だと起きる。ここは手順追加ではなく、同じ手順のまま「いつ早期結論を許すか」を明確化するだけで行動（結論/保留/追加探索）が変わる。

改善仮説（1つ）
- 「構造差」の早期 NOT_EQUIV ショートカットを、観測可能な“テスト可視の依存”に限定して定義すると、同等実装に対する偽 NOT_EQUIV を減らしつつ、偽 EQUIV を増やさない（不確実時は ANALYSIS へ進むだけで、EQUIV へ飛ばない）。

現状ボトルネック診断（SKILL.md 自己引用 + 誘発する失敗メカニズム）
- 該当箇所（Compare > STRUCTURAL TRIAGE）:
  - "If Change B omits a file that Change A modifies and a test imports that file, the changes are NOT EQUIVALENT regardless of the detailed semantics."
- 失敗メカニズム: 「import された」という観測は“依存（テスト結果に影響する）”の十分条件ではないのに、NOT_EQUIV の十分条件として表現されているため、詳細追跡を行う前に早期断定が起きやすい。

Decision-point delta（IF/THEN 2行。対応セクション名つき）
- Before (Compare > STRUCTURAL TRIAGE): IF 片側だけが触ったファイルを関連テストが import している THEN NOT EQUIVALENT を結論できる because import=依存の根拠型（構造差シグナル）
- After  (Compare > STRUCTURAL TRIAGE): IF 片側だけが触ったファイルに関連テストが「call path で依存」または「import-time side effects に依存」していると観測できる THEN NOT EQUIVALENT を結論できる ELSE 保留して ANALYSIS に進む because テスト可視依存という根拠型（観測境界の引き締め）

Trigger line:
- "conclude NOT EQUIVALENT only when a relevant test depends on its runtime behavior or import-time side effects (not mere import)."

変更タイプ
- 定義の精緻化（STRUCTURAL TRIAGE の NOT_EQUIV トリガの“十分条件”を狭める）

SKILL.md のどこをどう変えるか（具体）
- Compare > STRUCTURAL TRIAGE の S2 と、早期結論許可文の “structural gap” を「test-visible structural gap」に寄せる（表現差のみ。新モード追加なし。必須手順追加なし。）

支払い（必須ゲート総量不変の証明）
- 今回は MUST/REQUIRED の追加や、結論前の新しい判定ゲート化（強化）を行わない。既存の早期結論ショートカット条件を“狭める（弱める）”だけなので支払い不要（総量は増えない）。

変更差分の最小プレビュー（同一範囲 3〜10行、Before/After）
```diff
STRUCTURAL TRIAGE (required before detailed tracing):
 Before tracing individual functions, compare the two changes structurally:
   S1: Files modified — list files touched by each change. Flag any file
       modified in one change but absent from the other.
   S2: Completeness — does each change cover all the modules that the
       failing tests exercise?
-      If Change B omits a file that Change A modifies and a test imports that file, the changes are NOT EQUIVALENT
-      regardless of the detailed semantics.
+      If Change B omits a file that Change A modifies, conclude NOT EQUIVALENT only when a relevant test depends on its
+      runtime behavior or import-time side effects (not mere import).
   S3: Scale assessment — if either patch exceeds ~200 lines of diff,
       prioritize structural differences (S1, S2) and high-level semantic
       comparison over exhaustive line-by-line tracing.
 
-If S1 or S2 reveals a clear structural gap (missing file, missing module
+If S1 or S2 reveals a clear test-visible structural gap (missing file, missing module
 update, missing test data), you may proceed directly to FORMAL CONCLUSION
 with NOT EQUIVALENT without completing the full ANALYSIS section.
```
- 意思決定ポイントの変化（1行）: 早期に NOT EQUIVALENT へ飛べる条件が「import された」から「テスト可視の依存が観測できる」に変わり、不確実なら ANALYSIS へ進む（保留）

期待される“挙動差”（compare に効く形）
- 変更前に起きがちな誤り: 片側だけの変更ファイルがテストに import されているだけで NOT_EQUIV と断定し、実際にはテスト結果が同一になりうるケースで偽 NOT_EQUIV を出す
- 変更後に減るメカニズム: NOT_EQUIV のショートカットを「call path 依存 / import-time side effects 依存」という観測に結び、観測できない場合は追加探索（ANALYSIS）へ戻すため、早期断定が減る
- どの誤判定が減る見込みか（片方向最適化の回避）: 主に偽 NOT_EQUIV を減らす。偽 EQUIV は、早期に EQUIV へ飛ぶ条件は増やしていない（不確実時は ANALYSIS へ進むだけ）ため、悪化しにくい

最小インパクト検証（思考実験）
- ミニケースA（改善される）:
  - 観測: 変更Aのみが触ったファイルがあり、関連テストはそれを import するが、テストが実際に依存する振る舞いは別経路（別モジュール/別関数）で決まり、import は型参照等の薄い理由に留まる
  - Before: import だけで NOT_EQUIV に早期ジャンプ
  - After: 「call path / import-time side effects 依存」が観測できない限り保留して ANALYSIS に進み、同一結果へ収束しやすい
- ミニケースB（悪化しうる経路 + 回避）:
  - 悪化しうる経路: import-time side effects が実はテスト結果に影響するのに、それを見落として「test-visible ではない」と誤って保留→そのまま EQUIV へ流れてしまう
  - 回避策（新しい必須手順を増やさずに）: S2 の条件に import-time side effects を明示的に含め、"not mere import" と対比して“見落としやすい依存形”を言語化する（探索経路や証拠種類は固定しないが、観測すべき依存の型を曖昧にしない）

failed-approaches.md との整合（具体 1〜2点）
- 「既存の判定基準を特定の観測境界だけに過度に還元しすぎない」に整合: 今回は逆に、"import" という狭い境界へ還元しすぎていた NOT_EQUIV 条件を、より汎用な “テスト可視依存（call path / import-time side effects）” へ戻す（境界の狭さを緩和する）
- 「読解順序の半固定を避ける」に整合: どのファイルから読むか/どの証拠種を先に探すかは規定せず、早期結論のトリガ表現だけを精緻化する

参照範囲メモ
- 今回未参照: README.md / docs/design.md / docs/reference/agentic-code-reasoning.pdf（理由: 研究コアの再設計ではなく、compare テンプレ内の“早期 NOT_EQUIV トリガ文言”の定義精緻化のみが対象のため）

変更規模の宣言
- 変更は最大 3 行（S2 の2行置換 + "clear" 行の1語追加相当）。5行以内。

停滞対策の自己チェック（明記）
- これは「監査で褒められやすいだけの整形」ではなく、STRUCTURAL TRIAGE の早期結論条件そのものを分岐可能な観測条件へ置き換えるため、compare の結論（NOT_EQUIV へ飛ぶ/保留して ANALYSIS へ進む）が実際に変わる。
- Decision-point delta は条件と行動が変わっている（Before は import で即断、After は test-visible 依存が観測できない限り保留）。理由だけの言い換えではない。
- 必須ゲートは増やしていない（早期ショートカットの条件を狭めただけ）。