過去提案との差異: 直近却下された「構造差を特定の観測境界へ写像して探索を狭める」案ではなく、既存の早期 NOT_EQUIVALENT 許可文を、任意の境界固定なしに「少なくとも 1 つのテスト PASS/FAIL 予測差へ到達しているか」という根拠表現へ置換する。
Target: 両方
Mechanism (抽象): 早期結論の IF 条件を「clear structural gap」から「named relevant test の A/B PASS/FAIL 予測差が説明できる structural gap」へ具体化し、偽 NOT_EQUIV と過度な保留の両方を減らす。
Non-goal: 構造差の探索開始点、観測境界、assertion 種別、読むファイル順を固定しない。

カテゴリ E 内での具体的メカニズム選択理由:
- Objective.md のカテゴリ E は曖昧文言の具体化・簡潔化を許す。今回は手順を増やさず、SKILL.md の曖昧な "clear structural gap" を D1 の判定単位である test pass/fail outcomes に合わせて言い換える。
- 表現変更だが、compare の実行時分岐に効く。現在は missing file/module/test data という構造語だけで FORMAL CONCLUSION へ進みやすいが、変更後は同じ構造差を A/B の PASS/FAIL 予測差として言えない場合は ANALYSIS に戻る。

Step 1: 禁止された方向の列挙:
- 再収束を比較規則として前景化し、差分シグナルより後段吸収を既定化する方向は禁止。
- 未確定 relevance や未検証性を広い保留・UNVERIFIED 側の既定動作にする方向は禁止。
- 差分の昇格条件を新しい抽象ラベル、二軸分類、必須の言い換え形式で強くゲートする方向は禁止。
- 終盤の証拠十分性を confidence 調整だけへ吸収して premature closure を増やす方向は禁止。
- 最初に見えた差分から単一の追跡経路・単一の観測点を既定化する方向は禁止。
- 近接欄の統合で探索理由と反証可能な情報利得を潰す方向は禁止。
- 直近却下履歴より、impact witness なしの早期 STRUCTURAL TRIAGE 結論、および「未検証なら保留」を既定化する comparison は禁止。

Step 2 / 2.5: overall に直結する意思決定ポイント候補:
1. STRUCTURAL TRIAGE の早期結論分岐
   - 現在のデフォルト挙動: 構造差が clear に見えると、詳細 ANALYSIS 前に NOT_EQUIVALENT へ進みがち。
   - 変更後の観測可能アウトカム: NOT_EQUIV は named test の A/B PASS/FAIL 差を伴う時だけ早期化し、それ以外は追加探索へ戻る。
2. Step 5.5 の UNVERIFIED 扱い
   - 現在のデフォルト挙動: UNVERIFIED assumption が conclusion を alter しないなら結論へ進むが、alter の判断が曖昧。
   - 変更後の観測可能アウトカム: CONFIDENCE/UNVERIFIED の明示は変わるが、保留側既定化に寄りやすいため今回の主案からは外す。
3. NO COUNTEREXAMPLE EXISTS の探索打ち切り分岐
   - 現在のデフォルト挙動: counterexample pattern を 1 つ具体化して検索できれば EQUIVALENT へ進みがち。
   - 変更後の観測可能アウトカム: EQUIV 前の追加探索量や confidence が変わるが、既存の強い successful template に触れるため回帰リスクが高い。

Step 3: 選ぶ分岐:
- 選択: 1. STRUCTURAL TRIAGE の早期結論分岐。
- 理由 1: IF 条件が FORMAL CONCLUSION へ直行するか ANALYSIS に進むかを直接変えるため、ANSWER と追加探索に差が出る。
- 理由 2: D1 が test pass/fail outcomes を判定単位にしているため、構造差の根拠表現を同じ単位へ揃えるだけで、探索境界を固定せずに偽 NOT_EQUIV を減らせる。

Step 4: 改善仮説:
早期 NOT_EQUIVALENT を許す文言を、構造差の存在ではなく「その構造差が少なくとも 1 つの関連テストで A/B の PASS/FAIL 予測差を生む」という根拠形式へ具体化すると、構造的に大きく見えるがテスト結果が同じ変更を誤って NOT_EQUIVALENT とする失敗を減らし、真の NOT_EQUIVALENT は具体的な diverging prediction により維持される。

SKILL.md の該当箇所と変更:
- 現行引用: "If S1 or S2 reveals a clear structural gap (missing file, missing module update, missing test data), you may proceed directly to FORMAL CONCLUSION with NOT EQUIVALENT without completing the full ANALYSIS section."
- 変更方針: "clear structural gap" という曖昧な根拠型を、"name one relevant test whose A/B PASS/FAIL prediction differs because of that gap" へ置換する。新規モードや新規必須ゲートは追加しない。

Payment: add MUST("(none; no new MUST is introduced)") ↔ demote/remove MUST("(none; replace an existing MAY early-conclusion condition instead)")

Decision-point delta:
Before: IF S1/S2 reveals a clear structural gap THEN proceed directly to NOT EQUIVALENT because structural absence is treated as sufficient evidence.
After:  IF S1/S2 reveals a gap and the gap supports one named relevant test with different A/B PASS/FAIL predictions THEN proceed directly to NOT EQUIVALENT; otherwise continue ANALYSIS because verdict evidence is outcome-level.

変更差分プレビュー:
Before:
```text
If S1 or S2 reveals a clear structural gap (missing file, missing module
update, missing test data), you may proceed directly to FORMAL CONCLUSION
with NOT EQUIVALENT without completing the full ANALYSIS section.
```
After:
```text
If S1 or S2 reveals a structural gap, use early NOT EQUIVALENT only when
that gap explains one named relevant test whose A/B PASS/FAIL predictions
differ; otherwise continue ANALYSIS.
Trigger line (planned): "Early structural NOT EQUIVALENT needs one named relevant test with different A/B PASS/FAIL predictions."
```

Discriminative probe:
抽象ケース: 片方だけが補助ファイルを変更しているが、関連テストはその補助ファイルを読み込まず、両変更とも同じ公開 API 経路で fail-to-pass を満たす。
Before では「missing file」という構造差だけで偽 NOT_EQUIVALENT に進みがち。After では named relevant test の A/B PASS/FAIL 差を言えないため ANALYSIS に進み、同一 outcome を確認して偽 NOT_EQUIV を避ける。
これは新しい必須ゲートではなく、既存の早期結論許可文の置換であり、真の NOT_EQUIV では同じ構造差から diverging PASS/FAIL prediction を示せるため打ち切り可能性は残る。

failed-approaches.md との照合:
- 原則 2 との整合: 未検証なら保留という fallback を追加しない。結論に進む条件を outcome evidence へ具体化するだけで、UNVERIFIED や保留を既定化しない。
- 原則 3 / 5 との整合: 新しい抽象ラベルや単一観測アンカーを作らない。任意の relevant test の PASS/FAIL prediction で足り、探索経路や assertion boundary は固定しない。

Step 5: Before/After の挙動差:
Before: IF 構造差が clear に見える THEN 早期 NOT_EQUIVALENT に進むため、差分が既存テスト outcome に到達しない抽象ケースで偽 NOT_EQUIV が起きがち。
After: IF 構造差が relevant test の A/B PASS/FAIL 差を説明できない THEN ANALYSIS を継続するため、偽 NOT_EQUIV を避け、証拠が揃えば EQUIV または低 CONFIDENCE の根拠付き結論にできる。

変更規模の宣言:
SKILL.md の既存 3 行を 4 行程度に置換し、Trigger line 1 行を追加する。差分は合計 5 行前後、hard limit 15 行以内。
