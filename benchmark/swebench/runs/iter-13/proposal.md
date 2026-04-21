過去提案との差異: これは未検証リンクを理由に verdict を保留側へ倒す Guardrail の再導入ではなく、結論直前の重複ゲートを削って UNVERIFIED を結論へ局所吸収する圧縮提案である。
Target: 両方
Mechanism (抽象): compare の結論直前で発火する重複 self-check を削り、未解決事項は追加探索の既定トリガではなく Step 6 の scoped conclusion と CONFIDENCE 調整で処理する。
Non-goal: STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を特定の観測境界へ狭めたり、未検証リンクを新しい verdict gate にすることはしない。

カテゴリ G 内での具体的メカニズム選択理由:
- 削除候補は (1) Step 5.5 の pre-conclusion self-check、(2) Compare checklist の template 重複、(3) Step 4 の UNVERIFIED 指示と Guardrail 6 の重複。今回選ぶのは (1)。
- (1) だけが compare の実行時アウトカムを直接変える。現在は「NO があれば Step 6 前に fix」が既定分岐なので、証拠がほぼ揃っていても保留/追加探索へ倒れやすい。削除後は同じ未解決事項が UNVERIFIED 明示と CONFIDENCE 低下として吸収され、ANSWER まで到達しやすい。
- (2)(3) は主に読解負荷の削減で、判定分岐の挙動差が弱い。

改善仮説:
結論直前の全項目 self-check は、既に Step 4/5/6 で要求済みの内容を再度「通過しないと結論に進めない」形で重複させており、haiku 系モデルを過度な追加探索または保留へ誘導する。これを削り、未検証要素は Step 6 で結論の射程と confidence に吸収させた方が、研究コアを保ったまま compare の停滞を減らせる。

該当箇所と変更:
- 現行引用1: "### Step 5.5: Pre-conclusion self-check (required)"
- 現行引用2: "If any answer is NO, fix it before Step 6."
- 変更方針: Step 5.5 の節全体を削除し、Step 6 に 1 行だけ追加して、未解決事項は再探索の必須トリガではなく scoped conclusion の制約として扱う。

Payment: add MUST("If any trace element remains UNVERIFIED or any searched counterexample is inconclusive, narrow the conclusion to the traced evidence, state the uncertainty explicitly, and lower confidence instead of reopening analysis only to complete the certificate.") ↔ remove MUST("Before writing the formal conclusion, check each item below. If any answer is NO, fix it before Step 6.")

Decision-point delta:
Before: IF any pre-conclusion checklist item is NO THEN reopen analysis / delay conclusion because certificate completeness is a required gate.
After:  IF residual uncertainty is explicitly bounded and non-decisive for the traced claim THEN write Step 6 with UNVERIFIED scope + lower CONFIDENCE because conclusion scope, not certificate completeness, governs the final action.

変更差分プレビュー:
Before:
- ### Step 5.5: Pre-conclusion self-check (required)
- Before writing the formal conclusion, check each item below. If any answer is NO, fix it before Step 6.
- - [ ] Every PASS/FAIL or EQUIVALENT/NOT_EQUIVALENT claim traces to a specific `file:line` ...
- - [ ] Every function in the trace table is marked **VERIFIED**, or explicitly **UNVERIFIED** with a stated assumption that does not alter the conclusion.
After:
- ### Step 6: Formal conclusion
- Trigger line (planned): "If any trace element remains UNVERIFIED or any counterexample search is inconclusive, explicitly narrow the claim to what the traced evidence establishes and lower confidence rather than reopening analysis solely to complete the certificate."
- Write a conclusion that:
- - References specific numbered premises and claims
- - States what was established and what remains uncertain or unverified

Discriminative probe:
抽象ケース: 2 つの変更は traced assertion まで同じ PASS outcome に到達しているが、途中にある third-party helper 1 個だけ source unavailable で UNVERIFIED のまま残る。
変更前は Step 5.5 の「NO なら fix」が追加探索/保留を誘発し、過度な保留か confidence 崩壊が起きやすい。変更後はその helper を UNVERIFIED と明示したまま、assertion までの traced equivalence に限定した EQUIV + MEDIUM/LOW confidence を返せるので、不要な停滞を避けつつ偽 NOT_EQUIV も偽 EQUIV も増やしにくい。

failed-approaches.md との照合:
- 原則2と整合: 未確定性を広い既定動作として保留側へ倒すのではなく、その global fallback を削る提案である。
- 原則1/3とも非類似: 再収束の既定化や新しい抽象ラベルによる昇格ゲートは追加していない。結論直前の重複ゲート削減のみである。

変更規模の宣言:
削除 6-7 行 + 追加 1 行程度、合計 15 行以内の置換/圧縮で実施可能。