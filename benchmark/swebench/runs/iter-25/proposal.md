1) 過去提案との差異: Step 5 の反証優先順位や early NOT_EQUIV 条件には触れず、Step 3 の「次に何を読みに行くか」を決めるための“仮説メモの書き方”だけを変える。
2) Target: 両方（偽 EQUIV / 偽 NOT_EQUIV を同時に減らす）
3) Mechanism (抽象): 仮説ごとに「支持シグナル」と「反証シグナル」を対にして明示し、次の探索を片方向の証拠収集に寄せない。
4) Non-goal: STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件・観測境界の制限・反証( Step 5 )の優先順位付けの置換は行わない。

本文

カテゴリ B 内での具体的メカニズム選択理由
- カテゴリBは「何を探すか」ではなく「どう探すか／探索優先順位」を改善する枠。
- Step 3 は“次の一手”の選択点であり、ここで仮説が片側（肯定証拠）に寄ると、結果として読み方（参照先・検索クエリ・開くファイル）が半固定化しやすい。
- そこで、探索対象（ファイルや証拠型）を事前固定せずに、各仮説の両方向の観測を先に言語化してから読む、という取得手順の改善を選ぶ。

改善仮説（1つ）
- 仮説メモを「EVIDENCE/CONFIDENCE」中心から「支持/反証の観測シグナル」中心へ置き換えると、次の探索が“確認バイアス的な一方向読解”に偏りにくくなり、偽EQUIV（差を見落とす）と偽NOT_EQUIV（差を過大評価する）の両方が減る。

SKILL.md の該当箇所（短い引用）と変更
引用（現状）:
- Step 3 の仮説テンプレート:
  "HYPOTHESIS H[N]: ..."
  "EVIDENCE: ..."
  "CONFIDENCE: high / medium / low"

変更方針:
- 「EVIDENCE/CONFIDENCE」を、探索に直結する“観測可能な支持/反証シグナル”の対に置換する（証拠型や読み順を固定しない）。

Decision-point delta（IF/THEN 2行）
Before: IF 新しい仮説を立てて次に読む対象を選ぶ THEN 仮説の根拠(EVIDENCE)と主観確信度(CONFIDENCE)を先に書く because 根拠型=既知事実の列挙＋確信度タグ
After:  IF 新しい仮説を立てて次に読む対象を選ぶ THEN 「支持シグナル」と「反証シグナル」を先に書き、次の探索はそのどちらかを観測できる場所へ向ける because 根拠型=両方向の観測可能条件（反例像を含む）

変更差分プレビュー（Before/After）
Before:
```
HYPOTHESIS H[N]: [what you expect to find and why]
EVIDENCE: [what supports this hypothesis — cite premises or prior observations]
CONFIDENCE: high / medium / low
```
After:
```
HYPOTHESIS H[N]: [what you expect to find and why]
CONFIRMING SIGNAL: [what you would expect to observe if this hypothesis is true]
DISCONFIRMING SIGNAL: [what you would expect to observe if this hypothesis is false]
```

failed-approaches.md との照合（整合ポイント）
- 「証拠の種類をテンプレートで事前固定しすぎる変更は避ける」（8-10行目）に整合: 支持/反証“シグナル”は観測条件の記述であり、特定の証拠型（テスト、オラクル、接続など）を必須化しない。
- 「どこから読み始めるか…の読解順序の半固定は避ける」（14-17行目）に整合: 読み順を規定せず、各仮説で“両方向に効く観測”を意識して次の一手を選ぶため、固定順序の導入にならない。

変更規模の宣言
- SKILL.md の Step 3 テンプレート 3 行を置換（追加なし、5行以内）。
