過去提案との差異: これは STRUCTURAL TRIAGE や早期 NOT_EQUIV 条件の境界設定をいじる案ではなく、compare の直前で発火する重複チェックゲートを削って結論分岐を軽くする提案である。
Target: 両方
Mechanism (抽象): 結論直前の独立した checklist gate を、既存の compare certificate に内在する証拠判定へ吸収し、非決定的な未解決事項は再探索トリガではなく CONFIDENCE へ送る。
Non-goal: 構造差の昇格条件、早期 NOT_EQUIV 条件、観測境界の定義は変更しない。

カテゴリ G 内での候補整理:
1. Step 5.5「Pre-conclusion self-check」
   - 現在のデフォルト挙動: どれか 1 項目でも NO だと Step 6 に進まず、結論より checklist 修復を優先しがち。
   - 変更後に変わるアウトカム: 過度な保留/追加探索/UNVERIFIED の拡大を減らし、既に足りている EQUIV / NOT_EQUIV へ進める。
2. Compare checklist
   - 現在のデフォルト挙動: certificate template で既に要求済みの項目を終盤でもう一度満たそうとして、分析が要約整形寄りになりがち。
   - 変更後に変わるアウトカム: 追加探索の減少、CONFIDENCE 記述の簡素化。
3. Guardrails 8-10 と Step 4/6 の不確実性指示の重複
   - 現在のデフォルト挙動: 「不確実性を隠すな」「捏造するな」が複数箇所で再提示され、軽微な未検証を広く保留へ倒しやすい。
   - 変更後に変わるアウトカム: UNVERIFIED 明示は維持しつつ、結論保留の過剰発火を減らせる。

選定: 1. Step 5.5「Pre-conclusion self-check」
理由:
- compare の最終分岐を直接変える。今は「証拠が足りているか」より「独立 checklist が全点灯か」で Step 6 進行が止まりうる。
- Core Method と Compare template の既存要件だけで verdict に必要な証拠はすでに定義されており、追加の必須自己監査は主に再探索の既定化として働く。

改善仮説:
独立した Step 5.5 の必須 self-check は、compare に必要な証拠要求を増やしているのではなく、既存要件の重複確認を別ゲートとして再度 mandatory 化している。そのゲートを compare の結論条件へ統合すると、非決定的な未解決事項まで一律に再探索へ送る癖が弱まり、EQUIV/NOT_EQUIV の両側で過度な保留を減らせる。

該当箇所と変更方針:
- 現行引用: "### Step 5.5: Pre-conclusion self-check (required)" / "If any answer is NO, fix it before Step 6."
- 変更方針: Step 5.5 の独立セクションを削除し、compare 側に「verdict を左右しない未解決は CONFIDENCE に送る」1 行を入れて、重複ゲートを結論規則へ吸収する。

Payment: add MUST("If the compare certificate already establishes identical or different test outcomes, conclude and carry any remaining non-decisive uncertainty into CONFIDENCE rather than reopening analysis.") ↔ remove MUST("Before writing the formal conclusion, check each item below. If any answer is NO, fix it before Step 6.")

Decision-point delta:
Before: IF Step 5.5 の4項目のどれかが NO THEN Step 6 を止めて追加探索/修復に戻る because 独立した checklist completeness gate
After:  IF per-test trace と counterexample/no-counterexample が verdict を既に決め、残る未解決が非決定的 THEN Step 6 に進み未解決は CONFIDENCE/uncertainty に明示する because compare certificate sufficiency gate

変更差分プレビュー:
Before:
- ### Step 5.5: Pre-conclusion self-check (required)
- Before writing the formal conclusion, check each item below. If any answer is NO, fix it before Step 6.
- - [ ] Every PASS/FAIL or EQUIVALENT/NOT_EQUIVALENT claim traces to a specific `file:line`
- - [ ] Every function in the trace table is marked **VERIFIED**, or explicitly **UNVERIFIED**...
After:
- Trigger line (planned): "If the compare certificate already establishes identical or different test outcomes, conclude and carry any remaining non-decisive uncertainty into CONFIDENCE rather than reopening analysis."
- ### Step 6: Formal conclusion
- Write a conclusion that:
- - States what remains uncertain or unverified
- - Assigns a confidence level: HIGH / MEDIUM / LOW

Discriminative probe:
抽象ケース: 主要な fail-to-pass test では両変更の PASS/FAIL 差が file:line 付きで確定している一方、周辺の third-party helper 1 個だけが UNVERIFIED のまま残る。
変更前は Step 5.5 の NO が独立ゲートとして効き、偽 EQUIV/偽 NOT_EQUIV ではなく「過度な保留」や不要な再探索に流れやすい。変更後は、その helper が verdict 非決定的なら UNVERIFIED を明示したまま CONFIDENCE を下げて結論できるため、追加の必須ゲートを増やさず停滞を避ける。

failed-approaches.md との照合:
- 原則2と整合: 未解決事項を広い既定動作として保留側へ倒す新しい guardrail を足すのではなく、既存の保留誘発ゲートを1つ減らす。
- 原則3と整合: 差分の昇格条件に新しい抽象ラベルや観測境界を追加しない。compare の証拠形式そのものは維持する。

変更規模の宣言:
削除 6-8 行、追加 1-2 行の置換で収まり、hard limit 15 行以内。