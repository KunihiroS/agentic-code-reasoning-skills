過去提案との差異: これは STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を特定の観測境界へ狭める案ではなく、暫定 verdict から「それを覆す最小の証拠」を逆算して次の探索順を変える案である。
Target: 両方
Mechanism (抽象): compare の終盤を「列挙してから結論」ではなく「暫定 verdict を置き、その verdict を反転させる witness を先に探す」順序へ入れ替える。
Non-goal: structural gap 自体の意味づけ変更や、NOT_EQUIV を出す条件の観測境界固定は行わない。

カテゴリ A 内での具体的メカニズム選択理由
- 候補1: relevant test 候補の収集順。現在のデフォルトは changed symbol reference 起点に寄りやすく、証拠不足時は既に見えたテストへ収束しがち。変更後は追加探索の要求先が変わり、保留/追加探索/結論の分岐が変わる。
- 候補2: surviving semantic difference の処理順。現在のデフォルトは traced difference を見つけると、その場で D[N] 化して結論側へ進みがち。変更後は EQUIV/NOT_EQUIV/追加探索の分岐を、反対 verdict を作る最小 witness の有無で分けられる。
- 候補3: UNVERIFIED assumption の畳み方。現在のデフォルトは「結論を変えない assumption」と書いて前進しがち。変更後は CONFIDENCE/UNVERIFIED 明示が変わるが、compare の主分岐より自己監査寄り。

ステップ2.5の監査メモ
- 候補1: 現在は直接参照が見えた relevant tests を主集合にしがち; 変更後は追加探索の要求先と保留の発生位置が変わる。
- 候補2: 現在は一度優勢になった verdict に沿って残差分を整理しがち; 変更後は EQUIV/NOT_EQUIV/追加探索/CONFIDENCE が flip-witness 探索で変わる。
- 候補3: 現在は UNVERIFIED を脚注化して結論維持しがち; 変更後は UNVERIFIED 明示と CONFIDENCE は変わるが verdict 分岐への効きが相対的に弱い。

選定: 候補2（surviving semantic difference の処理順）
- compare では「どの差分を次に潰すか」がそのまま結論停止条件を決めるため、探索順の変更が verdict・保留・追加探索に直結する。
- EQUIV 側にも NOT_EQUIV 側にも同じ形で働く対称な reverse reasoning であり、片方向最適化になりにくい。

改善仮説
- per-test tracing の後、残った差分や一致をそのまま結論へ畳むのではなく、暫定 verdict を1つ置き、その verdict が false なら必ず存在するはずの最小 witness を先に探索させると、局所差分への早すぎる収束と、generic な no-counterexample での早すぎる収束の両方を減らせる。

該当箇所と変更方針
- 現行引用: "For each semantic difference that survives tracing:" / "COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):" / "NO COUNTEREXAMPLE EXISTS (required if claiming EQUIVALENT):"
- 変更: surviving difference の列挙後に直接 verdict-side template へ進むのではなく、暫定 verdict を明記し、その verdict を覆す witness を次の探索対象として定義する 4-6 行を挿入する。既存の counterexample / no-counterexample 節は保持し、そこへ入る前の探索順だけを変える。

Decision-point delta
Before: IF traced tests currently lean to one verdict and no already-traced assertion disproves it THEN move directly into the matching conclusion block because existing explicit evidence is treated as sufficient stopping signal.
After:  IF traced tests currently lean to one verdict but the minimal witness that would flip that verdict has not been searched for THEN spend the next search on that flip-witness before entering the conclusion block because unresolved discriminators outrank summary completion.

変更差分プレビュー
Before:
- For each semantic difference that survives tracing:
-   CLAIM D[N]: ...
- COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
- NO COUNTEREXAMPLE EXISTS (required if claiming EQUIVALENT):

After:
- For each semantic difference that survives tracing:
-   CLAIM D[N]: ...
- VERDICT-FLIP PROBE:
-   Trigger line (planned): "Before finalizing a compare verdict, name the smallest concrete witness that would make the opposite verdict true, and search for that witness next."
-   Tentative verdict: EQUIVALENT / NOT EQUIVALENT
-   Required flip witness: [specific test/assertion/path that would reverse the verdict]
- COUNTEREXAMPLE ... / NO COUNTEREXAMPLE EXISTS ...

Discriminative probe
- 抽象ケース: 両変更とも fail-to-pass では同じ PASS に見えるが、一方だけが既存 helper の入力正規化位置を変えており、別の既存 pass-to-pass path でのみ assertion 差が出る。
- Before では、見えている failing test の一致から generic な EQUIV まとめに入り、偽 EQUIV が起きがち。After では tentative EQUIV が「その verdict を壊す最小 witness = 既存 pass-to-pass path 上の helper 経由 assertion」を次探索に指名し、差分 assertion を見つけて偽 EQUIV を避ける。
- 逆向きにも、tentative NOT_EQUIV に対して「差分を吸収して同じ assertion に戻す downstream handling」を flip witness として先に探すため、過早な偽 NOT_EQUIV も減らせる。

failed-approaches.md との照合
- 原則1と整合: 再収束を既定 verdict にするのではなく、「今の verdict を反転させる具体証拠」を探すだけなので、下流一致への過剰前景化ではない。
- 原則2/3と整合: 未確定性を一律に保留へ倒す guardrail 追加でも、差分を新しい抽象ラベルへ強制再記述するゲート追加でもなく、次の探索順の置換に留める。

Payment: add MUST("Before finalizing a compare verdict, name the smallest concrete witness that would make the opposite verdict true, and search for that witness next.") ↔ demote/remove MUST("Complete every section. Do not skip to FORMAL CONCLUSION without completing ANALYSIS.")

変更規模の宣言
- 追加・置換は compare セクション内の 8-12 行想定、15 行以内。新規モード追加なし、既存 counterexample 構造は維持。