# Iteration 65 — proposal discussion

## 1. 既存研究との整合性

検索なし（理由: 一般原則の範囲で自己完結）。

提案の中核は、patch equivalence を内部実装差ではなく relevant tests の PASS/FAIL outcome で比較するというもの。これは README.md / docs/design.md / SKILL.md が既に採用している「per-test iteration」「formal definition of equivalence」「counterexample obligation」と整合する。特定の新規概念や外部研究用語へ強く依拠していないため、Web 検索は不要と判断した。

## 2. Exploration Framework のカテゴリ選定

カテゴリ C「比較の枠組みを変える」とする選定は概ね妥当。

理由:
- 変更対象は Compare template の per-test Comparison 行であり、比較粒度を internal behavior から PASS/FAIL consequence へ寄せるものだから。
- ただし実際の diff は既存文言の明確化に近く、カテゴリ E「表現・フォーマット改善」の性格も強い。
- C として通せる下限は満たすが、C の新しい比較軸を追加しているのではなく、既存 D1 の outcome 定義へ Comparison 行を揃える局所修正と見るのが適切。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用

期待される作用:
- EQUIVALENT 側: 内部処理が違っても同じテストが同じ PASS/FAIL なら DIFFERENT と早合点しにくくなり、偽 NOT_EQUIV を減らす可能性がある。
- NOT_EQUIVALENT 側: 内部説明が似ていても、片側だけ FAIL する帰結が trace できれば SAME と早合点しにくくなり、偽 EQUIV を減らす可能性がある。

ただし実効差分には懸念がある。SKILL.md の現行テンプレートは既に A/B 行を `[PASS/FAIL] because [trace from changed code to test outcome]` としているため、提案の「PASS/FAIL consequence を明示する」は完全な新規要件ではない。実際に変わるのは Trigger line の強調と、内部挙動しかない場合に UNVERIFIED へ倒す条件である。

このため、効果は両方向にありうるが、実装文言のままだと NOT_EQUIV の判別力強化よりも「明示が足りないので UNVERIFIED」に寄る片方向の保留圧が目立つ。

## 4. failed-approaches.md との照合

最大懸念: failed-approaches.md 原則 2 / 原則 3 の本質的再演に近い。

該当箇所:
- 原則 2: 「既存テンプレートの二択ラベルを、確定結果が揃った場合だけ使える条件付きラベルへ狭めると、未知の扱いを改善するより先に、比較判断そのものを非確定化する圧力が増えやすい。」
- 原則 3: 「比較前に両側の結果予測ペアを必ず完成させる形も、説明類似へのアンカリングを減らす意図に反して、ペア欄の充足自体を新しい通過条件にしやすい。」

proposal の問題文言:
- `Do not write SAME/DIFFERENT until both A and B PASS/FAIL consequences for the same test are explicit; if only internal behavior differs, keep the comparison UNVERIFIED and trace the PASS/FAIL consequence.`

これは既存 Trigger line の置換であり純増ではない点は評価できる。しかし「確定 PASS/FAIL が揃うまで SAME/DIFFERENT を禁止し、UNVERIFIED にする」という分岐は、failed-approaches.md が警告している「二択ラベルの条件付き化」「保留側既定化」とかなり近い。特に current template は既に PASS/FAIL prediction を要求しているため、差分の実体が outcome alignment の改善ではなく UNVERIFIED fallback の強化に寄りやすい。

## 5. 汎化性チェック

固有識別子チェック:
- 具体的な数値 ID: なし。
- リポジトリ名: なし。
- テスト名: なし。
- ベンチマーク対象のコード断片: なし。
- SKILL.md 自身の Trigger line / Comparison line の引用: あり。ただし Objective.md の R1 減点対象外に該当するため問題なし。

ドメイン依存性:
- 特定言語・フレームワーク・テストパターンへの依存は薄い。
- 「test outcome を PASS/FAIL で比較する」は Compare mode の D1 と一致しており、Go/JS/TS/Python など言語を問わず適用可能。

汎化性そのものは PASS 水準。

## 6. 推論品質への期待効果

良い点:
- Comparison 行が D1 の「identical pass/fail outcomes」により直接接続される。
- internal behavior の差を verdict 差と混同する誤りを抑制できる。
- per-test の A/B prediction pair を形式的に埋めるだけでなく、test outcome への帰結を明示する方向へ促す。

悪い点:
- 現行テンプレートは既に PASS/FAIL trace を要求しているため、改善の主成分が「outcome への接続」ではなく「明示不足なら UNVERIFIED」に見える。
- その場合、compare の決定力を上げるより、判断保留を増やす可能性がある。

## 停滞診断

監査 rubric に刺さる説明強化へ偏り、compare の意思決定を変えていない懸念: あり。proposal は Decision-point delta と Trigger line を明記しているが、SKILL.md 現行の A/B prediction 行自体が既に `[PASS/FAIL] because [trace ... test outcome]` であるため、実行時に変わる分岐が「outcome を書く」より「明示が足りなければ UNVERIFIED」に偏っている。

failed-approaches 該当:
- 探索経路の半固定: NO。特定 assertion/check や単一経路への固定はしていない。
- 必須ゲート増: YES。純増ではなく置換 Payment はあるが、`both A and B PASS/FAIL consequences ... are explicit` を SAME/DIFFERENT の通過条件として強めている。
- 証拠種類の事前固定: YES。`PASS/FAIL consequences` 自体は D1 と整合するが、`if only internal behavior differs, keep the comparison UNVERIFIED` が、内部差分を verdict 証拠へ昇格させる前に特定の証拠型へ狭める文言になっている。

## compare 影響の実効性チェック

0) 実行時アウトカム差:
- SAME/DIFFERENT を書く前に、A/B それぞれの PASS/FAIL consequence が明示されているかを確認するようになる。
- 内部挙動差だけが書かれている場合、Comparison を SAME/DIFFERENT にせず UNVERIFIED として trace 継続する可能性が増える。

1) Decision-point delta:
- IF/THEN 形式で 2 行（Before/After）になっているか？ YES。
- Before: IF both A and B predictions for a test are present THEN write SAME/DIFFERENT because the prediction pair exists.
- After: IF both A and B PASS/FAIL consequences for the same test are explicit THEN write SAME/DIFFERENT; otherwise keep the comparison UNVERIFIED and trace the missing consequence.
- ただし、現行 SKILL.md の prediction は既に `[PASS/FAIL] because [trace ... test outcome]` なので、条件の新規性は弱く、行動差は UNVERIFIED fallback 強化に集中している。
- 差分プレビュー内に Trigger line の自己引用が含まれているか？ YES。

2) Failure-mode target:
- Target は両方。
- 偽 NOT_EQUIV 低減メカニズム: internal behavior difference だけで DIFFERENT としない。
- 偽 EQUIV 低減メカニズム: similar internal explanation だけで SAME とせず、片側 FAIL の outcome trace を要求する。
- 懸念: どちらの誤判定低減も「追加 trace」ではなく「UNVERIFIED に倒す」動作として発火すると、正答率改善より停滞を招く。

2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？ NO。
- impact witness 要求の有無: N/A。
- 構造差だけで NOT_EQUIV へ退化させる変更ではない。

3) Non-goal:
- 変えないことは、STRUCTURAL TRIAGE、早期 NOT_EQUIV、探索経路、証拠種類の網羅順序。
- ただし現行文言では、証拠種類を PASS/FAIL consequence に事前固定する圧が少し強い。D1 との整合はあるが、failed-approaches 原則 2/3 との境界を越えかけている。

## Discriminative probe

抽象ケース: 両パッチは内部で異なる正規化処理を行うが、既存テストの assertion が見る最終値は同じでどちらも PASS する。一方、別の抽象ケースでは内部説明は似ているが、片側だけ validation 境界で FAIL する。

変更前は internal behavior の差や説明類似に引っ張られ、偽 NOT_EQUIV / 偽 EQUIV が起きうる。変更後は outcome に寄せるため誤判定を避けうる、という probe は妥当。

ただしこの probe を成立させるために必要なのは「UNVERIFIED fallback の強化」ではなく、「内部挙動差を見つけたら verdict 差と同一視せず、同じ test の PASS/FAIL へ trace してから Comparison する」という置換で足りる。proposal の現行 Trigger line はここに加えて保留側の既定分岐を強めている。

## 支払い（必須ゲート総量不変）の確認

Payment の A/B 対応付けは明示されている。

- Add/replace: PASS/FAIL consequences が explicit になるまで SAME/DIFFERENT を書かない。
- Demote/remove: 既存の predictions present Trigger line。

ただし、総量不変であっても、置換後の必須条件が failed-approaches.md の「条件付きラベル化」「保留側既定化」に近いため、Payment だけでは最大懸念を解消しない。

## 修正指示（最小限）

1. Trigger line から `otherwise keep the comparison UNVERIFIED` を削り、UNVERIFIED を既定動作にしないこと。
   - 置換案: `Do not treat internal behavior similarity/difference as SAME/DIFFERENT by itself; first trace how it changes the A/B PASS/FAIL outcome for the same test.`
   - これなら保留ゲートではなく、内部差分から outcome への trace 指示になる。

2. Payment を「既存 Trigger line の置換」だけでなく、「現行 A/B 行が既に PASS/FAIL を要求しているため、追加要件ではなく Comparison 行の根拠語を prediction pair から outcome pair へ限定する」と明記すること。
   - 追加ではなく、`based on the A/B prediction pair` を `based on the traced A/B PASS/FAIL outcome for this test` へ置換する支払いに寄せる。

3. Discriminative probe の最後を、UNVERIFIED に倒す説明ではなく「同じ test outcome へ trace した結果、SAME または DIFFERENT を出せる」に変えること。
   - compare の実行時アウトカム差を「保留増」ではなく「誤った Comparison label の根拠を internal behavior から test outcome へ移す」こととして固定する。

## 総合判定

提案の狙いは良い。D1 と Comparison 行を揃える方向は汎用的で、EQUIVALENT / NOT_EQUIVALENT の両方に効く可能性がある。固有 ID やドメイン依存も見当たらない。

しかし、現行 proposal の最大ブロッカーは failed-approaches.md の本質的再演である。特に `if only internal behavior differs, keep the comparison UNVERIFIED` は、過去に失敗原則として記録された「確定結果が揃った場合だけ二択ラベルを使える条件付き化」「未確定なら保留側へ倒す既定動作」にかなり近い。現行 SKILL.md が既に A/B PASS/FAIL prediction を要求しているため、このままでは compare 改善より UNVERIFIED fallback 強化として作用しやすい。

承認: NO（理由: failed-approaches.md 原則 2/3 の本質的再演。最大ブロッカーは `otherwise keep the comparison UNVERIFIED` による保留側既定化）
