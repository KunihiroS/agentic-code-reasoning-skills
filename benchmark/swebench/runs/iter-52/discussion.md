# Iteration 52 — Proposal Discussion

## 監査結論

承認候補: YES

提案は、STRUCTURAL TRIAGE や assertion/check 固定を強めず、結論直前の自己確認を「最弱の verdict-bearing link と ANSWER/CONFIDENCE/UNVERIFIED の対応」へ置換するもの。新しい探索経路や証拠種類を増やすのではなく、既存 Step 5.5 の広い自己確認 1 行と Step 6 の confidence 表現を置換・圧縮するため、監査 PASS の下限を満たしつつ compare の出力分岐に実効差が出る見込みがある。

## 1. 既存研究との整合性

検索なし（理由: 一般原則の範囲で自己完結）。

README.md と docs/design.md で確認できる範囲では、この SKILL.md の研究コアは「番号付き前提、具体的 trace、反証、形式的結論」による certificate-based reasoning である。今回の提案は、そのコア構造を変えず、形式的結論直前に証拠チェーンの弱点と confidence/UNVERIFIED の対応を明示させるだけなので、既存設計と整合する。

## 2. Exploration Framework のカテゴリ選定

カテゴリ D（メタ認知・自己チェックを強化する）の選定は適切。

理由:
- Objective.md の D は「結論に至った推論チェーンの弱い環を特定」「確信度と根拠の対応を明示」を含む。
- proposal は Step 5.5 の Pre-conclusion self-check と Step 6 の confidence を直接対象にしており、探索順序・証拠取得方法・比較単位そのものは変更していない。
- 汎用原則としても、結論を出す直前に一番弱い根拠が verdict なのか confidence なのか UNVERIFIED なのかを分けることは、過剰な高信頼判定と過剰な全面保留の両方を抑える方向に働く。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用

EQUIVALENT 側:
- semantic difference は観測されたが、既存テストの assertion outcome は同じ、ただし一部の前提が third-party behavior や indirect dispatch に依存する場合に、偽の HIGH confidence EQUIV を下げる。
- 影響が verdict に必要なのに未検証なら、EQUIV と断言せず impact UNVERIFIED または限定的な追加探索に戻す。
- 一方で、弱いリンクを明示した結果、そのリンクが verdict を変えないと整理できれば、不要な保留を避けて EQUIV を維持できる。

NOT_EQUIVALENT 側:
- 差分があり、traced assert/check result の差に到達している場合は、最弱リンクが verdict を支えると明示して NOT_EQUIVALENT を維持できる。
- 差分はあるが、assertion outcome への接続が弱い場合は、偽の高信頼 NOT_EQUIV を confidence 低下または UNVERIFIED に落とせる。
- STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を狭める変更ではないため、「ファイル差があるだけで NOT_EQUIV を禁じる」方向の片側最適化ではない。

片方向性の確認:
- 変更の主効果は ANSWER を EQUIV/NOT_EQUIV のどちらかへ誘導することではなく、verdict-bearing link の弱さを ANSWER / CONFIDENCE / UNVERIFIED に割り当てること。
- そのため、EQUIV 側では偽の高信頼 EQUIV を抑え、NOT_EQUIV 側では偽の高信頼 NOT_EQUIV を抑える。片方向にだけ作用する提案ではない。

## 4. failed-approaches.md との照合

該当しないと判断する。

- 原則 2（未確定 relevance や脆い仮定を常に保留側へ倒す）: NO。proposal は weakest link を見つけたら必ず保留するとは書いていない。supports verdict / lowers confidence / leaves impact UNVERIFIED の分岐を要求しており、未確定性を単一の保留トリガーにしていない。
- 原則 3（差分昇格条件を新しい抽象ラベルや必須言い換え形式で強くゲート）: NO。新しい分類ラベルを作るのではなく、既存の conclusion/self-check の表現を置換する。verdict-bearing link という語はあるが、差分を中間ラベルで二分して探索範囲を決める規則ではない。
- 原則 4（終盤チェックを confidence-only へ吸収）: NO。proposal は confidence だけでなく ANSWER と UNVERIFIED への影響を明示するため、最低限の検証フロアを消していない。
- 原則 5（探索経路の半固定）: NO。nearest assertion/check や単一 test/input への探索開始点固定ではなく、結論チェーン全体の最弱リンクを出力形式へ対応づけるだけ。
- 原則 6（探索理由と情報利得を短く潰す）: NO。Step 3 の探索理由欄や optional info gain を統合・削除する変更ではない。

過去失敗の再演可能性として一番近いのは原則 2 の「結論直前に未検証の最弱リンクを扱う」系だが、本 proposal は「未検証なら確定しない」ではなく「supports / lowers confidence / UNVERIFIED を選ぶ」ため、本質的再演にはなっていない。

## 5. 汎化性チェック

固有識別子の混入: なし。

確認結果:
- 具体的なベンチマーク ID、リポジトリ名、ファイルパス、テスト名、関数名、実コード断片は含まれていない。
- SKILL.md 自身の文言引用（例: “The conclusion I am about to write...”）は Objective.md の R1 減点対象外に該当する。
- “third-party/library behavior”, “indirect dispatch”, “assert/check” は一般概念であり、特定ドメイン・特定言語・特定テストパターンへの依存ではない。
- Go/JS/TS/Python のいずれにも限定されず、静的比較一般に適用できる。

## 6. 推論品質の期待改善

期待される改善:
- 結論直前の「証拠を超えない」という抽象チェックが、実際には通過儀礼化して ANSWER と CONFIDENCE の分離に効かない問題を緩和する。
- 最弱リンクを名指しさせることで、証拠チェーン中の unverified assumption が verdict を左右するのか、confidence だけを下げるのかが見えやすくなる。
- 結論の停止条件を単純に厳しくするのではなく、ANSWER 維持・confidence 低下・UNVERIFIED・一点追加探索の分岐に分けるため、保守的すぎる保留と早すぎる高信頼結論の両方を抑えられる。

## 停滞診断（必須）

懸念 1 点:
- proposal は監査 rubric に刺さる語彙（Payment、Decision-point delta、Trigger line、Discriminative probe）を十分に含むため、形式上は通りやすい。ただし今回は、実行時に HIGH→MEDIUM/LOW、impact UNVERIFIED、または一点追加探索へ戻るという観測可能な差分が明記されており、単なる説明強化には留まっていない。

failed-approaches 該当確認:
- 探索経路の半固定: NO。原因文言なし。
- 必須ゲート増: NO。Step 5.5 の既存必須 1 行を置換する Payment が明示されている。
- 証拠種類の事前固定: NO。特定の証拠種類や assertion boundary だけを要求していない。

## compare 影響の実効性チェック（必須）

0) 実行時アウトカム差:
- 同じ ANSWER でも CONFIDENCE が HIGH から MEDIUM/LOW に下がる。
- impact UNVERIFIED が明示される。
- verdict を左右する弱いリンクが残る場合、FORMAL CONCLUSION へ進まず一点追加探索へ戻る可能性がある。
- ANSWER 自体も、弱いリンクが verdict を支えないと分かれば過剰な NOT_EQUIV/EQUIV から保留または別判定へ変わりうる。

1) Decision-point delta:
- IF/THEN 形式で 2 行（Before/After）になっているか？ YES。
- Before/After は「条件も行動も同じで理由だけ言い換え」ではない。Before は global confidence を付けて結論へ進みがち、After は weakest link を名指しして verdict/confidence/UNVERIFIED/follow-up を分岐させる。
- Trigger line が差分プレビュー内に含まれているか？ YES。
- Trigger line: “Before ANSWER/CONFIDENCE, name the weakest verdict-bearing link and state whether the evidence supports the verdict, lowers confidence, or leaves impact UNVERIFIED.”

2) Failure-mode target:
- 対象は両方。
- 偽 EQUIV: semantic difference の影響が弱い仮定に依存しているのに、同一 outcome と見なして高信頼 EQUIV に進む誤りを減らす。
- 偽 NOT_EQUIV: 差分はあるが assertion outcome への接続が弱いのに、高信頼 NOT_EQUIV に進む誤りを減らす。
- メカニズムは、最弱リンクを verdict 支持・confidence 低下・impact UNVERIFIED に分けること。

2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？
- NO。
- STRUCTURAL TRIAGE の直接 NOT_EQUIV 許可条件は変更しない。したがって impact witness 要求の有無は今回の承認条件にはならない。
- ただし proposal が明示している通り、早期 NOT_EQUIV 条件を特定の観測境界へ写像する案を選ばない点は妥当。

3) Non-goal:
- 探索開始点を assertion/check や単一 test/input に固定しない。
- 新しい必須ゲートを純増しない。
- 証拠種類を事前固定しない。
- 構造差を NOT_EQUIV へ昇格する条件を狭めたり広げたりしない。
- 終盤チェックを confidence-only に吸収しない。

## Discriminative probe（必須）

抽象ケース:
- 2 つの変更は主要テストの assert/check では同じ outcome に見えるが、一方の trace だけが未読の外部 API の戻り値仮定に依存している。
- 変更前は「結論が証拠を超えない」と見なして HIGH EQUIV へ進みがち。変更後はその外部 API 仮定を weakest verdict-bearing link として名指しし、assertion outcome に影響しないなら confidence を下げて EQUIV、影響しうるなら impact UNVERIFIED または一点追加探索に戻る。
- これは新しい必須ゲートではなく、既存 Step 5.5 の 1 行置換と Step 6 の confidence 表現の結び直しで説明されている。

## 支払い（必須ゲート総量不変）の確認

A/B 対応は明示されている。

- Add: MUST “Before ANSWER/CONFIDENCE, name the weakest verdict-bearing link and state whether the evidence supports the verdict, lowers confidence, or leaves impact UNVERIFIED.”
- Remove: MUST “The conclusion I am about to write asserts nothing beyond what the traced evidence supports.”

Step 6 も “Assigns a confidence level” を “tied to the weakest verdict-bearing link” へ置換するだけなので、必須ゲートの純増ではなく、総量不変の範囲に収まる。

## 軽微な修正指示

承認前に必須ではないが、実装時は以下だけ注意すること。

1. “requires one targeted follow-up” は Decision-point delta にはあるが Trigger line には入っていない。実装で追加探索要求まで含めるなら、既存文言のどれを置換するかを崩さず、Trigger line と差分本文の表現を揃えること。
2. “weakest verdict-bearing link” が未検証なら常に保留、という読み方にならないよう、supports verdict / lowers confidence / leaves impact UNVERIFIED の三分岐を維持すること。
3. Step 5.5 の既存チェックのうち file:line trace、VERIFIED/UNVERIFIED、semantic difference と assert/check result の接続は削らないこと。

## 最終判定

承認: YES
