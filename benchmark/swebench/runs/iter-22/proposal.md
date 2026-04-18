1) 過去提案との差異: Step 5（反証の優先順位や早期 NOT_EQUIV 条件）をいじらず、Step 2（前提表現）の曖昧さを最小 diff で解消する提案。
2) Target: 両方（偽 EQUIV / 偽 NOT_EQUIV を同時に減らす）
3) Mechanism (抽象): 「未検証の前提」を premise に紛れ込ませないために、前提を FACT と ASSUMPTION に明示分離し、後続 claim の依存関係を形式的に見える化する。
4) Non-goal: 構造差→NOT_EQUIV の条件設計や探索順序（triage / 読解経路）の固定化は一切行わない。

---

ステップ 1: 禁止された方向の列挙（failed-approaches.md + 却下履歴の要約）
- 証拠種類をテンプレで事前固定しすぎる（探索が「特定シグナル捜索」化して確認バイアス・反証経路の弱体化）。
- 判定基準を特定の観測境界に過度還元する（構造差の扱いを“ある境界に写像できた時だけ”のように狭める等）。
- 探索ドリフト対策として読解順序や境界確定を半固定する（どこから読み始めるか等の固定化）。
- 局所的な仮説更新を即座の前提修正義務に結びつけすぎる（探索が不安定化）。
- ガードレールを特定方向の追跡・優先順位に具体化しすぎる（「最小分岐候補」等への差し替え、反証経路の細り）。
- 結論直前の必須メタ判断・報告様式を増やしすぎる（新しい実質ゲート化、結論の萎縮）。
- 却下履歴（iter-18〜20）で明示的に NG: Step 5 の pivot claims 優先の強い表現、highest-tier-first による探索経路の半固定、構造差/早期 NOT_EQUIV 条件を観測境界に狭める方向。

ステップ 2: 未探索の改善余地（SKILL.md から今回のカテゴリ E に合うものを抽出）
- Step 2「Numbered premises」は “guesses を premise にするな” と言うだけで、実務上もっとも頻発する「必要だが未検証の仮置き（assumption）」の置き場所が曖昧。
  - 結果として (a) 未検証が P として紛れ込み偽の確実性が生まれる、(b) 逆に premise に置けず本文に散逸して追跡不能、の両方が起きうる。
- Step 4 では VERIFIED/UNVERIFIED を明示できるのに、Step 2 には同等の“検証状態ラベル”がない（表現レベルの非対称）。
- これは compare/diagnose/explain/audit-improve の全モード共通の基盤（Core Method Step 2）で、かつ「表現・フォーマット改善（カテゴリ E）」として 5行以内で改善可能。

ステップ 3: 選択した改善仮説（1つ）
改善仮説: 前提（premise）を FACT と ASSUMPTION に明示分離し、各 claim が依存する ASSUMPTION を明示参照させると、
- 偽 EQUIV: “暗黙の仮定が真なら同値” を同値と誤判定する事故を減らす
- 偽 NOT_EQUIV: “仮定に依存した差” を確定差として扱う事故を減らす
の両方に効き、探索経路の固定や証拠種類の固定を起こさずに全体の推論品質を底上げできる。

---

カテゴリ E 内での具体的メカニズム選択理由
- 変更は「何を探すか／どの順に読むか」ではなく、「書き方（未検証をどこに置くか）」の明確化。
- “premise として書いてよいもの” の境界を、追加ゲートではなくラベルの導入で可視化するだけなので、探索自由度を削らない。
- Step 4 の VERIFIED/UNVERIFIED と整合するため、表現の一貫性が上がり認知負荷が下がる（同じ概念を別の言い回しで再学習しなくてよい）。

改善仮説（抽象・汎用）
- 推論の誤りは「事実と仮定の混同」によって増幅されやすい。仮定を“premise の外”に追放するのではなく、“premise の中で明示的に隔離”すると、後続の反証（Step 5）と結論（Step 6）の両方で依存関係が追跡可能になり、両方向（EQUIV/NOT_EQUIV）の判定が安定する。

SKILL.md 該当箇所（短い引用）と変更方針
引用（現状）:
- "### Step 2: Numbered premises"
- "Do not treat guesses as premises. Every later claim must reference a premise by number."
変更方針:
- 「guess は premise にするな」を、(P#=FACT, A#=ASSUMPTION) の2種に分ける書式へ具体化し、claim 側の参照ルールを明示する。

Decision-point delta（IF/THEN 2行）
Before: IF 前提として必要だが file:line/spec 等で直接確認できない文が出た THEN premise 化を避ける/本文に散らす because "guesses are not premises"（曖昧な禁止）
After:  IF 前提として必要だが直接確認できない文が出た THEN A#（ASSUMPTION）として番号付けし、依存する claim から明示参照する because 検証状態（FACT vs ASSUMPTION）をトレース可能にする（依存関係の証拠型: 参照可能なラベル）

変更差分プレビュー（3〜10行）
Before:
- Do not treat guesses as premises. Every later claim must reference a premise by number.
After:
- Do not treat guesses as FACT premises. If a statement is necessary but unverified, record it as a numbered ASSUMPTION (A1, A2, ...).
- Every later claim must reference the specific P# facts it uses, and any A# assumptions it depends on.

failed-approaches.md との照合（整合 1〜2点）
- 証拠種類の事前固定をしない: A# は「何を探すか」を固定せず、未検証を“どこに置くか”のラベル付けに留まる。
- 探索経路の半固定をしない: 読解順序・優先順位・観測境界の制限を追加せず、既存の仮説駆動探索（Step 3）と必須反証（Step 5）をそのまま活かす。

変更規模の宣言
- SKILL.md の変更は Step 2 の既存2行程度の置換（最大 2〜3行追加相当、合計 5行以内）。新しい必須ゲートの純増なし（既存 Step 2 の明確化のみ）。
