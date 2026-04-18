# Iteration 21 — 変更理由

## 前イテレーションの分析

- 前回スコア: （未取得）
- 失敗ケース: （未取得）
- 失敗原因の分析: 反証可能な前提と、推論中に紛れ込む仮定/定義の区別が出力上で不透明な場合、下流の主張が「どの弱い依存（仮定）に支えられているか」が見えにくく、EQUIV/NOT_EQUIV の両側で誤判定（思い込みの固定化、反証対象の取り違え）に繋がりうる。

## 改善仮説

番号付き前提に provenance（観測/仮定/定義）タグを付けて常に可視化すると、各主張が依存している最も弱い前提（特に ASM）を早期に特定できる。これにより、結論が片方向に寄る前に「反転しうる仮定」を最優先で反証対象へ回し、偽 EQUIV と偽 NOT_EQUIV を同時に減らせる。

## 変更内容

- Step 2 の前提テンプレートを、P1/P2 を [OBS]、可変要素を [ASM|DEF] として書く形式に置換した（追加の必須ゲートは増やさず、書式の統合のみ）。
- タグ付けの目的を 1 行で明示し、下流の主張が ASM に依存している場合は、その ASM を最優先の反証対象として扱う決定点を Step 2 の範囲内に統合した。

Trigger line (final): "Tag premises as OBS (observed), ASM (assumed), or DEF (definition) so downstream claims can surface their weakest dependency; if a claim depends on ASM, treat that ASM as the highest-priority refutation target."

上の Trigger line は、proposal の差分プレビューにある「前提を OBS/ASM/DEF でタグ付けして弱い依存を露出させる」趣旨と一致し、その弱い依存（ASM）を反証優先に接続する点までを同一の一般化として 1 行に統合している。

## 期待効果

- compare において、主張の正当化が「番号付き=根拠済み」という形式に依存して思い込みが混入するリスクを下げる。
- ASM 依存が見えた時点で反証努力をそこに集中できるため、結論の早期固定化を抑え、偽 EQUIV / 偽 NOT_EQUIV の双方を減らす方向に働く。