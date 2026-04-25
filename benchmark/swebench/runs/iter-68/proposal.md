過去提案との差異: STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を特定の観測境界へ狭めず、原論文 localize の PREMISE → divergence CLAIM → prediction 鎖を既存 COUNTEREXAMPLE 欄へ移植する点が異なる。
Target: 両方
Mechanism (抽象): NOT_EQUIV/EQUIV の結論直前で、単なる同一 assert 上の PASS/FAIL 予測ではなく、テスト前提を破るコード側の divergence claim を先に作らせる。
Non-goal: 構造差からの早期 NOT_EQUIV を新しいテスト依存条件・オラクル可視条件・単一観測境界へ固定しない。

カテゴリ F 内での具体的メカニズム選択理由
- docs/design.md は原論文の fault localization template を「PREMISE → CLAIM → PREDICTION chain」と要約し、各 prediction が divergence claim と特定の test premise に戻ることを中核にしている。現在の compare template は per-test PASS/FAIL と diverging assertion は持つが、NOT_EQUIV counterexample 内で「どの test premise をどのコード側 behavior が破るか」を明示する CLAIM 層が薄い。
- この移植は localize/explain の未活用要素を compare に応用するもので、探索範囲を狭める新モードではなく、既存 COUNTEREXAMPLE 欄の根拠型を置換するだけなので、overall に対して偽 NOT_EQUIV と偽 EQUIV の両方を減らしうる。

Step 1: 禁止された方向の列挙
- 再収束を比較規則として前景化し、差分を下流一致で過度に吸収する方向は禁止。
- relevance 未確定・弱い仮定を広く UNVERIFIED/保留へ倒す既定動作は禁止。
- 差分を新しい抽象ラベルや必須の言い換え形式で強くゲートし、分類整合を目的化する方向は禁止。
- 証拠十分性チェックを confidence 調整だけへ吸収して premature closure を増やす方向は禁止。
- 最初の差分から単一の追跡経路・単一観測点へ探索順を固定する方向は禁止。
- 近接欄を統合し、探索理由と反証可能な情報利得を潰す方向は禁止。
- 直近却下により、STRUCTURAL TRIAGE / 早期 NOT_EQUIV を特定の assertion boundary・impact witness・test oracle だけへ写像して狭める方向は禁止。

Step 2 / 2.5: overall に直結する意思決定ポイント候補
1. COUNTEREXAMPLE 欄の NOT_EQUIV 分岐
   - 現在のデフォルト: named test + PASS/FAIL prediction + diverging assertion があれば、コード側の前提違反 claim が薄くても NOT_EQUIV に進みがち。
   - 変更後アウトカム: NOT_EQUIV へ進む前に divergence claim が必要になり、根拠が作れない場合は追加探索または CONFIDENCE 低下として観測される。
2. NO COUNTEREXAMPLE EXISTS 欄の EQUIV 分岐
   - 現在のデフォルト: semantic difference を見つけた後、同じ traced assertion outcome を示せれば EQUIV に進むが、差分がどの前提を破らないのかは薄くなりうる。
   - 変更後アウトカム: EQUIV の no-counterexample が premise-linked になり、偽 EQUIV を避ける追加探索または UNVERIFIED 明示が増える。
3. Step 5.5 の conclusion 前 self-check 分岐
   - 現在のデフォルト: file:line trace と VERIFIED/UNVERIFIED の形式充足を満たすと結論へ進みやすい。
   - 変更後アウトカム: conclusion claim と premise/claim chain の接続が欠ける場合に結論保留または追加探索へ戻る。

Step 3: 選ぶ分岐
選択: 1. COUNTEREXAMPLE 欄の NOT_EQUIV 分岐。
理由は 2 点に絞る。
- compare の実行時アウトカムである ANSWER: NO not equivalent と CONFIDENCE に直接触れる欄であり、IF/THEN の THEN が「結論へ進む」から「premise-linked divergence claim を作ってから結論へ進む」に変わる。
- 既存の required counterexample 内の根拠型を置換するだけなので、新しい探索モードや STRUCTURAL TRIAGE の早期分岐変更にならない。

改善仮説
NOT_EQUIV counterexample を、原論文 localize の PREMISE → divergence CLAIM → PREDICTION 鎖に合わせて「テスト前提を破るコード側挙動」から書かせると、名前付きテストと PASS/FAIL 予測だけで成立したように見える偽の差分結論を減らしつつ、本当に異なる場合は根拠がより短く明確になる。

SKILL.md の該当箇所と変更案
短い引用:
- 現行: `COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):`
- 現行: `Diverging assertion: [test_file:line — the specific assert/check that produces a different result]`
変更: `Diverging assertion` 行を、localize の divergence claim 形式を使う 1 行へ置換し、その直後の therefore 行を claim 参照に軽く圧縮する。

Payment: add MUST("Divergence claim: At [file:line], Change A/B produces [behavior] that contradicts P[N]/test expectation [T] because [reason].") ↔ demote/remove MUST("Diverging assertion: [test_file:line — the specific assert/check that produces a different result]")

Decision-point delta
Before: IF claiming NOT_EQUIVALENT and a named relevant test has opposite PASS/FAIL predictions THEN proceed with NOT_EQUIVALENT because the evidence type is a diverging assertion/check.
After:  IF claiming NOT_EQUIVALENT and a named relevant test has opposite PASS/FAIL predictions THEN first state the code-side divergence claim that contradicts a numbered premise/test expectation, then proceed only if that claim supports the prediction because the evidence type is PREMISE → CLAIM → PREDICTION.

変更差分プレビュー
Before:
  COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
    Test [name] will [PASS/FAIL] with Change A because [reason]
    Test [name] will [FAIL/PASS] with Change B because [reason]
    Diverging assertion: [test_file:line — the specific assert/check that produces a different result]
    Therefore changes produce DIFFERENT test outcomes.
After:
  COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
    Test [name] will [PASS/FAIL] with Change A because [reason]
    Test [name] will [FAIL/PASS] with Change B because [reason]
    Trigger line (planned): "Divergence claim: At [file:line], Change A/B produces [behavior] that contradicts P[N]/test expectation [T] because [reason]."
    Therefore Claim D[N] predicts DIFFERENT test outcomes for the named test.

Discriminative probe
抽象ケース: 2 つの変更が同じ assert/check に到達し、片側だけ FAIL と予測されているが、その FAIL 理由が実際にはテスト前提ではなく内部実装の命名差に依存している。
Before では named test + opposite PASS/FAIL + diverging assertion の形が埋まり、偽 NOT_EQUIV に進みがち。After では「どの P[N]/test expectation をどの file:line behavior が破るか」を書けないため、既存 COUNTEREXAMPLE 欄内で追加探索または CONFIDENCE 低下になり、誤判定を避ける。
これは新しい必須ゲートの純増ではなく、既存の `Diverging assertion` 行を premise-linked divergence claim へ置換する支払い済み変更である。

failed-approaches.md との照合
- 原則 2 と整合: 未検証なら広く保留へ倒す既定動作ではなく、NOT_EQUIV を主張する既存 counterexample の根拠型だけを強くする。根拠がない場合の fallback を新しい Guardrail にしない。
- 原則 3/5 と整合: 差分を抽象ラベル分類したり単一観測境界へ固定したりしない。原論文の claim chain により、テスト前提・コード位置・予測の接続を明示するだけで、探索開始点は固定しない。

変更規模の宣言
SKILL.md の変更は COUNTEREXAMPLE ブロック内の 2 行置換・圧縮のみ、最大 4 行、15 行以内。研究のコア構造である番号付き前提、仮説駆動探索、手続き間トレース、必須反証は維持する。
