過去提案との差異: 直近で却下された「特定の番号や観測境界へ写像する」方向ではなく、次に読む情報を verdict を反転しうる未解決 claim へ結びつける探索優先順位の変更である。
Target: 両方
Mechanism (抽象): ファイルを読む前の分岐を、一般的な仮説 confidence から「どの証拠が EQUIV/NOT_EQUIV/保留を変えるか」を明示する探索クエリへ置き換える。
Non-goal: 構造差から早期 NOT_EQUIV へ進む条件を特定の観測境界に狭めない。

## 禁止方向の確認
- 再収束を比較規則として前景化しすぎる変更は禁止。
- 未確定 relevance や弱い仮定を広く保留側へ倒す既定動作は禁止。
- 差分を新しい抽象ラベルや固定アンカーへ写像して昇格条件を強くする変更は禁止。
- 終盤の証拠十分性を confidence 調整だけへ吸収する変更は禁止。
- 最初の差分から単一の追跡経路を既定化する変更は禁止。
- 近接する欄を統合して探索理由と反証可能な情報利得を潰す変更は禁止。

## カテゴリ B 内での具体的メカニズム選択理由
カテゴリ B は「どう探すか」「探索の優先順位」を変える。今回の変更は、次に読むファイルを選ぶ分岐で、単に plausibility の高い場所ではなく、未解決の verdict claim を反転・確定・UNVERIFIED 化しうる情報を優先させる。

検討した意思決定ポイント:
1. Step 3 の next action 選択: 現在は仮説と confidence があれば次のファイルへ進みがち。変更後は verdict claim を変える証拠を言えない場合、別探索・結論保留・UNVERIFIED 明示へ分岐する。
2. Step 4 の UNVERIFIED source handling: 現在は source 不在時に secondary evidence を探すが、どの claim を左右するかが曖昧だと assumption のまま進みがち。変更後は左右する claim がある場合だけ追加探索、ない場合は confidence に限定して扱う。
3. Compare の NO COUNTEREXAMPLE EXISTS: 現在は検索パターンを書けば EQUIV へ進みがち。変更後は、検索対象がどの反対 outcome を検出するかを明確化できない場合、追加探索または LOW confidence へ分岐する。

選定: 1. Step 3 の next action 選択。
理由は 2 点以内:
- compare の全探索順を支配するため、ANSWER だけでなく CONFIDENCE / 追加探索 / UNVERIFIED 明示に実行時差分が出る。
- IF 条件が「仮説がある」から「verdict claim を変える証拠を予告できる」へ変わり、THEN 行動も「読む」から「読む / 別探索 / 保留」を選び分ける形に変わる。

## 改善仮説
事前 confidence ラベルよりも、次に読む情報がどの未解決 verdict claim を confirm/refute するかを明示させる方が、無関係なファイル読解と premature conclusion の両方を減らし、EQUIV と NOT_EQUIV の片方向最適化を避けられる。

## SKILL.md の該当箇所と変更方針
該当箇所:
- `CONFIDENCE: high / medium / low`
- `OPTIONAL — INFO GAIN: [what uncertainty this action resolves; which hypothesis/claim it would confirm vs refute]`

変更方針:
- 事前 confidence ラベルを削り、同じ位置に verdict に効く探索クエリを置く。
- OPTIONAL INFO GAIN は削除し、探索理由と統合せず、独立した必須行として残す。

Payment: add MUST("DISCRIMINATIVE QUERY: name the unsettled claim and the evidence that would confirm vs refute it") ↔ demote/remove MUST("CONFIDENCE: high / medium / low")

## Decision-point delta
Before: IF a plausible hypothesis and supporting evidence can be stated THEN open the next file because confidence is labeled high/medium/low.
After:  IF the next read can name an unsettled EQUIV/NOT_EQUIV claim and evidence that would confirm vs refute it THEN open that file; otherwise choose a different query or mark the claim UNVERIFIED/LOW because the expected information gain is not verdict-discriminative.

## 変更差分プレビュー
Before:
```text
HYPOTHESIS H[N]: [what you expect to find and why]
EVIDENCE: [what supports this hypothesis — cite premises or prior observations]
CONFIDENCE: high / medium / low
...
NEXT ACTION RATIONALE: [why the next file or step is justified]
OPTIONAL — INFO GAIN: [what uncertainty this action resolves; which hypothesis/claim it would confirm vs refute]
```
After:
```text
HYPOTHESIS H[N]: [what you expect to find and why]
EVIDENCE: [what supports this hypothesis — cite premises or prior observations]
DISCRIMINATIVE QUERY: [which unsettled EQUIV/NOT_EQUIV claim this read can confirm vs refute]
...
NEXT ACTION RATIONALE: [why this query is the next highest-information read]
```
Trigger line (planned): "DISCRIMINATIVE QUERY: [which unsettled EQUIV/NOT_EQUIV claim this read can confirm vs refute]"

## Discriminative probe
抽象ケース: 2 つの変更が同じ関数名を触っているが、片方だけ別の caller 経由で既存テスト結果を変えうる可能性がある。
Before では confidence 付き仮説だけで近い定義を読み続け、caller 差分を見落として偽 EQUIV、または無関係な差分に引かれて偽 NOT_EQUIV が起きがち。
After では「この読解がどの EQUIV/NOT_EQUIV claim を反転させるか」を言えない読解を後回しにし、caller/outcome を分ける証拠を優先するため、追加探索または UNVERIFIED/LOW に留まり誤判定を避ける。

## failed-approaches.md との照合
- 原則 5 と整合: 最初の差分から単一経路へ固定せず、未解決 claim ごとに最も情報量の高い読解を選ぶ。
- 原則 6 と整合: 探索理由と情報利得を一文に潰さず、confidence ラベルを支払いとして削って独立した discriminative query に置き換える。
- 原則 2 と整合: 未検証なら常に保留へ倒す規則ではなく、verdict-discriminative な情報取得の優先順位だけを変える。

## 変更規模の宣言
SKILL.md の変更は 3〜5 行の置換で、15 行以内に収める。新規モードは追加しない。研究コアである番号付き前提、仮説駆動探索、手続き間トレース、必須反証は維持する。
