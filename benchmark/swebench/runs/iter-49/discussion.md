# Iteration 49 — proposal discussion

## 1. 既存研究との整合性

検索なし（理由: 提案は特定研究の新概念に依拠せず、SKILL.md / README.md / docs/design.md に既にある semi-formal reasoning、hypothesis-driven exploration、certificate-based reasoning の一般原則の範囲で自己完結している）。

整合性は概ね高い。docs/design.md は「premises → evidence gathering → counterexample check → formal conclusion」と、テンプレートが unsupported claim を抑える certificate として働くことを重視している。今回の提案は、探索の次行動を「未解決 uncertainty」一般ではなく「EQUIV/NOT_EQUIV verdict claim を反転しうるか」で選ばせるため、証拠収集を certificate の結論部へ接続しやすくする変更である。

懸念は、Compare template 冒頭の “Complete every section...” を弱める点。ただし Core Method と Step 5.5 を維持し、代替文も certificate sections を evidence guide として使う表現なので、研究コアの削除ではなく、過剰な全欄完遂指示を verdict-bearing evidence へ寄せる置換として許容できる。

## 2. Exploration Framework のカテゴリ選定

カテゴリ A「推論の順序・構造を変える」は適切。提案の中心は、新しい証拠種類や判定規則ではなく、次に読む対象の優先順位を「結論から逆算して必要な証拠を特定する」方向へ変えることだからである。

副次的には G「認知負荷の削減」も含む。Optional INFO GAIN を verdict-flip target へ置換し、重い全セクション完遂命令を弱める payment があるため。ただし主効果は簡素化ではなく探索順の分岐変更なので、A を主カテゴリにするのは理にかなっている。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用

- EQUIVALENT 側: semantic difference を見つけた後でも、その差分が relevant test/assertion outcome を反転しうる claim なのかを明示するため、差分を見ただけの偽 NOT_EQUIV を減らす可能性がある。confidence-only と判定される探索は、追加ブラウズではなく UNVERIFIED 明示または CONFIDENCE 調整へ回る。
- NOT_EQUIVALENT 側: まだ反転可能な unresolved claim がある場合は、結論前にその trace を優先するため、早すぎる EQUIV を減らす可能性がある。単なる「差分なし」確認ではなく、verdict-bearing claim を反転できる探索が残っているかを見るためである。
- 片方向最適化か: 片方向ではない。EQUIV では過剰な差分昇格を抑え、NOT_EQUIV では未探索の反転 claim を優先する。ただし “confidence only” を広く使いすぎると premature EQUIV に倒れるリスクがあるため、提案の After にある “unless a required trace or refutation item is still missing” は実装時に必ず残すべきである。

## 4. failed-approaches.md との照合

- 原則 1（再収束の前景化）: NO。再収束や下流一致を既定の比較規則にしていない。
- 原則 2（未確定 relevance を常に保留へ倒す）: NO。未確定性を一律保留にせず、verdict-flip target と confidence-only を分ける。
- 原則 3（新しい抽象ラベル/言い換え形式で差分昇格を強くゲート）: 概ね NO。ただし “VERDICT-FLIP TARGET” が新しいラベルとして形式充足だけに使われるリスクはある。提案は差分昇格ゲートではなく探索優先度の指定なので、本質的再演とは見なさない。
- 原則 4（証拠十分性を confidence 調整へ吸収）: NO。ただし confidence-only 分岐が広すぎると近づく。required trace / refutation item が missing なら confidence-only に逃がさない境界条件があるため許容。
- 原則 5（最初の差分から単一追跡経路を半固定）: NO。むしろ複数 unresolved claim から verdict を変えうるものを選ぶ設計であり、単一アンカー固定ではない。
- 原則 6（探索理由と情報利得を潰しすぎる）: NO。NEXT ACTION RATIONALE は残し、INFO GAIN を削って rationale に吸収するのではなく、verdict 反転可能性を別行として置換している。

## 5. 汎化性チェック

提案文に、ベンチマークケース ID、具体的リポジトリ名、具体的テスト名、実コード断片は含まれていない。Step 番号、SKILL.md 自身の引用、一般概念としての assertion / helper function / relevant test は R1 の減点対象外。

特定言語・特定フレームワーク・特定テストパターンへの暗黙依存も薄い。抽象ケースに「補助関数」「assertion outcome」が出るが、これは言語非依存の比較推論単位として一般的である。

## 6. compare 影響の実効性チェック

0) 実行時アウトカム差:
- 次に読む対象を選ぶ前に “VERDICT-FLIP TARGET” を名指すため、ANSWER を変えうる claim が残る場合は追加探索が発生し、confidence-only の場合は追加探索を抑えて UNVERIFIED 明示または CONFIDENCE 低下へ分岐する。
- 観測可能には、NEXT ACTION RATIONALE 周辺の記述、追加探索の有無、結論保留/CONFIDENCE の下げ方が変わる。

1) Decision-point delta:
- IF/THEN 形式で 2 行（Before/After）になっているか: YES。
- Before: IF an uncertainty remains after reading THEN choose a next file/step justified by rationale and optional info gain because it may resolve a hypothesis or claim.
- After: IF an uncertainty remains after reading THEN choose the next file/step only if it names an unresolved EQUIV/NOT_EQUIV claim it could change; otherwise conclude with stated uncertainty or lower CONFIDENCE because the action is confidence-only.
- 条件も行動も同じで理由だけ言い換えか: NO。追加探索する条件が “uncertainty generally” から “verdict claim を変えうる unresolved claim” へ変わっている。
- 差分プレビュー内に Trigger line があるか: YES。`Trigger line (planned): "MUST name VERDICT-FLIP TARGET: ..."` が含まれている。

2) Failure-mode target:
- 対象は両方。偽 NOT_EQUIV は、差分が verdict-bearing でないのに過大評価する場合を減らす。偽 EQUIV は、未解決 claim が verdict を反転しうるのに探索を止める場合を減らす。
- メカニズムは、探索の情報利得を verdict claim に接続し、単なる curiosity / template order の探索と conclusion-bearing trace を分けること。

2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か:
- NO。提案は STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を狭めたり広げたりするものではない。
- impact witness 要求の有無: N/A。ただし STRUCTURAL TRIAGE を実装差分で触らないことが前提。触る場合は、ファイル差だけでなく PASS/FAIL に結びつく assertion boundary を 1 つ目撃する要求が必要になる。

3) Non-goal:
- 探索経路を半固定しない。
- 新しい必須ゲートを純増しない。
- 証拠種類を事前固定しない。
- 特定 assertion boundary、テスト種別、構造差パターンを判定規則にしない。
- 必須行を増やす分は、既存 optional info-gain 行の置換と全セクション完遂命令の弱化で支払う。

## 7. 停滞診断

監査 rubric に刺さる説明強化へ偏り、compare の意思決定を変えていない懸念: 小さい。Decision-point delta と Trigger line があり、実行時には「追加で読む / 結論へ進む / CONFIDENCE を下げる」の分岐条件が変わる。ただし実装時に “VERDICT-FLIP TARGET” が単なる飾り行になると停滞するため、After 文言は “or confidence only” まで含めて、実際の分岐に接続する必要がある。

failed-approaches.md 該当性:
- 探索経路の半固定: NO。verdict-bearing claim を選ぶが、特定ファイル・特定 assertion・単一路線へ固定していない。
- 必須ゲート増: NO。MUST 行は増えるが、optional info-gain 行の置換と全セクション完遂命令の弱化という payment が明記されている。
- 証拠種類の事前固定: NO。必要なのは claim の反転可能性であり、証拠種類を file list / assertion / test type などに固定していない。

## 8. Discriminative probe

抽象ケース: 2 つの変更に内部差分はあるが、既存テストの assertion outcome は同じ可能性が高い。一方で、その内部差分が別の relevant path で FAIL/PASS を変える可能性も残っている。

変更前は、テンプレート順に周辺を読み続けて保留が増えるか、内部差分だけで NOT_EQUIV に寄りやすい。変更後は、次の trace が “その差分が EQUIV/NOT_EQUIV claim を反転しうるか” を名指すため、反転可能なら探索し、反転できないなら confidence-only として結論または低 confidence に進める。

これは新しい必須ゲートの純増ではなく、optional info-gain の置換と全セクション完遂命令の弱化で総量不変にする説明になっている。

## 9. 必須ゲート総量不変の支払い確認

A/B の対応付けは明示されている。追加される MUST は “VERDICT-FLIP TARGET” 行で、支払いは optional INFO GAIN の置換、および “Complete every section...” の弱化/削除である。compare の実効差を出すための必須行が増える一方、既存の重い完遂命令を緩めるため、停滞しにくい形になっている。

## 10. 全体の推論品質への期待効果

期待効果は、探索を「読みやすい順」「不安が残る順」から「ANSWER を変えうる claim 順」へ寄せること。これにより、無関係な追加ブラウズ、差分の過大評価、証拠不足のままの早期 closure の三つを同時に抑えられる可能性がある。

特に、Step 3 の上流で効くため、後段の formal conclusion だけを整える変更よりも、実際の compare 実行中の観測・探索・結論タイミングに作用しやすい。

## 修正指示（最小限）

1. 実装時は Trigger line をそのまま差分に入れること。特に “or 'confidence only'” と、その場合の “prefer concluding with explicit uncertainty/CONFIDENCE over more browsing unless a required trace or refutation item is still missing” を落とさない。
2. “Complete every section...” を弱める場合でも、Core Method の順序実行と Step 5.5 の必須 self-check は維持することを文面上で明確に残す。
3. “VERDICT-FLIP TARGET” を新しい分類ラベルの充足にしないため、例示や実装文言で特定の証拠種類・assertion boundary・構造差パターンを必須化しないこと。

承認: YES
