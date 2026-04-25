# Iteration 56 — proposal discussion

## 1. 既存研究との整合性

検索なし（理由: 一般原則の範囲で自己完結）。

提案は、README.md / docs/design.md にある「certificate-based reasoning」「per-test iteration」「evidence gathering before judgment」と整合する。特に docs/design.md は、Patch Equivalence Verification の中核を「Per-test iteration, formal definitions of equivalence, counterexample obligation」と整理しており、今回の変更は per-test loop を維持したまま、各 test 内で PASS/FAIL ラベルより先に観測対象を明示させる順序変更である。外部概念への強い依拠はなく、Web 検索は不要。

## 2. Exploration Framework のカテゴリ選定

カテゴリ A「推論の順序・構造を変える」は適切。

理由:
- 変更の本体は、新しい証拠種類や新しい判定カテゴリの追加ではなく、既存の per-test 分析内の順序を入れ替えること。
- 現行 SKILL.md では `Claim C[N].1` / `Claim C[N].2` が先に来るため、A/B それぞれの PASS/FAIL ラベルが先行しやすい。
- 提案後は `Observed assert/check` と `Expected observable` を先に置き、その同じ観測対象へ A/B を trace するため、まさに「ステップの実行順序を入れ替える」「並列的に書いていた side claim を同一観測対象へ直列化する」変更である。

汎用原則としても、比較対象を同じ観測点に揃えてから両側の結果を述べることは、パッチ等価性判定において自然である。ただし、assert/check を「唯一の探索起点」に固定しすぎると failed-approaches.md 原則 3/5 に近づくため、実装時は「各 relevant test の観測対象を先に確認する」範囲に留めるのがよい。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用

EQUIVALENT への作用:
- 変更前は、内部実装差や中間値差を先に PASS/FAIL claim へ投影し、観測されない差分まで NOT_EQUIV に寄せる余地がある。
- 変更後は、実テストが見る assert/check を先に固定するため、内部差分が同じ観測結果へ到達するなら EQUIV を支える trace が書きやすくなる。
- ただし「差分が観測されないはず」という主張は、既存の NO COUNTEREXAMPLE EXISTS 義務と接続される必要がある。ここは提案の scope 内で維持されている。

NOT_EQUIVALENT への作用:
- 変更前は、A/B の PASS/FAIL claim を先に書いてしまい、根拠が「構造差がある」「片側の内部意味が違う」だけに退化する可能性がある。
- 変更後は、同じ assert/check に向けて A/B を trace するため、NOT_EQUIV を出す場合に「どの観測点で PASS/FAIL が分かれるか」を明示しやすくなる。
- これは偽 NOT_EQUIV を減らす一方、真 NOT_EQUIV では divergence の assertion boundary を明確にする方向に働く。

片方向最適化か:
- 片方向だけではない。EQUIV 側では「表面差・内部差が観測結果へ出ない」ことを確認しやすくし、NOT_EQUIV 側では「同じ観測対象で結果が分かれる」ことを要求しやすくする。
- ただし、assert/check 先行が過度に強くなると、探索範囲をテスト assertion 周辺へ狭めすぎるリスクはある。proposal は Payment と Non-goal により、必須ゲート増や STRUCTURAL TRIAGE の変更を避けているため許容範囲。

## 4. failed-approaches.md との照合

本質的な再演ではないと判断する。

照合:
- 原則 1「再収束を比較規則として前景化しすぎない」: NO。提案は「共有観測点で再収束したら差分を弱める」規則ではなく、各 test の観測対象を先に読む順序変更である。
- 原則 2「未確定 relevance や脆い仮定を常に保留側へ倒す」: NO。UNVERIFIED への fallback を新たな既定動作として追加していない。
- 原則 3「差分の昇格条件を新しい抽象ラベルや必須の言い換え形式で強くゲート」: 概ね NO。新しい分類ラベルはない。ただし `Observed assert/check` が「差分を比較証拠へ昇格するための新 gate」として運用されると危険なので、実装では既存 per-test trace 行の置換に留めるべき。
- 原則 5「最初に見えた差分から単一の追跡経路を即座に既定化」: NO。最初に見えた差分ではなく、各 relevant test の観測対象を起点にするため、単一差分へのアンカーではない。
- 原則 6「探索理由と情報利得を短い要求へ潰しすぎる」: NO。探索理由欄の統合ではない。

## 5. 汎化性チェック

固有識別子チェック:
- 具体的なベンチマーク ID: なし。
- リポジトリ名: なし。
- 実テスト名: なし。`Test: [name]` は SKILL.md テンプレート自己引用であり問題ない。
- 実コード断片: なし。差分プレビューは SKILL.md のテンプレート文言であり、Objective.md の R1 減点対象外に該当する。
- 特定言語・フレームワーク前提: なし。

暗黙のドメイン偏り:
- `assert/check` という語はテスト一般の oracle を指すため、Go/JS/TS/Python などに限定されない。
- `file:line` は既存 SKILL.md 全体の証拠形式であり、新しいドメイン依存ではない。

汎化性は満たしている。

## 6. 推論品質の期待改善

期待できる改善:
- PASS/FAIL ラベル先行による premature conclusion を減らす。
- A/B を別々にもっともらしく説明した後で比較するのではなく、同じ assert/check に対する paired trace へ寄せることで、比較の対象が揃う。
- 偽 NOT_EQUIV では、内部差分を観測差と混同する誤りを減らす。
- 偽 EQUIV では、表面上の同一ラベルだけで済ませず、同じ観測点への trace を要求するため、実際には片側だけ diverge する経路を拾いやすくなる。
- 既存の反証義務や NO COUNTEREXAMPLE EXISTS の改善を削らず、per-test block の局所的な順序変更に収まるため、変更規模に対する効率がよい。

## 停滞診断（必須）

監査 rubric に刺さる説明強化へ偏り、compare の意思決定を変えていない懸念:
- 懸念は小さい。proposal は単なる説明強化ではなく、`Claim C[N].1/2` より前に `Observed assert/check` を置く差分プレビューと Trigger line を示しており、実行時に per-test 分析の書き出し順が変わる。

failed-approaches.md の停滞パターン:
- 探索経路の半固定: NO。各 relevant test の観測対象を先に読むだけで、最初の差分から単一経路へ固定しない。
- 必須ゲート増: NO。Payment で既存 checklist 1 行の置換を明示しており、総量不変を意図している。
- 証拠種類の事前固定: NO。テストの assert/check は patch equivalence の既存証拠対象であり、新しい証拠種類の固定ではない。ただし実装時に assertion 以外の observable を排除しないよう `assert/check or observable` の意味を保つと安全。

## compare 影響の実効性チェック（必須）

0) 実行時アウトカム差:
- per-test 分析で、A/B の PASS/FAIL を先に書かず、まず `Observed assert/check` と expected observable を書くようになる。
- 同じ check へ trace できない場合、ANSWER 確定前に追加探索または UNVERIFIED 明示へ倒れやすくなる。
- NOT_EQUIV では、差分の根拠が構造差・内部差だけでなく、同じ check での PASS/FAIL divergence として表現されやすくなる。

1) Decision-point delta:
- IF/THEN 形式で 2 行（Before/After）になっているか？ YES。
- Before: IF a relevant test is selected THEN predict Change A PASS/FAIL and Change B PASS/FAIL before naming the observed assert/check because the template orders side claims before comparison.
- After: IF a relevant test is selected THEN name the observed assert/check and expected observable first, then trace Change A and Change B to that same check before PASS/FAIL because the template orders observation target before side claims.
- 条件も行動も同じ言い換えか？ NO。行動が「PASS/FAIL 先行」から「観測対象先行」へ変わっている。
- Trigger line が差分プレビュー内に含まれるか？ YES。`Trigger line (planned): "Observed assert/check: [file:line and expected observable]"` がある。

2) Failure-mode target:
- 対象は両方。
- 偽 EQUIV: 表面上の PASS/PASS 予測だけで比較を閉じる前に、同じ assert/check への A/B trace を要求することで、片側だけ観測点へ違う値・例外・状態を届けるケースを拾いやすくする。
- 偽 NOT_EQUIV: 内部差分や構造差を PASS/FAIL 差へ短絡する前に、実テストが見る assert/check を固定することで、観測されない内部差を NOT_EQUIV にしにくくする。

2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？
- NO。proposal は明示的に `STRUCTURAL TRIAGE` の早期 NOT_EQUIV 条件を変更しないとしており、変更対象は ANALYSIS OF TEST BEHAVIOR の per-test block と checklist 1 行である。
- impact witness 要求の確認は、STRUCTURAL TRIAGE 変更ではないため必須ブロッカーではない。ただし NOT_EQUIV の場合は既存 `Diverging assertion` と今回の `Observed assert/check` が自然に impact witness として機能する。

3) Non-goal:
- 探索経路を半固定しない。各 relevant test ごとの観測対象を先に読むだけで、最初の差分から単一経路へ固定しない。
- 必須ゲート総量を増やさない。`Trace each test through both changes separately before comparing` を `Observed assert/check before predicting either side` へ置換する。
- 証拠種類を新たに固定しない。assert/check は既存の test outcome 証拠を明示するものであり、他の relevant observable を排除しない。

## 追加チェック: Discriminative probe

抽象ケース:
- 2 つの変更は内部の分岐構造が違うが、 relevant test は最終的な戻り値の equality check だけを見る。
- 変更前は、内部分岐差を先に A/B の PASS/FAIL claim へ投影して偽 NOT_EQUIV、または両方とも「正常化する」と表面ラベルだけで偽 EQUIV にしがち。
- 変更後は、最初に equality check と expected observable を固定し、両側がその check に同じ値を届けるかを trace するため、観測差がある場合だけ NOT_EQUIV、観測差がない場合は EQUIV または impact UNVERIFIED に分岐できる。

これは新しい必須ゲート追加ではなく、既存 per-test trace 行の順序入替・置換として説明されている。

## 追加チェック: 支払い（必須ゲート総量不変）

Payment は明示されている。

- Add: `For each relevant test, identify the observed assert/check before predicting either side`
- Demote/remove: `Trace each test through both changes separately before comparing`

A/B の対応付けがあるため、必須ゲート総量不変の説明として十分。

## 最小修正指示

承認可能だが、実装時は以下の 2 点だけ注意すること。

1. `Observed assert/check` は新規ゲートとして追加せず、既存の per-test trace / checklist 行を置換すること。Payment の通り、必須行数を増やさない。
2. `assert/check` を狭く解釈して assertion 文だけに限定しないこと。テストが観測する expected observable（例: 戻り値、例外、出力、状態変化）を含む表現にする。

## 総合判断

提案は、既存研究の certificate / per-test iteration のコアを維持しつつ、compare 実行時の意思決定順序を実際に変える。failed-approaches.md の本質的再演ではなく、固有識別子や特定ドメイン依存も見当たらない。Decision-point delta、Trigger line、Payment、Discriminative probe が揃っており、「監査に通りやすいだけで compare に効きにくい」提案ではない。

承認: YES
