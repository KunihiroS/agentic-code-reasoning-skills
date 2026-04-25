# Iteration 57 — proposal discussion

## 1. 既存研究との整合性

検索なし（理由: 提案は「仮説駆動探索」「判別力の高い次アクション選択」「反証可能な情報利得」という一般原則の範囲で自己完結しており、特定の外部概念・新規用語・研究主張に強く依拠していないため）。

README.md / docs/design.md との整合性は概ね高い。設計文書は、番号付き前提、仮説駆動探索、手続き間トレース、反証チェックを certificate として使い、Unsupported claim や premature conclusion を抑える方針を説明している。今回の提案は結論規則を変えず、Step 3 の「次に読む対象」を live hypotheses の分離力で選ばせる変更なので、研究コアのうち hypothesis-driven exploration を実行時行動に近づけるものと見なせる。

## 2. Exploration Framework のカテゴリ選定

カテゴリ B（情報の取得方法を改善する）の選定は適切。

理由:
- 提案の主対象は EQUIV/NOT_EQUIV の定義や結論条件ではなく、ファイルを開く前に「どの artifact を読むか」をどう優先順位付けするかである。
- Objective.md のカテゴリ B は「コードの読み方」「どう探すか」「探索の優先順位付け」を含むため、Step 3 の optional INFO GAIN を DISCRIMINATIVE READ TARGET に置換する方向と合っている。
- カテゴリ C の比較枠組み変更やカテゴリ D の終盤 self-check 強化ではなく、探索時点の読み先選択を改善するため、過去の失敗で問題になった結論ゲート増設とは異なる。

## 3. EQUIVALENT / NOT_EQUIVALENT の両方向への作用

EQUIVALENT 側:
- 変更前は、差分を見た後に局所的な downstream confirmation へ流れ、十分に分離的でない読み先でも「同じ outcome らしい」とまとめる危険がある。
- 変更後は、少なくとも 2 つの live hypotheses を分ける source/test artifact を事前に名指しするため、「本当に同じ outcome へ収束するのか」「未読の分岐で divergence が残るのか」を確認しやすくなる。
- 偽 EQUIV を減らす方向に作用する。

NOT_EQUIVALENT 側:
- 変更前は、最初に目立つ構造差・ファイル差を読んだだけで、その差分が relevant tests の outcome に届くか不十分なまま NOT_EQUIV に寄る危険がある。
- 変更後は、差分そのものではなく live hypotheses を分離する最小 artifact を選ばせるため、「差分が assertion outcome へ到達する」側の読み先へ寄りやすい。
- 偽 NOT_EQUIV を減らす方向にも作用しうる。

片方向最適化の懸念:
- 提案は EQUIV のための再収束規則でも、NOT_EQUIV のための構造差昇格規則でもない。追加探索の対象選択を変えるだけなので、片方向にだけ強く倒す変更ではない。
- ただし “smallest artifact” が強すぎると、最初に選んだ局所 artifact へ探索が狭まる可能性がある。この点は “if none exists, write NOT FOUND and broaden one step” により一定程度緩和されている。

## 4. failed-approaches.md との照合

本質的な再演ではないと判断する。

- 原則 1（再収束の前景化）: NO。再収束を比較規則にしていない。
- 原則 2（未確定 relevance を保留側へ倒す）: NO。UNVERIFIED や保留を結論前の既定動作にしていない。
- 原則 3（差分昇格条件を抽象ラベルで強ゲート）: NO。新しい分類ラベルを verdict 昇格条件にしていない。ただし “DISCRIMINATIVE READ TARGET” が単なる記入欄ではなく探索前の必須行動になるため、実装時は verdict gate と混同しない必要がある。
- 原則 4（終盤チェックを confidence 調整へ吸収）: NO。終盤チェックには触れていない。
- 原則 5（最初の差分から単一追跡経路を既定化）: NO。最初に見えた差分ではなく、複数仮説を分ける artifact を選ぶという点で逆方向。ただし “smallest” の解釈が「常に単一 assertion/check」へ縮むと危ういので、source/test artifact の自由度は維持すべき。
- 原則 6（探索理由と情報利得の圧縮）: 概ね NO。NEXT ACTION RATIONALE は残し、INFO GAIN を単に理由欄へ吸収せず、読み先選択欄として置換しているため。ただし OPTIONAL INFO GAIN の削除により「どの仮説を confirm/refute するか」の明示が弱まらないよう、DISCRIMINATIVE READ TARGET 内に “separate at least two live hypotheses” を残すことが重要。

## 5. 汎化性チェック

固有識別子チェック:
- 具体的な benchmark case ID: なし。
- 特定リポジトリ名: なし。
- 特定テスト名: なし。
- 実コード断片の引用: なし。
- 数値 ID: proposal の Step 番号や行数規模、一般的な “2 つの live hypotheses” は手順説明であり、ベンチマーク固有 ID ではない。

ドメイン暗黙前提:
- “source/test artifact”, “hypotheses”, “assertion outcome” は compare タスク一般の語彙であり、特定言語・フレームワークに依存しない。
- Go/JS/TS/Python のいずれにも適用可能で、特定のテストパターンや repository layout を前提にしていない。

汎化性は PASS 水準。

## 6. compare 影響の実効性チェック

0) 実行時アウトカム差:
- 追加探索で次に読む対象が変わる。変更前は NEXT ACTION RATIONALE と任意 INFO GAIN だけで、目立つ変更ファイルや広い周辺探索に流れうる。変更後は、少なくとも 2 つの live hypotheses を分離しうる最小 source/test artifact を先に名指しし、見つからなければ NOT FOUND として 1 段だけ広げる。
- 観測可能な差は、探索ログに DISCRIMINATIVE READ TARGET が現れ、読み先の選択理由が「分離できる仮説」に結びつくこと。

1) Decision-point delta:
- IF/THEN 形式で 2 行（Before/After）になっているか: YES。
- Before: IF 次に読む対象を選ぶ THEN HYPOTHESIS/EVIDENCE/CONFIDENCE と NEXT ACTION RATIONALE を書き、INFO GAIN は任意。
- After: IF 次に読む対象を選ぶ THEN 少なくとも 2 つの live hypotheses を分離しうる最小 source/test artifact を先に名指しし、なければ NOT FOUND として 1 段だけ広げる。
- 条件も行動も同じで理由だけ言い換えか: NO。任意の説明欄から、読み先選択の必須欄へ変わっている。
- Trigger line が差分プレビュー内に含まれるか: YES。`DISCRIMINATIVE READ TARGET: [smallest source/test artifact likely to separate at least two live hypotheses; if none exists, write NOT FOUND and broaden one step]` が自己引用されている。

2) Failure-mode target:
- 対象は両方。
- 偽 EQUIV: 分離力の低い downstream confirmation だけで「同じ」と見る前に、差分が outcome に届く可能性を分ける artifact を読むことで低減。
- 偽 NOT_EQUIV: 目立つ構造差だけで divergence と見る前に、relevant test/source の分岐に届く artifact を読むことで低減。

2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か:
- NO。STRUCTURAL TRIAGE の結論条件、早期 NOT_EQUIV 条件、impact witness 要件を直接変更しない。
- したがって、ファイル差だけを NOT_EQUIV 根拠にする退化はこの提案の直接リスクではない。

3) Non-goal:
- 探索経路を固定しない。
- 新しい結論ゲートを増やさない。
- 証拠種類を source/test artifact のどちらか一方へ事前固定しない。
- EQUIV/NOT_EQUIV の定義、STRUCTURAL TRIAGE の早期結論条件、特定 assertion boundary への固定は変えない。

## 7. 停滞診断

監査 rubric に刺さる説明強化へ偏り、compare の意思決定を変えていない懸念:
- 懸念は小さい。proposal は「説明を厚くする」だけでなく、Step 3 の実行時分岐を Optional INFO GAIN から必須の DISCRIMINATIVE READ TARGET へ置換し、実際に読む artifact の選択を変える。ただし実装時にこの欄が単なる説明文になり、読み先選択に反映されなければ停滞する。

failed-approaches.md の停滞パターン該当:
- 探索経路の半固定: NO。ただし “smallest artifact” を「常に単一 test/assertion」と解釈すると YES に近づくため、source/test artifact の選択幅を残す必要がある。
- 必須ゲート増: NO。proposal は OPTIONAL INFO GAIN の置換と mandatory 強調文の削除を payment として示している。ただし削除対象が Step 5 の refutation mandatory 文である点はやや不自然で、実装では研究コアの必須反証を弱めないよう注意。
- 証拠種類の事前固定: NO。source/test artifact としており、特定の証拠種類だけへ固定していない。

## 8. Discriminative probe

抽象ケース:
- 片方の変更は入力の前処理を変え、もう片方の変更は呼び出し側の分岐条件を変える。最初に見える diff は別々だが、ある relevant input では同じ assertion outcome になり、別の input では分岐する可能性がある。
- 変更前は、目立つ diff を順に読むだけで「どちらも同じテストを通しそう」と偽 EQUIV、または片側だけに前処理差があるとして偽 NOT_EQUIV に倒れがち。
- 変更後は、前処理と呼び出し分岐の両仮説を分ける合流点または relevant test usage を先に読むため、既存の探索総量を増やさず、読み順の置換で誤判定を避けやすい。

この probe は新しい必須ゲートの純増ではなく、既存 OPTIONAL 欄の置換と冗長 MUST 文削除という支払いで説明されている。

## 9. 支払い（必須ゲート総量不変）の検証

A/B 対応付けは proposal 内で明示されている。

- A: add MUST `DISCRIMINATIVE READ TARGET: ...`
- B: demote/remove MUST `This step is **mandatory**, not optional.`

ただし、B の削除対象は SKILL.md 上では Step 5 Refutation check の強調文であり、Step 3 の Optional INFO GAIN と直接同じ局所ではない。見出し `Step 5: Refutation check (required)` と guardrail により必須反証は残るため致命的ではないが、実装者には、反証チェックそのものを弱める意図がないことを rationale に明記させるのが望ましい。

## 10. 全体の推論品質への期待

期待できる改善:
- 仮説駆動探索が「仮説を書く」だけで終わらず、次に読む artifact の選択へ接続される。
- 広すぎる周辺読み、最初の差分へのアンカー、説明だけの INFO GAIN を減らし、同じ探索量でも判別的な観察を得やすくなる。
- EQUIV 判定では、差分が本当に outcome に影響しないかを分ける読み先を選びやすくなる。
- NOT_EQUIV 判定では、構造差が actual test outcome に届くかを分ける読み先を選びやすくなる。
- 変更規模は小さく、研究コアの番号付き前提・仮説駆動探索・手続き間トレース・反証チェックを維持している。

## 修正指示（最小限）

1. 実装時は `DISCRIMINATIVE READ TARGET` を verdict gate として扱わず、あくまで Step 3 の「次に読む artifact 選択」欄として置くこと。
2. `smallest source/test artifact` が単一 assertion/check 固定に読めないよう、source と test のどちらも選べること、見つからなければ 1 段だけ broaden することをそのまま残すこと。
3. Payment で Step 5 の mandatory 強調文を削る場合は、見出し・Counterexample check・Compare checklist に残る必須反証を弱めないことを rationale に明記すること。可能なら削除ではなく、Step 3 内の OPTIONAL INFO GAIN 置換を主な支払いとして扱う方が安全。

## 結論

承認: YES
