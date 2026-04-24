過去提案との差異: 直近の却下案のように構造差を特定の観測境界へ写像して早期 NOT_EQUIV 条件を狭めるのではなく、未検証時の次に読む対象を「差分を選択する直近の条件・データ源」へ寄せる探索優先順位の変更である。
Target: 両方
Mechanism (抽象): semantic difference を観測した後、結論や広い探索へ進む前に、その差分が実行経路上で選ばれる条件を読む優先順位を上げる。
Non-goal: 特定の assertion boundary、テスト ID、リポジトリ固有構造、または構造差からの早期 NOT_EQUIV 判定条件を追加しない。

カテゴリ B 内での具体的メカニズム選択理由
- Objective.md のカテゴリ B は「どう探すか」「探索の優先順位付け」を改善対象にしている。今回の変更は、読む量や新モードを増やさず、semantic difference 観測後の next action を、広い caller/test 探索ではなく差分を有効化する branch predicate / data source の確認へ並べ替える。
- overall に効く理由は、EQUIV 側では到達不能・吸収済みの差分を過大評価しにくくなり、NOT_EQUIV 側では実際に選ばれる差分を confidence-only に流しにくくなるためである。

Step 1: 禁止された方向の列挙
- 再収束を比較規則として前景化しすぎること。
- 未確定 relevance や脆い仮定を常に保留側へ倒す既定動作にすること。
- 差分の昇格条件を新しい抽象ラベルや必須の言い換え形式で強くゲートすること。
- 終盤の証拠十分性チェックを単なる confidence 調整へ吸収すること。
- 最初に見えた差分から単一の追跡経路を即座に既定化すること。
- 探索理由と反証可能な情報利得を同じ短い要求に潰しすぎること。
- 直近却下と同じく、具体的な反復番号やケース固有識別子を本文に含めること。
- 「構造差/早期 NOT_EQUIV の条件」をテスト依存・オラクル可視・VERIFIED 接続など特定の観測境界だけへ写像して狭めること。

Step 2 / 2.5: overall に直結する意思決定ポイント候補
1. Semantic difference 発見後の次探索
   - 現在のデフォルト挙動: 「trace at least one relevant test」があるため、証拠不足でも test/caller 側へ早く飛ぶか、差分の到達条件を読まずに影響なし/ありへ進みがち。
   - 変更後の観測可能アウトカム: 追加探索の対象が branch predicate / data source へ変わり、ANSWER と CONFIDENCE の根拠が到達条件つきになる。
2. UNVERIFIED 行の扱い
   - 現在のデフォルト挙動: unavailable source は UNVERIFIED と仮定を置くが、結論に影響するかどうかの探索優先度が曖昧で、保留または confidence 低下に流れがち。
   - 変更後の観測可能アウトカム: UNVERIFIED が verdict claim を支える場合だけ追加探索へ寄り、それ以外は明示したうえで結論可能になる。
3. EQUIV 主張時の no-counterexample 探索
   - 現在のデフォルト挙動: 観測済み semantic difference を anchor する指示はあるが、検索対象が pattern 記述に寄り、差分を選ぶ条件の source を読まないまま SAME assertion outcome としがち。
   - 変更後の観測可能アウトカム: NO COUNTEREXAMPLE の Found/Conclusion が「差分が選択される入力条件」を含むため、偽 EQUIV と過度な保留を減らす。

Step 3: 選ぶ分岐
選定: 1. Semantic difference 発見後の次探索。
理由は 2 点以内:
- IF が「semantic difference を観測したが、どの入力・状態で選ばれるか未読」に変わり、THEN が「まず直近の選択条件/データ源を読む」へ変わるため、compare の実行時アウトカムに差が出る。
- 結論そのものではなく情報取得順の変更なので、EQUIV/NOT_EQUIV の片側へ固定せず、両方向の誤判定を減らせる。

改善仮説
Semantic difference の有無だけでなく、その差分を選択する直近の条件・データ源を先に読むよう探索優先順位を変えると、到達不能な差分による偽 NOT_EQUIV と、到達可能な差分の見落としによる偽 EQUIV の両方が減る。

SKILL.md の該当箇所と変更方針
短い引用:
- 「Exploration priority is not a fixed reading order; choose the next action by discriminative power — what unresolved uncertainty it resolves.」
- 「When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact」

変更方針:
- Step 3 の NEXT ACTION RATIONALE 付近に、semantic difference 観測後の読み方を 1 文だけ追加する。
- Compare checklist の既存 bullet を置換して、test tracing の前に branch predicate / data source を読む優先順位を明示する。

Payment: add MUST("After observing a semantic difference, the next read should identify the nearest branch predicate or data source that selects the differing behavior before widening to callers/tests.") ↔ demote/remove MUST("Trace each test through both changes separately before comparing")
支払いの意味: test tracing 自体は template の ANALYSIS OF TEST BEHAVIOR と Step 5 に残るため削除しないが、Compare checklist 上の独立 bullet としての必須圧を弱め、同じ checklist 内の置換で必須総量を増やさない。

Decision-point delta
Before: IF a semantic difference is observed but its selecting condition is unread THEN trace a relevant test or decide impact from the observed behavior because the evidence type is semantic-difference plus test relevance.
After:  IF a semantic difference is observed but its selecting condition is unread THEN first read the nearest branch predicate/data source that selects the differing behavior, then trace the relevant test through that condition because the evidence type is reachability-conditioned semantic difference.

変更差分プレビュー
Before:
- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact
- Trace each test through both changes separately before comparing

After:
- When a semantic difference is found, first identify the nearest branch predicate or data source that selects the differing behavior, then trace one relevant test/input through that selection before deciding impact.
- Trigger line (planned): "After observing a semantic difference, the next read should identify the nearest branch predicate or data source that selects the differing behavior before widening to callers/tests."

Discriminative probe
抽象ケース: 2 つの変更に内部出力の差があるが、その差は設定値・入力形状・feature flag・normalizer のいずれかで選ばれる分岐の片側にだけ存在する。
Before では、差分だけを見て偽 NOT_EQUIV に寄るか、関連テストを広く見て選択条件を読まず偽 EQUIV/過度な保留に寄りがちである。
After では、既存文言の置換範囲で branch predicate / data source を先に読むため、その差分が実際に選ばれるかを確認してから ANSWER と CONFIDENCE を出せる。

failed-approaches.md との照合
- 原則 3・5 と整合: 差分を新しい抽象ラベルへ分類せず、単一 assertion/check へ固定もしない。読む対象は「差分を選ぶ直近条件」という探索優先順位であり、結論ゲートではない。
- 原則 2・4 と整合: 未検証なら常に保留、または confidence だけで吸収する規則ではない。追加探索で到達条件を具体化し、結論可能なら結論に進む。

変更規模の宣言
- 変更規模は SKILL.md 上で 2 bullet の置換・追加、合計 4 行以内の予定。
- 新規モードは追加しない。
- 研究のコア構造（番号付き前提、仮説駆動探索、手続き間トレース、必須反証）は維持する。
- ベンチマーク対象リポジトリの固有識別子は含めない。
