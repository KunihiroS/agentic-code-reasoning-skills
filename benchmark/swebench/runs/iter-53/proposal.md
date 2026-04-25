過去提案との差異: 直近の却下案のように構造差の早期 NOT_EQUIV 条件を特定の観測境界へ狭めず、per-test 比較欄で UNVERIFIED を SAME/DIFFERENT 証拠に混ぜない表現へ置換する。
Target: 両方
Mechanism (抽象): assert/check result が未検証のときの比較ラベルを明確化し、UNKNOWN を EQUIV/NOT_EQUIV の根拠として消費する分岐を減らす。
Non-goal: 新しいモード、特定リポジトリ用ヒューリスティック、構造差からの早期 NOT_EQUIV 追加条件は導入しない。

カテゴリ E 内での具体的メカニズム選択理由:
- 表現改善として、既存の `Comparison: SAME / DIFFERENT ...` 行を、UNVERIFIED を含む場合の出力語彙まで含めて短く具体化する。
- 新しい探索ゲートではなく、既存の per-test analysis フォーマットのラベル選択を明確にするため、コア構造（番号付き前提、仮説駆動探索、手続き間トレース、必須反証）は維持される。

Step 1 — 禁止された方向の列挙:
- 再収束を比較規則として前景化し、途中差分を弱める方向。
- relevance 未確定や脆い仮定を常に保留へ倒す広い既定分岐。
- 差分の昇格条件を新ラベルや必須言い換えで強くゲートする方向。
- 終盤の証拠十分性チェックを confidence 調整へ吸収して premature closure を増やす方向。
- 最初の差分から単一の追跡経路を即座に固定する方向。
- 探索理由と反証可能な情報利得を短い単一欄へ潰す方向。
- 直近却下履歴にある、具体的な数値 ID を proposal 本文へ含める方向、および構造差/早期 NOT_EQUIV 条件を特定の観測境界だけへ写像して狭める方向。

Step 2 / 2.5 — overall に直結する意思決定ポイント候補:
1. Per-test `Comparison` ラベルの分岐。
   現在のデフォルト挙動: 片側または両側の assert/check result が UNVERIFIED でも、欄が SAME/DIFFERENT 二択に見えるため比較証拠として消費しがち。
   変更後に観測可能に変わるアウトカム: UNVERIFIED が verdict-bearing evidence ではなく CONFIDENCE/追加探索へ残り、偽 EQUIV と偽 NOT_EQUIV の両方を減らす。
2. `NO COUNTEREXAMPLE EXISTS` で観測済み semantic difference を扱う分岐。
   現在のデフォルト挙動: 具体 test/input への anchor が取れないとき、no counterexample の説明を埋めて EQUIV へ進みがち。
   変更後に観測可能に変わるアウトカム: impact UNVERIFIED または追加探索が増えるが、過度な保留へ倒れすぎるリスクがある。
3. Step 5.5 の weakest verdict-bearing link の分岐。
   現在のデフォルト挙動: weakest link を named uncertainty として書くが、per-test の比較ラベルが先に verdict を固定しがち。
   変更後に観測可能に変わるアウトカム: CONFIDENCE が変わりうるが、結論分岐そのものは間接的。

Step 3 — 選ぶ分岐:
候補 1 を選ぶ。
- compare の中核である per-test assertion outcome の SAME/DIFFERENT 判定に直接触れるため、ANSWER と CONFIDENCE の両方に実行時差が出る。
- IF 条件を「両側が PASS/FAIL として traced されたか」に変えるため、理由の言い換えではなく比較ラベルの選択行動が変わる。

改善仮説:
Per-test comparison 欄で UNVERIFIED を SAME/DIFFERENT と同列に扱わない表現へ置換すれば、未検証の assert/check result を equivalence/non-equivalence の証拠として誤消費する premature verdict が減り、EQUIV と NOT_EQUIV の両側で判定品質が上がる。

SKILL.md の該当箇所と変更:
対象は Compare template の `ANALYSIS OF TEST BEHAVIOR` 内の行:
`Comparison: SAME / DIFFERENT assertion-result outcome; note any internal semantic difference separately.`
これを、両側の result が PASS/FAIL で確定している場合だけ SAME/DIFFERENT を使い、未検証が混じる場合は impact UNVERIFIED として残す文へ置換する。

Decision-point delta:
Before: IF a relevant test row has an assert/check result field filled with PASS/FAIL/UNVERIFIED THEN choose SAME or DIFFERENT for `Comparison` because the template exposes only verdict-like comparison labels.
After:  IF both sides have traced PASS/FAIL assert/check results THEN choose SAME or DIFFERENT; otherwise write `Impact: UNVERIFIED` and carry it to CONFIDENCE/additional exploration because unknown results are not assertion-outcome evidence.

Payment: add MUST("Comparison: SAME / DIFFERENT only when both traced assert/check results are PASS/FAIL; if either side is UNVERIFIED, write Impact: UNVERIFIED instead of using it as equivalence evidence.") ↔ demote/remove MUST("Comparison: SAME / DIFFERENT assertion-result outcome; note any internal semantic difference separately.")

変更差分プレビュー:
Before:
  Claim C[N].1: With Change A, this test reaches assert/check [file:line] with result [PASS/FAIL/UNVERIFIED].
  Claim C[N].2: With Change B, this test reaches the same assert/check with result [PASS/FAIL/UNVERIFIED].
  Comparison: SAME / DIFFERENT assertion-result outcome; note any internal semantic difference separately.
After:
  Claim C[N].1: With Change A, this test reaches assert/check [file:line] with result [PASS/FAIL/UNVERIFIED].
  Claim C[N].2: With Change B, this test reaches the same assert/check with result [PASS/FAIL/UNVERIFIED].
  Comparison: SAME / DIFFERENT only when both traced assert/check results are PASS/FAIL; if either side is UNVERIFIED, write Impact: UNVERIFIED instead of using it as equivalence evidence.
Trigger line (planned): "Comparison: SAME / DIFFERENT only when both traced assert/check results are PASS/FAIL; if either side is UNVERIFIED, write Impact: UNVERIFIED instead of using it as equivalence evidence."

Discriminative probe:
抽象ケース: 片方の変更は relevant test の assert に到達することが traced されているが、もう片方は外部依存または未読分岐のため result が UNVERIFIED のまま。
変更前は `Comparison: SAME / DIFFERENT` 欄を埋める圧力で、未検証側を推測して偽 EQUIV または偽 NOT_EQUIV に倒れがち。
変更後は新しい必須ゲートを増やさず既存行を置換するだけで、未検証 result は `Impact: UNVERIFIED` として CONFIDENCE/追加探索に残り、UNKNOWN を verdict 証拠に変換する誤診断を避ける。

failed-approaches.md との照合:
- 原則 2 に反しない: relevance 未確定を常に保留へ倒す広い fallback ではなく、per-test assertion result が未検証の場合だけ比較ラベルを使わない局所表現である。
- 原則 4 に反しない: 証拠十分性を confidence へ吸収して終えるのではなく、assert/check result の証拠型を明示し、PASS/FAIL と UNVERIFIED の混同を防ぐ。
- 原則 3/5 に反しない: 新しい抽象ラベルによる差分昇格ゲートや、単一追跡経路の固定は追加しない。

変更規模の宣言:
SKILL.md の変更は Compare template 内の 1 行置換のみ、差分 3 行以内を予定する。新規モードなし、必須ゲート総量は置換で不変。