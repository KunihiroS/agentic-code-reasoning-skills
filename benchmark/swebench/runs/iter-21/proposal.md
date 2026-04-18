1) 過去提案との差異: 構造差→早期 NOT_EQUIV の条件調整や反証優先順位(=pivot/最高tier先)の強化ではなく、「前提の出自(観測/仮定/定義)を可視化して思い込みを検査する」方向に限定する。
2) Target: 両方（偽 EQUIV / 偽 NOT_EQUIV の同時低減）
3) Mechanism (抽象): 番号付き前提に provenance タグを付け、後続の主張が「どの仮定に依存しているか」を自動的に露出させて反証対象選びを改善する。
4) Non-goal: STRUCTURAL TRIAGE や早期 NOT_EQUIV 判定条件の“観測境界への狭め”は一切いじらない。

本文

カテゴリ D（メタ認知・自己チェック）内での具体メカニズム選択理由
- 失敗しやすいのは「推論の中に紛れ込んだ仮定が、番号付き前提の見かけで事実扱いされる」こと。これが EQUIV/NOT_EQUIV のどちら側でも誤判定を誘発する。
- “何の証拠を探すべきか”をテンプレで固定せずに、思い込み(ASSUMED)を明示して弱い環を特定できる。探索経路の半固定にもなりにくい（次の一手はタグ付き前提への依存関係で決まるが、証拠種別は固定しない）。

改善仮説（1つ）
- 前提を OBS/ASM/DEF にタグ付けしておくと、後段の主張(C)が「ASM を踏み台にしている」ことが早期に見えるため、結論が片方向に寄る前に“反転しうる仮定”へ反証努力を配分でき、偽 EQUIV と偽 NOT_EQUIV を同時に減らせる。

SKILL.md 該当箇所（短い引用）
- Step 2: Numbered premises
  - "Before concluding anything, write numbered premises grounded in known facts." 
  - "Do not treat guesses as premises. Every later claim must reference a premise by number."

どう変えるか
- 前提テンプレートを provenance 付きに圧縮して、(a) どれが観測で、(b) どれが仮定/定義か、を常に見える状態にする。
- 追加の必須ゲートは増やさず、Step 2 内の書式だけでメタ認知(思い込み検査)を“摩擦ゼロで常時ON”にする。

Decision-point delta（IF/THEN 2行）
Before: IF ある主張Cが必要 THEN 番号付き前提Pを参照して正当化する because 「番号付き=根拠済み」という形式的保証
After:  IF 主張Cが ASM タグの前提に依存する THEN その ASM を最優先の反証対象として扱う（観測へ置換/弱い環として明示） because 「反転しうる仮定」を可視化した依存関係

変更差分プレビュー（Before/After, 3–10行）
Before:
```
P1: [fact about the task, inputs, or expected behavior]
P2: [fact about relevant files, tests, or specifications]
P3: ...
```
After:
```
P1 [OBS]: [observed fact about the task, inputs, or expected behavior]
P2 [OBS]: [observed fact about relevant files, tests, or specifications]
P3 [ASM|DEF]: ...
```
(+ 1 line) Tag premises as OBS (observed), ASM (assumed), or DEF (definition) so downstream claims can surface their weakest dependency.

failed-approaches.md との照合（整合 1–2点）
- 「証拠種類の事前固定を避ける」(failed-approaches.md 8–10): タグは“何を探すか”を固定しない。仮定の可視化のみで、探索の自由度は保つ。
- 「自己監査に新しい必須メタ判断を増やしすぎない」(27–31): 新しい必須ゲートを純増せず、Step 2 の表記圧縮で弱い環を露出させるだけ（追加の手順強制をしない）。

変更規模の宣言
- SKILL.md 変更は最大 4 行（Step 2 のテンプレ3行置換 + 説明1行追加）で、5行以内の制約を満たす。