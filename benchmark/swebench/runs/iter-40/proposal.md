過去提案との差異: 早期 NOT_EQUIV の条件を特定の観測境界へ写像して狭めるのではなく、「差分が無関係」と切り捨てる局面で localize/explain 由来の“影響の局在化”を要求して誤った EQUIV を減らす。
Target: 偽 EQUIV（副作用として偽 NOT_EQUIV も抑制）
Mechanism (抽象): 「意味差が見つかったが影響なし」と判断する分岐で、結論に進む前に downstream の観測点まで差分影響を局在化するよう行動を変える。
Non-goal: STRUCTURAL TRIAGE の早期 NOT_EQUIV を新しい必須ゲートで強化/固定したり、特定の境界だけを唯一の根拠型にすることはしない。

Step 1 (禁止方向の整理; failed-approaches + 却下履歴の要約)
- 構造差→NOT_EQUIV を「テスト依存/オラクル可視」など特定の観測境界に写像して成立条件を狭める（探索経路の半固定化になりやすい）
- 結論根拠の型を単一 witness へ還元しすぎる（他の有効シグナルを結論根拠から外して比較を弱める）
- 追うべき証拠種類や読解順序をテンプレで事前固定しすぎる（確認バイアス/探索自由度の低下）
- 結論直前に新しい必須のメタ判断/追加ゲートを純増させる（萎縮・停滞を招きうる）

Step 2 (SKILL.md から: overall に効く意思決定ポイント候補; IF/THEN で書ける分岐)
候補 A: pass-to-pass tests の扱い
- 分岐: IF 「pass-to-pass が changed code の call path に無い/不明」 THEN 「pass-to-pass を比較対象から外す」

候補 B: 意味差を見つけた後の “no impact” 結論
- 分岐: IF 「意味差が見つかった」 THEN 「少なくとも 1 つの relevant test を差分経路で追ってから、影響なし結論に進む/進まない」

候補 C: UNVERIFIED な挙動が trace 上に残る場合の結論強度
- 分岐: IF 「重要な挙動が UNVERIFIED のまま」 THEN 「結論を強く断定する/確信度を下げる/追加探索する」

Step 2.5 (各候補のデフォルト挙動 / 観測可能なアウトカム)
- 候補 A: デフォルト= pass-to-pass を“関係なさそう”として除外しがち / アウトカム= EQUIV 側へ寄りやすい（偽 EQUIV の温床）
- 候補 B: デフォルト= 意味差を見つけても downstream まで追わず「影響なし」で打ち切りがち / アウトカム= 追加探索が発生せず EQUIV に倒れやすい（偽 EQUIV）
- 候補 C: デフォルト= UNVERIFIED を注記しつつも結論自体は強く出しがち / アウトカム= CONFIDENCE の過大化（偽 EQUIV/偽 NOT_EQUIV の両方）

Step 3 (選定)
選ぶ分岐: 候補 B
理由:
- compare の誤り（特に偽 EQUIV）を生む代表的メカニズムである「subtle difference dismissal」を、行動レベル（追跡の到達点）で変えられる。
- Before/After で観測可能アウトカム（追加探索の発生、最終 ANSWER の反転、CONFIDENCE 低下）が明確に変わりうる。

カテゴリ F 内での具体的メカニズム選択理由
- 原論文は patch equivalence を “per-test の証拠付き主張” と “counterexample 義務”で支える（証拠が test outcome へ接続されることが重要）。
- 一方で SKILL.md の compare は「意味差を発見したが影響なし」を早めに言い切る余地が残る。ここに fault localization の発想（差分を downstream の観測点まで局在化する）と、explain の発想（データフロー上の最初の観測点へ追跡する）を移植するのが、カテゴリ F の “localize/explain の compare 応用”に該当する。

改善仮説 (1つ)
- 意味差が見つかった時点で「影響なし」を許すと、差分がテストの観測点へ届くケースを見落として偽 EQUIV を出しやすい。差分影響を “最初の downstream 観測点”まで局在化してからでないと「影響なし」を出せないようにすると、偽 EQUIV を減らし、同時に根拠薄い NOT_EQUIV も抑制できる。

SKILL.md 該当箇所 (自己引用) と変更方針
引用（Compare checklist より）:
- "When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact"
変更: “trace” の到達条件を localize/explain 的に具体化し、少なくとも 1 つの downstream 観測点（assertion / check / 例外の種別など）まで追ってからでないと「影響なし」を結論できない、という行動差を作る。

Decision-point delta (IF/THEN)
Before: IF 「意味差が見つかったが、手元の直観では影響が薄そう」 THEN 「差分経路の追跡を途中で止めて ‘no impact’ に進みがち」 because 根拠型= “局所差分の直観的軽視”
After:  IF 「意味差が見つかり、downstream の観測点での同値がまだ示せない」 THEN 「観測点まで追跡して同値を示すか、示せない限り ‘no impact’ を保留して追加探索する」 because 根拠型= “局在化された観測点での同値/非同値”

変更差分プレビュー (Before/After)
Before:
- Trace each test through both changes separately before comparing
- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact
- Provide a counterexample (if different) or justify no counterexample exists (if equivalent)

After:
- Trace each test through both changes separately before comparing
- When a semantic difference is found, trace at least one relevant test through the differing path up to the first downstream observation point (assertion/check/exception) before concluding it has no impact
- Provide a counterexample (if different) or justify no counterexample exists (if equivalent)

Trigger line (planned): "When a semantic difference is found, trace at least one relevant test through the differing path up to the first downstream observation point (assertion/check/exception) before concluding it has no impact"

Discriminative probe (抽象ケース)
- Before: 2 つの変更が同じ仕様を狙うが、片方だけが入力正規化の順序/条件を変えている。差分が見つかるが、途中までの追跡で「テストはそこを見ていないはず」と判断して EQUIV に倒れ、実際にはテストの観測点で値が分岐して偽 EQUIV になりがち。
- After: “最初の downstream 観測点”まで追うため、正規化結果が観測点へ流れ込む事実（あるいは同値性の成立条件）が明確になり、観測点で分岐するなら NOT_EQUIV、同値に再収束するなら EQUIV を根拠付きで出せる。

failed-approaches.md との照合（整合点）
- 「特定の観測境界だけへ過度に還元」を避ける: 観測点を assertion に固定せず、check/例外など広い観測点概念として “局在化”を要求する（単一 witness 型への還元にしない）。
- 「証拠種類の事前固定」を避ける: 追跡の到達点だけを規定し、どの種類の証拠（テスト/例外/チェック/データフロー）で局在化するかはケースに応じて選べる。

Payment
- Payment: add MUST("…") ↔ demote/remove MUST("…") は発生しない（MUST の純増なし / 新規必須ゲート追加なし）。

変更規模の宣言
- SKILL.md の変更は 1 行の置換（Compare checklist の 1 bullet を差し替え）のみ。