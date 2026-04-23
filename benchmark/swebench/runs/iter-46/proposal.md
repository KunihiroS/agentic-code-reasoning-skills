過去提案との差異: これは STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を特定境界へ狭める案でも、結論直前の weakest-link を新たな必須ゲート化する案でもなく、既存の EQUIV 側テンプレート文言を「観測した差分に再接続する形」へ置換する提案である。
Target: 両方
Mechanism (抽象): 既に見つけた意味差分を EQUIV 結論時の `NO COUNTEREXAMPLE EXISTS` に明示的に結び直し、汎用的な不在証明だけで吸収しにくくする。
Non-goal: STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を狭めたり、終盤に新しい必須ゲートを純増したりしない。

## Category E でこのメカニズムを選ぶ理由
compare で実際のアウトカムを変えやすい分岐は、「差分を見つけた後に EQUIV へ進む条件」の曖昧さにある。ここは文言置換だけで IF/THEN を変えられ、構造差の早期 NOT_EQUIV 条件や終盤 Guardrail の純増に触れずに、偽 EQUIV と過度な保留の両方へ効く。

## Candidate decision points (Step 2 + 2.5)
1. EQUIV 側の `NO COUNTEREXAMPLE EXISTS`:
   現在のデフォルト挙動: 意味差分を見つけても、一般的な「反例なし検索」で EQUIV に進みがち。
   変更後の観測アウトカム: 偽 EQUIV が減り、必要なら追加探索または UNVERIFIED/LOW CONFIDENCE が増える。
2. pass-to-pass relevance 未解決時の扱い:
   現在のデフォルト挙動: call path が曖昧だと pass-to-pass を暗黙に外しがち。
   変更後の観測アウトカム: 追加探索または relevance 未確定の明示が増える。
3. FORMAL CONCLUSION への写像:
   現在のデフォルト挙動: assertion outcome ではなく「挙動説明が同じ」で EQUIV/NOT_EQUIV に進みがち。
   変更後の観測アウトカム: 結論保留や CONFIDENCE 調整が増え、誤判定が減る。

## Selected decision point (Step 3)
選択: 1. EQUIV 側の `NO COUNTEREXAMPLE EXISTS`
理由:
- compare の主な停滞/誤判定は、差分発見後も EQUIV 側が汎用的な不在証明で閉じられる点にあり、ここを変えると EQUIV・追加探索・UNVERIFIED の分岐が実際に変わる。
- 変更対象が既存テンプレートの EQUIV 記述なので、IF 条件と THEN 行動を変えつつ、研究コアや既存モード構造を崩さない。

## 改善仮説 (1つ)
EQUIV 側の反証不在説明を「発見済みの strongest semantic difference に対する同一 assertion outcome の確認」へ言い換えると、差分を早々に吸収する読み方が減り、同時に generic な保留化も避けられる。

## 該当箇所と変更方針
現行引用:
- `NO COUNTEREXAMPLE EXISTS (required if claiming EQUIVALENT):`
- `If NOT EQUIVALENT were true, a counterexample would look like:`
- `I searched for exactly that pattern:`

変更方針:
- EQUIV 主張時の反例不在記述を、自由形式の一般論ではなく「観測済み差分に anchored な 1 つの具体テスト/入力/分岐」に寄せる。
- ただし early NOT_EQUIV 条件や新規モードは触らず、既存の `NO COUNTEREXAMPLE EXISTS` ブロックを置換するだけに留める。

## Decision-point delta
Before: IF semantic difference was observed but no concrete failing test has yet been derived THEN conclude EQUIV from a generic counterexample search because absence-of-evidence is accepted as the EQUIV witness
After:  IF semantic difference was observed and EQUIV is still claimed THEN anchor `NO COUNTEREXAMPLE EXISTS` to that exact difference with one concrete relevant test/input showing the same traced assertion outcome on both sides, else leave the impact explicit as UNVERIFIED because the equality witness must be tied to the discovered divergence

## 変更差分プレビュー (3-10 lines)
Before:
```md
NO COUNTEREXAMPLE EXISTS (required if claiming EQUIVALENT):
  If NOT EQUIVALENT were true, a counterexample would look like:
    [describe concretely: what test, what input, what diverging behavior]
  I searched for exactly that pattern:
```
After:
```md
NO COUNTEREXAMPLE EXISTS (required if claiming EQUIVALENT):
  If you already observed a semantic difference, name that difference first and test whether one concrete relevant test/input reaches the same assertion outcome on both sides.
  Trigger line (planned): "When claiming EQUIVALENT after observing a semantic difference, anchor the no-counterexample argument to that exact difference with one concrete relevant test/input and the same traced assertion outcome on both sides; otherwise mark the impact UNVERIFIED."
  If NOT EQUIVALENT were true, a counterexample would be this specific test/input diverging at [assert/check:file:line].
  I searched for exactly that anchored pattern:
```

Payment: no MUST increase; replace the existing generic EQUIV-side `NO COUNTEREXAMPLE EXISTS` wording in place instead of adding a new required gate.

## Discriminative probe
抽象ケース: 両変更に同じ高レベル目的があるが、片方だけ条件分岐の正規化位置が違い、途中の意味差分は見えている。しかし失敗テスト候補は複数あり、まだどの assertion へ届くか未特定。
Before では「反例が見つからない」で偽 EQUIV に閉じがち。After では、その差分に anchored な具体テスト/入力で同一 assertion outcome を示せない限り impact を UNVERIFIED と残すため、偽 EQUIV を避け、必要な追加探索へ戻れる。

## failed-approaches.md との照合
- 原則1との整合: 「最初の差分+後段吸収」を EQUIV の既定動作にするのではなく、既に見つけた差分を曖昧に吸収しないための文言置換である。
- 原則2/3との整合: weakest-link の新規 Guardrail 化や、新しい抽象ラベル/観測境界による昇格ゲート追加ではなく、既存 EQUIV テンプレートの根拠記述を具体化するだけである。

## 変更規模
SKILL.md では `NO COUNTEREXAMPLE EXISTS` 節の置換のみ、約 5-7 行の差し替えで収まる。