過去提案との差異: 構造差を特定の観測境界へ写像して早期 NOT_EQUIV を狭めるのではなく、既存の per-test comparison を「機構差」と「pass/fail outcome 差」の二軸に置換して、結論に使う差分種別を変える。
Target: 両方
Mechanism (抽象): compare の比較粒度を「同じ/違う」の単一欄から、内部 behavior relation と test outcome relation の分離へ変える。
Non-goal: 新しい探索モード、特定テスト境界への固定、早期 NOT_EQUIV の観測条件追加は行わない。

カテゴリ C 内での具体的メカニズム選択理由:
- C の「比較の枠組みを変える」として、変更分類を verdict 直結の outcome と内部実装 behavior に分離する。これは比較対象を狭い観測境界へ固定するのではなく、既に読んだ per-test trace の差分重要度を判定する粒度変更である。
- overall に効く理由は、偽 NOT_EQUIV では「内部挙動が違う」だけで outcome DIFFERENT と読んでしまう分岐を抑え、偽 EQUIV では「見た目の目的が同じ」だけで outcome SAME と読んでしまう分岐を抑えるため。

Step 1 — 禁止方向の列挙:
- 再収束を比較規則として前景化し、途中差分を弱める方向は禁止。
- relevance 未確定や弱い仮定を広く保留/UNVERIFIED へ倒す既定動作は禁止。
- 差分昇格を新ラベル、外部可視性、特定 premise/assertion 形式などで強くゲートする方向は禁止。
- 終盤の証拠十分性を confidence 調整だけへ吸収する方向は禁止。
- 最初に見えた差分から単一の追跡経路を既定化する方向は禁止。
- 近接欄を統合し、探索理由と反証可能な情報利得を潰す方向は禁止。
- 直近却下履歴のとおり、構造差/早期 NOT_EQUIV 条件を特定の観測境界だけへ写像して狭める方向は禁止。

Step 2 / 2.5 — overall に直結する意思決定ポイント候補:
1. Per-test comparison 欄:
   現在のデフォルト挙動: behavior 差と outcome 差が同じ SAME/DIFFERENT 語に畳まれ、不十分なときも結論ラベルへ進みがち。
   変更後の観測可能アウトカム: EQUIV/NOT_EQUIV の根拠が outcome relation へ寄り、内部差のみの偽 NOT_EQUIV と未追跡同一視による偽 EQUIV が減る。
2. STRUCTURAL TRIAGE から FORMAL CONCLUSION へ進む分岐:
   現在のデフォルト挙動: clear structural gap が見えると full ANALYSIS 前に NOT_EQUIV へ進みやすい。
   変更後の観測可能アウトカム: ただしこの方向は却下済みの「早期 NOT_EQUIV 条件の観測境界化」に近いため捨てる。
3. NO COUNTEREXAMPLE EXISTS 欄:
   現在のデフォルト挙動: semantic difference を見た後の同一 outcome 立証に寄るが、差分がない/弱い場合の EQUIV では既存テンプレート消化になりがち。
   変更後の観測可能アウトカム: UNVERIFIED や追加探索が増える可能性はあるが、failed-approaches 2 の保留既定化に近いため採用しない。

Step 3 — 選定:
選ぶ分岐: 1. Per-test comparison 欄。
理由は 2 点のみ:
- IF/THEN の IF が「behavior が違うか」ではなく「pass/fail outcome relation が traced か」へ変わるため、ANSWER が変わりうる。
- 既存の per-test loop 内の 1 行置換で済み、探索順固定や新モード追加ではなく comparison granularity の変更として作用する。

改善仮説:
Per-test comparison で behavior relation と outcome relation を同じ SAME/DIFFERENT 欄に入れると、モデルは内部機構差を outcome 差として過大評価し、また目的の類似を outcome 同一として過小検証しやすい。二軸化すれば、結論に使う根拠が D1 の pass/fail outcome に揃い、EQUIV/NOT_EQUIV の両方向の誤判定が減る。

SKILL.md の該当箇所と変更方針:
短い引用:
- `Comparison: SAME / DIFFERENT outcome`
- `Comparison: SAME / DIFFERENT outcome`
これを、同じ per-test analysis 内で次のように置換する。新しい必須ゲートを足すのではなく、既存の Comparison 行の意味を二軸へ置換する。

Payment: add MUST("Behavior relation: SAME / DIFFERENT mechanism; Outcome relation: SAME / DIFFERENT / UNVERIFIED pass/fail result") ↔ demote/remove MUST("Comparison: SAME / DIFFERENT outcome")

Decision-point delta:
Before: IF Change A と Change B の traced behavior に差が見える THEN `Comparison: DIFFERENT outcome` と書きがち because 単一欄が mechanism 差と outcome 差を同じ DIFFERENT 語で受ける。
After:  IF traced behavior が違っても pass/fail result が同じか未追跡 THEN `Behavior relation: DIFFERENT mechanism; Outcome relation: SAME or UNVERIFIED` と分ける because verdict 根拠は D1 の outcome relation だけになる。

変更差分プレビュー:
Before:
```text
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace from changed code to test assertion outcome — cite file:line]
  Comparison: SAME / DIFFERENT outcome
```
After:
```text
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace from changed code to test assertion outcome — cite file:line]
  Behavior relation: SAME / DIFFERENT mechanism
  Outcome relation: SAME / DIFFERENT / UNVERIFIED pass/fail result
```
Trigger line (planned): "Outcome relation: SAME / DIFFERENT / UNVERIFIED pass/fail result"

Discriminative probe:
抽象ケース: 両変更は同じ関連テストを PASS させるが、片方は入力を正規化し、もう片方は比較側で許容するため内部 behavior は違う。
Before では `Comparison: DIFFERENT outcome` と誤読して偽 NOT_EQUIV が起きがち。After では `Behavior relation: DIFFERENT mechanism; Outcome relation: SAME pass/fail result` になり、内部差を結論差へ昇格させない。
逆に、内部 behavior が似ていても片方の side-specific trace が PASS/FAIL まで届かない場合は `Outcome relation: UNVERIFIED` となり、目的類似だけの偽 EQUIV を避ける。

failed-approaches.md との照合:
- 原則 3 への整合: 新しい抽象ラベルで差分昇格を強くゲートするのではなく、既存 `Comparison` の曖昧な粒度を D1 の outcome と内部 mechanism に分解するだけで、差分そのものの直接比較を保つ。
- 原則 5 への整合: 最初の差分から単一追跡経路を固定しない。per-test loop 内で既に得た trace の記録粒度を変えるだけで、次に読む artifact を固定しない。

変更規模の宣言:
SKILL.md の変更は Compare template 内の `Comparison: SAME / DIFFERENT outcome` 2 箇所を各 2 行へ置換する想定で、実質 +2 行・総変更 6 行以内。研究コアである番号付き前提、仮説駆動探索、手続き間トレース、必須反証は維持する。
