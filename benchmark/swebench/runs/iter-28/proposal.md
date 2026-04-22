過去提案との差異: これは構造差を特定の観測境界へ狭める提案ではなく、構造差が見つかったときに compare を即時結論へ進める分岐そのものを、追加探索優先へ置き換える提案である。
Target: 両方
Mechanism (抽象): STRUCTURAL TRIAGE を verdict shortcut ではなく first-trace selector に変え、NOT_EQUIVALENT は少なくとも 1 本の traced test divergence を通ってから出す。
Non-goal: 構造差の重要度を下げることでも、固定の assertion boundary へ比較を写像することでもない。

カテゴリ A でこれを選ぶ理由:
- 現在の主要分岐は「S1/S2 の差を見た瞬間に結論へ行くか、次の探索対象を決めるだけに留めるか」であり、ANSWER と追加探索要求が直接変わる。
- compare の停滞源は説明不足ではなく shortcut の存在で、IF 条件は同じでも THEN 行動を verdict→trace に変えるだけで挙動差が観測できる。

改善仮説:
- 構造差は高情報量の手掛かりだが、それ自体を verdict にせず最初の反証トレースに変換した方が、偽 NOT_EQUIV を減らしつつ、真の差分では具体的な test divergence をより早く確立できる。

該当箇所と変更:
- 現行引用: "STRUCTURAL TRIAGE (required before detailed tracing)" と "If S1 or S2 reveals a clear structural gap ... you may proceed directly to FORMAL CONCLUSION with NOT EQUIVALENT without completing the full ANALYSIS section."
Payment: add MUST("When S1/S2 finds a structural gap, use it to pick the first relevant test trace; conclude NOT EQUIVALENT only after one traced test yields a diverging assertion.") ↔ demote/remove MUST("If S1 or S2 reveals a clear structural gap ... you may proceed directly to FORMAL CONCLUSION with NOT EQUIVALENT without completing the full ANALYSIS section.")

Decision-point delta:
Before: IF S1/S2 shows a clear structural gap THEN skip ANALYSIS and answer NOT EQUIVALENT because structural absence is treated as sufficient evidence.
After:  IF S1/S2 shows a clear structural gap THEN trace the first relevant test through that gap and conclude NOT EQUIVALENT only if a diverging assertion is reached, because structural evidence is treated as search prioritization until test-outcome divergence is witnessed.

変更差分プレビュー:
Before:
- "STRUCTURAL TRIAGE (required before detailed tracing):"
- "If S1 or S2 reveals a clear structural gap ... you may proceed directly to FORMAL CONCLUSION with NOT EQUIVALENT ..."
After:
- "STRUCTURAL TRIAGE: use S1/S2 to choose the first discriminative trace before broad analysis."
- "Trigger line (planned): When S1/S2 finds a structural gap, trace the most relevant test through that gap before any NOT EQUIVALENT conclusion."
- "A structural gap is decisive only if that trace reaches a diverging assertion or other explicit PASS/FAIL split."

Discriminative probe:
- 抽象ケース: 一方の変更だけが補助モジュールを更新しているが、既存テストではその経路が guard で回避される。
- 変更前は structural gap だけで偽 NOT_EQUIV に倒れやすい。変更後は最初の traced test が同じ assertion outcome に再収束し、即時結論ではなく追加探索 or EQUIV 側検証へ進むため誤判定を避ける。
- 逆に真の差分なら、その最初の traced test で diverging assertion を得て NOT_EQUIV をより具体的に確立できる。

failed-approaches.md との照合:
- 原則 2 と整合: 未確定性を広い保留既定にはせず、structural gap という局所手掛かりを次の探索順序にだけ使う。
- 原則 3 と整合: 新しい抽象ラベルや再記述形式は増やさず、既存 compare テンプレート内の shortcut 分岐を trace-first に置き換えるだけである。

変更規模の宣言:
- 置換 5-7 行、Compare セクション内のみ。新規モード追加なし、研究コア維持。