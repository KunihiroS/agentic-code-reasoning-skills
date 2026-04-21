過去提案との差異: これは STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を観測境界へ狭める案ではなく、既存の UNVERIFIED 文言を verdict 依存性で言い分けて compare の分岐を変える案である。
Target: 両方
Mechanism (抽象): 「未検証の仮定を書いたら通過」から「その未検証リンクが verdict を支えているか」を明示させる表現に置換し、結論・保留・CONFIDENCE の分岐を変える。
Non-goal: 構造差から NOT_EQUIV へ進む条件を特定の assertion/test 境界へ写像して狭めることはしない。

カテゴリ E の選択理由:
現行の「UNVERIFIED with a stated assumption that does not alter the conclusion」は、(a) 未検証リンクの記録 と (b) verdict 依存性の判定 を 1 句に圧縮しており、haiku が「仮定を書いたので通過」と処理しやすい。ここを分解して sentence stem を具体化すると、比較の停止/続行/低信頼化が実際に変わる。

改善仮説:
UNVERIFIED の扱いを「未検証である事実」ではなく「そのリンクが verdict の唯一の支えかどうか」で書き分けると、偽 EQUIV と偽 NOT_EQUIV の両方を減らしつつ、無関係な未検証リンクによる過度な保留も増やさない。

該当箇所と変更方針:
- Step 4: "If source is unavailable ... mark UNVERIFIED and note the assumption."
- Step 5.5: "... UNVERIFIED with a stated assumption that does not alter the conclusion."
この 2 箇所を、assumption の有無ではなく verdict-dependence を先に判定する文言へ置換する。

Decision-point delta:
Before: IF 主要な推論鎖に UNVERIFIED があっても「結論を変えない仮定」と言い換えられる THEN そのまま ANSWER を確定する because 記録義務はあるが、verdict 依存の判定手順は明文化されていない。
After:  IF ANSWER がその UNVERIFIED リンクなしでは立たない THEN 結論確定を止めて provisional/LOW confidence または追加探索へ回す because verdict-bearing assumption を別扱いする文言に変わる。

Payment: add MUST("If the answer depends on an UNVERIFIED link, do not finalize from that link alone; mark the dependency and keep the verdict provisional or LOW confidence.") ↔ demote/remove MUST("Every function in the trace table is marked VERIFIED, or explicitly UNVERIFIED with a stated assumption that does not alter the conclusion.")

変更差分プレビュー:
Before:
- If source is unavailable (third-party library), mark UNVERIFIED and note the assumption.
- [ ] Every function in the trace table is marked VERIFIED, or explicitly UNVERIFIED with a stated assumption that does not alter the conclusion.
After:
- If source is unavailable, mark UNVERIFIED and state whether the current verdict is independent of that link.
- Trigger line (planned): "If the answer depends on an UNVERIFIED link, do not finalize from that link alone; keep the verdict provisional or LOW confidence and name the missing evidence."
- [ ] Every traced function is VERIFIED, or UNVERIFIED with its verdict-independence stated.

Discriminative probe:
抽象ケース: 両変更の差分は repo 外ライブラリの戻り値解釈を 1 箇所だけ経由して test outcome に届く。変更前は、その箇所を「たぶん harmless」と書いて偽 EQUIV か偽 NOT_EQUIV を出しがち。変更後は、そのリンクが verdict-bearing だと明示されるため、結末は確定回答ではなく provisional/LOW confidence か追加探索になり、誤判定を避ける。

failed-approaches.md との照合:
- 原則 2 に反しない: 未確定性を広く保留側へ倒す既定動作は増やさず、「verdict を支える未検証リンク」という局所条件にだけ作用する。
- 原則 3 に反しない: 新しい抽象ラベルで差分昇格をゲートせず、既存の UNVERIFIED 記録義務の文言を具体化するだけである。

変更規模の宣言:
置換中心で 6-8 行以内。新規モード追加なし、必須総量は payment の範囲で不変。