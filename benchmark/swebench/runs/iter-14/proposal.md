過去提案との差異: 未検証リンクを理由に保留へ倒す Guardrail 追加でも、`counterexample search is inconclusive` を結論へ吸収する設計でもなく、比較の探索順を「前向き全追跡」から「判定起点の逆向き比較」へ入れ替える提案である。
Target: 両方
Mechanism (抽象): relevant test ごとに、変更差分ではなく verdict-setting assertion から逆向きに比較を始め、分岐を生む最短の判定ピボットを先に確定する。
Non-goal: STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を特定の観測境界へ狭めたり、未検証性そのものを保留トリガーとして強化したりしない。

## カテゴリAでの候補比較
1. Per-test tracing order
- 現在のデフォルト挙動: `Trace each test through both changes separately before comparing` に従い、各 change を前向きに個別追跡してから比較しがち。
- 変更後に観測可能に変わるアウトカム: EQUIV / NOT_EQUIV / 追加探索 の分岐が、パッチ形状ではなく assertion を左右する判定ピボット起点で起こる。

2. Structural triage exit
- 現在のデフォルト挙動: S1/S2 の structural gap が見えると detailed analysis を飛ばして NOT EQUIVALENT に進みうる。
- 変更後に観測可能に変わるアウトカム: 早期 NOT_EQUIV が追加探索や EQUIV に変わりうる。

3. No-counterexample timing
- 現在のデフォルト挙動: `NO COUNTEREXAMPLE EXISTS` は per-test claim の後段で処理されやすく、探索の向き自体は変わりにくい。
- 変更後に観測可能に変わるアウトカム: EQUIV / UNVERIFIED 明示 / 追加探索 の切替点を前倒しできる。

## 具体的メカニズム選択理由
- 候補1は compare の標準動作そのもの（どこから trace を始めるか）を変えるため、結論・保留・追加探索の分岐点が実際に変わる。
- 候補1は同じ判定ピボットから真の divergence も見つけられ、逆に structural difference が test verdict を変えないことも見抜けるため、片方向最適化になりにくい。

## 改善仮説
relevant test ごとに「どの assert/check が PASS/FAIL を決めるか」を先に固定し、その直前の判定ピボットを両 change で並べてから下流へ展開すると、下流の再収束や上流の構造差に引っ張られにくくなり、偽 EQUIV と偽 NOT_EQUIV の両方を減らせる。

## SKILL.md の該当箇所と変更方針
対象は Compare の `ANALYSIS OF TEST BEHAVIOR` と checklist の `Trace each test through both changes separately before comparing`。
ここを、各 change の前向き個別追跡を既定にする文言から、test verdict を左右する assertion/check → 最短の判定ピボット → 必要なら下流展開、という逆向き・並列の順序へ置換する。

Payment: add MUST("For each relevant test, first anchor the verdict-setting assertion/check and backtrace the nearest upstream decision that could make Change A and Change B disagree.") ↔ demote/remove MUST("Trace each test through both changes separately before comparing")

## Decision-point delta
Before: IF 複数の changed path が同じ test outcome を説明できそう THEN 各 change を前向きに個別 trace してから比較する because per-side full-path tracing が既定だから。
After:  IF 複数の changed path が同じ test outcome を説明できそう THEN verdict-setting assertion/check を先に特定し、その値を分けうる最短の upstream decision を両 change で並列に backtrace し、未解決のときだけ下流へ展開する because test verdict を分ける判定ピボットの方が識別力が高いから。

## 変更差分プレビュー
Before:
```md
For each relevant test:
  Test: [name]
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace from changed code to test assertion outcome — cite file:line]
```

After:
```md
For each relevant test:
  Trigger line (planned): "For each relevant test, first anchor the verdict-setting assertion/check and backtrace the nearest upstream decision that could make Change A and Change B disagree."
  Pivot: [assertion/check and the nearest decision or state transition that can flip it]
  Claim C[N].1: With Change A, this pivot resolves to [value/branch], so the test will [PASS/FAIL]
  Claim C[N].2: With Change B, this pivot resolves to [value/branch], so the test will [PASS/FAIL]
```

## Discriminative probe
抽象ケース: 一方の change は upstream の分岐条件を変え、もう一方は downstream の正規化処理を変える。変更前の手順では、前向き追跡が downstream の見かけ上の再収束を先に見つけて偽 EQUIV、または structural gap を先に見て偽 NOT_EQUIV になりやすい。
変更後は、test の assert を直接左右する判定ピボットを先に比較するため、「同じ assert 値に到達しているので EQUIV」か「ここで assert 値が分岐するので NOT_EQUIV」かを早く切り分けられる。新しい必須ゲート追加ではなく、既存の per-test trace の順序置換で実現する。

## failed-approaches.md との照合
- 原則1との整合: 再収束を既定の救済規則にせず、まず verdict を分けるピボットを取るので、下流一致への過剰依存を増やさない。
- 原則2・3との整合: 未検証性や新しい抽象ラベルを保留ゲートにせず、既存の per-test tracing の開始点だけを変えるため、広い fallback や強い昇格ゲートを追加しない。

## 変更規模の宣言
置換中心で 8-12 行程度。新規モード追加なし、研究コア（番号付き前提・仮説駆動探索・手続き間トレース・必須反証）は維持する。
