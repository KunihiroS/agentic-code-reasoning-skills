過去提案との差異: 構造差を特定の観測境界へ写像して早期 NOT_EQUIV を狭めるのではなく、ファイルを開く前の探索候補選択を「判別可能な読み先」に寄せる。
Target: 両方
Mechanism (抽象): 次に読む対象を、現在の複数仮説を最も分離する source/test artifact として明示させ、広すぎる読みや最初の差分への固定を減らす。
Non-goal: STRUCTURAL TRIAGE の結論条件、EQUIV/NOT_EQUIV の定義、特定 assertion boundary への固定は変更しない。

カテゴリ B 内での具体的メカニズム選択理由:
- Objective.md のカテゴリ B は「どう探すか」「探索の優先順位付け」を改善する領域であり、SKILL.md Step 3 は既に「discriminative power」を掲げるが、実際の書式は HYPOTHESIS/EVIDENCE/CONFIDENCE と任意の INFO GAIN に留まり、次に読む artifact の選び方が行動分岐として弱い。
- Compare では、広い構造読みだけで過度な NOT_EQUIV に寄る場合と、差分の下流確認だけで過度な EQUIV に寄る場合の両方があるため、結論規則ではなく「次の読み先」を分離力で選ぶ分岐を強化するのが overall に効く。

Step 1 — 禁止方向の列挙:
- 再収束を比較規則として前景化し、差分シグナルを弱める方向。
- 未確定 relevance / weak assumption を広く保留・UNVERIFIED 側へ倒す既定動作。
- 差分の昇格条件を新しい抽象ラベル、claim 形式、観測可能性分類で強くゲートする方向。
- 終盤の証拠十分性チェックを confidence 調整へ吸収し、premature closure を増やす方向。
- 最初に見えた差分から単一 trace / 単一共有テスト / 単一 assertion へ探索を固定する方向。
- 読む理由と反証可能な情報利得を一つに潰して、探索と判定の中間表現を弱める方向。
- 直近却下履歴にある「構造差/早期 NOT_EQUIV 条件を特定の観測境界だけに写像して狭める」方向。

Step 2 / 2.5 — overall に直結する意思決定ポイント候補:
1. Step 3 の次ファイル選択分岐。
   現在のデフォルト: HYPOTHESIS と NEXT ACTION RATIONALE は書くが、INFO GAIN は OPTIONAL なので、不十分な証拠では「目立つ変更ファイル」か「広い周辺読み」に流れがち。
   変更後の観測アウトカム: 追加探索の対象が、EQUIV/NOT_EQUIV のどちらを分けるか明示された artifact へ変わり、UNVERIFIED と CONFIDENCE の根拠も局所化される。
2. Compare の EQUIV 用 NO COUNTEREXAMPLE 分岐。
   現在のデフォルト: semantic difference を見た後は一つの concrete input / same assertion outcome にアンカーするため、未検証時は impact UNVERIFIED へ寄りやすい。
   変更後の観測アウトカム: 保留や UNVERIFIED の扱いは変わるが、観測点固定に近く、却下済み方向へ接近するため採用しない。
3. Step 5.5 の pre-conclusion self-check 分岐。
   現在のデフォルト: 結論直前に trace / search / unsupported claim を確認し、NO なら修正へ戻る。
   変更後の観測アウトカム: 結論保留や再探索は変わるが、終盤チェックを強めると failed-approaches.md 原則 2/4 の保留・confidence 調整過多に寄りやすいため採用しない。

Step 3 — 選定:
選ぶ分岐: Step 3 の次ファイル選択分岐。
理由は 2 点以内:
- IF 条件が「次に読む対象を選ぶとき」なので、ANSWER 前の実行時アウトカムである追加探索の順序と範囲が直接変わる。
- THEN 行動が「理由を書く」から「どの artifact が仮説を分離するかを選ぶ」に変わるため、偽 EQUIV と偽 NOT_EQUIV の両側で証拠取得が変わりうる。

改善仮説:
ファイルを開く前に、現在の競合仮説を最も分離する artifact を明示してから読むようにすれば、広い未確定性や最初の差分に探索が引っ張られにくくなり、同じ証拠量でも EQUIV/NOT_EQUIV の判別に使える観察が増える。

SKILL.md の該当箇所と変更案:
引用: 「Exploration priority is not a fixed reading order; choose the next action by discriminative power — what unresolved uncertainty it resolves.」
引用: 「OPTIONAL — INFO GAIN: [what uncertainty this action resolves; which hypothesis/claim it would confirm vs refute]」
変更: OPTIONAL な補助欄を、次に読む artifact を選ぶ行動欄へ置換する。ただし新しいモードや結論ゲートは足さず、同時に冗長な必須強調を削って mandatory 総量を不変にする。
Payment: add MUST("DISCRIMINATIVE READ TARGET: [smallest source/test artifact likely to separate at least two live hypotheses; if none exists, write NOT FOUND and broaden one step]") ↔ demote/remove MUST("This step is **mandatory**, not optional.")

Decision-point delta:
Before: IF 次に読む対象を選ぶ THEN HYPOTHESIS/EVIDENCE/CONFIDENCE と NEXT ACTION RATIONALE を書き、INFO GAIN は任意 because 根拠型は「読む理由」と「期待」の説明。
After:  IF 次に読む対象を選ぶ THEN 少なくとも 2 つの live hypotheses を分離しうる最小の source/test artifact を先に名指しし、なければ NOT FOUND として 1 段だけ広げる because 根拠型は「分離できる観察の事前指定」。

変更差分プレビュー:
Before:
  NEXT ACTION RATIONALE: [why the next file or step is justified]
  OPTIONAL — INFO GAIN: [what uncertainty this action resolves; which hypothesis/claim it would confirm vs refute]
After:
  NEXT ACTION RATIONALE: [why the next file or step is justified]
  DISCRIMINATIVE READ TARGET: [smallest source/test artifact likely to separate at least two live hypotheses; if none exists, write NOT FOUND and broaden one step]
Trigger line (planned): "DISCRIMINATIVE READ TARGET: [smallest source/test artifact likely to separate at least two live hypotheses; if none exists, write NOT FOUND and broaden one step]"
Payment edit:
  Remove the standalone sentence: "This step is **mandatory**, not optional."

Discriminative probe:
抽象ケース: 片方の変更は入力正規化を変え、もう片方は呼び出し側の分岐を変えており、最初に見える diff は別々だが、同じ relevant test では一部入力だけ結果が分かれる可能性がある。
Before では、目立つ変更ファイルを順に読み「どちらも似た結果に見える」ため偽 EQUIV、または片側の欠落だけを見て偽 NOT_EQUIV が起きがち。
After では、最初に「両仮説を分ける最小 artifact」を選ぶので、入力正規化と呼び出し分岐の合流点か relevant test usage を先に読み、誤判定を追加探索で避ける。これは新しい必須ゲートの純増ではなく、既存 OPTIONAL 欄の置換と冗長 MUST 文の削除で行う。

failed-approaches.md との照合:
- 原則 3/5 と整合: 差分を新しい抽象ラベルへ昇格させず、最初の差分から単一 assertion/check へ固定しない。読む前に候補 artifact の判別力を比較するだけで、結論条件は変えない。
- 原則 2/4/6 と整合: 未検証なら保留へ倒す規則や confidence-only 化ではなく、読む対象を絞る情報取得手順であり、探索理由と反証可能な情報利得を潰さず separate line として残す。

変更規模の宣言:
SKILL.md への実変更は 2 行置換 + 1 行削除の想定で、15 行以内。研究のコア構造（番号付き前提、仮説駆動探索、手続き間トレース、必須反証）は維持する。
