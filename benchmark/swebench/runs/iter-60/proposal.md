過去提案との差異: iter-59 のように証拠十分性チェックを CONFIDENCE/UNVERIFIED 処理へ吸収せず、既存の NOT_EQUIV 用 COUNTEREXAMPLE 欄の表現を outcome witness 付きに置換して早期結論の根拠型だけを明確化する。
Target: 両方
Mechanism (抽象): 構造差を見つけたときの分岐を、missing artifact という構造ラベルだけで閉じるのではなく、既存の反例欄に「片側ずつの予測 outcome」を書かせる形式へ具体化する。
Non-goal: 構造差/早期 NOT_EQUIV の条件を特定の観測境界へ狭めたり、新しい探索モードや必須ゲートを増やしたりしない。

カテゴリ E 内での具体的メカニズム選択理由
- E は曖昧文言の具体化なので、既存の `COUNTEREXAMPLE (required if claiming NOT EQUIVALENT)` の記入形式を短く置換する。新しい判定手順ではなく、既存欄の「reason」を outcome witness として書かせる表現改善である。
- Compare の実行時アウトカムに効く分岐は、STRUCTURAL TRIAGE 後に直接 NOT_EQUIV へ進むか、ANALYSIS へ持ち込むかである。ここを「構造ラベル」ではなく「A/B の PASS/FAIL 差を予測できる反例」として書かせると、偽 NOT_EQUIV を減らしつつ、真の NOT_EQUIV は既存反例欄で保てる。

ステップ 1: 禁止方向の列挙
- 原則 1: 再収束を比較規則として前景化し、途中差分を弱める方向は禁止。
- 原則 2: 未確定 relevance や脆い仮定を広く保留/UNVERIFIED 側へ倒す既定動作は禁止。
- 原則 3: 差分の昇格条件を新しい抽象ラベルや必須の言い換え形式で強くゲートする方向は禁止。
- 原則 4: 終盤の証拠十分性チェックを confidence 調整へ吸収する方向は禁止。iter-59 の rejected reason もここに該当。
- 原則 5: 最初に見えた差分から単一追跡経路を即座に固定する方向は禁止。
- 原則 6: 探索理由と反証可能な情報利得を短い要求に潰し、判別力を落とす方向は禁止。
- 追加禁止: 構造差/早期 NOT_EQUIV 条件を「テスト依存」「オラクル可視」「VERIFIED 接続」などの特定観測境界へ写像して狭める方向は禁止。

ステップ 2: overall に直結する意思決定ポイント候補
1. STRUCTURAL TRIAGE の早期終了分岐
   - 現在のデフォルト挙動: S1/S2 が clear structural gap と読めると、詳細 ANALYSIS なしで NOT_EQUIV へ進みがち。
   - 変更後の観測可能アウトカム: outcome witness が書けない場合は結論保留ではなく ANALYSIS へ進み、偽 NOT_EQUIV を減らす。
2. Step 5.5 の evidence sufficiency 分岐
   - 現在のデフォルト挙動: trace が不十分なとき、fix before Step 6 だが何を補うかが広く、追加探索か CONFIDENCE 低下かが揺れやすい。
   - 変更後の観測可能アウトカム: 不足した claim の file:line trace を補う追加探索に寄る。ただし iter-59/原則4と近く、今回は採用しない。
3. NO COUNTEREXAMPLE EXISTS の EQUIV 分岐
   - 現在のデフォルト挙動: counterexample pattern が広く、NONE FOUND の記述だけで EQUIV へ進むか、過度に保留するかが揺れやすい。
   - 変更後の観測可能アウトカム: searched pattern と relevant test outcome の対応が明確になり、偽 EQUIV と過度な保留の両方を抑えうる。ただし今回は NOT_EQUIV 側の早期分岐を優先する。

ステップ 3: 選ぶ分岐
選択: 候補 1、STRUCTURAL TRIAGE 後の早期 NOT_EQUIV 分岐。
- compare の ANSWER が直接変わる。Before は missing file/module/data という構造ラベルだけで NO not equivalent に進みやすいが、After は既存 COUNTEREXAMPLE 欄に A/B の predicted outcome を書ける場合だけ早期結論に進む。
- IF/THEN が変わる。IF は「clear structural gap」から「clear structural gap plus outcome witness」に具体化され、THEN は witness なしなら ANALYSIS 継続へ変わる。

改善仮説
構造差そのものではなく、既存の NOT_EQUIV 反例欄に片側ずつの予測 PASS/FAIL 差を書かせる表現へ置換すると、早期 NOT_EQUIV の根拠が test-relevant な outcome に揃い、偽 NOT_EQUIV を減らしながら真の NOT_EQUIV の反証可能性を保てる。

SKILL.md の該当箇所と変更案
該当引用:
- `If S1 or S2 reveals a clear structural gap ... you may proceed directly to FORMAL CONCLUSION with NOT EQUIVALENT without completing the full ANALYSIS section.`
- `COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):`
- `Test [name] will [PASS/FAIL] with Change A because [reason]`

変更方針:
- 早期終了文を 1 文だけ置換し、既存 COUNTEREXAMPLE 欄を outcome witness 形式に圧縮する。
- 「assertion boundary に限定」ではなく、missing import、missing data、changed call path など任意の構造差が、A/B の relevant outcome 差として書けるかを求める。

Payment: add MUST("For any direct structural NOT EQUIVALENT, the COUNTEREXAMPLE must name the structural gap and predict the relevant outcome for each change.") ↔ remove MUST("Test [name] will [PASS/FAIL] with Change A because [reason] / Test [name] will [FAIL/PASS] with Change B because [reason]")

Decision-point delta
Before: IF S1/S2 reveals a clear structural gap THEN proceed directly to FORMAL CONCLUSION with NOT EQUIVALENT because the gap is structurally clear.
After:  IF S1/S2 reveals a clear structural gap and the existing COUNTEREXAMPLE field can predict different relevant outcomes for A and B THEN proceed to NOT EQUIVALENT; otherwise carry the gap into ANALYSIS because the gap is not yet an outcome witness.

変更差分プレビュー
Before:
```
If S1 or S2 reveals a clear structural gap (missing file, missing module
update, missing test data), you may proceed directly to FORMAL CONCLUSION
with NOT EQUIVALENT without completing the full ANALYSIS section.

COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
  Test [name] will [PASS/FAIL] with Change A because [reason]
  Test [name] will [FAIL/PASS] with Change B because [reason]
```
After:
```
If S1 or S2 reveals a clear structural gap, you may proceed directly only
when the COUNTEREXAMPLE below can state the relevant outcome for each change;
otherwise carry the gap into ANALYSIS as a hypothesis to trace.

COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
  Structural/semantic gap: [what differs]
  Outcome witness: Change A => [PASS/FAIL or behavior], Change B => [PASS/FAIL or behavior]
```
Trigger line (planned): "If S1 or S2 reveals a clear structural gap, you may proceed directly only when the COUNTEREXAMPLE below can state the relevant outcome for each change; otherwise carry the gap into ANALYSIS as a hypothesis to trace."

Discriminative probe
抽象ケース: 片方の変更だけが補助ファイルを編集しているが、関連テストはその補助ファイルを通らない可能性がある。Before では `missing file` ラベルで偽 NOT_EQUIV に進みがち。
After では A/B の outcome witness を書けないため ANALYSIS に持ち込み、実際に関連 outcome が同じなら EQUIV または低 confidence の範囲限定結論へ進める。逆に missing data load が片側だけで FAIL を起こすなら、同じ欄に outcome witness を書けるので真の NOT_EQUIV は維持される。
これは新しい必須ゲートではなく、既存の required COUNTEREXAMPLE の 2 行を置換・圧縮するだけである。

failed-approaches.md との照合
- 原則 3 との整合: 新しい抽象ラベルで差分を昇格させない。`structural/semantic gap` は分類ゲートではなく、既存反例欄の記入対象であり、判定は outcome witness の有無で行う。
- 原則 4 との整合: 証拠十分性を CONFIDENCE/UNVERIFIED へ吸収しない。むしろ NOT_EQUIV の結論に必要な既存反例欄の証拠型を明確にする。
- 追加禁止との区別: 特定の観測境界へ写像しない。assertion line 固定ではなく、relevant outcome を説明できる witness なら import failure、data absence、call-path behavior などを許す。

変更規模の宣言
SKILL.md 変更は既存の早期終了文 3 行と COUNTEREXAMPLE 欄 3 行を、合計 6〜8 行に置換する想定。差分は 15 行以内で、新規モード追加なし、研究コア構造（番号付き前提、仮説駆動探索、手続き間トレース、必須反証）は維持する。
