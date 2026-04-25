過去提案との差異: 構造差や早期 NOT_EQUIV を特定の観測境界へ写像して狭める提案ではなく、結論直前の自己チェックで「verdict を支える最弱リンク」の扱いを明示して過信と過保留の両方を抑える。
Target: 両方
Mechanism (抽象): Step 5.5 の曖昧な証拠超過チェックを、最弱の verdict-supporting claim を名指しして CONFIDENCE / UNVERIFIED / 追加探索のどれに反映するかを決める分岐へ置換する。
Non-goal: 構造差から NOT_EQUIV へ進む条件を、テスト依存・oracle 可視・特定 assertion boundary などの固定境界へ狭めない。

カテゴリ D 内での具体的メカニズム選択理由
- D のうち「結論に至った推論チェーンの弱い環を特定させる」と「確信度と根拠の対応を明示させる」を選ぶ。これは新しい比較モードや観測境界ではなく、既存 Step 5.5 の自己チェックを実行時アウトカムへ接続する変更である。
- compare の挙動が変わりうる理由は 2 点: (1) weakest link が verdict を支えていないなら結論を維持し、過度な保留を避ける; (2) weakest link が唯一の verdict 根拠なら、ANSWER へ直行せず CONFIDENCE 低下・UNVERIFIED 明示・局所追加探索のいずれかに分岐する。

ステップ 1: 禁止された方向の列挙
- 再収束を比較規則として前景化し、下流一致を優先する方向。
- 未確定 relevance や脆い仮定を常に保留側へ倒す既定動作。
- 差分の昇格条件を新しい抽象ラベル、二軸分類、固定 assertion/check、単一起点 trace で強くゲートする方向。
- 終盤の証拠十分性チェックを confidence 調整だけへ吸収して premature closure を増やす方向。
- 最初に見えた差分から単一の追跡経路を即座に既定化する方向。
- 情報利得や探索理由を短い単一欄へ潰し、反証可能性を弱める方向。
- 直近却下方向: STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を「特定の観測境界だけ」へ写像して狭める方向。

ステップ 2 / 2.5: overall に直結する意思決定ポイント候補
1. Step 5.5 の結論前 self-check
   - 現在のデフォルト挙動: 「証拠を超えない」という広い文言のため、弱い推論が verdict を支えているかどうかを区別せず、十分そうなら結論へ進みがち。
   - 変更後に観測可能に変わるアウトカム: CONFIDENCE、UNVERIFIED 明示、追加探索、または結論保留が変わる。
2. Compare の NO COUNTEREXAMPLE EXISTS 欄
   - 現在のデフォルト挙動: 指定した反例パターンが見つからなければ EQUIV へ進みやすく、反例探索の前提が狭すぎた場合の弱さが confidence に残りにくい。
   - 変更後に観測可能に変わるアウトカム: 偽 EQUIV 回避、追加探索、CONFIDENCE が変わる。
3. Step 4 の UNVERIFIED source handling
   - 現在のデフォルト挙動: source unavailable を UNVERIFIED と書けば、その仮定が結論にどう効くかの分岐が曖昧なまま結論へ進みがち。
   - 変更後に観測可能に変わるアウトカム: UNVERIFIED 明示、CONFIDENCE、結論保留が変わる。

ステップ 3: 選ぶ分岐
- 選択: 1. Step 5.5 の結論前 self-check。
- 理由: Compare 全体の最後に ANSWER / CONFIDENCE / UNVERIFIED / 追加探索へ直接接続する分岐であり、EQUIV と NOT_EQUIV の両方に作用する。
- 理由: 既存の必須 self-check 1 行を置換するだけなので、新しいモードや固定探索経路を増やさず、IF 条件と THEN 行動を実際に変えられる。

Payment: add MUST("The weakest verdict-supporting link is named; if it is UNVERIFIED or only inferred, either perform one targeted check or reflect it in CONFIDENCE/UNVERIFIED before the verdict.") ↔ demote/remove MUST("The conclusion I am about to write asserts nothing beyond what the traced evidence supports.")

改善仮説
- 抽象仮説: 結論直前の自己チェックを「証拠一般」ではなく「verdict を実際に支えている最弱リンク」へ結びつけると、未検証事項をすべて保留へ送らずに、結論を左右する弱さだけを追加探索・UNVERIFIED・CONFIDENCE に反映でき、偽 EQUIV と偽 NOT_EQUIV の両方を減らせる。

SKILL.md の該当箇所と変更方針
- 現在の該当箇所: Step 5.5 の最後のチェック項目「The conclusion I am about to write asserts nothing beyond what the traced evidence supports.」
- 変更方針: この広い自己確認を、weakest verdict-supporting link の名指しと、その弱さを verdict 前にどう処理するかの分岐へ置換する。

Decision-point delta
Before: IF traced evidence seems generally sufficient THEN proceed to FORMAL CONCLUSION because broad evidence-bounds self-check passed.
After:  IF the weakest verdict-supporting link is UNVERIFIED or only inferred THEN perform one targeted check OR carry that weakness into CONFIDENCE/UNVERIFIED before the verdict because the weak link directly supports the answer.

変更差分プレビュー
Before:
- [ ] The Step 5 refutation or alternative-hypothesis check involved at least one actual file search or code inspection — not reasoning alone.
- [ ] The conclusion I am about to write asserts nothing beyond what the traced evidence supports.

After:
- [ ] The Step 5 refutation or alternative-hypothesis check involved at least one actual file search or code inspection — not reasoning alone.
- [ ] The weakest verdict-supporting link is named; if it is UNVERIFIED or only inferred, either perform one targeted check or reflect it in CONFIDENCE/UNVERIFIED before the verdict.
Trigger line (planned): "The weakest verdict-supporting link is named; if it is UNVERIFIED or only inferred, either perform one targeted check or reflect it in CONFIDENCE/UNVERIFIED before the verdict."

Discriminative probe
- 抽象ケース: 片方の変更だけが分岐条件を変えているが、その分岐が関連テストへ届くかは、未読の helper の戻り値に依存している。
- Before では「既に trace は十分」と見なして偽 EQUIV または偽 NOT_EQUIV へ進みがち。After では helper の戻り値が weakest verdict-supporting link として名指しされ、1 回の局所確認か CONFIDENCE/UNVERIFIED 反映が起きるため、過信した誤判定を避ける。
- これは新しい必須ゲートの純増ではなく、既存 Step 5.5 の広い必須チェック 1 行を、同じ位置で分岐可能な自己チェック 1 行へ置換するだけである。

failed-approaches.md との照合
- 原則 2 との整合: 未検証なら常に保留に倒す規則ではない。weakest link が verdict を支える場合だけ、追加探索または confidence/UNVERIFIED 反映へ分岐する。
- 原則 4 との整合: 終盤チェックを confidence-only へ吸収しない。必要なら局所追加探索を許し、ただし広い探索や新しい固定境界は増やさない。
- 原則 5 との整合: 最初の差分から単一 trace 経路を固定しない。対象は「最弱の verdict-supporting claim」であり、構造差や特定 assertion boundary に限定しない。

変更規模の宣言
- SKILL.md の変更は Step 5.5 のチェック項目 1 行置換のみ、差分 2 行以内の予定。15 行 hard limit を満たす。
