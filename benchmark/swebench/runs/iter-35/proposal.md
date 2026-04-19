過去提案との差異: 探索経路や観測境界を固定して狭めるのではなく、「STRUCTURAL TRIAGE→即結論」のショートカットだけを抑制し、既存の COUNTEREXAMPLE 証拠要求を早期結論にも適用する。
Target: 両方（偽 NOT_EQUIV と偽 EQUIV の双方の抑制）
Mechanism (抽象): 早期 NOT_EQUIV を許す分岐を「結論へ直行」から「テスト影響の証拠（impact witness）を伴う場合のみ直行」へ置換し、証拠が薄いときは ANALYSIS に戻す。
Non-goal: 構造差を特定の観測境界へ写像して“その境界だけ”を探させる／新しい必須ゲートを純増する。


ステップ1（禁止方向の列挙: failed-approaches + 却下履歴の要約）
- 証拠の種類や探索入口をテンプレで事前固定しすぎる（探索が「正当化」→「特定シグナルの捜索」に寄って確認バイアス化）。
- 既存の判定基準を「特定の観測境界だけ」に還元して狭める（構造差→境界写像の過度な限定）。
- 読解順序・境界確定順を半固定して探索自由度を削る。
- 局所的な仮説更新を、即座の前提修正義務へ直結させる。
- 既存ガードレールを特定方向（特定トレース/最小分岐など）へ具体化しすぎる。
- 結論直前に新しい必須のメタ判断（最弱点→確信度など）を増やす／片方向（EQUIV だけ or NOT_EQUIV だけ）に萎縮・偏りやすい変更。


ステップ2（SKILL.md から overall に直結する意思決定ポイント候補 3 つ）
1) Compare: STRUCTURAL TRIAGE の早期 NOT EQUIVALENT 直行
   - 根拠箇所: 「If S1 or S2 reveals... you may proceed directly to FORMAL CONCLUSION with NOT EQUIVALENT...」
2) Compare: パス・ツー・パス（pass-to-pass）を “changed code lies in their call path” のときだけ relevant にする分岐
   - 根拠箇所: D2(b) 「relevant only if the changed code lies in their call path」
3) Core Step 5.5: UNVERIFIED が結論を変えうるときの扱い（結論に進む/戻るの分岐）
   - 根拠箇所: Step 5.5 「UNVERIFIED ... with a stated assumption that does not alter the conclusion」

ステップ2.5（各候補のデフォルト挙動と、変化するアウトカム）
1) デフォルト: S1/S2 の “clear structural gap” を見つけると ANALYSIS を飛ばして NOT_EQUIVALENT へ寄りやすい → アウトカム: 偽 NOT_EQUIV（または premature conclusion）
2) デフォルト: call path 同定が粗い/未検証だと pass-to-pass を落としやすい → アウトカム: 偽 EQUIV（差があるのに SAME 扱い）
3) デフォルト: UNVERIFIED が残ると「結論を縮める」か「保留へ倒す」かが曖昧で、モデルが場当たりに流れやすい → アウトカム: 保留/CONFIDENCE の不安定化


ステップ3（1 つだけ選ぶ）
選択: 1) Compare の「STRUCTURAL TRIAGE→即 NOT_EQUIVALENT 結論」分岐
理由（2点）:
- compare の結論ラベル（EQUIV/NOT_EQ）へ直結する分岐で、条件/行動を少数行で実際に変えられる。
- D1 が “test outcomes” を定義基盤にしているのに、早期直行が「テスト影響の証拠」を省略しうるため、ここを整えると両ラベルの誤判定を同時に減らせる。


ステップ4（改善仮説: 1つ）
仮説: 「構造差がある」という事実だけで NOT_EQUIV に直行できる抜け道を塞ぎ、直行するなら “テストの PASS/FAIL に結びつく具体的な影響の目撃（impact witness）” を添えるよう分岐を再配置すると、偽 NOT_EQUIV を減らしつつ、偽 EQUIV も増やさない（影響が不明なら ANALYSIS に戻るため）。


ステップ5（抽象ケースで Before/After の挙動差）
- 抽象ケース: 変更Aは「テストと無関係な補助ファイル」も触るが、変更Bは触らない。STRUCTURAL TRIAGE では S1 で差が見えるが、実際のテスト・アサーション経路には現れない。
  - Before: IF「S1で片側だけが触るファイルがある」THEN「ANALYSISを飛ばして NOT_EQUIVALENT 結論へ」→ 偽 NOT_EQUIV が起きがち。
  - After: 早期直行するなら “どのテストのどの assertion / import / data参照で差が効くか” を先に言語化・引用できる必要があり、できないなら ANALYSIS に戻る → 影響なしを確認して EQUIV へ収束できる。


カテゴリAとしての具体メカニズム（順序・構造の変更）
- 「STRUCTURAL TRIAGE→FORMAL CONCLUSION 直行」を、
  (a) STRUCTURAL TRIAGE
  (b) （直行するなら）COUNTEREXAMPLE の “impact witness” を最小限で埋める
  (c) それが出せないなら ANALYSIS へ
に再配線する。新しい探索入口や証拠種の固定ではなく、既存テンプレ内の“スキップ可能な枝”だけを、証拠付きの枝へ接続し直す。


SKILL.md 該当箇所（引用）と変更
引用（現状）:
- "If S1 or S2 reveals a clear structural gap (missing file, missing module\nupdate, missing test data), you may proceed directly to FORMAL CONCLUSION\nwith NOT EQUIVALENT without completing the full ANALYSIS section."

変更意図:
- 「直行」を許すなら、D1（テスト結果同一性）に接続する最小限の証拠（impact witness）を先に提示させ、提示できない場合は直行をやめて ANALYSIS に戻す。


Decision-point delta（IF/THEN 2行）
Before: IF S1/S2 shows a clear structural gap THEN jump to FORMAL CONCLUSION (NOT EQUIVALENT) because structural mismatch is treated as sufficient
After:  IF S1/S2 shows a clear structural gap AND you can cite a concrete test-impact witness THEN jump to FORMAL CONCLUSION (NOT EQUIVALENT); ELSE continue into ANALYSIS because impact must connect to D1’s test outcomes


変更差分プレビュー（Before/After、3–10行）
Before:
- If S1 or S2 reveals a clear structural gap (missing file, missing module
- update, missing test data), you may proceed directly to FORMAL CONCLUSION
- with NOT EQUIVALENT without completing the full ANALYSIS section.
After:
- If S1 or S2 reveals a clear structural gap (missing file, missing module
- update, missing test data), you may skip detailed tracing, but do not skip
- COUNTEREXAMPLE: cite the concrete test-impact witness (e.g., import/use/assert)
- with file:line. If you cannot yet cite such a witness, continue into ANALYSIS.

Trigger line (planned): "If you cannot yet cite a concrete test-impact witness, continue into ANALYSIS."


Discriminative probe（2–3行、抽象ケース）
- Before は「差分ファイルの不一致」だけで NOT_EQUIV へ直行し、テスト非到達な差でも偽 NOT_EQUIV になりうる。
- After は「どのテストのどの assertion に差が現れるか」を最小限で提示できない限り直行できず、影響不明は ANALYSIS に戻して EQUIV/NOT_EQ の根拠を分離できる。


failed-approaches.md との照合（整合 1–2点）
- 「特定の観測境界だけに過度に還元」するのではなく、直行結論の“根拠の具体化”として impact witness を要求し、提示不能なら探索自由度を維持したまま ANALYSIS に戻す（探索入口の固定を避ける）。
- 結論直前の新規メタ判断を増やさず、既存テンプレ内の COUNTEREXAMPLE 要件を早期結論の枝にも適用するだけで、チェック純増を避ける。


Payment
- Payment: none（新しい MUST ゲートの純増なし。既存の "COUNTEREXAMPLE (required if claiming NOT EQUIVALENT)" の適用範囲を、STRUCTURAL TRIAGE 早期直行の枝にも明示的に接続するだけ）

変更規模の宣言
- SKILL.md の Compare セクション内、早期直行の説明文を 4 行以内で置換（全体 5 行以内）。
