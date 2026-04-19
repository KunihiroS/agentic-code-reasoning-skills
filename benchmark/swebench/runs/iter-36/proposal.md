1) 過去提案との差異: 「探索を特定の観測境界へ写像して狭める」方向ではなく、既存の早期 NOT_EQUIV 分岐に“根拠の具体化(impact witness)”を要求して早計な短絡だけを抑える。
2) Target: 両方（特に偽 NOT_EQUIV と audit の改善、ただし EQUIV 側の萎縮を増やさない）
3) Mechanism (抽象): compare の STRUCTURAL TRIAGE で早期結論に飛ぶ条件を「構造差そのもの」から「構造差＋影響の目撃(impact witness)」へ寄せ、情報取得(何を確認してから結論へ進むか)の分岐を変える。
4) Non-goal: 構造差を“特定の観測境界だけ”に還元して探索経路を半固定化すること、また新しい必須フェーズ/モードを増やすことはしない。


[Step 1 — 禁止方向の列挙（failed-approaches + 却下履歴から）]
- 証拠タイプのテンプレ事前固定（「この証拠を探せ」を固定しすぎて探索自由度を削る）
- 既存の判定基準を特定の観測境界だけに過度に還元（構造差→境界写像で狭める）
- 読解順序・探索入口の半固定（どこから読むべきかを強く決め打ち）
- ドリフト対策の名目で局所の“もっともらしさ”を押し付け、未列挙論点の発見を弱める
- 結論直前に新しい必須メタ判断を増やす（既存の反証義務と重複し、片方向に萎縮させる）


[Step 2 — overall に直結する意思決定ポイント候補（IF/THEN 分岐）]
候補A（compare / 早期結論の分岐）:
- IF STRUCTURAL TRIAGE が「明確な structural gap」を示す THEN ANALYSIS をスキップして NOT EQUIVALENT に進む（SKILL.md に明記）

候補B（compare / EQUIV 主張時の探索継続分岐）:
- IF EQUIVALENT を主張しつつ「counterexample の形」が具体化できない THEN 追加探索を要求する / あるいは結論を保留・低信頼に倒す

候補C（Core / UNVERIFIED の扱いによる探索優先分岐）:
- IF UNVERIFIED が最終結論を反転させうる依存点にある THEN 次アクションを「間接証拠（呼び出し箇所・テスト利用・doc）」の取得へ寄せる ELSE そのまま進み不確実性を明示


[Step 2.5 — 各候補のデフォルト挙動と、変更後に観測可能に変わるアウトカム（各1行）]
- 候補A: デフォルト= structural gap を見た時点で NOT_EQUIV に短絡しがち / 変更後= NOT_EQUIV へ進む前に「影響の目撃」を要求でき、偽 NOT_EQUIV と audit の弱さが減る（必要なら追加探索へ分岐）
- 候補B: デフォルト= “NO COUNTEREXAMPLE EXISTS” が抽象のままでも EQUIV 結論へ進みがち / 変更後= 追加探索 or 低信頼へ分岐し、偽 EQUIV を抑える
- 候補C: デフォルト= UNVERIFIED を置いたまま結論へ寄りがち / 変更後= 追加探索（間接証拠の収集）へ分岐し、保留/UNVERIFIED 明示が増える


[Step 3 — 今回選ぶ分岐（1つ）]
選定: 候補A（compare の STRUCTURAL TRIAGE → 早期 NOT_EQUIV 分岐）
理由（2点以内）:
- compare で「ANALYSIS を省略して結論へ進む」明示分岐があり、実行時アウトカム（NOT_EQUIV / 追加探索 / audit 証拠密度）が確実に変わりうる。
- 現状は早期 NOT_EQUIV の“根拠の型”が薄くなりやすく、偽 NOT_EQUIV だけでなく監査時の説明（なぜそれがテスト結果差につながるのか）も弱くなりやすい。


[Step 4 — 改善仮説（1つ、抽象・汎用）]
仮説: 構造差で早期 NOT_EQUIV に飛ぶときに「影響の目撃（impact witness）」を必須化（ただし新フェーズ追加ではなく既存の結論文の要件として）すると、構造差が“テスト結果差に接続する”ことを最小コストで確認する分岐が働き、偽 NOT_EQUIV を減らしつつ真の NOT_EQUIV は維持できる。


[Step 5 — 抽象ケースでの Before/After 挙動差（結末を明記）]
ケース: Change A は2ファイルに触れるが、片方は実質的にテスト結果へ影響しない（コメント/デッドコード/未参照の補助）。Change B は影響しない側の変更を含めない。
- Before: structural gap（片方のファイル欠落）だけで早期 NOT_EQUIV に進み、偽 NOT_EQUIV が起きがち。
- After: 早期結論に進むには「どのテスト/どの assertion boundary/どの具体使用が変わるか」という impact witness を書ける必要がある。書けない場合は ANALYSIS に進んで影響接続を探す（結末: 偽 NOT_EQUIV を回避し、EQUIV か UNVERIFIED/低信頼として扱う）。


カテゴリB内でのメカニズム選択理由:
- 変更点は「何を探すか（証拠タイプの固定）」ではなく、「早期結論に進む前に最低限どの情報を取得しておくか」を具体化するもの。
- 読解順序の半固定ではなく、既存の早期ショートカット分岐に対する“根拠取得の要件”を追加するため、探索自由度の削減よりも誤短絡の抑制に寄る。


該当箇所（SKILL.md 自己引用）と変更:
- 現行（compare / 証明書テンプレ冒頭）:
  "Complete every section. Do not skip to FORMAL CONCLUSION without completing ANALYSIS."
- 現行（compare / STRUCTURAL TRIAGE 後の早期結論案内）:
  "If S1 or S2 reveals a clear structural gap (missing file, missing module\nupdate, missing test data), you may proceed directly to FORMAL CONCLUSION\nwith NOT EQUIVALENT without completing the full ANALYSIS section."

Payment（必須ゲート純増を避けるための入替）:
Payment: add MUST("If you take the structural-triage early-exit, you MUST state an impact witness...") ↔ demote/remove MUST("Complete every section.")


Decision-point delta（IF/THEN 2行）:
Before: IF structural gap を見つけた THEN ANALYSIS を省略して NOT_EQUIV 結論へ進む because 構造差がそのまま非同値を示す
After:  IF structural gap を見つけた THEN （impact witness を書けるなら）ANALYSIS を省略して NOT_EQUIV へ進む;（書けないなら）ANALYSIS へ進む because 構造差がテスト結果差へ接続する根拠を最小限で確認する


変更差分プレビュー（Before/After, 3〜10行）:
Before:
- Complete every section. Do not skip to FORMAL CONCLUSION without completing ANALYSIS.
...
- If S1 or S2 reveals a clear structural gap (missing file, missing module
  update, missing test data), you may proceed directly to FORMAL CONCLUSION
  with NOT EQUIVALENT without completing the full ANALYSIS section.

After:
- Complete every section; exception: if you early-exit after STRUCTURAL TRIAGE,
  you MUST state an impact witness (test/assertion boundary or concrete usage)
  in FORMAL CONCLUSION.
...
- If S1 or S2 reveals a clear structural gap (missing file, missing module
  update, missing test data), you may proceed directly to FORMAL CONCLUSION
  with NOT EQUIVALENT only when you can state an impact witness.

Trigger line (planned): "impact witness (test/assertion boundary or concrete usage)"


Discriminative probe（抽象ケース, 2〜3行）:
- Before は「片側にファイルがない」だけで NOT_EQUIV に飛び、実際にはテスト結果が同じでも偽 NOT_EQUIV になりうる。
- After は early-exit 条件に impact witness が必要なので、影響接続が示せない場合は ANALYSIS へ分岐し、NOT_EQUIV の短絡を避けられる。


failed-approaches.md との整合（1〜2点）:
- 「特定の観測境界だけに過度に還元」を避ける: これは“境界へ写像して狭める”のではなく、早期結論の根拠を具体化して偽 NOT_EQUIV を減らす。
- 「読解順序の半固定を避ける」と整合: どこから読むべきかを固定せず、早期結論を選ぶ場合にだけ最小限の根拠取得を要求する。


変更規模の宣言:
- SKILL.md への変更は 5 行以内（compare セクション内の 2 箇所の文言置換/追記のみ、モード追加なし）。
