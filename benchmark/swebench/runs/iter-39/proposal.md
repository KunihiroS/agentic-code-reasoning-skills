過去提案との差異: iter-33/34/38 のような「結論直前メタ判断の追加」や「探索経路の半固定化」ではなく、compare の既存“早期 NOT_EQUIV”分岐の根拠表現だけを具体化して早期断定の誤爆を減らす。
Target: 偽 NOT_EQUIV（副作用として偽 EQUIV の増加を避ける）
Mechanism (抽象): 「STRUCTURAL TRIAGE だけで NOT_EQUIV に直行できる条件」を、根拠を伴うときだけ発火するように言語化し、根拠が薄いときは ANALYSIS へ押し戻す。
Non-goal: STRUCTURAL TRIAGE の探索対象（どの境界・どの証拠種類を探すか）を事前固定したり、新しい必須ゲートを増設したりしない。

---

Step 1 — 禁止された方向（failed-approaches + 却下履歴の要約）
- 証拠の種類や読解順序をテンプレで事前固定し、探索経路を半固定にする変更は不可（確認バイアス/探索の入口狭窄）。
- 既存の判定基準を「特定の観測境界だけ」に過度に還元して狭める変更は不可（構造差→特定 witness への写像で他の有効シグナルを落とす）。
- ドリフト抑制の名目で探索の自由度を削りすぎる変更は不可（局所最適で全体性能を落とす）。
- 結論直前に新しい必須メタ判断（最弱点→確信度等）を純増させる変更は不可（機能重複・萎縮）。
- focus_domain の片方向最適化で逆側を悪化させる設計は不可（overall では両側を悪化させない）。
- proposal に具体 ID/固有参照を埋め込む汎化性違反は不可。

---

Step 2 — SKILL.md から「意思決定ポイント（IF/THEN 分岐）」候補（3つ）
候補A（compare / 早期結論分岐）:
- 分岐: IF “S1/S2 で clear structural gap” THEN “ANALYSIS を飛ばして NOT EQUIVALENT 結論へ直行可能”。

候補B（compare / EQUIV 主張時の探索の打ち切り分岐）:
- 分岐: IF “EQUIVALENT を主張する” THEN “NO COUNTEREXAMPLE EXISTS 節で counterexample を具体化し、同パターンを検索して ‘NONE FOUND’ を根拠に結論”。

候補C（core / UNVERIFIED の扱いによる結論可否）:
- 分岐: IF “trace table に UNVERIFIED が残る” THEN “仮定が結論を変えないと扱って結論へ進む or 不確実性としてスコープ/確信度に反映して保留/限定する”。

Step 2.5 — 各候補の「現在のデフォルト挙動」と「観測可能なアウトカム変化」
- 候補A: 現在は ‘clear’ の解釈が曖昧なまま、早めに NOT_EQUIV へ直行しがち。アウトカム: 偽 NOT_EQUIV（早期結論） or 追加探索の省略。
- 候補B: 現在は counterexample の具体化が浅いと、探索が早めに打ち切られ EQUIV に寄りがち。アウトカム: 偽 EQUIV or 追加探索の不足。
- 候補C: 現在は “assumption that does not alter the conclusion” の自己判断で UNVERIFIED を押し流しがち。アウトカム: 誤った ANSWER / 不適切な CONFIDENCE（過信）/ UNVERIFIED の不明瞭化。

---

Step 3 — 選ぶ分岐（1つ）
選択: 候補A（compare の早期 NOT_EQUIV 直行分岐）
理由（2点以内）:
1) compare で最も大きくアウトカムを変えるのが「ANALYSIS を飛ばして結論へ進む」分岐で、ここを押し戻せると誤判定が直接減りうる。
2) 文言の曖昧さ（clear structural gap）が早期断定を誘発しやすく、フォーマット具体化（カテゴリE）だけで IF 条件と THEN 行動の両方に差を作れる。

---

Step 4 — 改善仮説（1つ）
仮説: “早期 NOT_EQUIV 直行”を許す条件を「構造差がテスト結果に影響するという根拠が1つでも言語化できる場合」に限定して書き換えると、根拠の薄い構造差での偽 NOT_EQUIV を減らしつつ、真の NOT_EQUIV は後段 ANALYSIS で回収できる。

---

Step 5 — 抽象ケースでの Before/After の挙動差（結末つき）
抽象ケース:
- 変更Aは “追加のファイル/データ” に手を入れるが、既存の relevant tests はそれを import/参照/読み込みしない（実際の PASS/FAIL は変わらない）。変更Bはその追加物に触れない。
Before（起きがち）: S1 で「片側だけファイルがある」= clear structural gap と解釈され、ANALYSIS を飛ばして NOT_EQUIV を早期結論 → 偽 NOT_EQUIV。
After（避け方）: “relevant-test dependency witness” が言語化できない限り早期結論できず、ANALYSIS に進んで「テストが触れていない」根拠を集めた上で EQUIV（modulo tests）へ到達 → 偽 NOT_EQUIV を回避。

---

カテゴリEとしてのメカニズム選択理由
- 追加の手順や新モード導入ではなく、既存の compare 分岐（早期結論）にある曖昧語 “clear structural gap” を、結論に必要な根拠型（test-outcome への関係づけ）へ寄せて明確化するだけ。
- これにより、同じ STRUCTURAL TRIAGE を維持しつつ「根拠が薄いときのデフォルト行動（早期断定）」を「追加探索（ANALYSIS 継続）」へ切り替える分岐差を作れる。

SKILL.md 該当箇所（短い引用）と変更
引用（現状）:
- “If S1 or S2 reveals a clear structural gap (missing file, missing module update, missing test data), you may proceed directly to FORMAL CONCLUSION with NOT EQUIVALENT without completing the full ANALYSIS section.”

変更方針:
- “clear structural gap” のまま直行するのではなく、早期直行は「relevant test との依存関係を示す witness を最低1つ書ける」ときに限定し、書けないなら ANALYSIS に進む、と一文で具体化する。

Decision-point delta (IF/THEN, 2 lines)
Before: IF S1/S2 suggests a “clear structural gap” THEN skip ANALYSIS and conclude NOT EQUIVALENT because structural mismatch is treated as sufficient.
After:  IF S1/S2 suggests a structural gap AND a relevant-test dependency witness can be stated THEN skip ANALYSIS and conclude NOT EQUIVALENT; ELSE continue into ANALYSIS because impact is not yet evidenced.

変更差分プレビュー（Before/After, 3–10 lines）
Before:
- If S1 or S2 reveals a clear structural gap (missing file, missing module
- update, missing test data), you may proceed directly to FORMAL CONCLUSION
- with NOT EQUIVALENT without completing the full ANALYSIS section.

After:
- If S1 or S2 reveals a structural gap AND you can state at least one relevant-test dependency witness (e.g., import/call path/test-data reference),
- you may proceed directly to FORMAL CONCLUSION with NOT EQUIVALENT; otherwise continue into ANALYSIS to establish or refute impact.
- Trigger line (planned): "If S1 or S2 reveals a structural gap AND you can state at least one relevant-test dependency witness ..."

Discriminative probe（抽象ケース、2–3行）
- 片側だけ“追加物”があるが、relevant tests がそれに触れないケースでは、Before は ‘clear structural gap’ だけで NOT_EQUIV を早期断定しやすい。
- After は witness を書けないため ANALYSIS に進み、「テストが依存していない」根拠を集めて EQUIV（modulo tests）へ戻せる（新しい必須ゲート増設ではなく、早期直行の根拠表現の具体化）。

failed-approaches.md との照合（整合点）
- 「観測境界への過度な還元」を避けるため、witness を単一境界に固定せず（import/call path/test-data reference など複数型を許容）、早期結論の根拠明確化に限定する。
- 「結論直前の必須メタ判断の純増」を避け、既存の分岐（早期結論）に対する文言の具体化で挙動差を作る（チェック項目純増ではない）。

Payment
- Payment: add MUST("(none)") ↔ demote/remove MUST("(none)")  # MUST の純増なし（既存文言の置換のみ）

変更規模の宣言
- SKILL.md の置換は 2–3 行相当（hard limit 5 行以内）。新規モード追加なし。新しい必須ゲートの純増なし。