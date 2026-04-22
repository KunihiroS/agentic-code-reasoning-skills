過去提案との差異: 直近却下案のように STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を特定観測境界へ狭めるのではなく、pass-to-pass relevance の判定単位そのものを「直接 call path」から「テストに露出する入力依存」へ置き換える。
Target: 両方
Mechanism (抽象): compare の比較粒度を「編集行が実行本体に入るか」ではなく「その編集が既存テストの入力・fixture・config を通じて assertion outcome を左右しうるか」で切り直す。
Non-goal: STRUCTURAL TRIAGE の早期 NOT_EQUIV を assertion boundary へ再マッピングして狭めることはしない。

禁止方向の確認:
- 構造差/早期結論を特定の観測境界へ写像して狭める案は不可。
- 再収束を既定規範にする案は不可。
- relevance 未確定を広く保留/UNVERIFIED 側へ倒す既定動作の追加は不可。
- 新しい抽象ラベルや再記述形式を前段ゲート化する案は不可。

カテゴリ C 内での候補分岐:
1) STRUCTURAL TRIAGE early exit
   現在のデフォルト: missing file/import を見ると詳細 ANALYSIS 前に NOT EQUIVALENT へ進みがち。
   変わるアウトカム: NOT_EQUIV → 追加探索/保留/CONFIDENCE。
2) D2(b) pass-to-pass relevance
   現在のデフォルト: edited code がその test の direct call path に見えないと pass-to-pass test を除外しがち。
   変わるアウトカム: EQUIV/保留 → 追加探索/NOT_EQUIV/CONFIDENCE。
3) S3 large-patch handling
   現在のデフォルト: >200 lines で structural/high-level 比較へ寄り、局所の差分重要度を粗く扱いがち。
   変わるアウトカム: EQUIV/NOT_EQUIV/CONFIDENCE。

選定: 2) D2(b) pass-to-pass relevance
- compare の relevant test 集合そのものが変わるため、以後の trace 対象・ANSWER・CONFIDENCE が実行時に変わりうる。
- 既存の「call path」条件を書き換えるだけで済み、STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を再演しない。

改善仮説:
pass-to-pass relevance を「直接 call path への出現」ではなく「既存テストが使う入力・fixture・config・mapping を決める依存」に広げると、実行本体の外で生じる差分を compare が取りこぼしにくくなり、偽 EQUIV を減らしつつ、無関係な編集は依然として除外できる。

該当箇所と変更方針:
- 現行引用: "Pass-to-pass tests: tests that already pass before the fix — relevant only if the changed code lies in their call path."
- 変更: relevance 判定を direct call-path membership から test-exposed input dependency へ置換する。

Decision-point delta:
Before: IF a pass-to-pass test does not directly execute the edited code body THEN exclude it from relevant-test analysis because relevance is keyed to direct call-path membership.
After:  IF a pass-to-pass test consumes arguments, fixtures, config, or lookup data whose selected value is determined by the edited code THEN include it in relevant-test analysis because relevance is keyed to test-exposed input dependency.

Payment: add MUST("For pass-to-pass tests, treat code that determines traced test inputs/fixtures/config as relevant even when the edited line is outside the final callee body.") ↔ demote/remove MUST("EDGE CASES RELEVANT TO EXISTING TESTS:")

変更差分プレビュー:
Before:
- "(b) Pass-to-pass tests: tests that already pass before the fix — relevant only if the changed code lies in their call path."
- "EDGE CASES RELEVANT TO EXISTING TESTS:"
After:
- "(b) Pass-to-pass tests: tests that already pass before the fix — relevant if the changed code is on the traced execution path or determines the inputs/fixtures/configuration that the traced path consumes."
- Trigger line (planned): "When a change only affects test-exposed setup/config/data selection, do not exclude the pass-to-pass test as 'off-path'; trace it as a relevance candidate."
- "EDGE CASES RELEVANT TO EXISTING TESTS (optional when the same dependency is already covered by per-test tracing):"

Discriminative probe:
抽象ケース: 2 つの変更は同じ処理関数を最終的に呼ぶが、片方だけが既存 pass-to-pass test の fixture 選択テーブル/default config を変える。変更前は「関数本体の direct call path に差がない」と見て test を除外し、偽 EQUIV になりがち。
変更後はその fixture/config feeder を relevance に含めて同じ test を trace するため、assertion input の差として NOT_EQUIV か追加探索に分岐でき、除外起因の見落としを避ける。

Runtime delta check:
変更前でも変更後でも同じ relevant test 集合・同じ追加探索・同じ結論ならこの案は無効。無効でない理由は、D2(b) の IF 条件が変わることで「除外されていた pass-to-pass test」が tracing 対象へ昇格し、ANSWER または CONFIDENCE が実際に変わるから。

failed-approaches.md との照合:
- 原則 1 には反しない: 下流での再収束説明を強化する案ではなく、比較の入口で relevant test 集合を取りこぼさないための置換である。
- 原則 2/3 に反しない: relevance 未確定を広く保留化する guardrail 追加ではなく、既存 D2(b) の比較基準を 1 箇所置換するだけで、新しい中間ラベル必須化も行わない。

変更規模の宣言:
最大 8 行の置換/圧縮で収まる。新規モードなし、必須総量は Payment の範囲で不変。