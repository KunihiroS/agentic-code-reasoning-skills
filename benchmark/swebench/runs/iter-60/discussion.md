# Iteration 60 — Proposal Discussion

## 監査サマリ

提案は、STRUCTURAL TRIAGE 後の早期 NOT_EQUIV を「構造差ラベルだけ」ではなく、既存 COUNTEREXAMPLE 欄で A/B の relevant outcome 差として説明できる場合に限定する、という方向である。

方向性自体は妥当で、compare の実行時アウトカムにも作用しうる。特に、missing file / missing module / missing test data というラベルだけで早期 NOT_EQUIV に倒れる偽陽性を減らす狙いは、README / docs/design.md の「premise、trace、counterexample obligation による premature conclusion 防止」と整合する。

ただし、差分プレビューが既存の `Diverging assertion: [test_file:line ...]` を落としており、After の `Outcome witness: Change A => [PASS/FAIL or behavior], Change B => [PASS/FAIL or behavior]` は、早期 NOT_EQUIV に必要な impact witness を十分に要求していない。STRUCTURAL TRIAGE / 早期結論に触れる提案では、構造差が PASS/FAIL に結びつく具体的な assertion boundary を少なくとも 1 つ目撃できる形が必要である。ここが曖昧なままでは、偽 NOT_EQUIV を減らす意図とは逆に、「relevant outcome」と書いただけの構造差ラベルで早期結論する余地が残る。

## 1. 既存研究との整合性

検索なし（理由: 一般原則の範囲で自己完結）。

根拠は、参照ファイル内で十分に確認できる。README.md は semi-formal reasoning を「premises、file:line evidence、formal conclusions」による unsupported claims の抑制として説明している。docs/design.md も、patch equivalence verification の中核を「per-test iteration、formal definitions of equivalence、counterexample obligation」と整理している。今回の提案は、既存 COUNTEREXAMPLE 欄の表現を outcome に寄せる点ではこの中核と整合する。

## 2. Exploration Framework のカテゴリ選定

カテゴリ E（表現・フォーマット改善）としての選定は概ね適切。

理由:
- 新しい探索モードや別タスクの導入ではなく、既存の早期終了文と COUNTEREXAMPLE 欄の書式を置換する提案である。
- 「構造差」から「outcome witness」へ表現を具体化し、曖昧な `clear structural gap` の使われ方を絞る狙いは E の「曖昧な指示をより具体的な言い回しに変える」に合う。
- Payment も既存 required 行の置換として提示されており、必須ゲート総量を増やさない設計意図はよい。

ただし、実際の After プレビューでは `Diverging assertion` が消えており、単なる表現改善を超えて反例成立条件を弱めている可能性がある。この点はカテゴリ選定ではなく、実装内容のブロッカーである。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用

### EQUIVALENT 側

期待される改善:
- 構造差だけで早期 NOT_EQUIV に進むケースを ANALYSIS に戻すため、実際には relevant tests に影響しない差分を EQUIVALENT と判断できる余地が増える。
- README.md の key findings にある「without-skill models tend to over-predict NOT_EQUIVALENT」という既存傾向への対策としては理にかなう。

懸念:
- `Outcome witness` が `PASS/FAIL or behavior` のままだと、テスト outcome ではなく一般的な behavior 差の記述で NOT_EQUIV に進む余地がある。これは EQUIVALENT 側の偽 NOT_EQUIV 削減効果を弱める。

### NOT_EQUIVALENT 側

期待される改善:
- 真に片側だけが失敗する構造差では、COUNTEREXAMPLE に A/B の outcome 差を書けるため NOT_EQUIV を維持できる。
- 構造差を完全に無効化するのではなく、早期結論の根拠型を outcome witness に揃える点は、真の NOT_EQUIV を過度に削る変更ではない。

懸念:
- 既存の `Diverging assertion` を削ると、真の NOT_EQUIV でも「どの check で outcome が分かれるか」を示さずに結論できる。これは NOT_EQUIV の反証可能性を弱め、逆に誤った NOT_EQUIV を残す。

結論として、変更前との差分は片方向だけではない。EQUIV 側では偽 NOT_EQUIV を減らし、NOT_EQUIV 側では outcome witness が書けるものを維持する設計意図はある。しかし、assertion boundary の保持が欠けるため、実効上は NOT_EQUIV の根拠が弱くなるリスクが残る。

## 4. failed-approaches.md との照合

### 探索経路の半固定
NO。

特定のファイル、テスト、assertion から単一経路を必ず逆算させる提案ではない。STRUCTURAL TRIAGE 後に witness がなければ ANALYSIS へ持ち込むため、探索順を一つに固定する性質は弱い。

### 必須ゲート増
NO寄りだが要修正。

Payment として既存 COUNTEREXAMPLE 行の置換を明示しており、必須ゲート総量不変の意図はある。ただし、プレビュー上は `Diverging assertion` を削っており、これは「増やしすぎ」ではなく「必要な反証可能性を落とす」方向の問題である。

### 証拠種類の事前固定
NO寄り。

`assertion line 固定ではなく、relevant outcome を説明できる witness なら import failure、data absence、call-path behavior などを許す` としており、証拠種類を特定ドメインへ固定する意図はない。

ただし、早期 NOT_EQUIV では「impact witness」を要求する必要がある。これは証拠種類の固定ではなく、D1 の test outcome と counterexample obligation を満たす最低限の境界である。

### 本質的再演の有無
failed-approaches.md 原則 3 の「差分の昇格条件を新しい抽象ラベルや必須の言い換え形式で強くゲートしすぎる」に近づく危険はあるが、現提案の主眼は既存 COUNTEREXAMPLE の置換であり、新しい分類ラベルを増やすものではないため、本質的再演とはまでは言えない。

最大の問題は、過去失敗の再演ではなく、早期結論に必要な assertion boundary / impact witness を差分プレビューから落としている点である。

## 5. 汎化性チェック

固有識別子の混入: なし。

提案文中に、具体的な数値 ID、ベンチマーク対象のリポジトリ名、テスト名、実コード断片は見当たらない。`iter-59` への言及は過去提案との差分説明であり、ベンチマークケース ID ではない。`missing import`、`missing data`、`changed call path` は一般概念であり、特定言語・特定リポジトリへの過剰適合ではない。

暗黙のドメイン前提:
- `import failure` は言語によって表現が異なるが、例示の一つとして扱われており、支配的な前提ではない。
- `PASS/FAIL or behavior` はむしろ広すぎる。汎化性違反ではないが、compare の D1 が test outcome ベースであるため、behavior のみで早期 NOT_EQUIV を許す書き方は危険である。

## 6. 推論品質への期待効果

期待できる品質向上:
- `clear structural gap` を見た瞬間に FORMAL CONCLUSION へ進む premature closure を減らす。
- 構造差を「判定」ではなく「outcome 差を予測できる反例候補」として扱わせるため、STRUCTURAL TRIAGE と counterexample obligation の接続が強くなる。
- 既存の NOT_EQUIV counterexample 欄を活用するため、研究コアである per-test / counterexample 型の証明構造を大きく崩さない。

ただし、`Diverging assertion` を落とすと、反例が「観測可能な test outcome 差」ではなく「説明上の behavior 差」へ緩む。これでは推論品質改善の主効果が薄れる。

## 停滞診断（必須）

監査 rubric に刺さる説明強化へ偏っている懸念: 小さいが存在する。

提案には Decision-point delta、Trigger line、Discriminative probe、Payment が揃っており、単なる監査向け説明ではない。一方で、実際の差分プレビューが `Outcome witness` という新語の説明に寄り、既存の `Diverging assertion` を保持していないため、compare の実行時アウトカム差が「説明文の見栄え」に留まる懸念がある。

failed-approaches.md 該当確認:
- 探索経路の半固定: NO
- 必須ゲート増: NO（ただし Payment の A/B 対応はあるが、必要行の削除が問題）
- 証拠種類の事前固定: NO

YES 該当なし。

## compare 影響の実効性チェック（必須）

0) 実行時アウトカム差
- 観測可能に変わること: STRUCTURAL TRIAGE で clear structural gap を見つけても、COUNTEREXAMPLE に A/B の relevant outcome 差を書けない場合、FORMAL CONCLUSION へ直行せず ANALYSIS に進む。
- ANSWER の出し方: 早期 `NO not equivalent` が減り、追加 trace 後の `YES equivalent` または範囲限定の結論に変わる可能性がある。

1) Decision-point delta
- IF/THEN 形式で 2 行（Before/After）になっているか: YES。
- Before: IF S1/S2 reveals a clear structural gap THEN proceed directly to FORMAL CONCLUSION with NOT EQUIVALENT.
- After: IF S1/S2 reveals a clear structural gap and COUNTEREXAMPLE can state different relevant outcomes for A/B THEN proceed to NOT_EQUIV; otherwise carry the gap into ANALYSIS.
- ただし、After の条件が `different relevant outcomes` だけだと、条件の中に assertion boundary がないため、分岐としては具体化不足。
- Trigger line が差分プレビュー内に含まれているか: YES。

2) Failure-mode target
- 減らしたい誤判定: 主に偽 NOT_EQUIV。構造差ラベルだけで NOT_EQUIV にする誤りを、outcome witness 不在なら ANALYSIS 継続へ変えることで減らす。
- 副作用として偽 EQUIV への影響: 真の NOT_EQUIV は outcome witness を書ける場合に維持する設計だが、assertion boundary を削ると反例品質が下がり、偽 NOT_EQUIV も偽 EQUIV も検出が不安定になりうる。

2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？
- YES。
- NOT_EQUIV の根拠が「ファイル差がある」だけに退化していないか: 意図としては退化を避けている。
- impact witness（PASS/FAIL に結びつく具体的な分岐＝assertion boundary を 1 つ目撃できる形）を提案が要求しているか: NO。
- 理由: After プレビューは `Outcome witness: Change A => [PASS/FAIL or behavior], Change B => [PASS/FAIL or behavior]` であり、既存の `Diverging assertion: [test_file:line ...]` を残していない。`behavior` でも可としているため、D1 の test outcome へ接続する assertion boundary が必須になっていない。

3) Non-goal
- 変えないこと: 新しい探索モードは増やさない。構造差を特定の証拠種類へ固定しない。既存 COUNTEREXAMPLE 欄の置換に留め、必須ゲート総量は増やさない。
- 追加すべき境界条件: `Diverging assertion` 相当の impact witness は削らず、Outcome witness の下に統合する。これは新規ゲート追加ではなく、既存行の保持・圧縮として扱うべき。

## Discriminative probe（必須）

抽象ケース: 片方だけが補助 artifact を変更しているが、関連テストの assertion はその artifact を通らない。変更前は `missing file` という構造差ラベルだけで偽 NOT_EQUIV に進みがち。

変更後の理想形では、A/B の PASS/FAIL 差と diverging assertion を書けないため ANALYSIS に戻り、実際に assertion outcome が同じなら EQUIV に近づく。一方、片方だけが import/load 失敗で特定 assertion または setup boundary に到達できない場合は、impact witness を書けるため NOT_EQUIV を維持できる。

ただし現 proposal の After 文面では `behavior` 差だけでも witness に見えてしまうため、この probe の判別力を十分に実装できていない。

## 支払い（必須ゲート総量不変）の検証

Payment の A/B 対応付けは明示されている。

ただし、支払い対象が不正確である。提案は `Test [name] will ...` 2 行の置換を述べているが、差分プレビューでは既存の `Diverging assertion` 行も消えている。ここは削除してはいけない。追加ではなく、次のように統合して支払うべきである。

- 削る/統合する: 既存の A/B の Test 2 行を 1 行の Outcome witness に圧縮する。
- 残す/統合する: `Diverging assertion` は `Impact witness: [test_file:line or setup/check boundary] where the predicted outcomes diverge` として保持する。

## 修正指示（2〜3 点）

1. After プレビューで `Diverging assertion` を削らず、Outcome witness に統合してください。
   - 例: `Impact witness: [test_file:line or setup/check boundary] where the structural gap changes the relevant PASS/FAIL outcome.`
   - これは新規必須ゲート追加ではなく、既存 `Diverging assertion` 行の置換・圧縮として扱うこと。

2. `PASS/FAIL or behavior` の `or behavior` を早期 NOT_EQUIV 条件から外すか、`behavior only is insufficient unless tied to the relevant test outcome` と明記してください。
   - D1 が test outcome ベースなので、behavior 差だけで早期結論できる書き方は避ける。

3. Payment を修正し、削除する行と保持・統合する行の対応を明示してください。
   - `Test [name]...` 2 行は `Outcome witness` へ圧縮。
   - `Diverging assertion` は `Impact witness` として保持。

## 最大ブロッカー

STRUCTURAL TRIAGE / 早期 NOT_EQUIV に触れる提案なのに、差分プレビューが既存の `Diverging assertion` を削除し、impact witness（PASS/FAIL に結びつく具体的な assertion/check boundary）を必須としていないこと。

このままでは、構造差ラベルだけでの早期 NOT_EQUIV を防ぐ目的は良いが、実装後に `relevant outcome` や `behavior` という曖昧な説明で早期結論する余地が残り、compare の実行時アウトカム差が不安定になる。

承認: NO（理由: 早期 NOT_EQUIV に必要な impact witness を差分プレビューが要求しておらず、既存の `Diverging assertion` を削っているため）
