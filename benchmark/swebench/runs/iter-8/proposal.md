過去提案との差異: これは STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を観測境界へ狭める案ではなく、差分を見つけた後にどのコードを次に読みに行くかという取得順序を変える案である。
Target: 両方
Mechanism (抽象): 局所差分を見つけた瞬間に、その差分を最初に解釈する下流コードを優先読解させ、局所差分を即座に結論へ短絡させない。
Non-goal: STRUCTURAL TRIAGE の結論条件そのものを狭めたり、新しい判定モードや必須ゲートを純増したりしない。

## 禁止方向の整理
- STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を、テスト依存・オラクル可視・VERIFIED な接続など特定の観測境界へ写像して狭める方向は不可。
- 「再収束」を比較規則として前景化し、局所差分を provisional 扱いする既定動作を強める方向は不可。
- relevance 未確定時に広く保留/UNVERIFIED 側へ倒す fallback の Guardrail 化は不可。

## 意思決定ポイント候補（Step 2 / 2.5）
1. 差分発見後の次の読みに行く先
   - 現在のデフォルト挙動: 局所的な semantic difference を見つけると、その差分自体から PASS/FAIL 物語を組み立てるか、逆に「影響なし」と早めに言いがち。
   - 変更後の観測可能アウトカム: 追加探索が「差分の最初の解釈点」へ向き、EQUIV / NOT_EQUIV / CONFIDENCE が変わりうる。
2. pass-to-pass relevance の確定前の探索優先順位
   - 現在のデフォルト挙動: changed function/class/variable への直接参照探索に寄り、関連が薄く見えると pass-to-pass を早めに脇へ置きがち。
   - 変更後の観測可能アウトカム: 保留の減少、追加探索の向き変更、NOT_EQUIV の取りこぼし減少がありうる。
3. EQUIV 主張時の no-counterexample search の検索語生成
   - 現在のデフォルト挙動: テスト名や関数名ベースの表層検索に寄り、反例候補の入力形・例外形・戻り値形を十分に掘らないことがある。
   - 変更後の観測可能アウトカム: 追加探索と CONFIDENCE が変わり、偽 EQUIV を減らしうる。

## 選定
選ぶ分岐: 1. 差分発見後の次の読みに行く先
理由:
- compare の停滞点は「差分を見つけた後、どのファイル/関数を読めば test outcome への接続が最も判別的か」が未指定なことにあり、ここは実際に追加探索の向きと結論を変える。
- IF 条件（semantic difference を見つけたとき）も THEN 行動（まず読む対象）も変えられ、説明の言い換えではなく行動分岐そのものが変わる。

## カテゴリ B 内での具体的メカニズム選択理由
Objective.md のカテゴリ B は「何を探すかではなく、どう探すかを改善する」を含む。今回の変更は、差分を見つけた後の探索順序を「差分が最初に解釈される場所」へ寄せるもので、結論条件の変更ではなく読解の具体化である。README.md / docs/design.md が強調する interprocedural tracing と incomplete reasoning chains の防止にも沿う。

## 改善仮説
比較で局所差分を見つけた直後に、その差分を最初に消費・正規化・分岐化する下流コードを優先して読むようにすると、局所差分を test-outcome 差と誤認する偽 NOT_EQUIV と、局所差分を安易に吸収済みとみなす偽 EQUIV の両方を減らせる。

## SKILL.md の該当箇所と変更方針
現行の関連箇所:
- Guardrail #5: "verify that downstream code does not already handle the edge case or condition you identified"
- Compare checklist: "When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact"

変更方針:
- Guardrail #5 の精神を compare の読み順ルールへ下ろし、差分発見後の「次の一手」を明示する。
- ただし structural gap の早期 NOT_EQUIV 条件や counterexample obligation 自体は変えない。

Payment: add MUST("When a semantic difference is first found, read the immediate downstream code that interprets that differing value/exception/state before classifying its test impact.") ↔ remove MUST("When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact")

## Decision-point delta
Before: IF a semantic difference is found THEN jump to a test-impact claim by tracing from the differing path itself because the current checklist only requires "trace at least one relevant test".
After:  IF a semantic difference is found THEN first read the immediate downstream interpreter of that differing value/exception/state, then trace the relevant test from there because the most discriminative evidence is where the local difference becomes (or fails to become) a branch/assert-relevant condition.

## 変更差分プレビュー
Before:
- **Do not trust incomplete chains.** After building a reasoning chain, verify that downstream code does not already handle the edge case or condition you identified...
- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact

After:
- **Do not trust incomplete chains.** When you identify a semantic difference, read the first downstream code that consumes or interprets that differing value/exception/state before deciding whether the difference matters to the test outcome.
- Trigger line (planned): "When a semantic difference is first found, read the immediate downstream code that interprets that differing value/exception/state before classifying its test impact."
- Then trace at least one relevant test through that interpreted path before concluding SAME / DIFFERENT impact.

## Discriminative probe
抽象ケース: 2 つの変更が中間表現だけ異なる値を返す。Before では、その局所差分から直接 test outcome の差を語って偽 NOT_EQUIV になりやすい。After では、最初の下流 consumer が両者を同じ predicate に正規化するか、逆に別分岐へ送るかを先に読むので、誤判定を避けて EQUIV / NOT_EQUIV を正しく分けやすい。

## failed-approaches.md との照合
- 原則 1 との整合: 再収束を比較規則として前景化していない。差分を見つけた後の「次にどこを読むか」を指定するだけで、下流一致を既定の結論にはしない。
- 原則 2 との整合: 未確定時に広く保留/UNVERIFIED 側へ倒す fallback は増やしていない。追加するのは探索優先順位のみで、保留既定分岐ではない。

## 変更規模の宣言
変更は compare checklist / Guardrail 周辺の置換・圧縮で 15 行以内に収める。新規モード追加なし、既存の mandatory 総量は payment の通り純増させない。
