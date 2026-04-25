過去提案との差異: 直近却下案のように STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を観測境界へ狭めず、per-test compare の SAME/DIFFERENT 分岐で explain/localize 由来の「観測される値・契約の追跡」を要求する置換である。
Target: 両方
Mechanism (抽象): 内部実装差の要約同士を比べる前に、テスト assertion が実際に読む共有 value/API contract へ両側の trace をそろえる。
Non-goal: 構造差だけで NOT_EQUIV を出す条件を弱める／特定の assertion boundary に探索開始点を固定することはしない。

Step 1 — 禁止方向の整理
- failed-approaches 原則 1: 再収束を比較規則として前景化しすぎ、途中差分を弱める方向は禁止。
- 原則 2: 未確定 relevance や未検証リンクを広く保留・UNVERIFIED 側へ倒す既定動作は禁止。
- 原則 3: 差分昇格条件を新ラベルや必須の言い換え形式でゲートし、比較より分類を目的化する方向は禁止。
- 原則 4: 終盤の証拠十分性 self-check を confidence 調整へ吸収して premature closure を増やす方向は禁止。
- 原則 5: 最初に見えた差分から単一の追跡経路を即座に既定化する方向は禁止。
- 原則 6: 探索理由と情報利得を圧縮しすぎ、反証可能性を弱める方向は禁止。
- 直近却下: weakest verdict-supporting link + CONFIDENCE/UNVERIFIED への置換、早期 NOT_EQUIV から impact witness / Diverging assertion を削る方向は禁止。

Step 2/2.5 — overall に効く意思決定ポイント候補
1. Per-test Comparison 欄の SAME/DIFFERENT 判定
   現在のデフォルト: 両側の trace が別々に書けると、assertion-facing な同一観測値へそろえる前に SAME/DIFFERENT を置きがち。
   変更後アウトカム: 追加探索または DIFFERENT/SAME の根拠が「テストが読む value/API contract」へ寄り、偽 EQUIV と偽 NOT_EQUIV の両方を減らす。
2. NO COUNTEREXAMPLE EXISTS の探索停止
   現在のデフォルト: 反例パターンを一つ具体化して見つからないと、別の data-flow 上の反例を拾う前に EQUIV へ進みがち。
   変更後アウトカム: 追加探索または CONFIDENCE 調整が起きるが、保留既定化に寄るリスクがある。
3. Step 4 の UNVERIFIED 行の扱い
   現在のデフォルト: source unavailable は assumption として記録されるが、その assumption が compare outcome を左右するかの扱いが結論直前に寄りがち。
   変更後アウトカム: UNVERIFIED 明示や confidence に差が出るが、failed-approaches 原則 2 に近づくリスクがある。

Step 3 — 選定
選ぶ分岐: 1. Per-test Comparison 欄の SAME/DIFFERENT 判定。
理由は 2 点以内:
- compare の実行時ラベルそのものを出す直前の分岐であり、ANSWER と CONFIDENCE に直接影響する。
- IF 条件を「両側 trace がある」から「両側 trace が同じ assertion-facing value/API contract に到達している」へ変えるため、単なる理由の言い換えではない。

カテゴリ F 内での具体的メカニズム選択理由
- docs/design.md は、原論文の localize が Code Path Tracing → Divergence Analysis を持ち、code QA が function trace / data flow tracking を重視すると整理している。
- これを compare に移植する対象は、新モードではなく既存 per-test comparison の直前である。つまり「差分を分類する新ゲート」ではなく、既存の Trace each test through both changes separately before comparing を、観測値レベルまでそろえる書き方へ置換する。

改善仮説
Compare で per-test SAME/DIFFERENT を出す直前に、両変更がテスト assertion に提示する共有 value/API contract とその値を名指しさせると、内部実装差の印象による偽 NOT_EQUIV と、同じ高レベル説明による偽 EQUIV の両方が減る。

SKILL.md の該当箇所と変更案
短い引用:
- 「Trace each test through both changes separately before comparing」
- 「Comparison: SAME / DIFFERENT outcome」

変更: Compare checklist の既存 1 行を、原論文の explain/localize 由来の data-flow / divergence locus を含む 1 行へ置換する。新しい mode や独立 gate は追加しない。

Payment: add MUST("before comparing, name the assertion-facing value/API contract and each side's value at that point") ↔ demote/remove MUST("Trace each test through both changes separately before comparing")

Decision-point delta
Before: IF each side has a separate trace to the test THEN assign SAME/DIFFERENT because both outcomes are narratively explained.
After:  IF each side's trace reaches the same assertion-facing value/API contract with side-specific values THEN assign SAME/DIFFERENT; otherwise perform one more targeted trace to that observed value because comparison must occur at the value the test reads.

変更差分プレビュー
Before:
```md
- Trace each test through both changes separately before comparing
- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact
```
After:
```md
- Trace each test through both changes separately; before comparing, name the assertion-facing value/API contract and each side's value at that point.
- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact
```
Trigger line (planned): "before comparing, name the assertion-facing value/API contract and each side's value at that point."

Discriminative probe
抽象ケース: 片方の変更は内部 helper の返値型を変え、もう片方は呼び出し側で変換する。テスト assertion は最終 API response の field だけを見る。
Before では helper 差分の印象だけで偽 NOT_EQUIV、または高レベルに「同じ field を返す」とだけ見て偽 EQUIV が起きがち。
After では既存 checklist 1 行の置換だけで、比較点が final field value にそろい、値が同じなら NOT_EQUIV を避け、違えば EQUIV を避ける。

failed-approaches.md との照合
- 原則 1 への整合: 再収束を EQUIV の既定規則にしない。shared value/API contract は「下流で同じなら吸収」と言うためではなく、SAME/DIFFERENT を置く比較対象を明示するために使う。
- 原則 3/5 への整合: 新しい抽象ラベルや単一の探索開始点を増やさない。既に per-test trace をする箇所の終点を、テストが読む観測値として明確化するだけである。
- 原則 4 への整合: pre-conclusion self-check は削らず、confidence-only へ逃がさない。

変更規模の宣言
- SKILL.md 変更は 1 行置換、最大 2 行。15 行以内。
- 新しい必須ゲートの純増なし。既存 checklist の MUST 相当 1 行を置換し、必須量は不変。
- 研究のコア構造（番号付き前提、仮説駆動探索、手続き間トレース、必須反証）は維持する。
