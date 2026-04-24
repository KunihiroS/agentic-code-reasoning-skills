過去提案との差異: 直近の却下案のように構造差を特定の観測境界へ狭めず、比較単位を「内部挙動」ではなく「各テストの assert/check 結果」に揃える提案である。
Target: 両方
Mechanism (抽象): 同じ relevant test の中で、raw semantic difference と assertion-result difference を分離してから EQUIV / NOT_EQUIV / UNVERIFIED を選ぶ。
Non-goal: 早期 NOT_EQUIV の構造条件を、特定のテスト・オラクル・到達境界へ固定しない。

カテゴリ C 内での具体的メカニズム選択理由
- C の「比較の枠組みを変える」として、比較粒度を「変更箇所の意味差」から「テストごとの outcome-carrying assertion result」へ寄せる。これは新しいモードではなく、既存 Compare template の per-test Comparison 欄の判定粒度を明確化するだけである。
- compare の誤りは、内部挙動差をそのまま DIFFERENT と読む偽 NOT_EQUIV と、内部挙動が似ているため assertion 結果差を見落とす偽 EQUIV の両方で起きる。assert/check 結果を比較単位にすると、両方向の決定条件が同じ軸に揃う。

Step 1: 禁止された方向の列挙
- 再収束を比較規則として前景化し、途中差分シグナルを弱める方向。
- 未確定 relevance や脆い仮定を常に保留へ倒す既定動作。
- 差分昇格を新しい抽象ラベル、必須の言い換え形式、外部可視性フィルタで強くゲートする方向。
- 終盤の証拠十分性チェックを confidence 調整へ吸収して premature closure を増やす方向。
- 最初に見えた差分から単一の追跡経路や共有テストへ探索を固定する方向。
- 探索理由と反証可能な情報利得を短く統合しすぎる方向。
- 直近の却下理由: proposal 本文に具体的な過去 iteration ID を含めること、および構造差/早期 NOT_EQUIV 条件を特定の観測境界だけへ写像して狭めること。

Step 2 / 2.5: overall に直結する意思決定ポイント候補
1. Compare の per-test Comparison 欄
   - 現在のデフォルト挙動: semantic difference と test outcome difference が同じ欄へ流れ込み、不十分な tracing でも SAME/DIFFERENT を選びがち。
   - 変更後の観測可能アウトカム: NOT_EQUIV は assertion-result divergence、EQUIV は identical assertion result、未追跡なら UNVERIFIED/CONFIDENCE へ分かれる。
2. NO COUNTEREXAMPLE EXISTS の observed semantic difference 処理
   - 現在のデフォルト挙動: 1 つの concrete input で同じ assertion outcome を示すことに寄り、差分の種類と outcome の結びつきが局所化しがち。
   - 変更後の観測可能アウトカム: no-counterexample の根拠が「同じ assertion result」に限定され、足りなければ EQUIV ではなく impact UNVERIFIED になる。
3. Trace table の UNVERIFIED assumption の扱い
   - 現在のデフォルト挙動: 「does not alter the conclusion」と書ければ結論へ進みがち。
   - 変更後の観測可能アウトカム: verdict-bearing assumption だけを CONFIDENCE/UNVERIFIED に反映し、非決定的な unknown は過度な保留にしない。

Step 3: 選ぶ分岐
選ぶ分岐: 1. Compare の per-test Comparison 欄。
理由は 2 点以内:
- ANSWER を直接決める SAME / DIFFERENT outcome の IF/THEN が変わるため、compare の実行時アウトカムに差が出る。
- 構造差の早期 NOT_EQUIV ではなく、既存の per-test analysis の比較粒度を変更するため、探索経路の半固定を避けられる。

改善仮説
比較単位を raw semantic behavior ではなく traced assertion/check result に揃えると、内部差分を過大評価する偽 NOT_EQUIV と、表面上の類似で assertion 差を見落とす偽 EQUIV の両方が減る。

SKILL.md の該当箇所と変更方針
短い引用:
- "Claim C[N].1: With Change A, this test will [PASS/FAIL]"
- "Claim C[N].2: With Change B, this test will [PASS/FAIL]"
- "Comparison: SAME / DIFFERENT outcome"
- "Diverging assertion: [test_file:line — the specific assert/check that produces a different result]"

変更方針:
既存の per-test Comparison 欄を、内部挙動差を記録する場所と、verdict を決める assertion/check result を分ける文言へ置換する。新しい必須ゲートを増やすのではなく、既存の required refutation/search 負荷の一部を置換・圧縮する。

Payment: add MUST("For each relevant test, compare the traced assert/check result, not merely the internal semantic behavior; semantic differences are verdict-bearing only when they change that result.") ↔ demote/remove MUST("The Step 5 refutation or alternative-hypothesis check involved at least one actual file search or code inspection — not reasoning alone.")

Decision-point delta
Before: IF a relevant-path semantic behavior differs THEN mark Comparison as DIFFERENT or pursue NOT EQUIVALENT because the ground is behavior-level difference.
After:  IF a relevant-path semantic behavior differs but the traced assert/check result is identical THEN mark Comparison as SAME; if the assert/check result is not traced, mark impact UNVERIFIED instead of using the semantic difference as verdict because the ground is assertion-result outcome.

変更差分プレビュー
Before:
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace from changed code to test assertion outcome — cite file:line]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace from changed code to test assertion outcome — cite file:line]
  Comparison: SAME / DIFFERENT outcome
After:
  Claim C[N].1: With Change A, this test reaches assert/check [file:line] with result [PASS/FAIL/UNVERIFIED].
  Claim C[N].2: With Change B, this test reaches the same assert/check with result [PASS/FAIL/UNVERIFIED].
  Comparison: SAME / DIFFERENT assertion-result outcome; note any internal semantic difference separately.
  Trigger line (planned): "For each relevant test, compare the traced assert/check result, not merely the internal semantic behavior; semantic differences are verdict-bearing only when they change that result."

Discriminative probe
抽象ケース: 2 つの変更が同じテスト入力で内部表現を異なる形へ正規化するが、最後の assert/check が見る値は同じである。Before では内部差分を DIFFERENT outcome と読み、偽 NOT_EQUIV が起きがちだが、After では assert/check result が同じなので SAME とし、内部差分は非 verdict-bearing として残す。
逆に、内部挙動の説明が似ていても assert/check に渡る最終値だけが片側で変わる場合、Before は偽 EQUIV に寄りうるが、After は assertion-result divergence を DIFFERENT とする。
これは新しい必須ゲートの増設ではなく、既存の per-test Comparison 欄と refutation search 要件の置換・再配置で総量を不変にする。

failed-approaches.md との照合
- 原則 1 との整合: 再収束を優先する規範ではなく、同じ assert/check に到達した後の結果差だけを verdict-bearing にするため、途中差分の記録は残す。
- 原則 3・5 との整合: 新しい抽象ラベルや単一追跡アンカーを追加しない。既存の per-test trace 内で、比較対象を assertion-result outcome と明記するだけである。
- 原則 2・4 との整合: 未検証なら常に保留へ倒すのではなく、verdict-bearing assert/check result が未追跡の場合だけ UNVERIFIED/CONFIDENCE に反映し、証拠十分性を単なる confidence へ吸収しない。

変更規模の宣言
SKILL.md の変更は Compare template と Pre-conclusion self-check の置換・圧縮で 15 行以内に収める。研究コアである番号付き前提、仮説駆動探索、手続き間トレース、必須反証は維持する。
