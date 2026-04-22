1) 過去提案との差異: 今回は STRUCTURAL TRIAGE や relevant tests 発見規則を狭めず、意味差が見つかった後の compare 内部分岐にだけ、原論文の localize/explain 系の「premise→claim→prediction」連結を移植する。
2) Target: 両方
3) Mechanism (抽象): 高レベルな obligation ラベルで差分を吸収/断定する代わりに、各 surviving difference を特定の test premise / assertion へ再記述してから verdict に使う。
4) Non-goal: 早期 NOT_EQUIV 条件を特定の観測境界へ狭めたり、pass-to-pass 側の relevant tests 発見規則を置換したりしない。

カテゴリ F 内での具体的メカニズム選択理由:
原論文の fault localization は PREMISE → CLAIM → PREDICTION 鎖で「どの観測期待に対する逸脱か」を明示させ、code QA は semantic property を explicit evidence に結びつける。SKILL.md の compare には per-test tracing はあるが、semantic difference 発見後の分岐だけはまだ obligation ラベル寄りで、どの premise/assertion に対する差かを飛ばして吸収・断定しうる。この未活用部分を compare に移すと、差分を verdict に使う直前の分岐が変わる。

改善仮説:
semantic difference を verdict に使う前に「どの test premise/assertion に対する divergence claim か」を 1 段挟むと、無害な内部差分の過剰昇格と、有害差分の早すぎる吸収の両方が減る。

該当箇所と変更方針:
現行引用: "After any semantic difference is found, classify the difference by the test-facing obligation it could change: preserved by both / broken in one change / unresolved."
これを、localize の divergence-claim 形式に寄せて「差分を premise-linked claim に変換してから preserved/broken/unresolved を判定する」文へ置換する。

Decision-point delta:
Before: IF semantic difference is found but no immediate PASS/FAIL witness is already traced THEN classify it at the obligation level and possibly absorb it as PRESERVED BY BOTH because the root evidence is an obligation label.
After:  IF semantic difference is found THEN rewrite it as CLAIM D[N] against a specific test premise/assertion and do one premise-to-assertion trace before verdict use because the root evidence is a premise-linked divergence claim.

Payment: add MUST("If a semantic difference survives tracing, rewrite it as CLAIM D[N] against a specific test premise/assertion before using it in the verdict.") ↔ demote/remove MUST("After any semantic difference is found, classify the difference by the test-facing obligation it could change: preserved by both / broken in one change / unresolved.")

変更差分プレビュー:
Before:
- After any semantic difference is found, classify the difference by the test-facing obligation it could change: preserved by both / broken in one change / unresolved.
- For each semantic difference that survives tracing:
-   OBLIGATION CHECK: what test-facing obligation could this difference change?
-   Status: PRESERVED BY BOTH / BROKEN IN ONE CHANGE / UNRESOLVED
After:
- Trigger line (planned): "If a semantic difference survives tracing, restate it as CLAIM D[N] against a specific test premise/assertion before classifying it."
- For each semantic difference that survives tracing:
-   CLAIM D[N]: at [file:line], Change A vs B differs in a way that would [preserve / violate / unresolved] PREMISE P[N] or a cited assertion because [...]
-   TRACE TARGET: [test/assertion line reached from that premise]
-   Status: PRESERVED BY BOTH / BROKEN IN ONE CHANGE / UNRESOLVED

Discriminative probe:
抽象ケース: 2 つの変更が内部で別の正規化順序を使い、片方だけが特定入力で例外型を変える。変更前は obligation レベルで「どちらも最終的に入力を拒否する」と吸収して偽 EQUIV になりやすい。変更後は CLAIM D を既存の assertion premise（例外型/戻り値条件）へ結びつけるため、その assertion に届く差だけが NOT_EQ の根拠になり、届かなければ preserved として偽 NOT_EQ も避ける。

failed-approaches.md との照合:
- 原則1への整合: 再収束を既定動作にしない。差分を「後で吸収できるか」ではなく、先にどの premise に対する divergence かで扱う。
- 原則2/3への整合: 未確定性を広く保留側へ倒す新ゲートも、観測可能性の抽象ラベルによる昇格ゲートも追加しない。既存の差分処理を premise-linked claim に置換するだけ。

変更規模の宣言:
置換ベースで 8-12 行想定。新規モードなし、既存の mandatory 総量は Payment の範囲で不増。