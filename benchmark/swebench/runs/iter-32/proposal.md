過去提案との差異: これは STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を特定の観測境界へ狭める案ではなく、詳細比較で「意味差を見つけた直後」の verdict 分岐を明文化する案である。
Target: 両方
Mechanism (抽象): semantic difference を verdict そのものではなく provisional signal と明記し、具体的な assertion-level trace か decisive UNVERIFIED link が出るまで結論を進めないようにする。
Non-goal: S1/S2 の早期構造判定ルールや新規モードは変えない。

Payment: add MUST("If a semantic difference has no traced assertion boundary yet, keep it provisional: continue tracing or name the decisive link UNVERIFIED; do not conclude EQUIVALENT or NOT EQUIVALENT from the difference alone.") ↔ remove MUST("When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact")

禁止方向の確認:
- 再収束を比較規則として前景化しすぎる案は避ける。
- 未確定性を広く保留側へ倒す既定動作の追加は避ける。
- 新しい抽象ラベルや CLAIM 形式で差分昇格を強くゲートする案は避ける。
- 特に STRUCTURAL TRIAGE の早期 NOT_EQUIV を特定の観測境界へ写像して狭める案は避ける。

意思決定ポイント候補:
1. compare 中に semantic difference を見つけたが、まだ test assertion まで trace していない分岐。
   現在のデフォルト挙動: checklist は「no impact」側だけを弱く牽制するため、差分そのものから EQUIV/NOT_EQUIV へ寄りやすい。
   変更後の観測アウトカム: 追加探索 / UNVERIFIED 明示 / NOT_EQUIV への昇格条件 が変わる。
2. S1/S2 で clear structural gap と見なす分岐。
   現在のデフォルト挙動: file asymmetry を早期 NOT_EQUIV に直結しやすい。
   変更後の観測アウトカム: NOT_EQUIV の早期結論条件が変わる。
3. trace table に UNVERIFIED 行が残ったまま formal conclusion に入る分岐。
   現在のデフォルト挙動: LOW confidence の categorical verdict か、曖昧な assumption で押し切りやすい。
   変更後の観測アウトカム: UNVERIFIED 明示 / 結論保留 / CONFIDENCE が変わる。

選定: 候補 1
理由:
- compare で最も直接に verdict を分けるのは「意味差を発見した瞬間に、それを verdict-ready evidence と扱うか、追加 tracing signal と扱うか」の分岐だから。
- これは IF 条件と THEN 行動の両方を変えられ、EQUIV と NOT_EQUIV の両側で実行時アウトカムを変える。

カテゴリ E 内での具体的メカニズム選択理由:
現在の Compare には、COUNTEREXAMPLE/NO COUNTEREXAMPLE という結論フォーマットはある一方で、分析途中の semantic difference をどう扱うかの trigger 文が曖昧に残っている。とくに checklist の "When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact" は、偽 EQUIV への注意としては働くが、偽 NOT_EQUIV を防ぐ対称な分岐文になっていない。カテゴリ E としてこの曖昧文言を「difference alone is not yet a verdict」という行動指示に置き換えると、テンプレートの見た目はほぼ維持したまま compare の挙動差を作れる。

改善仮説:
semantic difference 発見時の分岐を verdict trigger として明文化すると、モデルが差分そのものを結論化する premature verdict を減らし、具体的な test-outcome evidence へ tracing を戻しやすくなる。

該当箇所と変更:
- Compare checklist L231-L234 付近
  - 現行: "When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact"
  - 変更: semantic difference を provisional 扱いする trigger line に置換し、assertion boundary または decisive UNVERIFIED link が出るまで verdict 不可と明記する。
- COUNTEREXAMPLE / NO COUNTEREXAMPLE (L201-L213) の前段分岐として読める位置に再配置する。

Decision-point delta:
Before: IF semantic difference is found but no traced assertion outcome is identified yet THEN the agent may still drift toward EQUIVALENT ("probably no impact") or NOT EQUIVALENT ("difference exists") because semantic difference itself is treated as near-verdict evidence.
After:  IF semantic difference is found but no traced assertion outcome or decisive UNVERIFIED link is identified yet THEN continue tracing and keep the difference provisional because verdict evidence must be tied to a traced test-outcome witness, not the difference alone.

変更差分プレビュー:
Before:
- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact
- Provide a counterexample (if different) or justify no counterexample exists (if equivalent)

After:
- Trigger line (planned): "If a semantic difference has no traced assertion boundary yet, keep it provisional: continue tracing or name the decisive link UNVERIFIED; do not conclude EQUIVALENT or NOT EQUIVALENT from the difference alone."
- Provide a counterexample (if different) or justify no counterexample exists (if equivalent)
- A verdict may use the difference only after the trace reaches a concrete test outcome or an explicitly named decisive UNVERIFIED link.

Discriminative probe:
抽象ケース: 2 つの変更は helper の分岐条件が違うが、既存 tests がその入力域を通るか未確認。Before では semantic difference を見た時点で「差があるから NOT_EQUIV」または「たぶん既存 tests に触れないから EQUIV」に流れやすい。After では assertion boundary まで trace できるまで provisional 扱いになるため、真の diverging assert が見つかれば NOT_EQUIV、見つからなければ UNVERIFIED link を明示して premature verdict を避ける。これは新しい必須ゲートの純増ではなく、既存 checklist 文の置換である。

failed-approaches.md との照合:
- 原則 3 と整合: 新しい抽象ラベルや外部可視性ラベルで差分昇格をゲートせず、既存の per-test tracing 座標へ trigger 文を寄せるだけである。
- 原則 2 と整合: 未確定性一般を広く保留へ送るのではなく、semantic difference 発見時の局所分岐だけを明文化し、追加探索の対象をその差分に限定する。

変更規模の宣言:
置換ベースで 6-8 行想定、hard limit 15 行以内。