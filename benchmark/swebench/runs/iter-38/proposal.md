1) 過去提案との差異: 結論直前に新しい最弱点→確信度の“追加メタ判断”を増やすのではなく、既存の Step 5（必須反証）の「どれを反証するか」という分岐を、観測可能な探索行動へ結びつけて変える。
2) Target: 両方（偽 EQUIV と 偽 NOT_EQUIV）
3) Mechanism (抽象): 反証チェックの対象を「結論を反転させる pivot claim」に固定し、反証行動（検索/閲覧）が pivot を実際に潰す形に寄る。
4) Non-goal: STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を特定の観測境界（単一 witness 型）へ写像して狭めたり、探索経路をテンプレで半固定したりはしない。

---

Step 1: 禁止方向（failed-approaches.md + 却下履歴の要約）
- 「変更の直接効果が NOT_EQUIVALENT 側に偏る」片方向最適化（iter-32）。
- 結論直前に「最弱点を特定して確信度へ結びつける」追加メタ判断を増やす／既存 Step 5/5.5 と機能重複（iter-33、failed-approaches.md L28–L32）。
- focus_domain の片方向最適化で逆方向の悪化回避が不十分（iter-34）。
- 既存判定基準を「特定の観測境界だけ」に還元して狭める／証拠種類や結論根拠の型を単一 witness に揃える方向（failed-approaches.md L12–L17）。
- 次の探索で探すべき証拠の種類をテンプレで事前固定しすぎる（failed-approaches.md L8–L11）。

---

Step 2: overall に直結する意思決定ポイント候補（IF/THEN で書ける分岐）
候補A（compare / 早期結論分岐）
- IF STRUCTURAL TRIAGE で「clear structural gap」を見た THEN full ANALYSIS をスキップして NOT EQUIVALENT へ進む（SKILL.md Compare: “may proceed directly…”）。

候補B（Core Step 5 / 反証対象の選択分岐）
- IF 反証チェックを実施する THEN 「どの claim/assumption を最初に潰すか」を選ぶ（SKILL.md Step 5: “Prioritize the claim/assumption whose negation would flip…”）。

候補C（Step 5.5 / 探索の“形式充足” vs “目的適合”分岐）
- IF Step 5.5 のチェック項目を満たしたとみなす THEN “少なくとも1回検索した” だけで OK として結論に進む／or “その検索が実際に反証したい命題に刺さっている” を要求して追加探索へ回す（SKILL.md Step 5.5: “at least one actual file search…”）。

Step 2.5: 各候補のデフォルト挙動と、変更後に観測可能に変わるアウトカム
- 候補A
  - 現在のデフォルト: structural gap を見つけると、十分な反証探索をせず早期 NOT_EQUIV で締めがち。
  - 変更後アウトカム: NOT_EQUIV の早期結論が減る（代わりに追加探索 or UNVERIFIED 明示 or 低確信度の明示）。
- 候補B
  - 現在のデフォルト: Step 5 の反証が「とりあえず何か検索」になり、結論反転に効く命題（pivot）を潰せないまま EQUIV/NOT_EQUIV を出しがち。
  - 変更後アウトカム: 追加探索の方向が pivot に集中し、偽 EQUIV/偽 NOT_EQUIV が両方減る（結論が変わる or 追加探索が増える）。
- 候補C
  - 現在のデフォルト: “検索した” という形式を満たすだけで、反証としての情報利得が低い検索でも通過しがち。
  - 変更後アウトカム: 形式充足だけの通過が減り、結論に進む前に「pivot を潰す検索/閲覧」へ差し替わる（追加探索が増える）。

---

Step 3: 1つ選ぶ
選択: 候補B（Core Step 5 の「反証対象の選択」）
選定理由（2点）:
1) compare の停滞要因になりがちな「反証が形式化して pivot を潰せない」を、IF/THEN の行動差（次に何を検索/閲覧するか）として直接変えられる。
2) pivot を「EQUIV↔NOT_EQUIV を反転させる命題」と定義することで、EQUIV/NOT_EQ の片側だけを慎重化しにくく、両方向の誤判定を同時に抑えやすい。

---

Step 4: 改善仮説（1つ）
仮説: 反証チェックが「どの命題を潰すか」を明示しないまま実施されると、検索/閲覧が非識別的（generic）になり、pivot claim が未検証のまま結論へ進みやすい。pivot claim を明示させ、その否定を直接狙う反証行動に寄せると、偽 EQUIV と偽 NOT_EQUIV の双方が減る。

---

Step 5: 抽象ケースで Before/After の挙動差（結末まで明記）
抽象ケース:
- Change A と Change B は見た目の差分（構造差/条件分岐の配置差）があるが、実際にテストの判定値へ影響するかどうかは「ある1つの前提（pivot）」に依存する（例: その分岐がテスト入力に到達するか、別の箇所で同等の正規化が既に行われているか）。
Before（起きがち）:
- pivot を明示せずに Step 5 を消化し、「何か検索した」だけで EQUIV を宣言してしまい、実は pivot が偽で偽 EQUIV になる。
After（避けられる）:
- pivot を明示し、その否定が成立するなら存在するはずの証拠（到達経路・代替実装・相殺ロジック等）を狙って検索/閲覧するため、pivot が偽なら反例が見つかって NOT_EQUIV（もしくは少なくとも結論保留/低確信度ではなく追加探索）へ分岐し、偽 EQUIV を避ける。
（同様に、pivot が真である証拠が得られれば、構造差だけで早期 NOT_EQUIV に倒れるのを避け、偽 NOT_EQUIV も減る。）

---

SKILL.md 該当箇所（短い自己引用）と変更案
対象（Step 5）:
- 現行: “Prioritize the claim/assumption whose negation would flip the final answer (EQUIV↔NOT_EQUIV / PASS↔FAIL) when choosing what to refute first.”（SKILL.md Step 5, L121–L123 付近）
- 変更: ここに「pivot claim を1行で明示し、その否定を直接狙う反証行動を選ぶ」を追加（ただし証拠種類や観測境界のテンプレ固定はしない）。

Decision-point delta（IF/THEN 2行）
Before: IF performing Step 5 refutation THEN pick some plausible target and perform at least one search/inspection because “a refutation step is mandatory.”
After:  IF performing Step 5 refutation THEN explicitly name the pivot claim and choose a search/inspection that would most directly falsify that pivot because “only pivot-refutation changes the final answer reliably.”

変更差分プレビュー（Before/After、Trigger line planned を1行だけ含める）
Before:
- Prioritize the claim/assumption whose negation would flip the final answer (EQUIV↔NOT_EQUIV / PASS↔FAIL) when choosing what to refute first.
- ...
After:
- Prioritize the claim/assumption whose negation would flip the final answer (EQUIV↔NOT_EQUIV / PASS↔FAIL) when choosing what to refute first.
- Trigger line (planned): "Write the pivot claim explicitly (one line) and pick a refutation action (search/inspection) designed to falsify it."

Discriminative probe（抽象ケースで 2〜3 行）
- 変更前は「とりあえず検索」→ pivot 未検証のまま EQUIV/NOT_EQUIV を出して誤判定しがち。
- 変更後は pivot を明示し、その否定を狙う検索/閲覧へ差し替わるため、反例があるケースでは早期に NOT_EQUIV へ、反例がないケースでは EQUIV の根拠が締まり、両方向の誤判定が減る。

failed-approaches.md との照合（整合 1–2 点）
- 「証拠種類の事前固定」「単一 witness への還元」を避け、pivot の否定に直結する探索行動を都度設計する（failed-approaches.md L8–L17 に整合）。
- 結論直前の新しい必須メタ判断を増やさず、既存の必須 Step 5 の中で“何を反証するか”の選択を改善する（failed-approaches.md L28–L32 に抵触しない）。

Payment
- MUST の純増は行わない（既存 Step 5 の行動選択を具体化するのみ）。

変更規模の宣言
- SKILL.md への変更は 5 行以内（想定: Step 5 に 1 行追加、もしくは 1 行置換で完結）。
