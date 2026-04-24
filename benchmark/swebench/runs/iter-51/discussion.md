# iter-51 proposal discussion

## 1. 既存研究との整合性

検索なし（理由: 提案は特定の外部概念・固有用語・新規研究主張に強く依拠しておらず、既存 SKILL.md / docs/design.md にある patch equivalence verification の per-test iteration、test outcome、counterexample obligation の一般原則の範囲で自己完結している）。

整合性としては、docs/design.md の「Patch Equivalence Verification は per-test iteration と formal definitions of equivalence / counterexample obligation を enforced する」という設計に合う。README.md でも compare は「同じ behavioral outcome」を判定するモードであり、SKILL.md の D1 は relevant test suite の pass/fail outcome 同一性を equivalence の定義にしている。したがって、raw semantic difference ではなく traced assert/check result を比較単位にする方向は、既存コアを外すのではなく、既存定義 D1 を per-test Comparison 欄へより強く接続する変更と見なせる。

## 2. Exploration Framework のカテゴリ選定

カテゴリ C「比較の枠組みを変える」は概ね適切。

理由:
- 提案の主眼は探索順や情報取得方法ではなく、Comparison 欄で何を SAME / DIFFERENT とみなすかという比較粒度の変更である。
- 「内部挙動差」から「test outcome を運ぶ assert/check result」へ寄せるため、比較フレームの変更として自然。
- ただし完全な新規フレームではなく、既存 D1 と per-test analysis を明確化する小変更なので、カテゴリ C の中でも「枠組みの再定義」ではなく「既存比較単位の判定境界の明確化」と位置付けるのがよい。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用

EQUIVALENT 側:
- 内部表現・中間状態・実装経路が異なっても、関連テストの assert/check result が同一に trace できる場合、内部差分だけで DIFFERENT に倒す偽 NOT_EQUIV を減らす。
- ただし「同じ assert/check に到達した」という説明だけで差分を無視するのではなく、result が同じであることを trace する必要があるため、failed-approaches.md 原則1の「再収束を前景化しすぎる」失敗とは少し異なる。

NOT_EQUIVALENT 側:
- 内部挙動の説明が似ている、または大枠の設計が似ている場合でも、assert/check に渡る最終値・例外・状態が片側だけ変わるなら DIFFERENT assertion-result outcome として拾いやすくなる。
- NOT_EQUIV の根拠が「構造差がある」「内部挙動が違う」だけで止まらず、どの assertion/check の result が変わるかへ接続されるため、偽 NOT_EQUIV の抑制と同時に真 NOT_EQUIV の根拠品質も上がる。

片方向性:
- 片方向だけの最適化ではない。偽 NOT_EQUIV には「semantic difference だけでは verdict-bearing にしない」と作用し、偽 EQUIV には「semantic similarity だけでなく assertion-result divergence を見る」と作用する。
- ただし Payment で Step 5.5 の「actual file search or code inspection」MUST を demote/remove する点は、反証フロアを下げすぎないよう実装時に注意が必要。削るなら、per-test assert/check result の trace 文言に file:line evidence requirement を残すことが条件。

## 4. failed-approaches.md との照合

原則1「再収束を比較規則として前景化しすぎない」:
- 類似リスクはある。assert/check result を重視することは、下流一致を重視する方向に見えるため。
- しかし提案は「途中差分を弱める」のではなく「内部 semantic difference は separately note し、result を変える場合だけ verdict-bearing」としている。再収束の説明を既定化するのではなく、D1 の test outcome 定義へ比較欄を合わせる変更なので、本質的再演とは判断しない。

原則2「未確定 relevance や脆い仮定を常に保留へ倒す既定動作にしすぎない」:
- 「assert/check result が未追跡なら impact UNVERIFIED」は局所的で verdict-bearing な場合に限定されており、未確定一般を広く保留に送る規則ではない。再演ではない。

原則3「差分の昇格条件を新しい抽象ラベルや必須の言い換え形式で強くゲートしすぎない」:
- 新しい抽象ラベルは導入していない。Comparison 欄の既存 outcome を assertion-result outcome と明確化している。
- ただし実装で「必ず同じ assert/check を先に特定せよ」という探索アンカーに変質すると原則3/5へ近づくため、文言は「relevant test の traced assert/check result」とし、探索開始点を固定しないこと。

原則4「証拠十分性チェックを confidence 調整へ吸収しすぎない」:
- Payment で Step 5.5 の実ファイル確認 MUST を demote/remove する案はここに軽い懸念がある。完全削除ではなく、per-test trace の file:line 要求へ統合する形なら許容可能。

原則5「最初に見えた差分から単一の追跡経路を即座に既定化しすぎない」:
- 提案は最初の差分から単一経路へ固定するものではなく、既存の relevant test ごとの Comparison 欄の判定粒度を変えるもの。再演ではない。

原則6「近接する欄の統合で探索理由と反証可能な情報利得を潰しすぎない」:
- Payment が refutation/search 要件を圧縮するため、実装時に反証可能性が薄くなるリスクはある。削る対象と追加する文言の A/B 対応は proposal 内で明示されているため、現段階では許容。

## 5. 汎化性チェック

固有識別子:
- 具体的なベンチマーク ID、リポジトリ名、実テスト名、実コード断片は含まれていない。
- `file:line`, `test_file:line`, `Change A/B`, `assert/check` は SKILL.md 自身のテンプレート引用または汎用疑似表現であり、Objective.md の R1 減点対象外に該当する。

ドメイン・言語偏り:
- assert/check という語はテスト一般の oracle を指す表現で、Go/JS/TS/Python いずれにも対応可能。
- 特定フレームワーク、特定テストランナー、特定言語構文への依存はない。
- 「assert/check result」だけに寄せすぎると snapshot test、golden file、exception expectation、property-style check などの非 assert 名称の oracle を取りこぼす懸念はあるため、実装では `assert/check/oracle` 程度に広げるとさらに汎用性が上がる。ただし現 proposal のままでも重大な汎化性違反ではない。

## 6. compare 影響の実効性チェック

0) 実行時アウトカム差:
- Comparison 欄で、内部 semantic difference があっても traced assert/check result が同じなら SAME と明記するようになる。
- traced assert/check result が未確認なら、semantic difference だけで NOT_EQUIV にせず impact UNVERIFIED / lower confidence に倒す条件が明確になる。
- 逆に assert/check result が異なるなら、内部説明が似ていても DIFFERENT とする根拠が強くなる。

1) Decision-point delta:
- IF/THEN 形式で 2 行（Before/After）になっているか？ YES。
- Before/After は「理由だけ言い換え」ではなく、semantic behavior differs の場合に DIFFERENT へ進むか、assert/check result 同一なら SAME / 未追跡なら UNVERIFIED へ分岐するかが変わっている。
- Trigger line が差分プレビュー内に含まれているか？ YES。proposal line 66 に planned Trigger line がある。

Before:
- IF relevant-path semantic behavior differs THEN mark Comparison as DIFFERENT or pursue NOT_EQUIV.

After:
- IF semantic behavior differs but traced assert/check result is identical THEN mark SAME; IF result is not traced THEN mark impact UNVERIFIED rather than using semantic difference as verdict.

2) Failure-mode target:
- 対象は両方。
- 偽 NOT_EQUIV: 内部差分を test outcome 差と誤読するケースを、assert/check result の同一性確認で抑える。
- 偽 EQUIV: 内部説明の類似や大枠の一致で安心し、最終 oracle の差を見落とすケースを、assert/check result divergence の明示で抑える。

2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？ NO。
- proposal は STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件自体を変更していない。
- そのため impact witness 要件の追加有無は主要判定対象ではない。
- ただし将来この文言を structural gap にも適用するなら、「ファイル差がある」だけでなく、test outcome に結びつく assertion/oracle boundary を 1 つ目撃する形にする必要がある。

3) Non-goal:
- 探索経路を単一の assert/check から逆算するよう半固定しない。
- 新しい必須ゲート総量を増やさない。proposal の Payment 通り、追加 MUST は既存 Step 5.5 MUST の demote/remove または統合で支払う。
- 証拠種類を「assert 文」だけに固定せず、check / oracle / expected exception / output comparison など test outcome を運ぶ境界として扱う。

## 7. 停滞診断

監査 rubric に刺さる説明強化へ偏り、compare の意思決定を変えていない懸念:
- 低い。proposal は Decision-point delta、Trigger line、Discriminative probe、Payment を持ち、Comparison 欄で SAME / DIFFERENT / UNVERIFIED の分岐が実際に変わる。

failed-approaches.md 該当性:
- 探索経路の半固定: NO。理由: selected branch は per-test Comparison 欄の比較粒度変更であり、最初の差分から単一の追跡経路へ固定していない。
- 必須ゲート増: NO。理由: Payment で追加 MUST と既存 MUST の demote/remove 対応が明示されている。ただし実装時に両方 MUST として残すなら YES に転ぶ。
- 証拠種類の事前固定: NO。理由: assert/check は既存 test outcome の汎用境界として使われている。ただし `assert` という構文だけに限定する実装なら YES に転ぶ。

支払い（必須ゲート総量不変）:
- proposal 内で A/B 対応付けが明示されている。add MUST と demote/remove MUST が line 49 で対応しているため、この必須チェックは満たす。

## 8. Discriminative probe

抽象ケース:
- 2 つの変更が入力を異なる内部表現へ正規化するが、テスト oracle が読む最終値は同じである。変更前は内部表現差を DIFFERENT と読み偽 NOT_EQUIV になりやすいが、変更後は traced oracle result が同じなら SAME にできる。
- 逆に、両変更とも同じ関数経路を通り説明上は似ているが、片側だけ expected exception / check value が変わる。変更後は assertion-result divergence を見るため、偽 EQUIV を避けやすい。
- これは新しい必須ゲートの追加ではなく、既存 per-test Comparison 欄の置換と Step 5.5 の一部統合による総量不変の変更として説明されている。

## 9. 全体の推論品質への期待効果

期待できる改善:
- D1 の「test suite pass/fail outcomes」と ANALYSIS OF TEST BEHAVIOR の Comparison 欄がより直接につながる。
- semantic difference を見つけた後の扱いが、過大評価（偽 NOT_EQUIV）と過小評価（偽 EQUIV）の両方に対して対称になる。
- per-test certificate の出力が、内部挙動説明と verdict-bearing result を分けるため、結論の根拠が読みやすくなる。
- UNVERIFIED の発火条件が「verdict-bearing assert/check result が未追跡」の場合に限定され、広い保留化を避けつつ、根拠不足の conclusion を抑えられる。

軽微な修正指示:
1. `assert/check` は実装時に `assert/check/oracle` のように少し広げ、構文上の assert に証拠種類を固定しないこと。
2. Payment は必ず実行し、追加 MUST を入れる代わりに Step 5.5 の actual search/code inspection MUST を削除ではなく per-test trace の file:line requirement へ統合すること。反証フロアを confidence 記述へ吸収しない。
3. `same assert/check` を「探索開始点」にはしないこと。文言は relevant test を trace した結果としての oracle boundary を比較する、という順序に保つこと。

承認: YES
