# Iteration 16 — Discussion

## 総評
提案の核は、compare の判定基準そのものを変えるのではなく、全モード共通の Step 5（反証）で「どの主張を先に反証するか」の優先順位を明確化する点にあります。既存の 3 例を残したまま探索対象を増やすのではなく、4 行を 1 行に置換して認知負荷を下げつつ、反証の焦点を結論反転に効く主張へ寄せる設計になっており、R2/R4/R5 と整合的です。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

補足:
- README.md / docs/design.md の研究コアは「番号付き前提・仮説駆動探索・手続き間トレース・必須反証」。本提案はこのうち必須反証の運用粒度を調整するだけで、コア構造を壊していません。
- docs/design.md の「per-item iteration が premature conclusion を防ぐ」という趣旨とも矛盾しません。今回の変更は per-item 反証をやめるのではなく、複数候補があるときに先にどれを叩くかを明示するものです。

## 2. Exploration Framework のカテゴリ選定
判定: 妥当（カテゴリ E: 表現・フォーマット改善）

理由:
- 追加しているのは新しい探索テンプレートでも新しい証拠種でもなく、Step 5 の Scope 文の置換です。
- 変更の本体は「反証対象の選び方を 1 行で具体化する」ことであり、手順や判定基準を新設していないため、A/C/D より E に近いです。
- ただし実効面では単なる wording tweak ではなく、Step 5 内の注意配分を変えるため、E の中でも compare に効くタイプの変更です。

## 3. compare 影響の実効性チェック
### 3.1 Decision-point delta
- IF/THEN 形式で 2 行（Before/After）になっているか: YES
- Trigger line（発火する文言の自己引用）が差分プレビューに含まれているか: YES
  - After 行: "when there are many, pick 1–2 hinge claims that would flip the verdict if false (label them C#) and refute those first."
- 理由だけの言い換えか: NO
  - Before は「重要な中間主張ごと」に広く反証。
  - After は「複数あるなら、結論を反転させる hinge claim を 1–2 個選んで先に反証」という優先順位の分岐を追加しており、反証リソース配分が変わります。

Before:
- IF 重要な中間主張が複数ある THEN 代表例に沿って各主張を同列に反証しに行く。

After:
- IF 重要な中間主張が複数あり焦点が分散しそう THEN verdict を反転させる hinge claim を 1–2 個選び、その主張を先に反証する。

### 3.2 Failure-mode target
- 対象: 両方（偽 EQUIV / 偽 NOT_EQUIV）
- メカニズム:
  - 偽 EQUIV 側: 本当は非同値なのに、周辺主張ばかり検証して decisive な差分主張の反証が抜ける失敗を減らす。
  - 偽 NOT_EQUIV 側: 周辺的な差異や局所挙動の違いを過大評価し、テスト結果を反転させない非本質差分で NOT_EQUIVALENT に寄る失敗を減らす。

### 3.3 Non-goal
- 変えないことは明示できている。
- STRUCTURAL TRIAGE、早期 NOT_EQUIV 条件、観測境界への還元は触らないと書かれており、探索経路の半固定・必須ゲート増・証拠種類の事前固定を避ける境界条件として十分です。

### 3.4 Discriminative probe
抽象ケース:
- 2 つの変更に局所的な実装差はあるが、既存テスト結果を本当に分けるのは「その差が assertion に到達するか」という 1 つの主張だけである場合。
- 変更前は「振る舞いが X」「テストが無い」「結果が同一/相違」などを横並びに検討して、支点でない差異に引っ張られて誤って NOT_EQUIVALENT か EQUIVALENT に寄る余地がある。
- 変更後は、その verdict を反転させる hinge claim を先に反証するので、既存の Step 5 を置換するだけで、必須ゲートを増やさずに誤判定を避けやすくなる。

### 3.5 支払い（必須ゲート総量不変）
- A/B の対応付けは明示されている: Step 5 の Scope 1 行 + 例示 3 行を、同じ位置の Scope 1 行へ置換。
- したがって「必須ゲート総量不変」の条件は満たしている。

## 4. EQUIVALENT / NOT_EQUIVALENT への作用分析
### EQUIVALENT への作用
- 主に偽 EQUIV を減らす方向で効きます。
- 現状の Step 5 は代表例を列挙していて有用ですが、複数の中間主張がある compare では、どれが結論反転に効く主張なのかを明示していません。そのため、反証が「周辺 claims の確認」で終わり、決定的 counterexample 探索が弱くなる余地があります。
- hinge claim 優先にすると、「もし非同値ならどの claim が崩れるはずか」を先に叩けるため、EQUIVALENT 主張の過剰成立を抑えやすいです。

### NOT_EQUIVALENT への作用
- 偽 NOT_EQUIV も減らす余地があります。
- compare では局所差分を見つけた時点で、その差分が本当にテスト outcome を割るかどうかが本質です。hinge claim 優先は、周辺的な semantic difference を decisive difference と取り違えるリスクを下げます。
- つまり「差異の存在」ではなく「判定を反転させる差異か」に反証を集中させるため、NOT_EQUIVALENT の過剰宣言も抑えられます。

### 片方向最適化の懸念
- 明白な片方向最適化ではありません。
- ただし、"pick 1–2 hinge claims" が強すぎると、独立な hinge が 3 つ以上ある複雑ケースで他の重要 claim を見落とす表面上のリスクはあります。
- そのため実装時は「when there are many」の条件を保ち、少数の decisive claims を優先する趣旨に留めるのが安全です。現 proposal 文面のままなら許容範囲です。

## 5. failed-approaches.md との照合
### 本質的再演か
判定: NO

理由:
- 「証拠種類の事前固定」ではない。提案は test search / control-flow check / outcome refutation のような証拠種を固定せず、どの主張を先に疑うかだけを指定している。
- 「特定の観測境界への還元」でもない。STRUCTURAL TRIAGE や test visibility へ判定を縮退させていない。
- 「新しい必須メタ判断の増設」でもない。既存の mandatory Step 5 内の Scope 文を置換しているだけで、Step 5.5 や conclusion 前に新しいゲートは増えていない。

### 停滞診断（必須）
- 懸念 1 点:
  - 「反証の説明をうまく書かせる」だけに留まり、実際の compare の分岐を変えない危険はゼロではありません。だが本 proposal は Before/After を IF/THEN で切り、反証対象の優先順位を変えるので、単なる説明強化に留まる案より一段良いです。

### failed-approaches 該当性チェック（必須）
- 探索経路の半固定: NO
- 必須ゲート増: NO
- 証拠種類の事前固定: NO

補足:
- "refute those first" は優先順位づけではあるが、どこから読むか・どの境界を先に確定するかを固定していないため、failed-approaches のいう半固定そのものとは言いにくいです。

## 6. 汎化性チェック
判定: 問題なし

確認結果:
- proposal.md に具体的な数値 ID、ベンチマークケース名、特定リポジトリ名、特定テスト名、対象コード断片の引用は含まれていません。
- 引用されているのは SKILL.md 自身の文言だけで、Objective.md の R1 減点対象外に該当します。
- ドメイン依存性も弱いです。hinge claim という概念は compare に限らず、静的推論一般で使える抽象概念であり、特定言語・フレームワーク・テスト様式に依存していません。

軽微な注意:
- "label them C#" は compare テンプレート内の claim 番号文化と整合するが、全モード共通 Step 5 に入れるには少し compare 寄りです。とはいえ SKILL.md 全体が claim numbering を採用しているため、汎化性違反とまでは言えません。

## 7. 推論品質の向上見込み
期待できる改善:
- 反証の焦点が「重要そうな主張一般」から「verdict を反転させる主張」へ移る。
- compare でありがちな、周辺差分の検討に時間を使って decisive claim の検証が薄くなる問題を軽減できる。
- 4 行を 1 行へ置換するため、複雑性を増やさず、むしろ Step 5 の読みやすさと運用一貫性が上がる。
- 全モード共通 Step 5 の wording 改善なので、compare 以外でも「反証の打ちどころ」を選ぶ質が上がる可能性がある。

## 8. 監査結論
結論:
- 監査 PASS の下限を満たしたまま compare に効く改善として成立しています。
- 特に、Decision-point delta と Trigger line が proposal 内で具体化され、かつ支払い（4 行→1 行の置換）が明示されている点を評価します。

実装時の注意（軽微）:
1. "1–2 hinge claims" を絶対数の強い制約として読ませないよう、"when there are many" の条件を必ず残すこと。
2. C# ラベル付けを残すなら、Step 2/compare template の既存 claim numbering と自然につながる書き方にし、全モード共通 Step 5 で compare 専用文言に見えすぎないようにすること。
3. 例示 3 行を削る以上、置換後 1 行で「final conclusion だけでなく intermediate claim にも反証を適用する」という元の射程を落とさないこと。

承認: YES
