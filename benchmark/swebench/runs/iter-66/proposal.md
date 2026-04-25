過去提案との差異: 直近の却下案のように構造差/早期 NOT_EQUIV を特定の観測境界へ写像せず、結論直前の自己チェックで「最弱の証拠リンクが ANSWER/CONFIDENCE をどう変えるか」を明示させる。
Target: 両方
Mechanism (抽象): Step 5.5 の既存 self-check を、未検証項目の保留化ではなく、verdict を支える最弱リンクの影響評価と CONFIDENCE/追加探索の分岐へ置換する。
Non-goal: 早期 NOT_EQUIV 条件、構造差の昇格条件、観測境界、テスト oracle 固定を変更しない。

Step 1 — 禁止方向の列挙:
- 再収束を比較規則として前景化し、途中差分を弱める方向。
- 未確定 relevance / UNVERIFIED / 弱い仮定を広く保留側の既定分岐にする方向。
- 差分を外部可視性・assertion・特定観測点などの抽象ラベルへ写像してから昇格させる方向。
- 終盤の証拠十分性を confidence 記述だけへ吸収して premature closure を増やす方向。
- 最初の差分から単一の追跡経路を必須化する方向。
- 探索理由と反証可能な情報利得を短い単一欄へ潰し、柔軟な証拠探索を弱める方向。
- 直近却下履歴より、impact witness なしの早期 NOT_EQUIV、STRUCTURAL TRIAGE の早期結論強化、`otherwise keep the comparison UNVERIFIED` 型の保留既定化は禁止。

Step 2/2.5 — overall に直結する意思決定ポイント候補:
1. Step 5.5 pre-conclusion self-check:
   - 現在のデフォルト挙動: 各チェックに YES が出れば FORMAL CONCLUSION へ進み、弱い証拠リンクが confidence にどう効くかは明示されにくい。
   - 変更後の観測アウトカム: 最弱リンクが ANSWER を反転しうるなら追加探索、反転しないが弱いなら CONFIDENCE を下げる、支えないなら結論へ進む。
2. Compare の `NO COUNTEREXAMPLE EXISTS`:
   - 現在のデフォルト挙動: 反例パターンを検索して NONE FOUND なら EQUIVALENT へ進みやすい。
   - 変更後の観測アウトカム: 反例探索の結果がどの未解決仮説を閉じたかにより EQUIV/UNVERIFIED/追加探索が変わる。
3. Step 3 の `OPTIONAL — INFO GAIN`:
   - 現在のデフォルト挙動: optional なので、次アクションの判別価値が曖昧でも探索を続けられる。
   - 変更後の観測アウトカム: 追加探索の打ち切り/継続が情報利得で変わり、過剰探索または premature closure が減る。

Step 3 — 選択する分岐:
候補 1 の Step 5.5 pre-conclusion self-check を選ぶ。
理由は 2 点のみ:
- FORMAL CONCLUSION 直前なので、ANSWER / CONFIDENCE / 追加探索のいずれかに直接差が出る。
- 未検証を保留へ倒すのではなく、最弱リンクが結論を支えるかどうかで行動を分けるため、EQUIV と NOT_EQUIV の片方向最適化になりにくい。

カテゴリ D 内での具体的メカニズム選択理由:
Objective.md の D は「弱い環の特定」と「確信度と根拠の対応」を含む。既存 SKILL.md には Step 5.5 があり、ここを置換するだけで新規モードや新規チェックリストを増やさず、結論直前の思い込み検査を実行時アウトカムへ接続できる。

改善仮説:
結論直前に、verdict を支える最弱の証拠リンクと、そのリンクが反転した場合の ANSWER/CONFIDENCE への影響を 1 行で明示させれば、未検証を広く保留へ倒さずに、偽 EQUIV と偽 NOT_EQUIV の両方を減らせる。

SKILL.md の該当箇所と変更方針:
現在の Step 5.5 には以下がある:
- `Every function in the trace table is marked **VERIFIED**, or explicitly **UNVERIFIED** with a stated assumption that does not alter the conclusion.`
- `The conclusion I am about to write asserts nothing beyond what the traced evidence supports.`

これを、単なる VERIFIED/UNVERIFIED の有無ではなく、最弱リンクが結論を支えているか・confidence を下げるだけか・追加探索を要するかに分岐する文へ置換する。

Payment: add MUST("Name the weakest evidence link for the planned verdict; if it could flip ANSWER, inspect or refute it before concluding; if it only affects certainty, lower CONFIDENCE instead of changing ANSWER.") ↔ demote/remove MUST("Every function in the trace table is marked **VERIFIED**, or explicitly **UNVERIFIED** with a stated assumption that does not alter the conclusion.")

Decision-point delta:
Before: IF all Step 5.5 boxes can be checked THEN proceed to FORMAL CONCLUSION because evidence is traced and unsupported claims are excluded.
After:  IF the planned verdict has a weakest evidence link that could flip ANSWER THEN perform one targeted inspection/refutation before FORMAL CONCLUSION; otherwise proceed and set CONFIDENCE according to that link because the weakness is mapped to ANSWER vs CONFIDENCE impact.

変更差分プレビュー:
Before:
```
- [ ] Every function in the trace table is marked **VERIFIED**, or explicitly **UNVERIFIED** with a stated assumption that does not alter the conclusion.
- [ ] The Step 5 refutation or alternative-hypothesis check involved at least one actual file search or code inspection — not reasoning alone.
- [ ] The conclusion I am about to write asserts nothing beyond what the traced evidence supports.
```
After:
```
- [ ] Trigger line (planned): "Name the weakest evidence link for the planned verdict; if it could flip ANSWER, inspect or refute it before concluding; if it only affects certainty, lower CONFIDENCE instead of changing ANSWER."
- [ ] The Step 5 refutation or alternative-hypothesis check involved at least one actual file search or code inspection — not reasoning alone.
- [ ] The conclusion I am about to write asserts nothing beyond what the traced evidence supports, including any VERIFIED/UNVERIFIED trace-table assumptions.
```

Discriminative probe:
抽象ケース: 片方の変更だけが補助関数経由で条件分岐を変えそうだが、その補助関数の挙動が未読で、既存テストの PASS/FAIL への接続は一応推測できている。
Before では、UNVERIFIED assumption が「結論を変えない」と言えたつもりで偽 EQUIV/偽 NOT_EQUIV または HIGH confidence に進みがち。
After では、その補助関数が ANSWER を反転しうる最弱リンクなら一点だけ追加 inspection/refutation し、反転しないなら ANSWER は維持して CONFIDENCE だけ下げるため、新しい必須ゲートの純増なしに誤判定と過度な保留を避ける。

failed-approaches.md との照合:
- 原則 2 との整合: UNVERIFIED を保留の既定トリガーにしない。ANSWER を反転しうる場合だけ局所探索へ進み、それ以外は CONFIDENCE に反映する。
- 原則 3/5 との整合: 差分を特定の assertion boundary や単一追跡経路へ固定しない。対象は結論直前の証拠リンクであり、構造差の昇格条件は変更しない。
- 原則 4 との整合: 終盤チェックを confidence-only に吸収せず、ANSWER を反転しうる弱点は追加 inspection/refutation に残す。

変更規模の宣言:
SKILL.md の Step 5.5 チェックリスト内 1 行を置換し、隣接 1 行へ VERIFIED/UNVERIFIED の語を統合する。想定 diff は 2〜3 行、hard limit 15 行以内。研究コアである番号付き前提、仮説駆動探索、手続き間トレース、必須反証は維持する。
