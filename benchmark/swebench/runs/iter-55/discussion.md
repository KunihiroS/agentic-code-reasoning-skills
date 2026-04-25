# Iteration 55 — Discussion

## 監査結論

提案は、STRUCTURAL TRIAGE 本体を弱めず、Compare checklist 側にある構造/規模判断の重複再掲だけを 2 行から 1 行へ圧縮するものです。新しい必須ゲートや証拠種類の固定を増やさず、既存の per-test trace、counterexample/no-counterexample、assertion boundary 要求を残すため、監査 PASS の下限は満たすと判断します。

承認: YES

## 1. 既存研究との整合性

検索なし（理由: 一般原則の範囲で自己完結）。

本提案が依拠しているのは、README.md と docs/design.md に既に記載されている「structured templates act as certificates」「per-item iteration」「interprocedural tracing」「mandatory refutation」という既存設計の範囲です。外部の特定概念へ強く依拠した新規主張ではなく、既存テンプレート内の重複を減らす変更なので DuckDuckGo MCP による追加調査は不要です。

## 2. Exploration Framework のカテゴリ選定

カテゴリ G（認知負荷の削減・簡素化・削除・統合）の選定は適切です。

理由:
- proposal は新しい推論モードや分類軸を追加せず、Compare checklist の重複 2 行を 1 行の参照へ圧縮するだけである。
- Objective.md の G は「重複する指示や冗長な説明を統合・圧縮する」を含み、本提案の実体と一致する。
- 研究コアである番号付き前提、仮説駆動探索、手続き間トレース、必須反証は削除しない。
- 削る対象は certificate 本体ではなく、STRUCTURAL TRIAGE 本体と重複している checklist 側の再掲なので、汎用原則としても理にかなっている。

軽微な注意点として、構造差の扱いは NOT_EQUIV に効きやすい強いシグナルなので、実装時に STRUCTURAL TRIAGE 本体の S1-S3 や早期結論条件まで変更しないことが重要です。proposal はこの点を Non-goal として明示しているため許容できます。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用

### EQUIVALENT 判定への作用

変更前は、STRUCTURAL TRIAGE 本体で一度扱った構造/規模差が Compare checklist 冒頭で再度強調されるため、片側だけの補助ファイル変更や大きめの diff が、実際のテスト到達性より強い NOT_EQUIV シグナルとして残りやすい。変更後は、構造差を一度 triage した後、未解決の test-behavior claim、per-side trace、no-counterexample に作業を戻しやすくなるため、偽 NOT_EQUIV を減らす方向に働く。

### NOT_EQUIVALENT 判定への作用

STRUCTURAL TRIAGE 本体、S2 の completeness、clear structural gap からの早期 NOT_EQUIV、COUNTEREXAMPLE の divergence origin + assertion は残る。したがって、実際に missing module / missing test data / changed call path の不一致がテスト結果差へ結びつく場合の NOT_EQUIV 能力は維持される。さらに、チェックリストの重複で高レベル structural comparison に寄りすぎる代わりに、後続の changed files、tests、per-side trace、counterexample へ進みやすくなるため、構造差だけでは見えない偽 EQUIV も減らしうる。

### 片方向最適化か

片方向だけの最適化ではありません。
- 偽 NOT_EQUIV 対策: 構造差の二重強調を避ける。
- 偽 EQUIV 対策: structural/scale の再確認で止まらず、既存の per-test trace と counterexample/no-counterexample へ進ませる。

ただし、効果の中心は「構造差の過剰サリエンスを下げる」点なので、EQUIV 側への改善期待の方がやや大きいです。NOT_EQUIV 側は、早期結論条件を維持しつつ詳細 trace への移行を妨げない、という保全的な効果です。

## 4. failed-approaches.md との照合

結論: 本質的な再演ではありません。

- 原則 2（未確定 relevance を常に保留側へ倒す）: NO。未確定なら必ず保留、UNVERIFIED、再探索という新しい fallback を追加していない。
- 原則 3（差分の昇格条件を新しい抽象ラベルや必須形式で強くゲート）: NO。構造差を verdict 証拠へ使う条件を新しいラベルで狭めておらず、むしろ重複再掲を削るだけである。
- 原則 4（証拠十分性チェックを confidence へ吸収）: NO。Step 5、Step 5.5、COUNTEREXAMPLE、NO COUNTEREXAMPLE は維持される。
- 原則 5（最初に見えた差分から単一追跡経路を既定化）: NO。特定の trace 起点や単一 shared test へ固定していない。
- 原則 6（探索理由と情報利得を潰しすぎる）: NO。Step 3/4 の中間表現を圧縮する変更ではない。

過去失敗に近づくリスクがあるとすれば、実装時に「structural gap では直接結論しない」方向へ踏み込む場合です。しかし proposal は STRUCTURAL TRIAGE 本体の結論条件を変更しないと明記しているため、現案では該当しません。

## 5. 汎化性チェック

固有識別子・過剰適合:
- 具体的なベンチマークケース ID: なし。
- リポジトリ名: なし。
- テスト名: なし。
- 実コード断片: なし。
- SKILL.md 自身の文言引用: あり。ただし Objective.md の R1 減点対象外に該当する自己引用であり問題なし。

数値について:
- 「>200 lines」は SKILL.md 既存文言の自己引用であり、ベンチマーク固有の数値 ID ではない。
- 「候補 1/2/3」「S1-S3」も提案構造または SKILL.md 内部ラベルであり、ベンチマーク固有 ID ではない。

暗黙のドメイン前提:
- 特定言語、特定フレームワーク、特定テストパターンに依存していない。
- 「modified file lists」「missing modules」「test data」「relevant tests」は静的 compare 一般に適用できる抽象語彙である。

判定: 汎化性違反なし。

## 6. compare 影響の実効性チェック

0) 実行時アウトカム差
- Compare checklist 到達後に、structural/scale comparison を二度目の独立ゲートとして再実行しにくくなる。
- 追加探索の焦点が、構造差の再確認ではなく、未解決の verdict-bearing claim、relevant tests、per-side trace、counterexample/no-counterexample へ移る。
- 構造差が未確定な場面で、ANSWER を早期 NOT_EQUIV に倒す圧力が下がる。
- 大規模差分でも、既に triage した後は high-level comparison だけで閉じるのではなく、既存の証拠欄へ戻りやすくなる。

1) Decision-point delta
- IF/THEN 形式で 2 行（Before/After）になっているか？ YES。
- Before/After が「条件も行動も同じで理由だけ言い換え」か？ NO。Before は checklist で structural/scale を再ゲートする、After は再ゲートせず test/trace/counterexample へ進む、という分岐差がある。
- Trigger line が差分プレビュー内に含まれているか？ YES。
  - Trigger line: “Structural/scale triage is defined above; do not repeat it as a second checklist gate.”

評価:
- Decision-point delta は compare の実行時分岐として具体的です。
- ただし実装時は、この Trigger line が単なる説明文ではなく checklist の実文として入る必要があります。proposal は planned として明示しているため承認可能です。

2) Failure-mode target
- 対象: 両方。ただし主効果は偽 NOT_EQUIV の低減。
- 偽 NOT_EQUIV 低減メカニズム: 構造差・規模差を triage 本体と checklist で二度強調することを避け、未確定な構造差を結論シグナルとして過大評価しにくくする。
- 偽 EQUIV 低減メカニズム: checklist 冒頭の structural/scale 再確認で止まらず、既存の per-test trace と counterexample 探索へ進ませることで、高レベル比較だけの早期同一視を避ける。

2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？
- NO。
- 理由: proposal は STRUCTURAL TRIAGE 本体の S1-S3 と「clear structural gap なら直接 NOT_EQUIV」条件を変更しない。触れているのは Compare checklist 側の重複再掲であり、早期結論ルール自体ではない。
- したがって impact witness 追加要求はこの提案には発火しない。
- ただし、実装時に STRUCTURAL TRIAGE 本体や早期結論条件へ変更範囲を広げるなら、missing file / missing module だけでなく assertion boundary へ結びつく impact witness を要求する必要がある。

3) Non-goal
- STRUCTURAL TRIAGE 本体の S1-S3 は変えない。
- clear structural gap から NOT_EQUIV へ進める既存条件は変えない。
- per-test trace、interprocedural trace、COUNTEREXAMPLE、NO COUNTEREXAMPLE、Step 5/5.5 は変えない。
- 探索経路を単一の test/assertion へ固定しない。
- 新しい必須ゲート、新しい証拠種類、新しい抽象ラベルを追加しない。

## 7. 停滞診断

監査 rubric に刺さる説明強化へ偏り、compare の意思決定を変えていない懸念:
- 懸念は低い。proposal は「重複しているから簡潔にする」だけでなく、Compare checklist 到達時の分岐を Before/After で示し、structural/scale 再ゲートから unresolved verdict-bearing claim への移行という観測可能な差を述べている。

failed-approaches.md 該当性:
- 探索経路の半固定: NO。
- 必須ゲート増: NO。
- 証拠種類の事前固定: NO。

YES の原因文言:
- 該当なし。

支払い（必須ゲート総量不変）:
- 必要な提案か？ YES。必須 checklist の行数を変更するため、支払いの明示が必要。
- A/B 対応付けはあるか？ YES。
  - A: 新規 MUST は none。
  - B: Compare checklist 冒頭 2 行を削除/統合。
- 必須ゲート総量は増えず、むしろ 1 行減る。

## 8. Discriminative probe

抽象ケース:
- Change A だけが補助ファイルを変更し、Change B は主ファイルのみを変更している。ただし、その補助ファイルが relevant tests の assertion outcome に到達するかは STRUCTURAL TRIAGE 時点では未確定。
- 変更前は checklist 冒頭で structural/scale が再強調され、未確定の片側ファイル差が二度目の強い NOT_EQUIV シグナルになりやすい。
- 変更後は新しい必須ゲートを増やさず、重複 2 行を 1 行の参照へ置換するだけで、既存の changed files、test identification、per-side trace、counterexample/no-counterexample へ進むため、ファイル差だけの偽 NOT_EQUIV を避けやすい。

この probe は、追加ゲートではなく既存文言の置換・圧縮で説明できており、compare の観測可能な分岐差もあるため十分です。

## 9. 全体の推論品質への期待効果

期待できる改善:
- 認知負荷を下げる: 同じ structural/scale 判断を certificate 本体と checklist で二度処理する負荷を減らす。
- premature closure を減らす: 構造差または大規模差分の印象で早く閉じる代わりに、未解決の test-behavior claim へ進みやすくする。
- 研究コアを保つ: certificate、本体 triage、per-test analysis、counterexample/no-counterexample を維持する。
- 回帰リスクを抑える: 変更は checklist の局所 2 行→1 行で、diff が小さい。

懸念:
- 「do not repeat it as a second checklist gate」が、誤って「structural triage を軽視してよい」と読まれると、明確な missing module / missing test data の NOT_EQUIV を弱める可能性がある。
- ただし After 文に “triage is defined above” とあるため、本体の triage を実行しない意味ではない。実装時はこのニュアンスを維持すること。

## 10. 最小修正指示

承認可能だが、実装者は以下だけ守ること。

1. STRUCTURAL TRIAGE 本体の S1-S3 と早期 NOT_EQUIV 条件は一切変更しない。
2. Trigger line は proposal の通り Compare checklist の実文として入れる。
3. 「do not repeat」を「do not perform structural triage」と誤読させないよう、After 行は “Structural/scale triage is defined above” を含めたままにする。

## 最終判定

承認: YES
