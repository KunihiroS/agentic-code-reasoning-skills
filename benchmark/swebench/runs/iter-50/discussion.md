# iter-50 proposal discussion

## 1. 既存研究との整合性

検索なし（理由: 提案は「次の探索を、未解決 claim を confirm/refute できる情報利得で選ぶ」という一般的な仮説駆動探索・反証可能性の明確化であり、特定の外部概念や固有用語に強く依拠していないため）。

README.md / docs/design.md との整合性は概ね高い。既存設計の中核は、premise、hypothesis-driven exploration、interprocedural tracing、mandatory refutation、formal conclusion によって unsupported claim を減らすことにある。今回の変更はそのうち Step 3 の探索前記録を、単なる confidence ラベルから「どの EQUIV/NOT_EQUIV claim を左右する読解か」へ寄せるもので、研究コアの削除ではなく、証拠収集前の反証可能性を強める変更と見なせる。

## 2. Exploration Framework のカテゴリ選定

カテゴリ B「情報の取得方法を改善する」は適切。

理由:
- 提案は結論規則そのものを変えるのではなく、次に読む情報の優先順位を変える。
- 「何を探すか」を特定ファイル・特定テスト・特定パターンに固定せず、「この読解がどの未解決 verdict claim を反転しうるか」という探索基準を変えている。
- カテゴリ D の自己チェック強化やカテゴリ E の単なる表現改善ではなく、実行時の探索分岐に作用するため、B としての説明は妥当。

## 3. EQUIVALENT / NOT_EQUIVALENT 双方への作用

EQUIVALENT への作用:
- 変更前は plausible hypothesis と confidence があるだけで近いファイルを読み続け、NO COUNTEREXAMPLE EXISTS の検索対象が verdict 反転条件と弱く結びつく可能性がある。
- 変更後は「どの反対 outcome を検出する読解か」を言えない場合、別探索・UNVERIFIED/LOW に倒すため、偽 EQUIV を減らす方向に働く。

NOT_EQUIVALENT への作用:
- 変更前は目立つ構造差・局所差に confidence を付けて読み進め、実際の test outcome への接続が弱いまま NOT_EQUIV へ進む危険がある。
- 変更後は差分読解にも EQUIV/NOT_EQUIV claim の confirm/refute 関係を要求するため、outcome に効かない差分だけで偽 NOT_EQUIV に進む圧力を下げる。

片方向最適化か:
- 片方向ではない。EQUIV 側では反例探索の焦点化、NOT_EQUIV 側では差分から outcome divergence への接続確認として働く。
- ただし、discriminative query が形式的な言い換えだけになると、監査説明は強くても compare の探索分岐は変わらない。この懸念は Trigger line と Decision-point delta が明示されているため、現提案では許容範囲。

## 4. failed-approaches.md との照合

本質的再演ではないと判断する。

- 原則 1「再収束を比較規則として前景化しすぎない」: 該当しない。再収束や共有観測点を優先する規則ではない。
- 原則 2「未確定 relevance や脆い仮定を常に保留側へ倒す」: 該当しない。未検証なら常に保留ではなく、verdict-discriminative な探索が言えるかで次行動を選ぶ。
- 原則 3「新しい抽象ラベルや必須の言い換え形式で強くゲート」: 軽微な注意はある。DISCRIMINATIVE QUERY という新しい欄は追加されるが、差分の抽象分類ラベルではなく、既存の hypothesis exploration の confidence 行を置換するため、分類整合の目的化までは行っていない。
- 原則 4「証拠十分性を confidence 調整へ吸収」: むしろ confidence 行を削り、探索時の反証可能性に置換するため逆方向。
- 原則 5「最初の差分から単一追跡経路を既定化」: 該当しない。別探索を許容しており、単一路線への固定ではない。
- 原則 6「探索理由と情報利得を潰す」: 該当しない。NEXT ACTION RATIONALE と DISCRIMINATIVE QUERY を分けており、optional info gain の消滅分を独立必須行へ移している。

## 5. 汎化性チェック

固有識別子の有無:
- 具体的な数値 ID: なし。
- リポジトリ名: なし。
- テスト名: なし。
- 実コード断片: なし。
- SKILL.md 自身の文言引用: あり。ただし Objective.md の R1 減点対象外に該当する自己引用であり問題なし。

暗黙のドメイン前提:
- 「同じ関数名」「caller」は一般的な抽象例として許容範囲。特定言語・フレームワーク・テストパターンには依存していない。
- 「caller/outcome」を例にしているが、呼び出し関係を持たない宣言的設定やデータ変換比較にも「verdict claim を反転する証拠」という形で適用できる。

## 6. compare 影響の実効性チェック

0) 実行時アウトカム差:
- Step 3 で次ファイルを読む前に、ANSWER を左右する未解決 EQUIV/NOT_EQUIV claim と confirm/refute 条件を言えない読解が後回しになる。
- その結果、追加探索の要求、UNVERIFIED 明示、LOW confidence への倒し方が観測可能に変わる。
- NO COUNTEREXAMPLE EXISTS でも、検索対象が反対 outcome の検出条件と結びつかない場合に、そのまま EQUIV へ進みにくくなる。

1) Decision-point delta:
- IF/THEN 形式で 2 行（Before/After）になっているか？ YES。
- Before: IF a plausible hypothesis and supporting evidence can be stated THEN open the next file because confidence is labeled high/medium/low.
- After: IF the next read can name an unsettled EQUIV/NOT_EQUIV claim and evidence that would confirm vs refute it THEN open that file; otherwise choose a different query or mark the claim UNVERIFIED/LOW.
- これは条件も行動も同じ言い換えではない。条件は「plausible hypothesis」から「verdict-discriminative evidence を予告できる」へ変わり、行動も「読む」から「読む / 別探索 / UNVERIFIED/LOW」へ分岐している。
- Trigger line が差分プレビュー内に含まれているか？ YES。`DISCRIMINATIVE QUERY: [which unsettled EQUIV/NOT_EQUIV claim this read can confirm vs refute]` が自己引用されている。

2) Failure-mode target:
- 対象は両方。
- 偽 EQUIV: 反対 outcome を検出する探索条件が曖昧なまま no counterexample を主張することを減らす。
- 偽 NOT_EQUIV: outcome に効かない構造差・局所差だけで divergence と見なすことを減らす。
- メカニズムは、次の読解を verdict claim の confirm/refute に結びつけることで、単なる plausible exploration を判別的 exploration に変えること。

2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？ NO。
- Structural triage の早期 NOT_EQUIV 条件を直接変更していない。
- したがって impact witness 要求の有無はこの proposal の承認ブロッカーではない。
- ただし実装時に Structural triage へ波及させるなら、「ファイル差がある」だけではなく、test outcome / assertion boundary に効く witness を要求する形に限定すべき。

3) Non-goal:
- 探索経路を最初の差分・単一 caller・単一 assertion へ固定しない。
- 新しい証拠種類を事前固定しない。confirm/refute される claim を求めるだけで、証拠が test、call path、configuration、data mapping のどれであるかは固定しない。
- 必須ゲート総量は増やさない。CONFIDENCE 行を demote/remove する支払いで DISCRIMINATIVE QUERY を置く。

## 7. Discriminative probe

抽象ケース:
- 2 つの変更が同じ表面差分を持つが、片方だけ既存の assertion outcome に到達する経路へ接続され、もう片方は到達不能な補助経路に閉じている。
- 変更前は、表面差分への confidence が高いだけで偽 NOT_EQUIV、または近い定義だけを読んで到達経路を見落とし偽 EQUIV が起きうる。
- 変更後は「この読解が到達可能な assertion outcome の同一/差異 claim を confirm/refute するか」を言えない探索を後回しにするため、追加探索または LOW/UNVERIFIED に留まり誤判定を避けやすい。

これは新しい必須ゲートを純増する提案ではなく、CONFIDENCE 行を DISCRIMINATIVE QUERY に置換し、optional info gain の役割を独立欄として再配置する提案なので、支払いは明示されている。

## 8. 停滞診断

監査 rubric に刺さる説明強化へ偏り、compare の意思決定を変えていない懸念:
- 懸念は小さい。提案は単に「反証可能性が大事」と説明するだけでなく、Step 3 の次アクション選択を「confidence 付き仮説があるか」から「verdict claim を反転しうる証拠を予告できるか」へ変えているため、実行時の探索分岐が観測可能に変わる。

failed-approaches.md 該当性:
- 探索経路の半固定: NO。理由: 最初の差分や単一経路への固定ではなく、別探索を明示的に許す。
- 必須ゲート増: NO。理由: DISCRIMINATIVE QUERY は追加されるが、CONFIDENCE 行の demote/remove と対応しており、必須行の純増ではない。
- 証拠種類の事前固定: NO。理由: evidence that would confirm vs refute を求めるだけで、証拠種類やアンカーを固定していない。

支払い（必須ゲート総量不変）:
- A/B 対応は proposal 内で明示されている。`add MUST("DISCRIMINATIVE QUERY...") ↔ demote/remove MUST("CONFIDENCE...")` があり、必須ゲート総量不変の説明として十分。

## 9. 全体の推論品質への期待効果

期待できる改善:
- 読む前の hypothesis が単なる予想ではなく、verdict を動かす claim と結びつく。
- CONFIDENCE の主観ラベルに早く寄りかかる傾向を抑え、探索段階で confirm/refute 条件を持たせられる。
- EQUIV では no counterexample の検索対象が具体化し、NOT_EQUIV では差分から test outcome divergence への接続が強くなる。
- Optional info gain が使われないまま流れる問題を、必須の探索クエリとして前段に移すことで、証拠収集の順序が改善する。

軽微な実装注意:
- DISCRIMINATIVE QUERY が長い説明欄になりすぎると原則 3 の「言い換え形式の目的化」に近づくため、実装は 1 行の探索分岐条件に留めるべき。
- NEXT ACTION RATIONALE と統合せず、proposal どおり独立欄にすること。
- Structural triage の早期 NOT_EQUIV 条件へ追加変更しないこと。触る場合は別 proposal として impact witness を明示させるべき。

## 結論

この proposal は、汎化性違反がなく、failed-approaches.md の本質的再演でもなく、EQUIVALENT / NOT_EQUIVALENT の両方に対して観測可能な compare 実行時差分を持つ。Decision-point delta、Trigger line、Discriminative probe、支払い対応も明示されているため、監査 PASS の下限を満たす。

承認: YES
