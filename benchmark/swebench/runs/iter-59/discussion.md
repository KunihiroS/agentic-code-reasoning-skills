# Iteration 59 — Discussion / Audit

## 1. 既存研究との整合性

検索なし（理由: 提案は「半形式的な証拠チェーン」「結論前 self-check」「未検証事項の confidence/UNVERIFIED 反映」という一般原則の範囲で自己完結しており、特定研究の新規概念・固有用語へ強く依拠していない）。

README.md / docs/design.md の研究コアとは概ね整合する。番号付き前提、実コード trace、反証、formal conclusion の枠組みを削らず、Step 5.5 の結論前チェックを具体化しようとしている点は、certificate による premature conclusion 抑制という設計意図に沿う。

ただし、今回の具体案は failed-approaches.md に既に明文化された危険パターンと強く重なるため、研究コアとの整合性だけでは承認できない。

## 2. Exploration Framework のカテゴリ選定

カテゴリ D（メタ認知・自己チェックを強化する）の選定自体は適切。

- 「結論に至った推論チェーンの弱い環を特定させる」
- 「確信度と根拠の対応を明示させる」

という D の説明に合っている。新しい比較モードや言語固有の探索ではなく、結論直前の自己チェックを扱うため、カテゴリ選定としては自然。

しかし、D に属することは承認理由にはならない。failed-approaches.md はまさにこの方向の過去失敗として「広い『結論が証拠を超えない』確認を、最弱リンクの名指しと confidence / UNVERIFIED への振り分けに置換する形も危うい」と記録している。カテゴリは合っているが、選んだメカニズムが過去失敗の本質に近すぎる。

## 3. EQUIVALENT / NOT_EQUIVALENT 双方への作用

提案の意図上の作用:

- EQUIVALENT 側: NO COUNTEREXAMPLE や trace が弱いまま EQUIVALENT に進む場合、weakest verdict-supporting link を名指しさせ、追加確認または CONFIDENCE/UNVERIFIED 反映へ送ることで偽 EQUIV を減らす狙い。
- NOT_EQUIVALENT 側: 構造差や局所差だけで NOT_EQUIV に進む場合、その差が verdict を支える最弱リンクかを確認し、弱ければ追加確認または confidence 反映へ送ることで偽 NOT_EQUIV を減らす狙い。

変更前との差分は、既存の広いチェック

- “The conclusion I am about to write asserts nothing beyond what the traced evidence supports.”

を、

- “The weakest verdict-supporting link is named; if it is UNVERIFIED or only inferred, either perform one targeted check or reflect it in CONFIDENCE/UNVERIFIED before the verdict.”

へ置換する点。

実効差は確かに存在する。変更後は「証拠一般が足りるか」ではなく「verdict を実際に支える最弱リンクが未検証・推論のみか」によって、追加探索 / UNVERIFIED / CONFIDENCE 低下の分岐が発火する。

ただし、その分岐は EQUIV/NOT_EQUIV のどちらにも効きうる一方で、failed-approaches.md 原則 2 と 4 が警告する通り、実運用では「弱い箇所の名指し」自体が目的化し、局所的な弱点処理へ過剰適応する危険が高い。特に Step 5.5 の広い証拠十分性チェックを削って置換するため、総合的な主張範囲抑制が弱まる可能性がある。

## 4. failed-approaches.md との照合

最大の問題は、failed-approaches.md 原則 4 の次の文言と本質的に重なること。

> 広い「結論が証拠を超えない」確認を、最弱リンクの名指しと confidence / UNVERIFIED への振り分けに置換する形も危うい。過剰な保留を避ける意図でも、証拠十分性の総合確認が弱まり、局所的な弱点の扱いだけが目的化しやすい。

今回の proposal はまさに以下を行う。

- 既存の広い自己確認を削る / demote する。
- weakest verdict-supporting link の名指しへ置換する。
- 未検証または推論のみなら targeted check、CONFIDENCE、UNVERIFIED のいずれかへ振り分ける。

表現上は「confidence-only ではなく targeted check も許す」「verdict を支える場合だけ」と緩和しているが、本質は failed-approaches.md が危険視した置換と同じである。したがって、これは過去失敗の再演と判断する。

## 5. 汎化性チェック

固有識別子チェック:

- 具体的なベンチマーク ID: なし。
- リポジトリ名: なし。
- テスト名: なし。
- 実コード断片: なし。
- 特定ファイルパスや関数名への依存: なし。

SKILL.md 自身の文言引用と抽象的な helper / branch / assertion boundary 程度の語は、Objective.md の R1 減点対象外に該当する一般概念として扱える。

特定ドメイン・言語・テストパターンへの暗黙依存も強くは見えない。静的 trace と verdict-supporting claim という抽象に留まっており、Go/JS/TS/Python のいずれにも限定されない。

汎化性だけなら問題は小さい。

## 6. 全体の推論品質への期待効果

期待効果は理解できる。

- 結論直前に、verdict を支える最弱の claim を明示させる。
- 弱さが verdict に効く場合だけ、局所確認または confidence/UNVERIFIED へ反映する。
- 未検証事項をすべて保留に倒すのではなく、結論に効く弱さだけを扱う。

この狙いは、過信した EQUIV と過信した NOT_EQUIV の両方を抑える可能性がある。

しかし、今回の文面は「広い証拠十分性チェック」を置換してしまうため、推論品質の改善よりも「最弱リンク処理」という局所メタ認知へ焦点が移る。failed-approaches.md 原則 4 の懸念が直接当たるため、期待効果を上回る回帰リスクがある。

## 停滞診断（必須）

懸念 1 点:
- proposal は Decision-point delta、Trigger line、Payment、Discriminative probe を揃えており、監査 rubric に刺さる説明は十分。ただし compare の実行時には「weakest link を書く → confidence/UNVERIFIED に逃がす」だけで、既存の per-test outcome 比較そのものを変えない可能性がある。すなわち、説明強化に比べて verdict 分岐の実効変化が局所的すぎる懸念がある。

failed-approaches 該当性:
- 探索経路の半固定: NO。特定ファイル、特定 assertion、単一 trace 起点を固定してはいない。
- 必須ゲート増: NO（形式上）。既存 Step 5.5 の 1 行置換であり、純増ではない。ただし、置換後の要求は新しい必須 self-check として働く。
- 証拠種類の事前固定: NO。特定の証拠種類を固定してはいない。

ただし、上記 3 つとは別に、failed-approaches.md 原則 4 の明示済み失敗文言に該当する。原因文言は proposal の Payment と After 行:

- “demote/remove MUST(\"The conclusion I am about to write asserts nothing beyond what the traced evidence supports.\")”
- “The weakest verdict-supporting link is named; if it is UNVERIFIED or only inferred, either perform one targeted check or reflect it in CONFIDENCE/UNVERIFIED before the verdict.”

## compare 影響の実効性チェック（必須）

0) 実行時アウトカム差
- 変更後は、ANSWER 直前に weakest verdict-supporting link が UNVERIFIED / only inferred なら、追加探索を 1 回行う、または CONFIDENCE を下げる、または UNVERIFIED を明示する、という観測可能な変化が起きる。

1) Decision-point delta
- IF/THEN 形式で 2 行（Before/After）になっているか？ YES。
- Before: IF traced evidence seems generally sufficient THEN proceed to FORMAL CONCLUSION because broad evidence-bounds self-check passed.
- After: IF the weakest verdict-supporting link is UNVERIFIED or only inferred THEN perform one targeted check OR carry that weakness into CONFIDENCE/UNVERIFIED before the verdict because the weak link directly supports the answer.
- 条件も行動も同じ言い換えか？ NO。条件は「一般的な証拠十分性」から「verdict を支える最弱リンクの未検証性」へ変わり、行動も「結論へ進む」から「targeted check / confidence / UNVERIFIED 反映」へ変わる。
- Trigger line が差分プレビュー内に含まれるか？ YES。

ただし、ここが具体的であるにもかかわらず、failed-approaches.md 原則 4 の既知の失敗形と一致するため承認不可。

2) Failure-mode target
- 対象: 両方。
- 偽 EQUIV: 反例探索の前提や helper / downstream behavior が未検証なのに「差なし」と結論する過信を、weakest link の明示で抑える。
- 偽 NOT_EQUIV: 構造差・局所差が実際の test outcome に届くか弱いまま「差あり」と結論する過信を、weakest link の明示で抑える。
- 機構: verdict を支える claim のうち最弱のものを、ANSWER 前の追加確認または不確実性表示へ接続する。

2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？
- NO。proposal は Step 5.5 の結論前 self-check 置換であり、STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を直接変更しない。
- impact witness 要求の有無は、この提案の主対象ではない。ただし Structural triage を触らないため、この点を理由に NO とはしない。

3) Non-goal
- 探索経路の半固定はしない。
- 必須ゲート総量は増やさない（1 行置換）。
- 証拠種類を事前固定しない。
- 特定 assertion boundary、テスト依存、oracle 可視性などへ構造差を狭めない。

## Discriminative probe（必須）

抽象ケース:
- 片方の変更で条件分岐は変わるが、その分岐が既存テストの PASS/FAIL に届くかは未読 helper の戻り値に依存している。
- 変更前は「trace は概ね十分」として EQUIV または NOT_EQUIV に進みやすい。変更後は helper の戻り値が weakest verdict-supporting link として名指しされ、1 回の局所確認または CONFIDENCE/UNVERIFIED 反映が起きる。
- これは proposal 内では既存 Step 5.5 の 1 行置換として説明されており、必須ゲート純増ではない。

この probe 自体は compare 影響を示せている。しかし、failed-approaches.md 原則 4 と同じ置換形であるため、probe の存在だけでは承認できない。

## 必須ゲート総量不変の支払い確認

proposal は Payment を明示している。

- add: weakest verdict-supporting link の名指しと処理。
- demote/remove: 既存の広い evidence-support self-check。

A/B の対応付けは明示されている。形式上の「支払い」は満たしている。

ただし、支払い対象がまさに failed-approaches.md 原則 4 で危険視された「広い証拠十分性チェックの置換」であるため、支払いがあることはむしろ再演性を強める。

## 修正指示（最小限）

1. 最大ブロッカーを避けるため、既存の広い self-check を demote/remove しないこと。追加するなら置換ではなく、既存行の中に「verdict-supporting weakest link は例示的な確認対象であり、総合的な evidence-bound check を代替しない」と統合する形にする。

2. どうしても必須行を 1 行に収めるなら、Payment の支払い先を Step 5.5 の広い evidence-support 行ではなく、より重複している近接表現へ変えること。少なくとも “asserts nothing beyond what the traced evidence supports” の機能は残す。

3. After 文言から “reflect it in CONFIDENCE/UNVERIFIED” だけで閉じられる逃げを弱めること。例: 「追加確認できない場合に限り confidence/UNVERIFIED へ反映」とし、confidence-only premature closure への誘導を抑える。

## 総合判断

カテゴリ選定、汎化性、Decision-point delta、Trigger line、Discriminative probe、Payment の形式はかなり整っている。通常なら監査 PASS の下限に近い。

しかし、failed-approaches.md に、今回とほぼ同じ本質の失敗形が既に明記されている。特に「広い証拠十分性チェックを、最弱リンクの名指しと confidence / UNVERIFIED 振り分けへ置換する」点が一致する。

このため、細部の粗さではなく、過去失敗の本質的再演として差し戻す。

承認: NO（理由: failed-approaches.md 原則 4 の本質的再演。広い evidence-bound self-check を weakest verdict-supporting link + CONFIDENCE/UNVERIFIED 処理へ置換しており、証拠十分性の総合確認を弱める既知の失敗方向に該当する）
