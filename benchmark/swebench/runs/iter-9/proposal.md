1) Target misclassification: 偽 EQUIV を減らす
2) Current failure story (抽象): 反証が見つからない＝同一挙動と短絡し、途中の UNVERIFIED 仮定が結論を左右しうるのに「影響しない」と自己申告して EQUIV を出してしまう
3) Mechanism (抽象): UNVERIFIED が結論に影響しうる時だけ“追加で確かめる/条件付きに縮める”へ分岐し、過剰な同一視を起こしにくくする
4) Non-goal boundary: 読解順序や証拠種類の事前固定・新しい必須ゲート増設はしない（既存チェックの意味を明確化するだけ）

---

Exploration Framework のカテゴリ: D（メタ認知・自己チェック）
- 選んだメカニズム: 「確信度と根拠（UNVERIFIED 仮定）の対応を、結論直前の自己チェックで明示して分岐させる」
- 理由: compare の誤りは“探索不足そのもの”よりも「未検証リンクが残ったまま結論を確定してしまう」形で出やすく、カテゴリ D の『弱い環の特定』『確信度と根拠の対応』が decision-point に直結するため（Objective.md: D は「思い込み検査、弱い環特定、確信度」）。

改善仮説（1つ）
- 結論が EQUIV 側に寄る場面で、UNVERIFIED 仮定が outcome を左右しうるかどうかの自己チェックを“具体的な分岐（追加探索 or 条件付き結論+低確信度）”として明示すると、反証探索が不十分なままの偽 EQUIV を減らし、同時に NOT_EQ 側の過剰反応（些細な不確かさで即 NOT_EQ）を避けられる。

現状ボトルネック診断（SKILL.md 自己引用 + 失敗メカニズム）
- 現在の文言:
  - 「Every function in the trace table is marked VERIFIED, or explicitly UNVERIFIED with a stated assumption that does not alter the conclusion.」(Step 5.5)
- 誘発しうる失敗:
  - “does not alter the conclusion” が抽象的で、(a) 本当に outcome-invariant なのか、(b) 影響しうるのに言い切ってしまっているのか、の判別が曖昧なまま Step 6 に進めてしまう。
  - 結果として「NO COUNTEREXAMPLE FOUND」を広く解釈して EQUIV を確定し、偽 EQUIV が増えうる。

Decision-point delta（IF/THEN 2行、行動が変わる条件を明示）
- Before: IF UNVERIFIED が残っていても「結論を変えない」と言い切れそう THEN EQUIV を出す because “反証なし/自己申告の安全な仮定” という根拠型で十分と扱える
- After:  IF UNVERIFIED が“関連テスト outcome を変えうる”可能性が残る THEN 追加で探す（検証 or 影響しない根拠を作る）/ それでも残るなら条件付き結論+LOW に縮める because “弱い環が outcome を支配するか” を根拠型として優先する
- 対応する SKILL.md の見出し/セクション名:
  - 「Step 5.5: Pre-conclusion self-check (required)」
  - （補助的に）「Step 4: Interprocedural tracing」の UNVERIFIED 取り扱い規則

変更タイプ: 定義の精緻化（1行置換）
- なぜ効くか: 既存チェックの抽象語を“分岐可能な判定文”に落とし、結論（EQUIV）へ進む条件を明確にする。新しい探索経路や証拠種類を固定せず、仮説駆動探索の自由度は維持する。

SKILL.md のどこをどう変えるか（具体）
- 変更箇所: Core Method > Step 5.5 のチェックリスト 2つ目の項目（UNVERIFIED の扱い）
- 変更内容: 「影響しない仮定」を、(a) outcome-invariant を説明できる、または (b) 影響しうるなら結論を条件付きに縮めて確信度を落とす、という具体分岐に置換する。

支払い（必須ゲート総量不変）
- 今回は MUST/REQUIRED の追加やチェック項目数の増加はしていない（既存 1 行の意味を明確化する置換のみ）。したがって“必須ゲート総量”は不変。

変更差分の最小プレビュー（同じ範囲を 3〜10 行、Before/After）
```diff
### Step 5.5: Pre-conclusion self-check (required)
 
 - [ ] Every PASS/FAIL or EQUIVALENT/NOT_EQUIVALENT claim traces to a specific `file:line` — not inferred from function names.
-- [ ] Every function in the trace table is marked **VERIFIED**, or explicitly **UNVERIFIED** with a stated assumption that does not alter the conclusion.
+- [ ] Every function in the trace table is **VERIFIED**, or (if **UNVERIFIED**) you either justify why it cannot change any relevant test outcome OR you narrow the conclusion to be conditional on that assumption and set CONFIDENCE=LOW.
 - [ ] The Step 5 refutation or alternative-hypothesis check involved at least one actual file search or code inspection — not reasoning alone.
 - [ ] The conclusion I am about to write asserts nothing beyond what the traced evidence supports.
```
- 意思決定ポイントの変化（1行）: “UNVERIFIED が残る”という条件が、EQUIV を確定してよい状況と「追加探索/条件付きに縮める」状況に分岐し、偽 EQUIV を起こしにくくする。

期待される挙動差（compare に効く形）
- 変更前に起きがちな誤り（一般形）: 反証探索が見つからない状況で、未検証の外部/間接挙動を「たぶん影響しない」として EQUIV を確定する。
- 変更後に減るメカニズム: UNVERIFIED が“outcome を変えうる弱い環”として残っている場合、Step 6 へ進む前に (a) 追加探索で検証するか、(b) 結論を条件付きに縮め確信度を下げる、へ行動が分岐する。
- 誤判定への影響（片方向最適化を避ける）: 主に偽 EQUIV を減らす。一方で不確かさが些細な場合は (a)「outcome を変えない根拠」を書ければ通常どおり結論でき、偽 NOT_EQ（過剰保留/過剰否定）への寄りも抑える。

最小インパクト検証（思考実験で可）
- ミニケース A（変更前は揺れる/誤るが、変更後は安定）:
  - 2案の差が“直接はテストに見えないが、間接的に入力/分岐を変えうる”位置にあり、その挙動が未検証（UNVERIFIED）な状況。
  - Before は「反証なし」で EQUIV を出しやすい。After は UNVERIFIED が outcome を変えうる可能性として残るため、追加探索（検証）に進むか、条件付き結論+LOW に縮めて偽 EQUIV を避ける。
- ミニケース B（逆方向の誤判定を誘発しうる状況と回避）:
  - UNVERIFIED はあるが、テスト outcome には影響しないことが簡単に示せる（例: 影響範囲が結論スコープ外である、観測可能性が遮断されている、等）状況。
  - After でも「outcome を変えない根拠」を書けば通常どおり結論へ進める。新しい必須手順を増やさず、“不確かさ＝即保留”にならない。

focus_domain=overall のトレードオフ（悪化しうる経路と回避）
- 悪化しうる経路: UNVERIFIED を過大視して常に保留/LOW に寄り、必要以上に結論が出せなくなる（萎縮）。
- 回避策（新しい必須手順を増やさずに）: 条件は「関連テスト outcome を変えうる」場合に限定し、影響しない根拠が書けるなら従来どおり結論できるよう同一行内で分岐を明示した。

failed-approaches.md との照合（1〜2点を具体に）
- 「証拠種類をテンプレートで事前固定しすぎる変更は避ける」: 本提案は“何を探すか”の種類を固定せず、UNVERIFIED が結論に影響しうる時だけ「検証（追加探索）」へ分岐する抽象ルールに留める。
- 「結論直前の自己監査に新しい必須のメタ判断を増やしすぎない」: 新規チェック項目の追加はせず、既存 1 行の曖昧語を分岐可能な定義に精緻化するだけで、必須ゲート総量は増やしていない。

参照状況
- docs/design.md / docs/reference/agentic-code-reasoning.pdf / README.md は今回は未参照（理由: 本提案は Step 5.5 の既存自己チェック文言の“意思決定分岐”を明確化する小変更であり、研究コア構造の追加/改変を伴わないため）。

変更規模の宣言
- 変更: 1行置換（追加 0 行 / 変更 1 行）

停滞対策の自己チェック（proposal 内で明記）
- 監査で褒められやすい説明強化だけに留まっていないか？: 留まっていない。Step 5.5 の 1 行が「追加探索/条件付き結論+LOW」という compare 行動に直接分岐する。
- compare の誤判定を減らす意思決定ポイントが実際に変わるか？: 変わる。UNVERIFIED が outcome を変えうる場合に、EQUIV 確定から“追加で探す/縮める”へ行動が変わる。
- Decision-point delta の Before/After が条件も行動も同じで理由だけ言い換えになっていないか？: なっていない。After は UNVERIFIED の扱いが「自己申告で通す」から「影響可能性があれば追加探索/条件付き」へ分岐する。
- 必須ゲート総量を増やしていないか？: 増やしていない（項目追加なし、1行置換のみ）。
