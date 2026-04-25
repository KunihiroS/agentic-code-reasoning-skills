# iter-61 proposal discussion

## 1. 既存研究との整合性

検索なし（理由: 一般原則の範囲で自己完結）。

提案は外部の新しい専門概念へ強く依拠しているというより、既に参照ファイル内で整理されている Agentic Code Reasoning の中核、すなわち per-test iteration、interprocedural tracing、data-flow tracking、divergence analysis を compare の既存チェックリストへ戻す変更である。README.md と docs/design.md だけで、研究コアとの整合性は判断できる。

## 2. Exploration Framework のカテゴリ選定

カテゴリ F「原論文の未活用アイデアを導入する」の選定は概ね適切。

理由:
- docs/design.md は、Fault Localization の Code Path Tracing / Divergence Analysis と、Code QA の function trace / data flow tracking を、論文から抽出された重要要素として整理している。
- proposal はそれを新しい mode や独立 gate として足すのではなく、既存 compare checklist の「Trace each test through both changes separately before comparing」を、テスト assertion が読む value/API contract まで揃える形に置換している。
- 汎用原則としても、内部実装差を比較する前に「テストが実際に観測する値・契約」で両側を揃えるのは、patch equivalence の定義（テスト pass/fail outcome の同一性）と整合する。

軽微な注意点:
- これは F だけでなく E（曖昧な指示の具体化）にもまたがる。ただし、docs/design.md の data-flow / divergence の移植という説明があるため、主カテゴリ F として問題ない。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用

EQUIVALENT 側:
- 変更前は、両側の説明がそれぞれ成り立つだけで SAME に寄る可能性がある。
- 変更後は、同じ assertion-facing value/API contract 上で両側の値が一致しているかを見るため、高レベル説明だけで偽 EQUIV に倒れるリスクを下げる。

NOT_EQUIVALENT 側:
- 変更前は、内部 helper や中間表現の差だけで DIFFERENT に寄る可能性がある。
- 変更後は、テストが読む値・契約まで trace してから DIFFERENT を置くため、内部差が最終観測値で吸収されるケースの偽 NOT_EQUIV を減らす。

片方向最適化か:
- 片方向ではない。比較点を「内部差分」でも「高レベル要約」でもなく「テスト assertion が読む観測値」に揃えるため、偽 EQUIV と偽 NOT_EQUIV の両方に効く。
- ただし、再収束を EQUIV の既定規則にしてしまうと failed-approaches 原則 1 に近づく。proposal は shared value/API contract を「吸収説明」ではなく SAME/DIFFERENT の比較対象明示として使う、と明記しているため、このリスクは許容範囲。

## 4. failed-approaches.md との照合

本質的な再演ではないと判断する。

- 原則 1「再収束を比較規則として前景化しすぎない」: NO。提案は下流一致を優先する規則ではなく、比較点を assertion-facing value/API contract に揃える置換である。ただし実装文が「共有 value に到達すれば同じ」と読めると危険なので、値が同じなら SAME、違えば DIFFERENT という両方向性を維持する必要がある。
- 原則 2「未確定 relevance や脆い仮定を常に保留側へ倒す」: NO。UNVERIFIED や confidence を主対象にしておらず、未確定時の広い保留既定動作を追加していない。
- 原則 3「差分昇格条件を新ラベルや必須の言い換え形式でゲートしすぎる」: NO寄り。新ラベルは追加していない。既存の trace 行の置換なので必須ゲート総量も不変。ただし「name the assertion-facing value/API contract」が形式充足だけに流れると中間表現化するため、実装では Comparison 行の直前に密着させ、独立セクション化しないこと。
- 原則 4「終盤 self-check を confidence 調整へ吸収」: NO。Step 5.5 は維持される。
- 原則 5「最初に見えた差分から単一の追跡経路を即座に既定化」: NO。起点を最初の差分に固定するのではなく、既存の per-test trace の比較終点を明確にする変更である。
- 原則 6「探索理由と情報利得を圧縮しすぎる」: NO。Step 3 の探索理由欄には触れていない。

## 5. 汎化性チェック

固有識別子チェック:
- 具体的なベンチマーク ID: なし。
- リポジトリ名: なし。
- テスト名: なし。
- 実コード断片: なし。
- SKILL.md 自身の文言引用: あり。ただし Objective.md の R1 減点対象外に該当する。

ドメイン偏り:
- 「helper」「API response」「field」という probe の語彙は Web/API 系を少し想起させるが、抽象例としての範囲に収まる。
- 実際の proposed diff は value/API contract と assertion-facing value という言い方で、Go/JS/TS/Python や特定フレームワークに限定されない。

判定: 汎化性違反なし。

## 6. compare 影響の実効性チェック

0) 実行時アウトカム差:
- Per-test Comparison の直前で、ANSWER の根拠が「両側 trace がある」から「同じ assertion-facing value/API contract 上の side-specific value が示されている」へ変わる。
- 観測可能には、SAME/DIFFERENT の直前に、テスト assertion が読む値・契約と両側の値が明示される。
- それが揃わない場合、即 SAME/DIFFERENT ではなく、追加の targeted trace が要求される。

1) Decision-point delta:
- IF/THEN 形式で 2 行（Before/After）になっているか: YES。
- Before: IF each side has a separate trace to the test THEN assign SAME/DIFFERENT because both outcomes are narratively explained.
- After: IF each side's trace reaches the same assertion-facing value/API contract with side-specific values THEN assign SAME/DIFFERENT; otherwise perform one more targeted trace to that observed value.
- 条件も行動も同じで理由だけ言い換えか: NO。比較ラベルを置く条件が「別々の trace」から「同じ観測値/契約への到達と値の明示」へ変わっている。
- proposal の差分プレビュー内に Trigger line が含まれているか: YES。`before comparing, name the assertion-facing value/API contract and each side's value at that point.` が自己引用されている。

2) Failure-mode target:
- 対象: 両方（偽 EQUIV / 偽 NOT_EQUIV）。
- 偽 EQUIV への機構: 高レベルに同じ説明ができても、assertion-facing value で side-specific value が違えば DIFFERENT に倒せる。
- 偽 NOT_EQUIV への機構: 内部実装差があっても、assertion-facing value が同じなら、内部差だけで DIFFERENT としない。

2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か:
- NO。proposal は Structural triage の早期 NOT_EQUIV 条件を変更しない。
- impact witness 要求の確認: 該当なし。ただし既存の Counterexample にある Diverging assertion は維持され、proposal も削っていない。

3) Non-goal:
- 探索経路の半固定はしない。特定の assertion boundary を探索開始点に固定するのではなく、既存 per-test trace の比較点を、テストが読む値・契約として明確化するだけ。
- 必須ゲート総量は増やさない。既存 checklist 1 行の置換であり、独立セクションや新ラベルを追加しない。
- 証拠種類の事前固定はしない。値、API contract、assertion-facing behavior のいずれでもよく、言語・フレームワーク固有の証拠形式を要求しない。

## 7. Discriminative probe

抽象ケース:
- Change A は内部正規化を helper 内で行い、Change B は呼び出し側で同じ正規化を行う。テストは最終公開 API の戻り値だけを assert する。
- 変更前は helper の中間差で偽 NOT_EQUIV、または「どちらも正規化する」という説明だけで偽 EQUIV が起きうる。
- 変更後は既存 1 行の置換だけで、比較点が最終 assert 値に揃う。同じ値なら偽 NOT_EQUIV を避け、異なる値なら偽 EQUIV を避ける。

この probe は新しい必須ゲートの増設ではなく、既存 trace 行の置換として説明されているため、compare への実効差がある。

## 8. 停滞診断

監査 rubric に刺さる説明強化へ偏り、compare の意思決定を変えていない懸念:
- 懸念は小さい。proposal は research alignment や failed-approaches 照合だけでなく、Per-test Comparison の SAME/DIFFERENT を置く条件そのものを変えている。ただし実装時に Trigger line が checklist から離れて rationale だけに残ると、説明強化止まりになるため、差分プレビュー通り checklist 内に入れる必要がある。

failed-approaches 該当確認:
- 探索経路の半固定: NO。理由: 「特定の assertion boundary に探索開始点を固定することはしない」と明記し、既存 per-test trace の比較終点を明確化しているため。
- 必須ゲート増: NO。理由: Payment で既存 MUST 相当 1 行の置換を明示しているため。
- 証拠種類の事前固定: NO。理由: value/API contract は比較対象の観測面を示す抽象語であり、特定のファイル種別・テスト形式・言語機能を要求していないため。

支払い（必須ゲート総量不変）の検証:
- A/B 対応付けは明示されている。`add MUST(...) ↔ demote/remove MUST("Trace each test through both changes separately before comparing")` により、増設ではなく置換であることが分かる。

## 9. 全体の推論品質への期待効果

期待できる改善:
- per-test compare が、内部実装差の印象や高レベル要約ではなく、テストが実際に読む観測値へ接地される。
- SAME / DIFFERENT の根拠が、より判別的で反証可能になる。
- 既存の interprocedural tracing と counterexample obligation を弱めず、Comparison 行の直前の粒度だけを改善するため、複雑性増加に対して効果が見合う。
- EQUIVALENT 判定では「違って見えるが観測値は同じ」を拾いやすくなり、NOT_EQUIVALENT 判定では「同じ説明に見えるが観測値が違う」を拾いやすくなる。

## 10. 最小限の実装時注意

1. Trigger line は必ず Compare checklist の置換行に含める。rationale 側だけに置かない。
2. 「共有 value/API contract」を EQUIV の既定規則として書かない。必ず `each side's value at that point` まで要求し、同じなら SAME、違えば DIFFERENT の両方向に使う。
3. 新しい独立セクション、ラベル、pre-comparison gate は作らない。proposal 通り既存 1 行の置換に留める。

## 11. 監査結論

承認: YES
