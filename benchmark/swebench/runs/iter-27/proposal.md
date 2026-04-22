過去提案との差異: これは structural triage の早期 NOT_EQUIV 条件を別の観測境界へ写像する案ではなく、結論直前の重複ゲートを削って compare の停止点を変える提案である。
Target: 両方
Mechanism (抽象): Step 5.5 の重複 self-check を除去し、Step 5 の refutation を唯一の結論前ゲートに戻して、未解決性の既定アウトカムを「追加探索」から「明示付き結論」へ切り替える。
Non-goal: structural gap から NOT_EQUIV を出す条件そのものや、特定の観測境界への結び付けは変更しない。

カテゴリ G 内での具体的メカニズム選択理由:
- 候補1: Step 5.5 の mandatory self-check 削除。現在の既定挙動は、証拠が足りていても checklist の NO で追加探索へ戻りがち。変更後は 結論保留/追加探索 が減り、UNVERIFIED を明示したまま Step 6 に進める。
- 候補2: Compare checklist の structural-first 重複圧縮。現在の既定挙動は、template と checklist の二重強調で高レベル比較へ寄りがち。変更後は 追加探索 の優先順が少し変わるが、主分岐の変更は弱い。
- 候補3: Step 3 の OPTIONAL INFO GAIN 削除。現在の既定挙動は、説明負荷が増えるだけで分岐はほぼ不変。変更後に観測可能なアウトカム差が弱い。

選定: 候補1。
理由は 2 点だけ: (1) compare の実行時分岐が明示的に「NO なら Step 6 禁止」になっており、結論保留/追加探索を直接増やすから。 (2) Step 4・Step 5・Guardrails・Minimal Response Contract と重複していて、削除しても研究のコア構造を壊さないから。

改善仮説:
結論直前の第二 mandatory gate は、新しい証拠生成よりも checklist 充足を優先させ、bounded な未検証事項まで追加探索へ押し戻すため、これを削って Step 5 の refutation に統合した方が偽 EQUIV/偽 NOT_EQUIV を増やさず過度な保留を減らせる。

該当箇所と変更:
- 現行引用: "### Step 5.5: Pre-conclusion self-check (required)" / "If any answer is NO, fix it before Step 6."
- 変更: Step 5.5 の checklist 全体を削除し、Step 6 の直前に「Step 5 完了後は、結論非依存の未検証事項を追加探索で埋めず、UNVERIFIED として明示して結論へ持ち込む」という 1 行に置換する。
Payment: add MUST("If Step 5 is complete, carry bounded non-decisive uncertainty into Step 6 as explicit UNVERIFIED scope instead of reopening exploration solely to satisfy a duplicate checklist.") ↔ remove MUST("If any answer is NO, fix it before Step 6.")

Decision-point delta:
Before: IF pre-conclusion checklist に 1 つでも NO が残る THEN Step 6 に進まず追加探索/修正へ戻る because duplicated mandatory gate.
After:  IF Step 5 が完了し残余不確実性が結論非依存と局所化できる THEN UNVERIFIED を明示して Step 6 に進む because refutation-complete evidence gate.

変更差分プレビュー:
Before:
- "### Step 5.5: Pre-conclusion self-check (required)"
- "If any answer is NO, fix it before Step 6."
- four-item checklist
After:
- "### Step 5.5: Pre-conclusion note"
- Trigger line (planned): "If Step 5 is complete, carry bounded non-decisive uncertainty into Step 6 as explicit UNVERIFIED scope instead of reopening exploration solely to satisfy a duplicate checklist."
- "Do not use a second checklist as a separate gate; report remaining limits in Step 6."

Discriminative probe:
抽象ケース: 両変更とも同じ assertion outcome まで trace できているが、途中に third-party helper が 1 つあり source 不在で UNVERIFIED。変更前は Step 5.5 の "Every function ... VERIFIED, or explicitly UNVERIFIED..." を満たすため追加探索/保留に寄りやすい。変更後は、その helper が結論非依存と示せていれば Step 6 で明示して EQUIV/NOT_EQUIV 判定まで進めるので、過度な保留を避ける。

Runtime delta check:
変更前でも変更後でも同じ結論・同じ追加探索になるなら、この案は無効。無効でない理由は、"NO なら Step 6 禁止" という実行時分岐を削るため、bounded uncertainty 下でのアウトカムが 追加探索/保留 から 明示付き結論 へ実際に変わるから。

failed-approaches.md との照合:
- 原則2と整合: 未確定性を広い既定動作として保留側へ倒す重複ゲートを削るので、未解決状態そのものを強い fallback signal にしない。
- 原則3と整合: 新しい抽象ラベルや中間表現は追加せず、既存の refutation gate へ統合するだけである。

変更規模の宣言:
15 行以内。実質は Step 5.5 の 6-7 行削除と Step 6 直前の 1-2 行置換で収まる。